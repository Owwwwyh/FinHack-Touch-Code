from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from ml.eas.app import create_app


def _payload():
    return {
        "user_id": "demo_user",
        "policy": "v3.2026-04-22",
        "features": {
            "tx_count_30d": 18,
            "tx_count_90d": 46,
            "tx_amount_p95_30d": 48,
            "prior_offline_count": 11,
            "prior_offline_settle_rate": 0.97,
            "account_age_days": 420,
            "kyc_tier": 2,
            "last_sync_age_min": 4,
            "device_attest_ok": 1,
        },
    }


def test_score_returns_expected_shape(monkeypatch):
    monkeypatch.delenv("EAS_TOKEN", raising=False)
    app = create_app()
    client = app.test_client()

    response = client.post("/score", json=_payload())

    assert response.status_code == 200
    body = response.get_json()
    assert set(body) == {"safe_offline_balance_myr", "confidence", "policy", "computed_at"}
    assert body["policy"] == "v3.2026-04-22"
    assert 0 <= body["confidence"] <= 0.99


def test_score_requires_token_when_configured(monkeypatch):
    monkeypatch.setenv("EAS_TOKEN", "demo-token")
    app = create_app()
    client = app.test_client()

    response = client.post("/score", json=_payload())

    assert response.status_code == 401
    assert response.get_json()["error"]["code"] == "UNAUTHORIZED"


def test_score_accepts_fc_style_feature_aliases(monkeypatch):
    monkeypatch.delenv("EAS_TOKEN", raising=False)
    app = create_app()
    client = app.test_client()
    payload = _payload()
    payload["features"] = {
        "f01": 18,
        "f02": 46,
        "f05": 48,
        "f15": 11,
        "f16": 0.97,
        "f17": 420,
        "f18": 2,
        "f19": 4,
        "f20": 1,
    }

    response = client.post("/score", json=payload)

    assert response.status_code == 200
    assert response.get_json()["policy"] == "v3.2026-04-22"
