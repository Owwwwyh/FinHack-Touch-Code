"""Shared helpers for settlement bridge tests."""

from __future__ import annotations

import base64
import json
import time

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ed25519


def build_signed_token(
    *,
    tx_id: str = "01HW3YKQ8X2A5FR7JM6T1EE9NP",
    nonce: str = "bm9uY2UtMDAxLXRlc3Q",
    sender_kid: str = "did:tng:device:SENDER001",
    receiver_kid: str = "did:tng:device:RECEIVER001",
    sender_user_id: str = "u_sender",
    receiver_user_id: str = "u_receiver",
    amount_cents: int = 850,
    policy_version: str = "v3.2026-04-22",
    expires_in_seconds: int = 3600,
) -> dict:
    private_key = ed25519.Ed25519PrivateKey.generate()
    public_key = private_key.public_key().public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )

    now = int(time.time())
    amount_value = f"{amount_cents // 100}.{str(amount_cents % 100).zfill(2)}"
    header = {
        "alg": "EdDSA",
        "typ": "tng-offline-tx+jws",
        "kid": sender_kid,
        "policy": policy_version,
        "ver": 1,
    }
    payload = {
        "tx_id": tx_id,
        "sender": {
            "kid": sender_kid,
            "user_id": sender_user_id,
            "pub": b64url(public_key),
        },
        "receiver": {
            "kid": receiver_kid,
            "user_id": receiver_user_id,
            "pub": b64url(b"merchant-public-key-32-bytes!!"[:32]),
        },
        "amount": {
            "value": amount_value,
            "currency": "MYR",
            "scale": 2,
        },
        "nonce": nonce,
        "iat": now,
        "exp": now + expires_in_seconds,
        "policy_signed_balance": "120.00",
    }

    header_b64 = b64url(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    payload_b64 = b64url(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signing_input = f"{header_b64}.{payload_b64}".encode("utf-8")
    signature = private_key.sign(signing_input)

    return {
        "token": f"{header_b64}.{payload_b64}.{b64url(signature)}",
        "tx_id": tx_id,
        "nonce": nonce,
        "sender_public_key": b64url(public_key),
    }


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")
