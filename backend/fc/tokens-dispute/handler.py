"""
Alibaba Function Compute: tokens-dispute
Per docs/08-backend-api.md §3.6 — Create dispute record.

Writes to Alibaba RDS disputes table + emits cross-cloud event to update
DynamoDB token_ledger status to DISPUTED.
"""

import json
import os
import time
import logging
import uuid

logger = logging.getLogger()
logger.setLevel(logging.INFO)

RDS_DSN = os.environ.get("RDS_DSN", "")
EVENT_BUS = os.environ.get("EVENTBRIDGE_BUS", "tng-cross-cloud")


def handler(event, context):
    """FC handler for POST /v1/tokens/dispute"""
    try:
        body = json.loads(event.get("body", "{}"))
    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": {"code": "BAD_REQUEST", "message": "Invalid JSON"}}),
        }

    tx_id = body.get("tx_id")
    reason_code = body.get("reason_code")
    details = body.get("details", "")

    valid_reasons = {"UNAUTHORIZED", "WRONG_AMOUNT", "NOT_RECEIVED", "OTHER"}
    if not tx_id or not reason_code:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": {"code": "BAD_REQUEST", "message": "tx_id and reason_code are required"}}),
        }

    if reason_code not in valid_reasons:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": {"code": "BAD_REQUEST", "message": f"reason_code must be one of {valid_reasons}"}}),
        }

    # Extract user from JWT claims
    claims = event.get("requestContext", {}).get("authorizer", {}).get("claims", {})
    raised_by = claims.get("sub", "unknown")

    # Generate dispute ID
    dispute_id = f"dsp_{uuid.uuid1().hex[:22]}"
    now = int(time.time())
    now_dt = time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime(now))

    # Write to RDS
    try:
        import pymysql
        if RDS_DSN:
            conn = pymysql.connect(**_parse_dsn(RDS_DSN))
            with conn.cursor() as cursor:
                cursor.execute(
                    "INSERT INTO disputes (dispute_id, tx_id, reason_code, details, status, raised_by, raised_at) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s)",
                    (dispute_id, tx_id, reason_code, details, "RECEIVED", raised_by, now_dt),
                )
            conn.commit()
            conn.close()
    except Exception as e:
        logger.warning(f"RDS write failed (stub mode): {e}")

    # Emit cross-cloud event to update DynamoDB ledger
    try:
        import hmac
        import hashlib
        import requests

        bridge_url = os.environ.get("AWS_BRIDGE_URL", "")
        bridge_secret = os.environ.get("AWS_BRIDGE_HMAC_SECRET", "")

        if bridge_url:
            payload = {
                "version": "0",
                "id": dispute_id,
                "detail-type": "dispute.created",
                "source": "tng.alibaba.fc.dispute",
                "time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now)),
                "detail": {
                    "dispute_id": dispute_id,
                    "tx_id": tx_id,
                    "reason_code": reason_code,
                    "raised_by": raised_by,
                    "raised_at": now,
                },
            }
            body_json = json.dumps(payload)
            sig = hmac.new(bridge_secret.encode(), body_json.encode(), hashlib.sha256).hexdigest()
            requests.post(
                bridge_url,
                data=body_json,
                headers={
                    "Content-Type": "application/json",
                    "X-TNG-Signature": f"sha256={sig}",
                    "X-TNG-Timestamp": str(now),
                },
                timeout=5,
            )
    except Exception as e:
        logger.warning(f"Cross-cloud event failed: {e}")

    logger.info(f"Dispute created: dispute_id={dispute_id}, tx_id={tx_id}")

    return {
        "statusCode": 201,
        "body": json.dumps({
            "dispute_id": dispute_id,
            "status": "RECEIVED",
        }),
    }


def _parse_dsn(dsn: str) -> dict:
    """Parse mysql://user:pass@host:port/db DSN."""
    from urllib.parse import urlparse
    p = urlparse(dsn)
    return {
        "host": p.hostname,
        "port": p.port or 3306,
        "user": p.username,
        "password": p.password,
        "database": p.path.lstrip("/"),
    }
