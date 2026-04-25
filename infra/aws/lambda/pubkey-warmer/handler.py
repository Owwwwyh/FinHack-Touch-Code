"""
AWS Lambda: pubkey-warmer
Per docs/05-aws-services.md §4.

Pulls new public keys from Alibaba OSS into DynamoDB pubkey_cache.
Scheduled every 15 minutes.
"""

import json
import os
import boto3
import urllib.request

PUBKEY_CACHE_TABLE = os.environ.get("DYNAMO_PUBKEY_CACHE", "tng_pubkey_cache")
OSS_PUBKEY_BUCKET = os.environ.get("OSS_PUBKEY_BUCKET", "tng-finhack-pubkeys")

ddb = boto3.resource("dynamodb")
table = ddb.Table(PUBKEY_CACHE_TABLE)


def handler(event, context):
    """
    Pull new public keys from Alibaba OSS pubkey directory
    and upsert into DynamoDB pubkey_cache.
    """
    # In a full implementation, this would:
    # 1. List objects in OSS bucket tng-finhack-pubkeys
    # 2. For each {kid}.pem, download and parse the public key
    # 3. Upsert into DynamoDB tng_pubkey_cache

    # For the demo, we just refresh TTL on existing entries
    try:
        # Scan existing cache entries
        response = table.scan(ProjectionExpression="kid, pub_b64, #s", ExpressionAttributeNames={"#s": "status"})

        refreshed = 0
        for item in response.get("Items", []):
            kid = item["kid"]
            # Refresh TTL
            table.update_item(
                Key={"kid": kid},
                UpdateExpression="SET #ttl = :ttl",
                ExpressionAttributeNames={"#ttl": "ttl"},
                ExpressionAttributeValues={":ttl": int(__import__("time").time()) + 7 * 24 * 3600},
            )
            refreshed += 1

        return {
            "status": "ok",
            "refreshed": refreshed,
            "message": "In production, this would pull new keys from Alibaba OSS",
        }
    except Exception as e:
        return {"status": "error", "reason": str(e)}
