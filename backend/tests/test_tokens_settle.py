"""Focused tests for the Alibaba settlement entrypoint."""

import io
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
sys.path.insert(0, str(Path(__file__).parent))

from aws_lambda.settle_batch import handler as settle_batch_handler
from fc.tokens_settle import handler as mod
from fc.wallet_balance import handler as wallet_mod
from lib import demo_state
from lib.bridge_auth import sign_body
from settlement_test_utils import build_signed_token


def _make_post_environ(body: dict, auth: str = "Bearer demo"):
    raw = json.dumps(body).encode("utf-8")
    return {
        "REQUEST_METHOD": "POST",
        "HTTP_AUTHORIZATION": auth,
        "CONTENT_LENGTH": str(len(raw)),
        "wsgi.input": io.BytesIO(raw),
        "HTTP_X_REQUEST_ID": "req_settle001",
    }


def _make_get_environ(auth: str = "Bearer demo"):
    return {
        "REQUEST_METHOD": "GET",
        "HTTP_AUTHORIZATION": auth,
        "CONTENT_LENGTH": "0",
        "wsgi.input": io.BytesIO(b""),
        "HTTP_X_REQUEST_ID": "req_wallet001",
    }


def _capture(handler_fn, environ):
    status_holder = {}

    def start_response(status, headers):
        status_holder["status"] = status

    chunks = handler_fn(environ, start_response)
    return status_holder["status"], json.loads(b"".join(chunks))


class _FakeJwtMiddleware:
    def __init__(self, user_id: str):
        self._user_id = user_id

    def verify(self, token: str) -> dict:
        return {"sub": self._user_id}


class _FakeResponse:
    def __init__(self, payload: dict, status_code: int = 200):
        self.status_code = status_code
        self.text = json.dumps(payload)


class TestTokensSettle:
    def setup_method(self):
        demo_state.reset()
        settle_batch_handler.reset_demo_state()

    def test_demo_mode_runs_full_local_settlement_round_trip(self, monkeypatch):
        token = build_signed_token(
            sender_user_id="u_sender",
            receiver_user_id="u_receiver",
        )
        demo_state.seed_wallet(
            "u_sender",
            balance_cents=24850,
            safe_offline_balance_cents=12000,
        )
        demo_state.seed_wallet("u_receiver", balance_cents=0)

        status, body = _capture(
            mod.handler,
            _make_post_environ(
                {
                    "device_id": "did:tng:device:SENDER001",
                    "batch_id": "batch_local",
                    "tokens": [token["token"]],
                    "ack_signatures": [
                        {
                            "tx_id": token["tx_id"],
                            "ack_sig": "ack-signature",
                            "ack_kid": "did:tng:device:MERCHANT001",
                        },
                    ],
                },
            ),
        )

        monkeypatch.setattr(
            wallet_mod,
            "get_jwt_middleware",
            lambda: _FakeJwtMiddleware("u_receiver"),
        )
        wallet_status, wallet_body = _capture(wallet_mod.handler, _make_get_environ())

        assert status.startswith("200")
        assert body["results"][0]["status"] == "SETTLED"
        assert demo_state.get_wallet("u_sender")["balance_cents"] == 24000
        assert demo_state.get_wallet("u_receiver")["balance_cents"] == 850
        assert wallet_status.startswith("200")
        assert wallet_body["balance_myr"] == "8.50"

    def test_posts_requested_event_to_aws_bridge(self, monkeypatch):
        token = build_signed_token()
        captured = {}

        def fake_post(url, data, headers, timeout):
            captured["url"] = url
            captured["data"] = data
            captured["headers"] = headers
            captured["timeout"] = timeout
            return _FakeResponse(
                {
                    "detail": {
                        "batch_id": "batch_remote",
                        "results": [{"tx_id": token["tx_id"], "status": "SETTLED"}],
                    },
                },
            )

        monkeypatch.setenv("AWS_BRIDGE_URL", "https://aws.example/bridge")
        monkeypatch.setenv("AWS_BRIDGE_HMAC_SECRET", "shared-secret")
        monkeypatch.setattr(mod.requests, "post", fake_post)

        status, body = _capture(
            mod.handler,
            _make_post_environ(
                {
                    "device_id": "did:tng:device:SENDER001",
                    "batch_id": "batch_remote",
                    "tokens": [token["token"]],
                    "ack_signatures": [
                        {
                            "tx_id": token["tx_id"],
                            "ack_sig": "ack-signature",
                            "ack_kid": "did:tng:device:MERCHANT001",
                        },
                    ],
                },
            ),
        )

        posted_event = json.loads(captured["data"])

        assert status.startswith("200")
        assert body["results"][0]["status"] == "SETTLED"
        assert captured["url"] == "https://aws.example/bridge"
        assert captured["timeout"] == 1.5
        assert captured["headers"]["X-TNG-Signature"] == sign_body(
            "shared-secret",
            captured["data"],
        )
        assert posted_event["detail-type"] == "tokens.settle.requested"
        assert posted_event["detail"]["ack_signatures"][0]["ack_kid"] == "did:tng:device:MERCHANT001"
