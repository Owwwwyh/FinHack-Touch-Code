"""Integration-style tests for POST /v1/score/refresh."""

from __future__ import annotations

import requests
import sys
from decimal import Decimal
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from lib import demo_state
from lib.score_inference import compute_score_response
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

    def test_refresh_score_uses_online_eas_when_available(self, monkeypatch):
        client = app.test_client()
        captured = {}

        class _FakeResponse:
            status_code = 200

            def raise_for_status(self):
                return None

            def json(self):
                return {
                    "safe_offline_balance_myr": "140.00",
                    "confidence": 0.91,
                    "policy": "v3.2026-04-22",
                    "computed_at": "2026-04-26T00:00:00Z",
                }

        def fake_post(url, json, headers, timeout):
            captured["url"] = url
            captured["json"] = json
            captured["headers"] = headers
            captured["timeout"] = timeout
            return _FakeResponse()

        monkeypatch.setenv("EAS_ENDPOINT", "https://pai-eas.example.com")
        monkeypatch.setenv("EAS_TOKEN", "demo-token")
        monkeypatch.setattr(requests, "post", fake_post)

        response = client.post(
            "/v1/score/refresh",
            json=_payload(last_sync_age_min=0),
            headers={"Authorization": "Bearer demo"},
        )

        assert response.status_code == 200
        body = response.get_json()
        assert body["safe_offline_balance_myr"] == "140.00"
        assert body["confidence"] == 0.91
        assert body["policy_version"] == "v3.2026-04-22"
        assert captured["url"] == "https://pai-eas.example.com/score"
        assert captured["timeout"] == 0.8
        assert captured["headers"]["Authorization"] == "Bearer demo-token"

    def test_timeout_falls_back_to_local_inference(self, monkeypatch):
        client = app.test_client()
        calls = {"count": 0}
        payload = _payload(last_sync_age_min=40)

        def fake_post(url, json, headers, timeout):
            calls["count"] += 1
            raise requests.Timeout("timed out")

        monkeypatch.setenv("EAS_ENDPOINT", "https://pai-eas.example.com")
        monkeypatch.setattr(requests, "post", fake_post)

        response = client.post(
            "/v1/score/refresh",
            json=payload,
            headers={"Authorization": "Bearer demo"},
        )

        expected = compute_score_response(
            payload,
            cached_balance_cents=24850,
            default_manual_offline_cents=5000,
        )

        assert response.status_code == 200
        body = response.get_json()
        assert calls["count"] == 1
        assert body["safe_offline_balance_myr"] == expected["safe_offline_balance_myr"]
        assert body["policy_version"] == expected["policy_version"]

    def test_low_history_uses_manual_offline_wallet_path(self, monkeypatch):
        client = app.test_client()
        calls = {"count": 0}

        def fake_post(url, json, headers, timeout):
            calls["count"] += 1
            raise AssertionError("PAI-EAS should not be called for low-history users")

        monkeypatch.setenv("EAS_ENDPOINT", "https://pai-eas.example.com")
        monkeypatch.setattr(requests, "post", fake_post)

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
        assert calls["count"] == 0

    def test_missing_features_returns_bad_request(self, monkeypatch):
        client = app.test_client()
        calls = {"count": 0}

        def fake_post(url, json, headers, timeout):
            calls["count"] += 1
            raise AssertionError("PAI-EAS should not be called when validation fails")

        monkeypatch.setenv("EAS_ENDPOINT", "https://pai-eas.example.com")
        monkeypatch.setattr(requests, "post", fake_post)

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
        assert calls["count"] == 0
