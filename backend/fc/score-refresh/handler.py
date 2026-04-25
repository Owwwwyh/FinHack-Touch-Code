"""
Alibaba Function Compute: score-refresh
Per docs/08-backend-api.md §3.7 — Proxy to PAI-EAS for fresh safe-offline-balance.
"""

import json
import os
import time
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

EAS_ENDPOINT = os.environ.get("EAS_ENDPOINT", "http://localhost:8080/score")
EAS_TOKEN = os.environ.get("EAS_TOKEN", "")


def handler(event, context):
    """FC handler for POST /v1/score/refresh"""
    try:
        body = json.loads(event.get("body", "{}"))
    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": {"code": "BAD_REQUEST", "message": "Invalid JSON"}}),
        }

    user_id = body.get("user_id")
    policy_version = body.get("policy_version", "v3.2026-04-22")
    features = body.get("features", {})

    if not user_id or not features:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": {"code": "BAD_REQUEST", "message": "user_id and features are required"}}),
        }

    # Call PAI-EAS endpoint
    now = int(time.time())
    try:
        import requests
        resp = requests.post(
            EAS_ENDPOINT,
            json={
                "user_id": user_id,
                "features": features,
                "policy": policy_version,
            },
            headers={
                "Authorization": f"Bearer {EAS_TOKEN}",
                "Content-Type": "application/json",
            },
            timeout=0.8,  # 800ms timeout per spec
        )
        if resp.status_code == 200:
            eas_result = resp.json()
            logger.info(f"Score refresh: user_id={user_id}, balance={eas_result.get('safe_offline_balance_myr')}")
            return {
                "statusCode": 200,
                "body": json.dumps({
                    "safe_offline_balance_myr": eas_result.get("safe_offline_balance_myr", "50.00"),
                    "confidence": eas_result.get("confidence", 0.5),
                    "policy_version": eas_result.get("policy", policy_version),
                    "computed_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now)),
                }),
            }
    except requests.Timeout:
        logger.warning(f"PAI-EAS timeout for user_id={user_id}")
        return {
            "statusCode": 504,
            "body": json.dumps({"error": {"code": "INTERNAL", "message": "Score refresh timeout, use on-device estimate"}}),
        }
    except Exception as e:
        logger.warning(f"PAI-EAS error: {e}")

    # Fallback: return a default score
    return {
        "statusCode": 200,
        "body": json.dumps({
            "safe_offline_balance_myr": "50.00",
            "confidence": 0.3,
            "policy_version": policy_version,
            "computed_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now)),
        }),
    }
