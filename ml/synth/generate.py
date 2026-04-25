"""
Synthetic data generator for TNG offline payment credit scoring.
Per docs/04-credit-score-ml.md §6.

Generates:
  - users.parquet: synthetic user profiles
  - transactions.parquet: synthetic transaction history

Usage:
  python generate.py --num-users 10000 --days 90 --out ./output
"""

import argparse
import os
import random
from datetime import datetime, timedelta

import numpy as np
import pandas as pd


ARCHETYPES = ["rural_merchant", "gig_worker", "student", "urban_office"]
ARCHETYPE_WEIGHTS = [0.25, 0.30, 0.25, 0.20]

MALAYSIA_CENTROIDS = {
    "rural_merchant": [(3.139, 101.687), (5.4164, 100.3327), (1.4927, 103.7415)],
    "gig_worker": [(3.139, 101.687), (3.0656, 101.5717), (2.9293, 101.6371)],
    "student": [(2.9293, 101.6371), (5.3584, 100.3067), (1.4927, 103.7415)],
    "urban_office": [(3.139, 101.687), (3.0656, 101.5717)],
}

MONTHLY_INCOME_RANGE = {
    "rural_merchant": (800, 3500),
    "gig_worker": (1200, 4500),
    "student": (300, 800),
    "urban_office": (3000, 12000),
}

TX_PER_MONTH_RANGE = {
    "rural_merchant": (40, 120),
    "gig_worker": (60, 150),
    "student": (20, 80),
    "urban_office": (30, 100),
}

OFFLINE_RATE = {
    "rural_merchant": 0.15,
    "gig_worker": 0.08,
    "student": 0.10,
    "urban_office": 0.05,
}

RELOAD_RATE = {
    "rural_merchant": 2,
    "gig_worker": 3,
    "student": 1,
    "urban_office": 2,
}


def generate_users(num_users: int) -> pd.DataFrame:
    """Generate synthetic user profiles."""
    archetypes = random.choices(ARCHETYPES, weights=ARCHETYPE_WEIGHTS, k=num_users)

    rows = []
    for i, arch in enumerate(archetypes):
        centroid = random.choice(MALAYSIA_CENTROIDS[arch])
        lat = centroid[0] + np.random.normal(0, 0.05)
        lon = centroid[1] + np.random.normal(0, 0.05)
        income_low, income_high = MONTHLY_INCOME_RANGE[arch]
        income = np.random.lognormal(
            mean=np.log((income_low + income_high) / 2),
            sigma=0.3,
        )

        rows.append({
            "user_id": f"u_{i:04d}",
            "signup_date": datetime(2026, 4, 25) - timedelta(days=random.randint(30, 500)),
            "kyc_tier": random.choices([0, 1, 2], weights=[0.3, 0.5, 0.2])[0],
            "archetype": arch,
            "monthly_income_myr": round(income, 2),
            "centroid_lat": round(lat, 4),
            "centroid_lon": round(lon, 4),
        })

    return pd.DataFrame(rows)


def generate_transactions(users: pd.DataFrame, days: int) -> pd.DataFrame:
    """Generate synthetic transactions for all users."""
    rows = []
    end_date = datetime(2026, 4, 25)
    start_date = end_date - timedelta(days=days)

    for _, user in users.iterrows():
        uid = user["user_id"]
        arch = user["archetype"]
        tx_per_month_low, tx_per_month_high = TX_PER_MONTH_RANGE[arch]
        total_tx = int(random.uniform(tx_per_month_low, tx_per_month_high) * days / 30)
        offline_rate = OFFLINE_RATE[arch]
        reload_rate = RELOAD_RATE[arch]

        # Generate spending transactions
        for j in range(total_tx):
            ts = start_date + timedelta(
                days=random.uniform(0, days),
                hours=random.uniform(0, 24),
            )

            # Log-normal amount distribution
            mean_amount = user["monthly_income_myr"] / total_tx * 30
            amount = round(np.random.lognormal(mean=np.log(max(mean_amount, 1)), sigma=0.8), 2)
            amount = min(amount, 500)  # cap at RM 500

            is_offline = random.random() < offline_rate
            payee_id = f"p_{random.randint(1, 500):04d}"
            lat = user["centroid_lat"] + np.random.normal(0, 0.02)
            lon = user["centroid_lon"] + np.random.normal(0, 0.02)

            # Adversarial: 1% double-spend attempts
            settled_clean = True
            if random.random() < 0.01:
                settled_clean = False  # adversarial case

            rows.append({
                "tx_id": f"tx_{uid}_{j:05d}",
                "user_id": uid,
                "ts": ts,
                "amount_myr": amount,
                "payee_id": payee_id,
                "is_reload": False,
                "is_offline": is_offline,
                "settled_clean": settled_clean if is_offline else None,
                "lat": round(lat, 4),
                "lon": round(lon, 4),
            })

        # Generate reload transactions
        num_reloads = int(reload_rate * days / 30)
        for j in range(num_reloads):
            ts = start_date + timedelta(
                days=random.uniform(0, days),
                hours=random.uniform(8, 22),
            )
            reload_amount = round(np.random.lognormal(mean=np.log(50), sigma=0.6), 2)
            reload_amount = min(reload_amount, 500)

            rows.append({
                "tx_id": f"tx_{uid}_r{j:05d}",
                "user_id": uid,
                "ts": ts,
                "amount_myr": reload_amount,
                "payee_id": "RELOAD",
                "is_reload": True,
                "is_offline": False,
                "settled_clean": None,
                "lat": user["centroid_lat"],
                "lon": user["centroid_lon"],
            })

    return pd.DataFrame(rows)


def main():
    parser = argparse.ArgumentParser(description="Generate synthetic TNG data")
    parser.add_argument("--num-users", type=int, default=10000, help="Number of synthetic users")
    parser.add_argument("--days", type=int, default=90, help="Number of days of history")
    parser.add_argument("--out", type=str, default="./output", help="Output directory")
    parser.add_argument("--seed", type=int, default=42, help="Random seed")
    args = parser.parse_args()

    random.seed(args.seed)
    np.random.seed(args.seed)

    os.makedirs(args.out, exist_ok=True)

    print(f"Generating {args.num_users} users with {args.days} days of history...")
    users = generate_users(args.num_users)
    users.to_parquet(os.path.join(args.out, "users.parquet"), index=False)
    print(f"  Users: {len(users)} rows → users.parquet")

    print("Generating transactions...")
    transactions = generate_transactions(users, args.days)
    transactions.to_parquet(os.path.join(args.out, "transactions.parquet"), index=False)
    print(f"  Transactions: {len(transactions)} rows → transactions.parquet")

    # Print summary statistics
    print("\n--- Summary ---")
    print(f"Users by archetype:\n{users['archetype'].value_counts()}")
    print(f"\nTransactions by type:")
    print(f"  Reloads: {transactions['is_reload'].sum()}")
    print(f"  Offline: {(~transactions['is_reload'] & transactions['is_offline']).sum()}")
    print(f"  Online: {(~transactions['is_reload'] & ~transactions['is_offline']).sum()}")
    print(f"  Adversarial: {(~transactions['settled_clean'].fillna(True)).sum()}")


if __name__ == "__main__":
    main()
