"""
Alibaba Function Compute: publickeys-get
Per docs/08-backend-api.md §3.9 — Resolve a device's public key.
Returns signed URL to OSS pubkey directory.
"""

import json
import os
import time
import logging
import base64

logger = logging.getLogger()
logger.setLevel(logging.INFO)

OSS_PUBKEY_BUCKET = os.environ.get("OSS_PUBKEY_BUCKET", "tng-finhack-pubkeys")
OTS_INSTANCE = os.environ.get("OTS_INSTANCE", "tng-finhack")


def handler(event, context):
    """FC handler for GET /v1/publickeys/{kid}"""
    # Extract kid from path parameters
    path_params = event.get("pathParameters", {})
    kid = path_params.get("kid", "")

    if not kid:
        # Try to extract from path
        path = event.get("path", "")
        parts = path.rstrip("/").split("/")
        kid = parts[-1] if parts else ""

    if not kid:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": {"code": "BAD_REQUEST", "message": "kid is required"}}),
        }

    # Look up from Tablestore (stub for demo)
    now = int(time.time())

    # Try to read from OSS directly (stub)
    public_key = ""
    status = "ACTIVE"
    registered_at = "2026-04-10T11:00:00Z"

    # Demo: return a mock public key
    # In production, this would read from Tablestore devices table
    public_key = base64.urlsafe_b64encode(b"\x00" * 32).decode().rstrip("=")

    logger.info(f"Public key requested: kid={kid}")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "kid": kid,
            "alg": "EdDSA",
            "public_key": public_key,
            "status": status,
            "registered_at": registered_at,
            "revoked_at": None,
        }),
    }
