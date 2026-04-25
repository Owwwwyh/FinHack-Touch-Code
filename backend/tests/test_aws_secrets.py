"""Focused tests for AWS Secrets Manager env resolution."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from lib import aws_secrets


def test_returns_plain_env_value_without_lookup(monkeypatch):
    aws_secrets.resolve_secret_reference.cache_clear()
    monkeypatch.setenv("PLAIN_SECRET", "plain-value")

    assert aws_secrets.resolve_secret_env("PLAIN_SECRET") == "plain-value"


def test_resolves_secret_reference_via_secrets_manager(monkeypatch):
    aws_secrets.resolve_secret_reference.cache_clear()
    captured = {}

    class _FakeClient:
        def get_secret_value(self, SecretId):  # noqa: N802
            captured["secret_id"] = SecretId
            return {"SecretString": "resolved-value"}

    monkeypatch.setenv("BRIDGE_SECRET", "secret://tng-finhack-bridge")
    monkeypatch.setattr(aws_secrets, "_get_secrets_client", lambda: _FakeClient())

    assert aws_secrets.resolve_secret_env("BRIDGE_SECRET") == "resolved-value"
    assert captured["secret_id"] == "tng-finhack-bridge"
