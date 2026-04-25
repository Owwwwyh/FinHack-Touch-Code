"""
Alibaba Function Compute: wallet-sync
Per docs/08-backend-api.md §3.4 — Apply queued reloads, return latest balance.
"""

import json
import os
import time
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

OTS_INSTANCE = os.environ.get("OTS_INSTANCE", "tng-finhack")


def handler(event, context):
    """FC handler for POST /v1/wallet/sync"""
    try:
        body = json.loads(event.get("body", "{}"))
    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": {"code": "BAD_REQUEST", "message": "Invalid JSON"}}),
        }

    user_id = body.get("user_id")
    since_version = body.get("since_version", 0)

    if not user_id:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": {"code": "BAD_REQUEST", "message": "user_id is required"}}),
        }

    # Read current wallet from Tablestore
    now = int(time.time())

    # Stub: return mock wallet for demo
    wallet = {
        "user_id": user_id,
        "balance_myr": "248.50",
        "currency": "MYR",
        "version": 4321,
        "as_of": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now)),
        "safe_offline_balance_myr": "120.00",
        "policy_version": "v3.2026-04-22",
    }

    # Delta events since the requested version
    delta_events = []
    if since_version < 4321:
        delta_events = [
            {"type": "topup", "amount_myr": "50.00", "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now - 3600))},
        ]

    logger.info(f"Wallet sync: user_id={user_id}, since_version={since_version}")

    return {
        "statusCode": 200,
        "body": json.dumps({**wallet, "delta_events": delta_events}),
    }
