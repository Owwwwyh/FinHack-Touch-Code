"""
Alibaba Function Compute: eb-cross-cloud-ingest
Per docs/08-backend-api.md §3.11 — Receive AWS settlement-result events.
Also per docs/06-alibaba-services.md §10 — receives cross-cloud webhook posts.
"""

import json
import os
import time
import logging
import hmac
import hashlib

logger = logging.getLogger()
logger.setLevel(logging.INFO)

HMAC_SECRET = os.environ.get("AWS_BRIDGE_HMAC_SECRET", "")
OTS_INSTANCE = os.environ.get("OTS_INSTANCE", "tng-finhack")
RDS_DSN = os.environ.get("RDS_DSN", "")


def _verify_hmac(event_body: str, signature_header: str) -> bool:
    """Verify HMAC signature from AWS bridge."""
    if not HMAC_SECRET:
        logger.warning("HMAC secret not configured, skipping verification")
        return True  # Demo mode

    expected = hmac.new(
        HMAC_SECRET.encode(),
        event_body.encode(),
        hashlib.sha256,
    ).hexdigest()

    return hmac.compare_digest(f"sha256={expected}", signature_header)


def handler(event, context):
    """FC handler for POST /v1/_internal/eb/aws-bridge"""
    body = event.get("body", "{}")
    headers = event.get("headers", {})
    signature = headers.get("x-tng-signature", headers.get("X-TNG-Signature", ""))

    # Verify HMAC
    if not _verify_hmac(body, signature):
        return {
            "statusCode": 401,
            "body": json.dumps({"error": {"code": "UNAUTHENTICATED", "message": "Invalid HMAC signature"}}),
        }

    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": {"code": "BAD_REQUEST", "message": "Invalid JSON"}}),
        }

    detail_type = payload.get("detail-type", "")
    detail = payload.get("detail", {})

    logger.info(f"Cross-cloud event received: type={detail_type}")

    if detail_type == "settlement.completed":
        _handle_settlement_completed(detail)
    elif detail_type == "dispute.created":
        _handle_dispute_created(detail)
    else:
        logger.warning(f"Unknown event type: {detail_type}")

    return {
        "statusCode": 200,
        "body": json.dumps({"status": "processed"}),
    }


def _handle_settlement_completed(detail: dict):
    """Update Tablestore wallet balance and RDS history for settled transactions."""
    results = detail.get("results", [])

    for result in results:
        if result.get("status") != "SETTLED":
            continue

        tx_id = result.get("tx_id", "")
        sender_user_id = result.get("sender_user_id", "")
        receiver_user_id = result.get("receiver_user_id", "")
        amount_cents = result.get("amount_cents", 0)
        settled_at = result.get("settled_at", 0)

        # Update receiver's wallet in Tablestore (+amount)
        # Update sender's wallet in Tablestore (-amount)
        # Stub for demo — in production, use OTS conditional update
        logger.info(f"Settlement: tx={tx_id}, +{amount_cents} for {receiver_user_id}, -{amount_cents} for {sender_user_id}")

        # Write to RDS settled_transactions
        try:
            if RDS_DSN:
                import pymysql
                conn = pymysql.connect(**_parse_dsn(RDS_DSN))
                with conn.cursor() as cursor:
                    cursor.execute(
                        "INSERT IGNORE INTO settled_transactions "
                        "(tx_id, sender_user_id, receiver_user_id, amount_cents, currency, iat, settled_at, policy_version, status) "
                        "VALUES (%s, %s, %s, %s, %s, %s, FROM_UNIXTIME(%s), %s, %s)",
                        (tx_id, sender_user_id, receiver_user_id, amount_cents, "MYR", 0, settled_at, "v3.2026-04-22", "SETTLED"),
                    )
                conn.commit()
                conn.close()
        except Exception as e:
            logger.warning(f"RDS write failed: {e}")

    # Trigger Mobile Push notification
    try:
        _send_push_notifications(results)
    except Exception as e:
        logger.warning(f"Push notification failed: {e}")


def _handle_dispute_created(detail: dict):
    """Handle dispute event from AWS."""
    logger.info(f"Dispute event: {detail.get('dispute_id')}")


def _send_push_notifications(results: list):
    """Send push notifications for settled transactions."""
    # Stub — in production, use Alibaba Mobile Push API
    for result in results:
        if result.get("status") == "SETTLED":
            logger.info(f"Push: settlement notification for tx={result.get('tx_id')}")


def _parse_dsn(dsn: str) -> dict:
    from urllib.parse import urlparse
    p = urlparse(dsn)
    return {
        "host": p.hostname,
        "port": p.port or 3306,
        "user": p.username,
        "password": p.password,
        "database": p.path.lstrip("/"),
    }
