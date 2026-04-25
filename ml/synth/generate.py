#!/usr/bin/env python3
"""
Synthetic data generator for TNG Finhack ML training
Generates 10,000 synthetic users with 90-day transaction history
Output: S3 parquet files (users.parquet, transactions.parquet)

See docs/04-credit-score-ml.md §6 for schema and design details
"""

import argparse
import json
import random
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Dict, List

import numpy as np
import pandas as pd


class SyntheticDataGenerator:
    """Generate synthetic user and transaction data for ML training"""

    ARCHETYPES = {
        "rural_merchant": {
            "share": 0.2,
            "monthly_income_range": (2000, 5000),
            "monthly_tx_count_range": (50, 100),
            "offline_share": 0.15,  # 15% of txns offline
            "reload_freq_30d": 2,
        },
        "gig_worker": {
            "share": 0.35,
            "monthly_income_range": (3000, 8000),
            "monthly_tx_count_range": (80, 150),
            "offline_share": 0.10,  # 10% offline
            "reload_freq_30d": 1,
        },
        "student": {
            "share": 0.25,
            "monthly_income_range": (500, 2000),
            "monthly_tx_count_range": (40, 80),
            "offline_share": 0.08,  # 8% offline
            "reload_freq_30d": 0.5,
        },
        "urban_office": {
            "share": 0.20,
            "monthly_income_range": (4000, 12000),
            "monthly_tx_count_range": (60, 120),
            "offline_share": 0.05,  # 5% offline
            "reload_freq_30d": 1,
        },
    }

    PAYEE_CATEGORIES = ["merchant_cafe", "merchant_retail", "friend", "utility", "merchant_transport"]

    def __init__(self, num_users: int = 10000, days_history: int = 90, seed: int = 42):
        """
        Initialize generator

        Args:
            num_users: Number of synthetic users to generate
            days_history: History window in days (typically 90)
            seed: Random seed for reproducibility
        """
        self.num_users = num_users
        self.days_history = days_history
        random.seed(seed)
        np.random.seed(seed)

    def generate_users(self) -> pd.DataFrame:
        """Generate user profiles"""
        users = []

        for user_idx in range(self.num_users):
            # Pick archetype weighted by distribution
            archetype = random.choices(
                list(self.ARCHETYPES.keys()),
                weights=[self.ARCHETYPES[a]["share"] for a in self.ARCHETYPES.keys()],
                k=1,
            )[0]

            config = self.ARCHETYPES[archetype]
            signup_date = datetime.now() - timedelta(days=random.randint(200, 500))
            monthly_income = random.uniform(*config["monthly_income_range"])

            # Generate geographic centroid (Malaysia coordinates range)
            # Lat: 1–7°N, Lon: 100–120°E
            lat = random.uniform(1, 7)
            lon = random.uniform(100, 120)

            users.append(
                {
                    "user_id": f"u_{user_idx + 1:06d}",
                    "signup_date": signup_date,
                    "kyc_tier": random.randint(1, 3),
                    "archetype": archetype,
                    "monthly_income_myr": monthly_income,
                    "centroid_lat": lat,
                    "centroid_lon": lon,
                }
            )

        return pd.DataFrame(users)

    def generate_transactions(self, users_df: pd.DataFrame) -> pd.DataFrame:
        """Generate transaction history for all users"""
        transactions = []
        now = datetime.now()

        for _, user_row in users_df.iterrows():
            user_id = user_row["user_id"]
            archetype = user_row["archetype"]
            config = self.ARCHETYPES[archetype]

            # Generate transaction count for this user over history period
            avg_monthly = np.mean(config["monthly_tx_count_range"])
            month_count = self.days_history / 30
            tx_count = int(np.random.poisson(avg_monthly * month_count))

            for tx_idx in range(tx_count):
                # Random timestamp in history window
                ts = now - timedelta(
                    days=random.randint(0, self.days_history),
                    hours=random.randint(0, 23),
                    minutes=random.randint(0, 59),
                )

                # Determine if reload or spend
                is_reload = random.random() < 0.05  # 5% of txns are reloads

                if is_reload:
                    amount = random.uniform(50, 500)
                else:
                    # Spending: log-normal distribution
                    amount = np.random.lognormal(
                        mean=np.log(config["monthly_income_range"][0] / 20),
                        sigma=0.8,
                    )

                # Offline decision
                is_offline = random.random() < config["offline_share"]

                # Payee selection
                payee_id = f"{random.choice(self.PAYEE_CATEGORIES)}_{random.randint(1, 1000)}"

                # Geographic variance around centroid
                lat = user_row["centroid_lat"] + np.random.normal(0, 0.1)
                lon = user_row["centroid_lon"] + np.random.normal(0, 0.1)

                # Settlement status (mostly clean for good users, some issues for adversarial)
                if random.random() < 0.99:  # 99% clean
                    settled_clean = True
                else:  # 1% adversarial (double-spend, fraud)
                    settled_clean = False

                transactions.append(
                    {
                        "tx_id": f"tx_{len(transactions) + 1:08d}",
                        "user_id": user_id,
                        "ts": ts,
                        "amount_myr": round(amount, 2),
                        "payee_id": payee_id,
                        "is_reload": is_reload,
                        "is_offline": is_offline,
                        "settled_clean": settled_clean,
                        "lat": lat,
                        "lon": lon,
                    }
                )

        return pd.DataFrame(transactions).sort_values(["user_id", "ts"]).reset_index(drop=True)

    def generate(self) -> tuple[pd.DataFrame, pd.DataFrame]:
        """Generate all synthetic data"""
        print(f"Generating {self.num_users} synthetic users...")
        users_df = self.generate_users()

        print(f"Generating transactions ({self.days_history}-day history)...")
        transactions_df = self.generate_transactions(users_df)

        print(f"Generated {len(users_df)} users with {len(transactions_df)} total transactions")
        print(f"Average transactions per user: {len(transactions_df) / len(users_df):.1f}")

        return users_df, transactions_df

    def save_parquet(self, users_df: pd.DataFrame, transactions_df: pd.DataFrame, output_dir: str):
        """Save to parquet files"""
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)

        users_path = output_path / "users.parquet"
        transactions_path = output_path / "transactions.parquet"

        users_df.to_parquet(users_path, index=False)
        transactions_df.to_parquet(transactions_path, index=False)

        print(f"✓ Saved users to {users_path}")
        print(f"✓ Saved transactions to {transactions_path}")

        # Print summary
        print(f"\nSummary:")
        print(f"  Users file size: {users_path.stat().st_size / 1024:.1f} KB")
        print(f"  Transactions file size: {transactions_path.stat().st_size / 1024:.1f} KB")
        print(f"  Users: {len(users_df)}")
        print(f"  Transactions: {len(transactions_df)}")


def main():
    parser = argparse.ArgumentParser(description="Generate synthetic training data")
    parser.add_argument("--num-users", type=int, default=10000, help="Number of synthetic users")
    parser.add_argument("--days", type=int, default=90, help="History window in days")
    parser.add_argument(
        "--out",
        type=str,
        default="/tmp/ml/synthetic/v1",
        help="Output directory for parquet files",
    )
    parser.add_argument("--seed", type=int, default=42, help="Random seed")

    args = parser.parse_args()

    print(f"TNG Finhack Synthetic Data Generator")
    print(f"====================================")
    print(f"Users: {args.num_users}")
    print(f"History: {args.days} days")
    print(f"Output: {args.out}")
    print()

    generator = SyntheticDataGenerator(
        num_users=args.num_users, days_history=args.days, seed=args.seed
    )
    users_df, transactions_df = generator.generate()

    generator.save_parquet(users_df, transactions_df, args.out)

    print("\n✅ Done!")


if __name__ == "__main__":
    main()
