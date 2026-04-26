"""
POST /v1/devices/register
Registers a device Ed25519 public key + attestation chain.
Writes to Tablestore devices table and OSS pubkeys bucket.
"""
import base64
import hashlib
import json
import logging
import os
import sys
import uuid
from datetime import datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from lib.alibaba_runtime import create_oss_bucket, create_tablestore_client, device_table_name, wallets_table_name
from lib.jwt_middleware import JwtVerificationError, get_jwt_middleware

logger = logging.getLogger()

MAX_DEVICES_PER_USER = 3
SIGNING_KEY_ALIAS = "tng_signing_v1"


def _error(start_response, http_status: str, code: str, message: str, request_id: str):
    body = {"error": {"code": code, "message": message, "request_id": request_id}}
    start_response(http_status, [
        ("Content-Type", "application/json; charset=utf-8"),
        ("X-Request-Id", request_id),
        ("X-API-Version", "v1"),
    ])
    return [json.dumps(body).encode("utf-8")]


def _generate_kid() -> str:
    return uuid.uuid4().hex.upper()[:26]


def handler(environ, start_response):
    request_id = environ.get("HTTP_X_REQUEST_ID", f"req_{uuid.uuid4().hex[:12]}")

    # Auth
    auth_header = environ.get("HTTP_AUTHORIZATION", "")
    token = auth_header.removeprefix("Bearer ").strip()
    try:
        claims = get_jwt_middleware().verify(token)
    except JwtVerificationError as e:
        return _error(start_response, "401 Unauthorized", e.code, str(e), request_id)

    # Parse body
    content_length = int(environ.get("CONTENT_LENGTH", 0) or 0)
    raw_body = environ["wsgi.input"].read(content_length) if content_length > 0 else b""
    try:
        body = json.loads(raw_body)
    except json.JSONDecodeError:
        return _error(start_response, "400 Bad Request", "BAD_REQUEST", "Invalid JSON body", request_id)

    # Validate required fields
    for field in ("user_id", "public_key", "alg"):
        if not body.get(field):
            return _error(start_response, "400 Bad Request", "BAD_REQUEST", f"Missing required field: {field}", request_id)

    if body["alg"] != "EdDSA":
        return _error(start_response, "422 Unprocessable Entity", "BAD_REQUEST", "alg must be EdDSA", request_id)

    # Validate public key is 32 bytes base64url
    try:
        pub_bytes = base64.urlsafe_b64decode(body["public_key"] + "==")
        if len(pub_bytes) != 32:
            raise ValueError("Ed25519 public key must be 32 bytes")
    except Exception:
        return _error(start_response, "422 Unprocessable Entity", "BAD_REQUEST", "public_key must be base64url-encoded 32-byte Ed25519 key", request_id)

    user_id = body["user_id"]
    device_label = body.get("device_label", "Unknown device")
    attestation_chain = body.get("attestation_chain", [])
    android_id_hash = body.get("android_id_hash", "")
    registered_at = datetime.now(timezone.utc).isoformat()

    # Demo mode: skip Tablestore, return synthetic response
    if not os.environ.get("TABLESTORE_ENDPOINT"):
        kid = _generate_kid()
        device_id = f"did:tng:device:{kid}"
        response_body = {
            "device_id": device_id,
            "kid": kid,
            "policy_version": "v3.2026-04-22",
            "initial_safe_offline_balance_myr": "50.00",
            "registered_at": registered_at,
        }
        start_response("200 OK", [
            ("Content-Type", "application/json; charset=utf-8"),
            ("X-Request-Id", request_id),
            ("X-API-Version", "v1"),
        ])
        return [json.dumps(response_body).encode("utf-8")]

    try:
        import tablestore

        client = create_tablestore_client(environ)

        # Check device count for user
        primary_key = [("user_id", user_id)]
        cols = tablestore.ColumnsToGet(["device_count"])
        _, wallet_row, _ = client.get_row(wallets_table_name(), primary_key, cols, None, 1)
        device_count = 0
        if wallet_row:
            attrs = {c[0]: c[1] for c in wallet_row.attribute_columns}
            device_count = int(attrs.get("device_count", 0))

        if device_count >= MAX_DEVICES_PER_USER:
            return _error(start_response, "409 Conflict", "DEVICE_LIMIT_REACHED", f"Maximum {MAX_DEVICES_PER_USER} devices per user", request_id)

        # Generate kid and write device row
        kid = _generate_kid()
        device_id = f"did:tng:device:{kid}"

        device_pk = [("kid", kid)]
        device_attrs = [
            ("user_id", user_id),
            ("device_id", device_id),
            ("device_label", device_label),
            ("public_key", body["public_key"]),
            ("alg", body["alg"]),
            ("android_id_hash", android_id_hash),
            ("attestation_chain", json.dumps(attestation_chain)),
            ("status", "ACTIVE"),
            ("registered_at", registered_at),
        ]
        device_row = tablestore.Row(device_pk, device_attrs)
        client.put_row(
            device_table_name(),
            device_row,
            tablestore.Condition(tablestore.RowExistenceExpectation.EXPECT_NOT_EXIST),
        )

        # Increment device count in wallets table
        inc_row = tablestore.Row(primary_key, {"INCREMENT": [("device_count", 1)]})
        client.update_row(
            wallets_table_name(),
            inc_row,
            tablestore.Condition(tablestore.RowExistenceExpectation.IGNORE),
        )

    except Exception as e:
        logger.error("Tablestore write failed: %s", e)
        return _error(start_response, "500 Internal Server Error", "INTERNAL", "Storage error", request_id)

    # Upload pubkey to OSS
    try:
        bucket = create_oss_bucket(environ)
        bucket.put_object(f"{kid}.pub", body["public_key"].encode("utf-8"))
    except Exception as e:
        logger.warning("OSS pubkey upload failed (non-fatal): %s", e)

    response_body = {
        "device_id": device_id,
        "kid": kid,
        "policy_version": "v3.2026-04-22",
        "initial_safe_offline_balance_myr": "50.00",
        "registered_at": registered_at,
    }
    start_response("200 OK", [
        ("Content-Type", "application/json; charset=utf-8"),
        ("X-Request-Id", request_id),
        ("X-API-Version", "v1"),
    ])
    return [json.dumps(response_body).encode("utf-8")]
