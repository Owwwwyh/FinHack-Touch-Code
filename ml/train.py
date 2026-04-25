"""
XGBoost training script for TNG credit scoring model.
Per docs/04-credit-score-ml.md §5, §7.

Trains an XGBoost regressor on synthetic data to predict safe_offline_balance.
Applies monotonic constraints and isotonic calibration.

Usage:
  python train.py --data ./output --model-dir ./model_output
"""

import argparse
import os
import json
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.isotonic import IsotonicRegression
from sklearn.metrics import mean_squared_error
import xgboost as xgb


def compute_features(users: pd.DataFrame, transactions: pd.DataFrame) -> pd.DataFrame:
    """Compute the 20-feature vector per user from transaction history."""
    now = pd.Timestamp("2026-04-25")
    td_30 = pd.Timedelta(days=30)
    td_90 = pd.Timedelta(days=90)

    # Only spending transactions (not reloads)
    spending = transactions[~transactions["is_reload"]].copy()
    reloads = transactions[transactions["is_reload"]].copy()

    rows = []
    for _, user in users.iterrows():
        uid = user["user_id"]
        u_spend = spending[spending["user_id"] == uid]
        u_reload = reloads[reloads["user_id"] == uid]

        # 30-day window
        spend_30 = u_spend[u_spend["ts"] >= now - td_30]
        spend_90 = u_spend[u_spend["ts"] >= now - td_90]
        reload_30 = u_reload[u_reload["ts"] >= now - td_30]

        # Feature computation
        tx_count_30d = len(spend_30)
        tx_count_90d = len(spend_90)
        avg_tx_amount_30d = spend_30["amount_myr"].mean() if len(spend_30) > 0 else 0
        median_tx_amount_30d = spend_30["amount_myr"].median() if len(spend_30) > 0 else 0
        tx_amount_p95_30d = spend_30["amount_myr"].quantile(0.95) if len(spend_30) > 0 else 0
        unique_payees_30d = spend_30["payee_id"].nunique()
        unique_payees_90d = spend_90["payee_id"].nunique()

        # Payee diversity (Shannon entropy)
        payee_counts = spend_30["payee_id"].value_counts()
        payee_diversity_idx = -(payee_counts / payee_counts.sum() * np.log2(payee_counts / payee_counts.sum())).sum() if len(payee_counts) > 0 else 0

        reload_freq_30d = len(reload_30)
        reload_amount_avg = reload_30["amount_myr"].mean() if len(reload_30) > 0 else 0
        days_since_last_reload = (now - u_reload["ts"].max()).days if len(u_reload) > 0 else 999

        # Time-of-day primary
        if len(spend_30) > 0:
            hour_mode = spend_30["ts"].dt.hour.mode()
            time_of_day_primary = int(hour_mode.iloc[0]) if len(hour_mode) > 0 else 12
        else:
            time_of_day_primary = 12

        weekday_share = (spend_30["ts"].dt.weekday < 5).mean() if len(spend_30) > 0 else 0.7

        # Geo dispersion
        if len(spend_30) > 1:
            geo_dispersion_km = np.sqrt(spend_30["lat"].var() + spend_30["lon"].var()) * 111
        else:
            geo_dispersion_km = 0

        # Offline-specific features
        offline_30 = u_spend[(u_spend["is_offline"]) & (u_spend["ts"] >= now - td_90)]
        prior_offline_count = len(offline_30)
        prior_offline_settle_rate = offline_30["settled_clean"].mean() if len(offline_30) > 0 else 1.0

        account_age_days = (now - user["signup_date"]).days
        kyc_tier = user["kyc_tier"]

        rows.append({
            "user_id": uid,
            "f01_tx_count_30d": tx_count_30d,
            "f02_tx_count_90d": tx_count_90d,
            "f03_avg_tx_amount_30d": avg_tx_amount_30d,
            "f04_median_tx_amount_30d": median_tx_amount_30d,
            "f05_tx_amount_p95_30d": tx_amount_p95_30d,
            "f06_unique_payees_30d": unique_payees_30d,
            "f07_unique_payees_90d": unique_payees_90d,
            "f08_payee_diversity_idx": payee_diversity_idx,
            "f09_reload_freq_30d": reload_freq_30d,
            "f10_reload_amount_avg": reload_amount_avg,
            "f11_days_since_last_reload": days_since_last_reload,
            "f12_time_of_day_primary": time_of_day_primary,
            "f13_weekday_share": weekday_share,
            "f14_geo_dispersion_km": geo_dispersion_km,
            "f15_prior_offline_count": prior_offline_count,
            "f16_prior_offline_settle_rate": prior_offline_settle_rate,
            "f17_account_age_days": account_age_days,
            "f18_kyc_tier": kyc_tier,
            "f19_last_sync_age_min": 0,  # placeholder, filled at inference time
            "f20_device_attest_ok": 1,
        })

    return pd.DataFrame(rows)


