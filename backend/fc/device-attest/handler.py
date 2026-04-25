"""
Alibaba Function Compute: device-attest
Per docs/08-backend-api.md §3.2 — Refresh attestation.
"""

import json
import os
import time
import logging
import base64

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    """FC handler for POST /v1/devices/attest"""
    try:
        body = json.loads(event.get("body", "{}"))
    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": {"code": "BAD_REQUEST", "message": "Invalid JSON"}}),
        }

    kid = body.get("kid")
    attestation_chain = body.get("attestation_chain", [])

    if not kid or not attestation_chain:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": {"code": "BAD_REQUEST", "message": "kid and attestation_chain are required"}}),
        }

    # Verify attestation chain (stub for demo)
    now = int(time.time())
    attest_valid_until = now + 365 * 24 * 3600  # 1 year

    logger.info(f"Attestation refreshed for kid={kid}")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "kid": kid,
            "attest_valid_until": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(attest_valid_until)),
        }),
    }
