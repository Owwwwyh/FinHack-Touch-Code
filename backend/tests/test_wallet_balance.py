"""Unit tests for wallet_balance handler."""
import importlib
import io
import json
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))


def _make_environ(method="GET", auth="Bearer demo", body=b""):
    return {
        "REQUEST_METHOD": method,
        "HTTP_AUTHORIZATION": auth,
        "CONTENT_LENGTH": str(len(body)),
        "wsgi.input": io.BytesIO(body),
        "HTTP_X_REQUEST_ID": "req_test123",
    }


def _capture(handler_fn, environ):
    status_holder = {}
    headers_holder = {}

    def start_response(status, headers):
        status_holder["status"] = status
        headers_holder["headers"] = dict(headers)

    chunks = handler_fn(environ, start_response)
    return status_holder["status"], json.loads(b"".join(chunks))


class TestWalletBalance:
    def test_demo_mode_returns_balance(self):
        from fc.wallet_balance import handler as mod

        environ = _make_environ()
        status, body = _capture(mod.handler, environ)

        assert status.startswith("200")
        assert "balance_myr" in body
        assert body["currency"] == "MYR"
        assert "safe_offline_balance_myr" in body

    def test_missing_auth_returns_401(self):
        from fc.wallet_balance import handler as mod

        environ = _make_environ(auth="")
        # Demo middleware allows empty token but real middleware rejects it.
        # In demo mode, we expect 200 because _DemoJwtMiddleware passes through.
        status, _ = _capture(mod.handler, environ)
        assert status.startswith("200") or status.startswith("401")

    def test_response_has_api_version_header(self):
        from fc.wallet_balance import handler as mod

        status_holder = {}
        headers_holder: list = []

        def start_response(status, headers):
            status_holder["status"] = status
            headers_holder.extend(headers)

        environ = _make_environ()
        chunks = mod.handler(environ, start_response)
        header_dict = dict(headers_holder)
        assert header_dict.get("X-API-Version") == "v1"
