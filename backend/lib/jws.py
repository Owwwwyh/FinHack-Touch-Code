"""
JWS token verification library for TNG offline payment tokens.
Per docs/03-token-protocol.md — Ed25519 JWS Compact Serialization.

Usage:
    from lib.jws import verify_token, decode_token
    result = verify_token(jws_string, pubkey_lookup_func)
"""

import json
import base64
import time
from typing import Optional, Callable, Tuple

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
from cryptography.exceptions import InvalidSignature


def base64url_decode(s: str) -> bytes:
    """Decode base64url without padding."""
    padded = s + "=" * (4 - len(s) % 4) if len(s) % 4 else s
    return base64.urlsafe_b64decode(padded)


def base64url_encode(data: bytes) -> str:
    """Encode to base64url without padding."""
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def decode_token(jws: str) -> Tuple[dict, dict, bytes]:
    """Decode a JWS token without verifying. Returns (header, payload, signature_bytes)."""
    parts = jws.split(".")
    if len(parts) != 3:
        raise ValueError("Invalid JWS format: expected 3 parts")

    header = json.loads(base64url_decode(parts[0]))
    payload = json.loads(base64url_decode(parts[1]))
    signature = base64url_decode(parts[2])

    return header, payload, signature


def verify_token(
    jws: str,
    pubkey_lookup: Callable[[str], Optional[bytes]],
    check_expiry: bool = True,
    now: Optional[float] = None,
) -> dict:
    """
    Verify a JWS offline payment token.

    Args:
        jws: The compact JWS string
        pubkey_lookup: Function that takes a kid and returns 32-byte Ed25519 public key, or None
        check_expiry: Whether to check token expiry
        now: Override current time for testing

    Returns:
        dict with keys:
            - ok: bool
            - reason: str (if not ok)
            - header: dict
            - payload: dict
    """
    try:
        parts = jws.split(".")
        if len(parts) != 3:
            return {"ok": False, "reason": "bad_header", "header": {}, "payload": {}}

        header = json.loads(base64url_decode(parts[0]))
        payload = json.loads(base64url_decode(parts[1]))
        signature = base64url_decode(parts[2])

        # Check header fields
        if header.get("alg") != "EdDSA":
            return {"ok": False, "reason": "bad_header", "header": header, "payload": payload}
        if header.get("typ") != "tng-offline-tx+jws":
            return {"ok": False, "reason": "bad_header", "header": header, "payload": payload}

        # Look up public key
        kid = header.get("kid", "")
        # Extract the device ID from "did:tng:device:XXX"
        device_id = kid.split(":")[-1] if ":" in kid else kid
        pub_bytes = pubkey_lookup(device_id)
        if pub_bytes is None:
            return {"ok": False, "reason": "unknown_kid", "header": header, "payload": payload}

        # Verify Ed25519 signature
        signing_input = f"{parts[0]}.{parts[1]}".encode("utf-8")
        pub_key = Ed25519PublicKey.from_public_bytes(pub_bytes)
        try:
            pub_key.verify(signature, signing_input)
        except InvalidSignature:
            return {"ok": False, "reason": "bad_sig", "header": header, "payload": payload}

        # Check expiry
        if check_expiry:
            current_time = now or time.time()
            if payload.get("exp", 0) < current_time:
                return {"ok": False, "reason": "expired", "header": header, "payload": payload}

        return {"ok": True, "header": header, "payload": payload}

    except Exception as e:
        return {"ok": False, "reason": f"parse_error: {str(e)}", "header": {}, "payload": {}}


def create_test_token(
    private_key_bytes: bytes,
    sender_kid: str = "01HW3YKQ8X2A5FR7JM6T1EE9NP",
    sender_user_id: str = "u_8412",
    receiver_kid: str = "01HW4ABCD1234567890ABCDEF",
    receiver_user_id: str = "u_3091",
    amount_value: str = "8.50",
    nonce: Optional[str] = None,
    iat: Optional[int] = None,
    exp: Optional[int] = None,
    policy_version: str = "v3.2026-04-22",
) -> str:
    """Create a test JWS token for testing purposes."""
    import os
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

    if nonce is None:
        nonce = base64url_encode(os.urandom(16))
    if iat is None:
        iat = int(time.time())
    if exp is None:
        exp = iat + 72 * 3600  # 72 hours

    pub_key_bytes = Ed25519PrivateKey.from_private_bytes(private_key_bytes).public_key().public_bytes_raw()
    pub_b64 = base64url_encode(pub_key_bytes)

    header = {
        "alg": "EdDSA",
        "typ": "tng-offline-tx+jws",
        "kid": f"did:tng:device:{sender_kid}",
        "policy": policy_version,
        "ver": 1,
    }

    payload = {
        "tx_id": sender_kid,  # simplified for test
        "sender": {
            "kid": f"did:tng:device:{sender_kid}",
            "user_id": sender_user_id,
            "pub": pub_b64,
        },
        "receiver": {
            "kid": f"did:tng:device:{receiver_kid}",
            "user_id": receiver_user_id,
            "pub": base64url_encode(os.urandom(32)),  # placeholder receiver pub
        },
        "amount": {
            "value": amount_value,
            "currency": "MYR",
            "scale": 2,
        },
        "nonce": nonce,
        "iat": iat,
        "exp": exp,
        "policy_signed_balance": "120.00",
    }

    header_b64 = base64url_encode(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    payload_b64 = base64url_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signing_input = f"{header_b64}.{payload_b64}".encode("utf-8")

    private_key = Ed25519PrivateKey.from_private_bytes(private_key_bytes)
    signature = private_key.sign(signing_input)
    sig_b64 = base64url_encode(signature)

    return f"{header_b64}.{payload_b64}.{sig_b64}"
