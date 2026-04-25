"""Focused tests for Alibaba's AWS bridge ingest handler."""

import io
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from fc.eb_cross_cloud_ingest import handler as mod
from lib import demo_state
from lib.bridge_auth import sign_body
from lib.settlement_events import encode_event


def _make_environ(body: bytes, signature: str = ""):
    return {
        "REQUEST_METHOD": "POST",
        "CONTENT_LENGTH": str(len(body)),
        "wsgi.input": io.BytesIO(body),
        "HTTP_X_REQUEST_ID": "req_ingest001",
        "HTTP_X_TNG_SIGNATURE": signature,
    }


def _capture(handler_fn, environ):
    status_holder = {}

    def start_response(status, headers):
        status_holder["status"] = status

    chunks = handler_fn(environ, start_response)
    return status_holder["status"], json.loads(b"".join(chunks))


class TestEbCrossCloudIngest:
    def setup_method(self):
        demo_state.reset()

    def test_applies_settlement_to_demo_wallets(self, monkeypatch):
        demo_state.seed_wallet(
            "u_sender",
            balance_cents=24850,
            safe_offline_balance_cents=12000,
        )
        demo_state.seed_wallet("u_receiver", balance_cents=0)

        event = {
            "version": "0",
            "id": "evt_001",
            "detail-type": "settlement.completed",
            "source": "tng.aws.lambda.settle",
            "time": "2026-04-26T00:00:00+00:00",
            "detail": {
                "batch_id": "batch_001",
                "results": [
                    {
                        "tx_id": "tx_001",
                        "status": "SETTLED",
                        "sender_user_id": "u_sender",
                        "receiver_user_id": "u_receiver",
                        "amount_cents": 850,
                        "policy_version": "v3.2026-04-22",
                    },
                ],
            },
        }
        raw = encode_event(event)

        monkeypatch.setenv("AWS_BRIDGE_HMAC_SECRET", "shared-secret")
        status, body = _capture(
            mod.handler,
            _make_environ(raw, sign_body("shared-secret", raw)),
        )

        assert status.startswith("200")
        assert body["applied_results"] == 1
        assert demo_state.get_wallet("u_sender")["balance_cents"] == 24000
        assert demo_state.get_wallet("u_receiver")["balance_cents"] == 850
        assert demo_state.get_pending_batch("batch_001")["status"] == "COMPLETED"

    def test_rejects_bad_hmac_signature(self, monkeypatch):
        event = {
            "version": "0",
            "id": "evt_002",
            "detail-type": "settlement.completed",
            "source": "tng.aws.lambda.settle",
            "time": "2026-04-26T00:00:00+00:00",
            "detail": {"batch_id": "batch_002", "results": []},
        }
        raw = encode_event(event)

        monkeypatch.setenv("AWS_BRIDGE_HMAC_SECRET", "shared-secret")
        status, body = _capture(mod.handler, _make_environ(raw, "bad-signature"))

        assert status.startswith("403")
        assert body["error"]["code"] == "FORBIDDEN"
