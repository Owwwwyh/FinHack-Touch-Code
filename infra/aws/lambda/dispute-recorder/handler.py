"""
AWS Lambda: dispute-recorder
Per docs/05-aws-services.md §4 — Records disputes (writes both Dynamo + RDS via VPN).
"""

import json
import os
import time
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

LEDGER_TABLE = os.environ.get("DYNAMO_LEDGER_TABLE", "tng_token_ledger")
ddb = boto3.resource("dynamodb")
ledger = ddb.Table(LEDGER_TABLE)


def handler(event, context):
    """Lambda handler for dispute recording."""
    detail = event.get("detail", event)
    dispute_id = detail.get("dispute_id", "")
    tx_id = detail.get("tx_id", "")
    reason_code = detail.get("reason_code", "")
    raised_by = detail.get("raised_by", "")

    if not tx_id:
        logger.error("No tx_id in dispute event")
        return {"status": "error", "reason": "missing tx_id"}

    # Update token ledger status to DISPUTED
    try:
        ledger.update_item(
            Key={"tx_id": tx_id},
            UpdateExpression="SET #s = :status, dispute_id = :dispute_id, reason_code = :reason",
            ConditionExpression="attribute_exists(tx_id)",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={
                ":status": "DISPUTED",
                ":dispute_id": dispute_id,
                ":reason": reason_code,
            },
        )
        logger.info(f"Dispute recorded: tx_id={tx_id}, dispute_id={dispute_id}")
    except Exception as e:
        logger.error(f"Failed to update ledger for dispute: {e}")
        return {"status": "error", "reason": str(e)}

    return {"status": "recorded", "tx_id": tx_id, "dispute_id": dispute_id}
