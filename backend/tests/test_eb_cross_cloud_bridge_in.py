"""Tests for the AWS inbound cross-cloud bridge Lambda."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from aws_lambda.eb_cross_cloud_bridge_in import handler as mod
from lib.bridge_auth import sign_body
from settlement_test_utils import build_signed_token


class TestEbCrossCloudBridgeIn:
    def setup_method(self):
        mod.reset_demo_state()

    def test_processes_settlement_request_and_returns_completion_event(self, monkeypatch):
        token = build_signed_token()
        event = {
            "detail-type": "tokens.settle.requested",
            "source": "tng.alibaba.fc.tokens-settle",
            "detail": {
                "batch_id": "batch_bridge_in",
                "device_id": "did:tng:device:SENDER001",
                "tokens": [token["token"]],
                "ack_signatures": [],
            },
        }

        monkeypatch.setenv("AWS_BRIDGE_HMAC_SECRET", "shared-secret")

        response = mod.handler(
            {
                "body": mod._json_dumps(event),
                "headers": {
                    "x-tng-signature": sign_body(
                        "shared-secret",
                        mod._json_dumps(event).encode("utf-8"),
                    ),
                },
            },
            None,
        )

        assert response["statusCode"] == 200
        body = mod._json_loads(response["body"])
        assert body["detail-type"] == "settlement.completed"
        assert body["detail"]["batch_id"] == "batch_bridge_in"
        assert body["detail"]["results"][0]["status"] == "SETTLED"

    def test_rejects_invalid_hmac_signature(self, monkeypatch):
        monkeypatch.setenv("AWS_BRIDGE_HMAC_SECRET", "shared-secret")

        response = mod.handler(
            {
                "body": mod._json_dumps(
                    {
                        "detail-type": "tokens.settle.requested",
                        "detail": {"batch_id": "batch_invalid", "tokens": []},
                    },
                ),
                "headers": {"x-tng-signature": "bad-signature"},
            },
            None,
        )

        assert response["statusCode"] == 403
        body = mod._json_loads(response["body"])
        assert body["error"]["code"] == "FORBIDDEN"
