"""Focused tests for the AWS outbound settlement bridge."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from aws_lambda.eb_cross_cloud_bridge_out import handler as mod
from lib.bridge_auth import sign_body
from lib.settlement_events import encode_event


class _FakeResponse:
    status_code = 200
    body = '{"status":"accepted"}'


def test_posts_signed_payload_to_alibaba(monkeypatch):
    captured = {}
    event = {
        "version": "0",
        "id": "evt_001",
        "detail-type": "settlement.completed",
        "source": "tng.aws.lambda.settle",
        "time": "2026-04-26T00:00:00+00:00",
        "detail": {"batch_id": "batch_001", "results": []},
    }

    def fake_post(url, data, headers, timeout):
        captured["url"] = url
        captured["data"] = data
        captured["headers"] = headers
        captured["timeout"] = timeout
        return {
            "status_code": _FakeResponse.status_code,
            "body": _FakeResponse.body,
        }

    monkeypatch.setenv("ALIBABA_INGEST_URL", "https://alibaba.example/internal")
    monkeypatch.setenv("AWS_BRIDGE_HMAC_SECRET", "shared-secret")
    monkeypatch.setattr(mod, "_post", fake_post)

    response = mod.handler(event, None)

    assert response["delivered"] is True
    assert captured["url"] == "https://alibaba.example/internal"
    assert captured["timeout"] == 3
    assert captured["headers"]["X-TNG-Signature"] == sign_body(
        "shared-secret",
        encode_event(event),
    )
