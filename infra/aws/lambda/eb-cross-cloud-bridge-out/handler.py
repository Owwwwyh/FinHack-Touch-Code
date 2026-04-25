"""
AWS Lambda: eb-cross-cloud-bridge-out
Per docs/05-aws-services.md §8.

POSTs settlement results from AWS EventBridge to Alibaba EventBridge webhook.
HMAC-signed payload for authenticity (boundary B3).
"""

import json
import hmac
import hashlib
import os
import time
import urllib.request
import urllib.error
import boto3

INGEST_URL = os.environ.get("ALIBABA_INGEST_URL", "")
HMAC_SECRET = os.environ.get("ALIBABA_INGEST_HMAC_SECRET", "")

secrets_client = boto3.client("secretsmanager")


def _get_secret(key: str) -> str:
    """Retrieve secret from AWS Secrets Manager if not in env."""
    if key in os.environ and os.environ[key]:
        return os.environ[key]
    try:
        secret_name = os.environ.get(f"{key}_SECRET_NAME", f"tng-finhack/{key.lower()}")
        resp = secrets_client.get_secret_value(SecretId=secret_name)
        return json.loads(resp["SecretString"])[key.split("_")[-1].lower()]
    except Exception:
        return ""


def handler(event, context):
    """Forward AWS EventBridge event to Alibaba EventBridge."""
    ingest_url = _get_secret("ALIBARA_INGEST_URL") or INGEST_URL
    hmac_secret = _get_secret("ALIBARA_INGEST_HMAC_SECRET") or HMAC_SECRET

    if not ingest_url:
        print("Warning: ALIBABA_INGEST_URL not configured, skipping bridge")
        return {"status": "skipped", "reason": "no_url"}

    # Build the event payload
    payload = json.dumps({
        "version": "0",
        "id": event.get("id", ""),
        "detail-type": event.get("detail-type", ""),
        "source": event.get("source", "tng.aws"),
        "time": event.get("time", ""),
        "detail": event.get("detail", {}),
    }).encode("utf-8")

    # HMAC sign
    timestamp = str(int(time.time()))
    signature = hmac.new(
        hmac_secret.encode("utf-8"),
        timestamp.encode("utf-8") + b"." + payload,
        hashlib.sha256,
    ).hexdigest()

    headers = {
        "Content-Type": "application/json",
        "X-TNG-Timestamp": timestamp,
        "X-TNG-Signature": signature,
    }

    req = urllib.request.Request(
        ingest_url,
        data=payload,
        headers=headers,
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            body = resp.read().decode("utf-8")
            return {"status": "ok", "response_code": resp.status, "body": body}
    except urllib.error.HTTPError as e:
        print(f"Bridge POST failed: {e.code} {e.reason}")
        return {"status": "error", "code": e.code, "reason": e.reason}
    except Exception as e:
        print(f"Bridge POST error: {e}")
        return {"status": "error", "reason": str(e)}
