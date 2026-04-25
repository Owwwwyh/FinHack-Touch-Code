#!/usr/bin/env python3
"""
XGBoost training pipeline for credit-score safe-offline-balance model
Reads synthetic data, computes features, trains model, outputs metrics

See docs/04-credit-score-ml.md §5-7 for model architecture and training
"""

import argparse
import json
import logging
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
import pandas as pd
import xgboost as xgb
from sklearn.metrics import mean_squared_error, r2_score
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class FeatureEngineer:
    """Compute 20 features from raw transaction data"""

    @staticmethod
    def compute_features(user_df: pd.DataFrame, reference_date: datetime = None) -> Dict[str, float]:
        """
        Compute all 20 features for a single user

        Args:
            user_df: DataFrame of transactions for one user (sorted by ts)
            reference_date: Reference date for feature computation (default: now)

        Returns:
            Dictionary with f01-f20 feature keys
        """
        if reference_date is None:
            reference_date = datetime.now()

        features = {}

        # f01-f02: Transaction counts
        thirty_days_ago = reference_date - timedelta(days=30)
        ninety_days_ago = reference_date - timedelta(days=90)
        spends_30d = user_df[
            (user_df["ts"] >= thirty_days_ago)
            & (user_df["ts"] < reference_date)
            & (~user_df["is_reload"])
        ]
        spends_90d = user_df[
            (user_df["ts"] >= ninety_days_ago)
            & (user_df["ts"] < reference_date)
            & (~user_df["is_reload"])
        ]

        features["f01_tx_count_30d"] = len(spends_30d)
        features["f02_tx_count_90d"] = len(spends_90d)

        # f03-f05: Transaction amounts (30d)
        if len(spends_30d) > 0:
            features["f03_avg_tx_amount_30d"] = spends_30d["amount_myr"].mean()
            features["f04_median_tx_amount_30d"] = spends_30d["amount_myr"].median()
            features["f05_tx_amount_p95_30d"] = spends_30d["amount_myr"].quantile(0.95)
        else:
            features["f03_avg_tx_amount_30d"] = 0
            features["f04_median_tx_amount_30d"] = 0
            features["f05_tx_amount_p95_30d"] = 0

        # f06-f07: Unique payees
        features["f06_unique_payees_30d"] = spends_30d["payee_id"].nunique()
        features["f07_unique_payees_90d"] = spends_90d["payee_id"].nunique()

        # f08: Payee diversity (Shannon entropy)
        if len(spends_90d) > 0:
            payee_counts = spends_90d["payee_id"].value_counts()
            payee_probs = payee_counts / len(spends_90d)
            features["f08_payee_diversity_idx"] = float(
                -np.sum(payee_probs * np.log(payee_probs + 1e-9))
            )
        else:
            features["f08_payee_diversity_idx"] = 0

        # f09-f11: Reload features
        reloads_30d = user_df[
            (user_df["ts"] >= thirty_days_ago)
            & (user_df["ts"] < reference_date)
            & (user_df["is_reload"])
        ]
        features["f09_reload_freq_30d"] = len(reloads_30d)

        if len(reloads_30d) > 0:
            features["f10_reload_amount_avg"] = reloads_30d["amount_myr"].mean()
            days_since_reload = (
                reference_date - reloads_30d["ts"].max()
            ).total_seconds() / 86400
            features["f11_days_since_last_reload"] = days_since_reload
        else:
            features["f10_reload_amount_avg"] = 0
            features["f11_days_since_last_reload"] = 999  # No recent reload

        # f12: Time-of-day primary
        if len(spends_90d) > 0:
            hours = spends_90d["ts"].dt.hour
            features["f12_time_of_day_primary"] = float(hours.mode()[0]) if len(hours.mode()) > 0 else 12
        else:
            features["f12_time_of_day_primary"] = 12

        # f13: Weekday share
        if len(spends_90d) > 0:
            weekday_count = spends_90d["ts"].dt.weekday[spends_90d["ts"].dt.weekday < 5].count()
            features["f13_weekday_share"] = weekday_count / len(spends_90d)
        else:
            features["f13_weekday_share"] = 0.7

        # f14: Geographic dispersion
        if len(spends_90d) > 1:
            lat_std = spends_90d["lat"].std()
            lon_std = spends_90d["lon"].std()
            # Approximate distance std in km
            features["f14_geo_dispersion_km"] = (lat_std + lon_std) * 111
        else:
            features["f14_geo_dispersion_km"] = 0

        # f15-f16: Offline transaction history
        offline_txs = user_df[user_df["is_offline"]]
        features["f15_prior_offline_count"] = len(offline_txs)

        if len(offline_txs) > 0:
            clean_offline = offline_txs[offline_txs["settled_clean"] == True]
            features["f16_prior_offline_settle_rate"] = len(clean_offline) / len(offline_txs)
        else:
            features["f16_prior_offline_settle_rate"] = 1.0

        # f17: Account age
        signup_date = user_df["ts"].min()
        features["f17_account_age_days"] = (reference_date - signup_date).days

        # f18: KYC tier (set in separate step; placeholder here)
        features["f18_kyc_tier"] = 1

        # f19: Last sync age in minutes (set at inference; placeholder)
        features["f19_last_sync_age_min"] = 30  # Assume 30min old cache at training

        # f20: Device attestation (boolean)
        features["f20_device_attest_ok"] = 1

        return features

    @staticmethod
    def compute_label(user_df: pd.DataFrame, reference_date: datetime = None) -> float:
        """
        Compute safe offline balance label

        For synthetic data: the largest amount the user could have spent offline
        in the 30 days after reference_date without overdraft, given their
        cached balance and reload events.

        Simplified: estimate as median(spends_90d) * 1.5, capped at 500
        """
        if reference_date is None:
            reference_date = datetime.now()

        spends_90d = user_df[
            (user_df["ts"] >= reference_date - timedelta(days=90))
            & (~user_df["is_reload"])
        ]

        if len(spends_90d) == 0:
            return 100  # Conservative estimate for inactive users

        # Safe amount = median spend * 1.5 (some headroom)
        safe = spends_90d["amount_myr"].median() * 1.5
        return min(safe, 500)  # Hard cap at RM 500


