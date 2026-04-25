"""Alibaba FC: tokens-settle handler.

Per docs/08-backend-api.md §3.5:
- POST /v1/tokens/settle
- Validates batch, emits cross-cloud event to AWS
"""

import json
import os
import logging
import time
import hashlib
import hmac
import urllib.request

logger = logging.getLogger()

ALIBABA_AK = os.environ.get('ALIBABA_AK', '')
ALIBABA_SK = os.environ.get('ALIBABA_SK', '')
AWS_BRIDGE_URL = os.environ.get('AWS_BRIDGE_URL', '')
AWS_BRIDGE_HMAC_SECRET = os.environ.get('AWS_BRIDGE_HMAC_SECRET', 'dev-secret')


def handler(event, context):
    """FC handler for POST /tokens/settle"""
    try:
        body = json.loads(event.get('body', '{}'))
        device_id = body.get('device_id', '')
        batch_id = body.get('batch_id', '')
        tokens = body.get('tokens', [])

        if not tokens or len(tokens) > 50:
            return {
                "isBase64Encoded": False,
                "statusCode": 400,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": {"code": "BAD_REQUEST", "message": "tokens must be 1-50"}}),
            }

        # Validate each token is a valid JWS format (3 dot-separated parts)
        for t in tokens:
            if t.count('.') != 2:
                return {
                    "isBase64Encoded": False,
                    "statusCode": 400,
                    "headers": {"Content-Type": "application/json"},
                    "body": json.dumps({"error": {"code": "BAD_REQUEST", "message": "Invalid JWS format"}}),
                }

        # Emit cross-cloud event to AWS via EventBridge bridge
        event_payload = {
            "version": "0",
            "id": batch_id,
            "detail-type": "tokens.settle.requested",
            "source": "tng.alibaba.fc",
            "time": time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
            "detail": {
                "device_id": device_id,
                "batch_id": batch_id,
                "tokens": tokens,
            },
        }

        # Send to AWS bridge
        _send_to_aws(event_payload)

        # Synchronous wait pattern (simplified for demo)
        # In production, would poll or wait for callback
        return {
            "isBase64Encoded": False,
            "statusCode": 200,
            "headers": {"Content-Type": "application/json; charset=utf-8"},
            "body": json.dumps({
                "batch_id": batch_id,
                "results": [{"tx_id": "pending", "status": "SUBMITTED"}],
            }),
        }

    except Exception as e:
        logger.error(f"tokens-settle error: {e}")
        return {
            "isBase64Encoded": False,
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": {"code": "INTERNAL", "message": str(e)}}),
        }


def _send_to_aws(payload: dict):
    """Send event to AWS cross-cloud bridge via HTTPS POST with HMAC signing."""
    try:
        body = json.dumps(payload).encode('utf-8')
        timestamp = str(int(time.time()))
        signature = hmac.new(
            AWS_BRIDGE_HMAC_SECRET.encode(),
            body + timestamp.encode(),
            hashlib.sha256,
        ).hexdigest()

        req = urllib.request.Request(
            AWS_BRIDGE_URL,
            data=body,
            headers={
                'Content-Type': 'application/json',
                'X-Timestamp': timestamp,
                'X-HMAC-Signature': signature,
            },
            method='POST',
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            logger.info(f"Bridge response: {resp.status}")
    except Exception as e:
        logger.error(f"Failed to send to AWS bridge: {e}")
