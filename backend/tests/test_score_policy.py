"""Unit tests for score_policy handler."""
import io
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))


def _make_environ(auth="Bearer demo"):
    return {
        "REQUEST_METHOD": "GET",
        "HTTP_AUTHORIZATION": auth,
        "CONTENT_LENGTH": "0",
        "wsgi.input": io.BytesIO(b""),
        "HTTP_X_REQUEST_ID": "req_policy789",
    }


def _capture(handler_fn, environ):
    status_holder = {}

    def start_response(status, headers):
        status_holder["status"] = status

    chunks = handler_fn(environ, start_response)
    return status_holder["status"], json.loads(b"".join(chunks))


class TestScorePolicy:
    def test_returns_default_policy_in_demo_mode(self):
        from fc.score_policy import handler as mod

        status, body = _capture(mod.handler, _make_environ())
        assert status.startswith("200")
        assert "policy_version" in body
        assert "model" in body
        assert "limits" in body

    def test_limits_contain_kyc_tiers(self):
        from fc.score_policy import handler as mod

        _, body = _capture(mod.handler, _make_environ())
        limits = body["limits"]
        assert "hard_cap_per_tier" in limits
        caps = limits["hard_cap_per_tier"]
        assert "0" in caps and "1" in caps and "2" in caps

    def test_model_has_required_fields(self):
        from fc.score_policy import handler as mod

        _, body = _capture(mod.handler, _make_environ())
        model = body["model"]
        assert model["format"] == "tflite"
        assert "url" in model
        assert "sha256" in model
