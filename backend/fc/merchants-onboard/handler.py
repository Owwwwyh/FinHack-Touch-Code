"""
Alibaba Function Compute: merchants-onboard
Per docs/08-backend-api.md §3.10 — Stub merchant onboarding.
"""

import json
import os
import time
import logging
import uuid

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    """FC handler for POST /v1/merchants/onboard"""
    try:
        body = json.loads(event.get("body", "{}"))
    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": {"code": "BAD_REQUEST", "message": "Invalid JSON"}}),
        }

    merchant_name = body.get("merchant_name")
    business_id = body.get("business_id", "")
    contact = body.get("contact", "")

    if not merchant_name:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": {"code": "BAD_REQUEST", "message": "merchant_name is required"}}),
        }

    # Generate merchant ID
    merchant_id = uuid.uuid1().hex[:26]

    logger.info(f"Merchant onboarded: merchant_id={merchant_id}, name={merchant_name}")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "merchant_id": merchant_id,
        }),
    }