class CreditScoreModelTrainer:
    """Train XGBoost model for safe-offline-balance"""

    def __init__(self, users_df: pd.DataFrame, transactions_df: pd.DataFrame):
        """Initialize with data"""
        self.users_df = users_df
        self.transactions_df = transactions_df

    def prepare_features_and_labels(self) -> Tuple[pd.DataFrame, pd.Series, pd.Series]:
        """Prepare feature matrix and labels"""
        logger.info("Computing features and labels...")

        X_data = []
        y_data = []
        user_ids = []

        for user_id, user_txs in self.transactions_df.groupby("user_id"):
            user_row = self.users_df[self.users_df["user_id"] == user_id]
            if len(user_row) == 0:
                continue

            # Merge transaction data with user profile
            user_txs = user_txs.copy()
            user_txs["kyc_tier"] = user_row["kyc_tier"].values[0]

            # Compute features and label
            features = FeatureEngineer.compute_features(user_txs.sort_values("ts"))
            label = FeatureEngineer.compute_label(user_txs.sort_values("ts"))

            X_data.append(features)
            y_data.append(label)
            user_ids.append(user_id)

        X_df = pd.DataFrame(X_data)
        y_series = pd.Series(y_data, name="safe_balance_label")

        logger.info(f"Computed {len(X_df)} feature vectors")
        logger.info(f"Feature columns: {sorted(X_df.columns)}")
        logger.info(f"Label stats: mean={y_series.mean():.2f}, std={y_series.std():.2f}")

        return X_df, y_series, pd.Series(user_ids)

    def train(self, test_size: float = 0.2) -> Dict[str, any]:
        """Train XGBoost model"""
        X, y, user_ids = self.prepare_features_and_labels()

        # Train-test split
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=test_size, random_state=42
        )

        logger.info(f"Training set size: {len(X_train)}")
        logger.info(f"Test set size: {len(X_test)}")

        # Scale features
        scaler = StandardScaler()
        X_train_scaled = scaler.fit_transform(X_train)
        X_test_scaled = scaler.transform(X_test)

        # Train XGBoost with monotonic constraints
        logger.info("Training XGBoost model (200 trees, depth 6)...")
        model = xgb.XGBRegressor(
            n_estimators=200,
            max_depth=6,
            learning_rate=0.1,
            objective="reg:squarederror",
            monotone_constraints={
                "f19_last_sync_age_min": -1,  # Decrease with older cache
                "f17_account_age_days": 1,  # Increase with older account
                "f16_prior_offline_settle_rate": 1,  # Increase with better history
            },
            random_state=42,
        )

        model.fit(
            X_train_scaled,
            y_train,
            eval_set=[(X_test_scaled, y_test)],
            early_stopping_rounds=10,
            verbose=False,
        )

        # Evaluate
        y_pred_train = model.predict(X_train_scaled)
        y_pred_test = model.predict(X_test_scaled)

        rmse_train = np.sqrt(mean_squared_error(y_train, y_pred_train))
        rmse_test = np.sqrt(mean_squared_error(y_test, y_pred_test))
        r2_train = r2_score(y_train, y_pred_train)
        r2_test = r2_score(y_test, y_pred_test)

        logger.info(f"Training RMSE: RM {rmse_train:.2f}")
        logger.info(f"Test RMSE: RM {rmse_test:.2f}")
        logger.info(f"Training R²: {r2_train:.4f}")
        logger.info(f"Test R²: {r2_test:.4f}")

        return {
            "model": model,
            "scaler": scaler,
            "X_test": X_test,
            "y_test": y_test,
            "y_pred_test": y_pred_test,
            "metrics": {
                "rmse_train": float(rmse_train),
                "rmse_test": float(rmse_test),
                "r2_train": float(r2_train),
                "r2_test": float(r2_test),
            },
        }

    def save_model(self, model: xgb.XGBRegressor, output_path: str):
        """Save model as pickle"""
        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        model.save_model(str(output_path))
        logger.info(f"Model saved to {output_path}")


