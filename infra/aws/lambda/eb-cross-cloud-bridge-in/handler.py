"""
AWS Lambda: eb-cross-cloud-bridge-in
Per docs/05-aws-services.md §8 — Translate Alibaba EB events → internal EB.
"""

import json
import os
import logging
import hmac
import hashlib

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

EVENT_BUS = os.environ.get("EVENTBRIDGE_BUS", "tng-cross-cloud")
HMAC_SECRET = os.environ.get("ALIBABA_INGEST_HMAC_SECRET", "")

eb = boto3.client("events")


def handler(event, context):
    """Lambda handler for inbound cross-cloud events from Alibaba."""
    # API GW passes the body; verify HMAC
    body = event.get("body", "{}")
    headers = event.get("headers", {})
    signature = headers.get("x-tng-signature", headers.get("X-TNG-Signature", ""))

    # Verify HMAC
    if HMAC_SECRET and signature:
        expected = hmac.new(
            HMAC_SECRET.encode(),
            body.encode() if isinstance(body, str) else body,
            hashlib.sha256,
        ).hexdigest()
        if not hmac.compare_digest(f"sha256={expected}", signature):
            logger.warning("HMAC verification failed")
            return {"statusCode": 401, "body": json.dumps({"error": "Invalid signature"})}

    try:
        payload = json.loads(body) if isinstance(body, str) else body
    except json.JSONDecodeError:
        return {"statusCode": 400, "body": json.dumps({"error": "Invalid JSON"})}

    # Put event onto internal EventBridge
    detail_type = payload.get("detail-type", "alibaba.cross-cloud")
    source = payload.get("source", "tng.alibaba.fc")
    detail = payload.get("detail", {})

    try:
        eb.put_events(Entries=[{
            "Source": source,
            "DetailType": detail_type,
            "Detail": json.dumps(detail) if isinstance(detail, dict) else str(detail),
            "EventBusName": EVENT_BUS,
        }])
        logger.info(f"Cross-cloud event bridged in: type={detail_type}")
    except Exception as e:
        logger.error(f"Failed to bridge event: {e}")
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}

    return {"statusCode": 200, "body": json.dumps({"status": "bridged"})}