def compute_labels(users: pd.DataFrame, transactions: pd.DataFrame) -> pd.DataFrame:
    """
    Compute the target label: safe_offline_balance.
    For synthetic data, this is derived from the user's balance pattern.
    """
    rows = []
    for _, user in users.iterrows():
        uid = user["user_id"]
        # Simulated cached balance: sum of reloads - sum of spending
        u_tx = transactions[transactions["user_id"] == uid]
        total_reloads = u_tx[u_tx["is_reload"]]["amount_myr"].sum()
        total_spending = u_tx[~u_tx["is_reload"]]["amount_myr"].sum()
        cached_balance = max(0, total_reloads - total_spending)

        # Safe offline balance: conservative fraction based on archetype and KYC
        arch = user["archetype"]
        kyc = user["kyc_tier"]
        if user.get("lifetime_tx_count", 1000) < 600:
            safe = min(cached_balance * 0.2, 50)  # manual mode
        else:
            base_frac = {"rural_merchant": 0.4, "gig_worker": 0.5, "student": 0.35, "urban_office": 0.45}[arch]
            safe = cached_balance * base_frac * (1 + kyc * 0.15)
            safe = min(safe, cached_balance)
            # Apply hard cap per tier
            hard_cap = {0: 20, 1: 150, 2: 500}[kyc]
            safe = min(safe, hard_cap)

        rows.append({
            "user_id": uid,
            "cached_balance_myr": round(cached_balance, 2),
            "safe_offline_balance_myr": round(max(0, safe), 2),
        })

    return pd.DataFrame(rows)


def main():
    parser = argparse.ArgumentParser(description="Train TNG credit scoring model")
    parser.add_argument("--data", type=str, default="./output", help="Path to synthetic data")
    parser.add_argument("--model-dir", type=str, default="./model_output", help="Output model directory")
    args = parser.parse_args()

    os.makedirs(args.model_dir, exist_ok=True)

    # Load data
    users = pd.read_parquet(os.path.join(args.data, "users.parquet"))
    transactions = pd.read_parquet(os.path.join(args.data, "transactions.parquet"))

    # Compute features and labels
    print("Computing features...")
    features = compute_features(users, transactions)
    labels = compute_labels(users, transactions)

    # Merge
    data = features.merge(labels, on="user_id")
    feature_cols = [c for c in features.columns if c.startswith("f")]

    X = data[feature_cols].values
    y = data["safe_offline_balance_myr"].values

    # Split
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    # Monotonic constraints (per docs/04 §5):
    # f19 (last_sync_age_min) should decrease → -1
    # f17 (account_age_days) should increase → +1
    # f16 (prior_offline_settle_rate) should increase → +1
    monotone_constraints = [0] * len(feature_cols)
    f19_idx = feature_cols.index("f19_last_sync_age_min")
    f17_idx = feature_cols.index("f17_account_age_days")
    f16_idx = feature_cols.index("f16_prior_offline_settle_rate")
    monotone_constraints[f19_idx] = -1
    monotone_constraints[f17_idx] = 1
    monotone_constraints[f16_idx] = 1

    # Train XGBoost
    print("Training XGBoost model...")
    model = xgb.XGBRegressor(
        n_estimators=200,
        max_depth=6,
        learning_rate=0.1,
        monotone_constraints=monotone_constraints,
        random_state=42,
    )
    model.fit(X_train, y_train)

    # Evaluate
    y_pred = model.predict(X_test)
    rmse = np.sqrt(mean_squared_error(y_test, y_pred))
    print(f"RMSE on test: {rmse:.2f} MYR")

    # Isotonic calibration
    print("Applying isotonic calibration...")
    y_pred_train = model.predict(X_train)
    calibrator = IsotonicRegression(out_of_bounds="clip")
    calibrator.fit(y_pred_train, y_train)

    # Calibrate test predictions
    y_pred_cal = calibrator.predict(y_pred)
    rmse_cal = np.sqrt(mean_squared_error(y_test, y_pred_cal))
    print(f"RMSE after calibration: {rmse_cal:.2f} MYR")

    # Save model
    model_path = os.path.join(args.model_dir, "model.pkl")
    import pickle
    with open(model_path, "wb") as f:
        pickle.dump({"model": model, "calibrator": calibrator, "feature_cols": feature_cols}, f)
    print(f"Model saved to {model_path}")

    # Save metrics
    metrics = {
        "rmse_raw": round(rmse, 2),
        "rmse_calibrated": round(rmse_cal, 2),
        "n_train": len(X_train),
        "n_test": len(X_test),
        "feature_cols": feature_cols,
    }
    with open(os.path.join(args.model_dir, "metrics.json"), "w") as f:
        json.dump(metrics, f, indent=2)

    print("Training complete!")


if __name__ == "__main__":
    main()