def main():
    parser = argparse.ArgumentParser(description="Train credit-score model")
    parser.add_argument(
        "--users", required=True, help="Path to users.parquet"
    )
    parser.add_argument(
        "--transactions", required=True, help="Path to transactions.parquet"
    )
    parser.add_argument(
        "--output-model", default="/tmp/ml/models/credit-v1.pkl", help="Output model path"
    )
    parser.add_argument(
        "--output-metrics", default="/tmp/ml/metrics.json", help="Output metrics JSON"
    )

    args = parser.parse_args()

    logger.info("Loading data...")
    users_df = pd.read_parquet(args.users)
    transactions_df = pd.read_parquet(args.transactions)

    logger.info(f"Loaded {len(users_df)} users, {len(transactions_df)} transactions")

    trainer = CreditScoreModelTrainer(users_df, transactions_df)
    result = trainer.train()

    trainer.save_model(result["model"], args.output_model)

    # Save metrics
    metrics_path = Path(args.output_metrics)
    metrics_path.parent.mkdir(parents=True, exist_ok=True)
    with open(metrics_path, "w") as f:
        json.dump(result["metrics"], f, indent=2)
    logger.info(f"Metrics saved to {metrics_path}")

    print("\n✅ Training complete!")
    print(f"Model: {args.output_model}")
    print(f"Metrics: {args.output_metrics}")


if __name__ == "__main__":
    main()
