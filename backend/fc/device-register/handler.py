"""
Alibaba Function Compute: device-register
Per docs/08-backend-api.md §3.1 — Register device pubkey + attestation.

Writes to Tablestore devices table + copies pubkey to Alibaba OSS.
"""

import json
import os
import time
import logging
import base64

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
OTS_INSTANCE = os.environ.get("OTS_INSTANCE", "tng-finhack")
OSS_PUBKEY_BUCKET = os.environ.get("OSS_PUBKEY_BUCKET", "tng-finhack-pubkeys")

# Stub clients (replace with real Alibaba SDK in production)
_ots_client = None
_oss_client = None


def _get_ots_client():
    global _ots_client
    if _ots_client is None:
        try:
            from ots2 import OTSClient
            _ots_client = OTSClient(
                os.environ.get("OTS_ENDPOINT", ""),
                os.environ.get("ALIBABA_ACCESS_KEY_ID", ""),
                os.environ.get("ALIBABA_ACCESS_KEY_SECRET", ""),
                OTS_INSTANCE,
            )
        except ImportError:
            _ots_client = None
    return _ots_client


def _get_oss_client():
    global _oss_client
    if _oss_client is None:
        try:
            import oss2
            auth = oss2.Auth(
                os.environ.get("ALIBABA_ACCESS_KEY_ID", ""),
                os.environ.get("ALIBABA_ACCESS_KEY_SECRET", ""),
            )
            _oss_client = oss2.Bucket(
                auth,
                os.environ.get("OSS_ENDPOINT", "oss-ap-southeast-3.aliyuncs.com"),
                OSS_PUBKEY_BUCKET,
            )
        except ImportError:
            _oss_client = None
    return _oss_client


def _verify_attestation(attestation_chain: list, challenge: str) -> bool:
    """Verify Android Key Attestation chain rooted at Google attestation root.
    Stub for demo — in production, verify cert chain properly."""
    if not attestation_chain:
        return False
    # Demo: accept any non-empty chain
    return True


def handler(event, context):
    """FC handler for POST /v1/devices/register"""
    try:
        body = json.loads(event.get("body", "{}"))
    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": {"code": "BAD_REQUEST", "message": "Invalid JSON"}}),
        }

    user_id = body.get("user_id")
    device_label = body.get("device_label", "Unknown Device")
    public_key = body.get("public_key")
    attestation_chain = body.get("attestation_chain", [])
    alg = body.get("alg", "EdDSA")
    android_id_hash = body.get("android_id_hash", "")

    # Validate required fields
    if not user_id or not public_key:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": {"code": "BAD_REQUEST", "message": "user_id and public_key are required"}}),
        }

    if alg != "EdDSA":
        return {
            "statusCode": 400,
            "body": json.dumps({"error": {"code": "BAD_REQUEST", "message": "Only EdDSA is supported"}}),
        }

    # Verify attestation
    if not _verify_attestation(attestation_chain, "demo-challenge"):
        return {
            "statusCode": 422,
            "body": json.dumps({"error": {"code": "ATTESTATION_INVALID", "message": "Attestation chain verification failed"}}),
        }

    # Check device limit (max 3 per user)
    # Stub: always allow for demo

    # Generate device ID (UUIDv7-like)
    import uuid
    kid = uuid.uuid1().hex[:26]  # Simplified for demo
    device_id = f"did:tng:device:{kid}"
    now = int(time.time())

    # Write to Tablestore
    ots = _get_ots_client()
    if ots:
        try:
            from ots2 import PutRowItem, RowPrimaryKey, RowPutChange, Condition
            from ots2 import INF_MIN, INF_MAX
            pk = [(u"device_id", kid)]
            attr = [
                (u"user_id", user_id),
                (u"pub_key_b64", public_key),
                (u"alg", alg),
                (u"attestation_sha256", ""),
                (u"status", u"ACTIVE"),
                (u"registered_at", now),
                (u"last_seen_at", now),
                (u"device_label", device_label),
            ]
            put_change = RowPutChange(OTS_INSTANCE, "devices", pk)
            for k, v in attr:
                put_change.add_column(k, v)
            ots.put_row(put_change, Condition(None))
        except Exception as e:
            logger.warning(f"OTS write failed: {e}")

    # Copy pubkey to OSS
    oss = _get_oss_client()
    if oss:
        try:
            # Store as PEM-wrapped raw Ed25519 pubkey
            pub_bytes = base64.urlsafe_b64decode(public_key + "=" * (4 - len(public_key) % 4))
            pem_content = f"-----BEGIN PUBLIC KEY-----\n{base64.b64encode(pub_bytes).decode()}\n-----END PUBLIC KEY-----"
            oss.put_object(f"{kid}.pem", pem_content.encode())
        except Exception as e:
            logger.warning(f"OSS write failed: {e}")

    # Initial policy and safe offline balance
    policy_version = "v3.2026-04-22"
    initial_safe_balance = "50.00"

    logger.info(f"Device registered: device_id={device_id}, user_id={user_id}")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "device_id": device_id,
            "kid": kid,
            "policy_version": policy_version,
            "initial_safe_offline_balance_myr": initial_safe_balance,
            "registered_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now)),
        }),
    }
