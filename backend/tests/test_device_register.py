"""Unit tests for device_register handler."""
import base64
import io
import json
import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))


def _b64url(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def _make_environ(body: dict, auth="Bearer demo"):
    raw = json.dumps(body).encode()
    return {
        "REQUEST_METHOD": "POST",
        "HTTP_AUTHORIZATION": auth,
        "CONTENT_LENGTH": str(len(raw)),
        "wsgi.input": io.BytesIO(raw),
        "HTTP_X_REQUEST_ID": "req_test456",
    }


def _capture(handler_fn, environ):
    status_holder = {}

    def start_response(status, headers):
        status_holder["status"] = status

    chunks = handler_fn(environ, start_response)
    return status_holder["status"], json.loads(b"".join(chunks))


class TestDeviceRegister:
    def _valid_body(self):
        import secrets

        return {
            "user_id": "u_test_001",
            "device_label": "Pixel 8 Pro",
            "public_key": _b64url(secrets.token_bytes(32)),
            "alg": "EdDSA",
            "android_id_hash": "abc123",
            "attestation_chain": [],
        }

    def test_registers_device_demo_mode(self):
        from fc.device_register import handler as mod

        status, body = _capture(mod.handler, _make_environ(self._valid_body()))
        assert status.startswith("200")
        assert "kid" in body
        assert body["device_id"].startswith("did:tng:device:")
        assert body["policy_version"] == "v3.2026-04-22"

    def test_missing_user_id_returns_400(self):
        from fc.device_register import handler as mod

        body = self._valid_body()
        del body["user_id"]
        status, resp = _capture(mod.handler, _make_environ(body))
        assert status.startswith("400")
        assert resp["error"]["code"] == "BAD_REQUEST"

    def test_wrong_alg_returns_422(self):
        from fc.device_register import handler as mod

        body = self._valid_body()
        body["alg"] = "RS256"
        status, resp = _capture(mod.handler, _make_environ(body))
        assert status.startswith("422")

    def test_short_public_key_returns_422(self):
        from fc.device_register import handler as mod

        body = self._valid_body()
        body["public_key"] = _b64url(b"\x01\x02\x03")  # too short
        status, resp = _capture(mod.handler, _make_environ(body))
        assert status.startswith("422")
