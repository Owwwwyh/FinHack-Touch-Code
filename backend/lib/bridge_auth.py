"""Helpers for HMAC-signing cross-cloud bridge payloads."""

from __future__ import annotations

import hashlib
import hmac


def sign_body(secret: str, body: bytes) -> str:
    return hmac.new(secret.encode("utf-8"), body, hashlib.sha256).hexdigest()


def verify_body(secret: str, body: bytes, signature: str) -> bool:
    expected = sign_body(secret, body)
    return hmac.compare_digest(expected, signature)
