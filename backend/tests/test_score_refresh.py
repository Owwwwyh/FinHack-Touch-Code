"""Integration-style tests for POST /v1/score/refresh."""

from __future__ import annotations

import sys
from decimal import Decimal
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from lib import demo_state
from server import app


def _payload(
    *,
    last_sync_age_min: int = 0,
    lifetime_tx_count: int = 642,
    manual_offline_wallet_myr: str = "35.00",
    kyc_tier: int = 2,
) -> dict:
    return {
        "user_id": "demo_user",
        "policy_version": "v3.2026-04-22",
        "lifetime_tx_count": lifetime_tx_count,
        "manual_offline_wallet_myr": manual_offline_wallet_myr,
        "features": {
            "tx_count_30d": 38,
            "tx_count_90d": 92,
            "avg_tx_amount_30d": 7.40,
            "median_tx_amount_30d": 5.00,
            "tx_amount_p95_30d": 30.00,
            "unique_payees_30d": 17,
            "unique_payees_90d": 36,
            "payee_diversity_idx": 2.91,
            "reload_freq_30d": 4,
            "reload_amount_avg": 50.00,
            "days_since_last_reload": 3,
            "time_of_day_primary": 12,
            "weekday_share": 0.78,
            "geo_dispersion_km": 6.2,
            "prior_offline_count": 11,
            "prior_offline_settle_rate": 1.0,
            "account_age_days": 421,
            "kyc_tier": kyc_tier,
            "last_sync_age_min": last_sync_age_min,
            "device_attest_ok": 1,
        },
    }


class TestScoreRefresh:
    def setup_method(self):
        demo_state.reset()
        demo_state.seed_wallet(
            "demo_user",
            balance_cents=24850,
            safe_offline_balance_cents=5000,
        )

    def test_refresh_score_uses_input_features_instead_of_static_stub(self):
        client = app.test_client()

        fresh = client.post(
            "/v1/score/refresh",
            json=_payload(last_sync_age_min=0),
            headers={"Authorization": "Bearer demo"},
        )
        stale = client.post(
            "/v1/score/refresh",
            json=_payload(last_sync_age_min=120),
            headers={"Authorization": "Bearer demo"},
        )

        assert fresh.status_code == 200
        assert stale.status_code == 200

        fresh_body = fresh.get_json()
        stale_body = stale.get_json()

        assert fresh_body["policy_version"] == "v3.2026-04-22"
        assert 0 <= fresh_body["confidence"] <= 0.99
        assert Decimal(stale_body["safe_offline_balance_myr"]) < Decimal(
            fresh_body["safe_offline_balance_myr"]
        )

    def test_low_history_uses_manual_offline_wallet_path(self):
        client = app.test_client()

        response = client.post(
            "/v1/score/refresh",
            json=_payload(
                lifetime_tx_count=120,
                manual_offline_wallet_myr="35.00",
                kyc_tier=1,
            ),
            headers={"Authorization": "Bearer demo"},
        )

        assert response.status_code == 200
        body = response.get_json()
        assert body["safe_offline_balance_myr"] == "35.00"
        assert body["confidence"] == 0.0

    def test_missing_features_returns_bad_request(self):
        client = app.test_client()

        response = client.post(
            "/v1/score/refresh",
            json={
                "user_id": "demo_user",
                "policy_version": "v3.2026-04-22",
            },
            headers={"Authorization": "Bearer demo"},
        )

        assert response.status_code == 400
        body = response.get_json()
        assert body["error"]["code"] == "BAD_REQUEST"
