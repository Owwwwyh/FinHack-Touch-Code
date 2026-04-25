"""
AWS Lambda: settle-batch
Per docs/05-aws-services.md §4.1 and docs/03-token-protocol.md §7.

Verifies JWS tokens, checks nonce uniqueness, writes to DynamoDB ledger.
"""

import json
import os
import time
import boto3
from botocore.exceptions import ClientError

# Environment variables
LEDGER_TABLE = os.environ.get("DYNAMO_LEDGER_TABLE", "tng_token_ledger")
NONCE_TABLE = os.environ.get("DYNAMO_NONCE_TABLE", "tng_nonce_seen")
PUBKEY_CACHE_TABLE = os.environ.get("DYNAMO_PUBKEY_CACHE", "tng_pubkey_cache")
EVENT_BUS = os.environ.get("EVENTBRIDGE_BUS", "tng-cross-cloud")

ddb = boto3.resource("dynamodb")
eb = boto3.client("events")

ledger = ddb.Table(LEDGER_TABLE)
nonce_table = ddb.Table(NONCE_TABLE)
pubkey_cache = ddb.Table(PUBKEY_CACHE_TABLE)


def pubkey_lookup(kid: str) -> bytes | None:
    """Look up public key from DynamoDB cache."""
    try:
        resp = pubkey_cache.get_item(Key={"kid": kid})
        item = resp.get("Item")
        if not item:
            return None
        import base64
        return base64.urlsafe_b64decode(item["pub_b64"])
    except Exception:
        return None


def verify_token(jws: str) -> dict:
    """Verify a JWS token. Returns dict with ok, reason, header, payload."""
    import sys
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
    from jws import verify_token as _verify

    return _verify(jws, pubkey_lookup)


def handler(event, context):
    """Lambda handler for settle-batch."""
    detail = event.get("detail", event)
    tokens = detail.get("tokens", [])
    batch_id = detail.get("batch_id", "unknown")

    results = []

    for jws in tokens:
        # Verify token
        v = verify_token(jws)
        if not v["ok"]:
            results.append({
                "tx_id": v.get("payload", {}).get("tx_id", "unknown"),
                "status": "REJECTED",
                "reason": v["reason"],
            })
            continue

        payload = v["payload"]
        tx_id = payload.get("tx_id", "unknown")
        nonce = payload.get("nonce", "")

        # Check nonce (double-spend prevention)
        try:
            nonce_table.put_item(
                Item={
                    "nonce": nonce,
                    "tx_id": tx_id,
                    "ttl": int(time.time()) + 90 * 24 * 3600,  # 90 days
                },
                ConditionExpression="attribute_not_exists(nonce)",
            )
        except ClientError as e:
            if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
                results.append({
                    "tx_id": tx_id,
                    "status": "REJECTED",
                    "reason": "NONCE_REUSED",
                })
                continue
            raise

        # Write to token ledger
        ledger_item = {
            "tx_id": tx_id,
            "kid": v["header"].get("kid", ""),
            "iat": payload.get("iat", 0),
            "nonce": nonce,
            "amount_cents": int(float(payload.get("amount", {}).get("value", 0)) * 100),
            "currency": payload.get("amount", {}).get("currency", "MYR"),
            "sender_user_id": payload.get("sender", {}).get("user_id", ""),
            "receiver_user_id": payload.get("receiver", {}).get("user_id", ""),
            "status": "SETTLED",
            "settled_at": int(time.time()),
            "policy_version": v["header"].get("policy", ""),
            "jws": jws,
        }
        ledger.put_item(Item=ledger_item)

        # Emit settlement event
        eb.put_events(Entries=[{
            "Source": "tng.aws.lambda.settle",
            "DetailType": "settlement.completed",
            "Detail": json.dumps({
                "batch_id": batch_id,
                "tx_id": tx_id,
                "status": "SETTLED",
                "sender_user_id": ledger_item["sender_user_id"],
                "receiver_user_id": ledger_item["receiver_user_id"],
                "amount_cents": ledger_item["amount_cents"],
                "settled_at": ledger_item["settled_at"],
            }),
            "EventBusName": EVENT_BUS,
        }])

        results.append({
            "tx_id": tx_id,
            "status": "SETTLED",
            "settled_at": ledger_item["settled_at"],
        })

    return {"batch_id": batch_id, "results": results}
