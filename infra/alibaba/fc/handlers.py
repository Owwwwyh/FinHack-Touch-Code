"""
Alibaba Function Compute: Wallet API handlers.
Per docs/06-alibaba-services.md §4, docs/08-backend-api.md.

Implements all FC function handlers for the TNG wallet API.
"""

import json
import os
import time
import logging
import urllib.request

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment
OTS_INSTANCE = os.environ.get("OTS_INSTANCE", "tng-finhack")
OSS_PUBKEY_BUCKET = os.environ.get("OSS_PUBKEY_BUCKET", "tng-finhack-pubkeys")
OSS_MODEL_BUCKET = os.environ.get("OSS_MODEL_BUCKET", "tng-finhack-models")
EAS_ENDPOINT = os.environ.get("EAS_ENDPOINT", "")
AWS_BRIDGE_URL = os.environ.get("AWS_BRIDGE_URL", "")
RDS_DSN = os.environ.get("RDS_DSN", "")
COGNITO_JWKS_URL = os.environ.get("COGNITO_JWKS_URL", "")


# ─────────────────────────────────────────────
# JWT Verification Middleware
# ─────────────────────────────────────────────

def verify_jwt(token: str) -> dict | None:
    """Verify Cognito-issued JWT. Stub for demo."""
    # In production: fetch JWKS from COGNITO_JWKS_URL and verify RS256 signature
    # For demo: decode without verification
    try:
        import base64
        parts = token.split(".")
        if len(parts) < 2:
            return None
        payload = json.loads(base64.urlsafe_b64decode(parts[1] + "=="))
        return payload
    except Exception:
        return None


def get_auth_context(event: dict) -> dict | None:
    """Extract and verify JWT from request headers."""
    headers = event.get("headers", {})
    auth_header = headers.get("Authorization", headers.get("authorization", ""))
    if not auth_header.startswith("Bearer "):
        return None
    token = auth_header[7:]
    return verify_jwt(token)


def error_response(code: str, message: str, status: int = 400):
    """Build a standard error response."""
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"error": {"code": code, "message": message}}),
    }


def ok_response(data: dict, status: int = 200):
    """Build a success response."""
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "X-API-Version": "v1",
        },
        "body": json.dumps(data),
    }


# ─────────────────────────────────────────────
# GET /v1/wallet/balance
# ─────────────────────────────────────────────

def wallet_balance(event, context):
    """Read wallet balance from Tablestore."""
    auth = get_auth_context(event)
    if not auth:
        return error_response("UNAUTHENTICATED", "Missing or invalid JWT", 401)

    user_id = auth.get("sub", auth.get("cognito:username", "unknown"))

    # In production: read from Tablestore
    # For demo: return mock data
    return ok_response({
        "user_id": user_id,
        "balance_myr": "248.50",
        "currency": "MYR",
        "version": 4321,
        "as_of": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "safe_offline_balance_myr": "120.00",
        "policy_version": "v3.2026-04-22",
    })


# ─────────────────────────────────────────────
# POST /v1/wallet/sync
# ─────────────────────────────────────────────

def wallet_sync(event, context):
    """Apply pending reloads and return latest balance."""
    auth = get_auth_context(event)
    if not auth:
        return error_response("UNAUTHENTICATED", "Missing or invalid JWT", 401)

    body = json.loads(event.get("body", "{}"))
    user_id = body.get("user_id", auth.get("sub", ""))
    since_version = body.get("since_version", 0)

    # In production: read from Tablestore, apply delta events
    return ok_response({
        "user_id": user_id,
        "balance_myr": "248.50",
        "currency": "MYR",
        "version": 4322,
        "as_of": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "safe_offline_balance_myr": "120.00",
        "policy_version": "v3.2026-04-22",
        "delta_events": [],
    })


# ─────────────────────────────────────────────
# POST /v1/devices/register
# ─────────────────────────────────────────────

def device_register(event, context):
    """Register device public key + attestation."""
    auth = get_auth_context(event)
    if not auth:
        return error_response("UNAUTHENTICATED", "Missing or invalid JWT", 401)

    body = json.loads(event.get("body", "{}"))
    user_id = body.get("user_id")
    public_key = body.get("public_key")
    attestation_chain = body.get("attestation_chain", [])
    alg = body.get("alg", "EdDSA")

    if not user_id or not public_key:
        return error_response("BAD_REQUEST", "user_id and public_key required")

    # Generate device ID (kid)
    import uuid
    kid = str(uuid.uuid4())[:26]

    # In production: write to Tablestore.devices + OSS pubkey directory
    return ok_response({
        "device_id": f"did:tng:device:{kid}",
        "kid": kid,
        "policy_version": "v3.2026-04-22",
        "initial_safe_offline_balance_myr": "50.00",
        "registered_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }, status=200)


# ─────────────────────────────────────────────
# POST /v1/tokens/settle
# ─────────────────────────────────────────────

def tokens_settle(event, context):
    """Validate batch, emit cross-cloud event for settlement."""
    auth = get_auth_context(event)
    if not auth:
        return error_response("UNAUTHENTICATED", "Missing or invalid JWT", 401)

    body = json.loads(event.get("body", "{}"))
    device_id = body.get("device_id", "")
    batch_id = body.get("batch_id", "")
    tokens = body.get("tokens", [])

    if not tokens:
        return error_response("BAD_REQUEST", "tokens array required")

    if len(tokens) > 50:
        return error_response("BAD_REQUEST", "Maximum 50 tokens per batch")

    # Validate JWS shape (basic regex check)
    import re
    jws_pattern = re.compile(r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$')
    for i, t in enumerate(tokens):
        if not isinstance(t, str) or not jws_pattern.match(t):
            return error_response("BAD_REQUEST", f"Token at index {i} is not valid JWS format")

    # In production:
    # 1. Write pending_batches to Tablestore
    # 2. Emit Alibaba EventBridge event
    # 3. Cross-cloud webhook to AWS Lambda settle-batch

    # For demo: simulate immediate settlement
    results = []
    for t in tokens:
        # Parse JWS to get tx_id (without full verification for demo)
        try:
            import base64
            parts = t.split(".")
            payload = json.loads(base64.urlsafe_b64decode(parts[1] + "=="))
            tx_id = payload.get("tx_id", "unknown")
            results.append({
                "tx_id": tx_id,
                "status": "SETTLED",
                "settled_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            })
        except Exception:
            results.append({"tx_id": "unknown", "status": "REJECTED", "reason": "PARSE_ERROR"})

    return ok_response({
        "batch_id": batch_id,
        "results": results,
    })


# ─────────────────────────────────────────────
# POST /v1/tokens/dispute
# ─────────────────────────────────────────────

def tokens_dispute(event, context):
    """Open dispute on a settled token."""
    auth = get_auth_context(event)
    if not auth:
        return error_response("UNAUTHENTICATED", "Missing or invalid JWT", 401)

    body = json.loads(event.get("body", "{}"))
    tx_id = body.get("tx_id")
    reason_code = body.get("reason_code")

    valid_reasons = {"UNAUTHORIZED", "WRONG_AMOUNT", "NOT_RECEIVED", "OTHER"}
    if not tx_id or reason_code not in valid_reasons:
        return error_response("BAD_REQUEST", "tx_id and valid reason_code required")

    import uuid
    dispute_id = f"dsp_{str(uuid.uuid4())[:22]}"

    # In production: write to RDS disputes + DynamoDB ledger update via cross-cloud

    return ok_response({
        "dispute_id": dispute_id,
        "status": "RECEIVED",
    }, status=201)


# ─────────────────────────────────────────────
# POST /v1/score/refresh
# ─────────────────────────────────────────────

def score_refresh(event, context):
    """Proxy to PAI-EAS for online score refresh."""
    auth = get_auth_context(event)
    if not auth:
        return error_response("UNAUTHENTICATED", "Missing or invalid JWT", 401)

    body = json.loads(event.get("body", "{}"))
    user_id = body.get("user_id")
    policy_version = body.get("policy_version", "v3.2026-04-22")
    features = body.get("features", {})

    if not user_id or not features:
        return error_response("BAD_REQUEST", "user_id and features required")

    # In production: call PAI-EAS endpoint
    # For demo: return computed value
    tx_count = features.get("tx_count_30d", 0)
    account_age = features.get("account_age_days", 0)
    kyc_tier = features.get("kyc_tier", 0)

    safe_balance = 50.0 + tx_count * 1.0 + account_age * 0.5
    safe_balance *= (1 + kyc_tier * 0.5)
    safe_balance = min(safe_balance, 500)

    return ok_response({
        "safe_offline_balance_myr": f"{safe_balance:.2f}",
        "confidence": 0.87,
        "policy_version": policy_version,
        "computed_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    })


# ─────────────────────────────────────────────
# GET /v1/score/policy
# ─────────────────────────────────────────────

def score_policy(event, context):
    """Return current active policy + signed model URL."""
    auth = get_auth_context(event)
    if not auth:
        return error_response("UNAUTHENTICATED", "Missing or invalid JWT", 401)

    return ok_response({
        "policy_version": "v3.2026-04-22",
        "released_at": "2026-04-22T08:00:00Z",
        "model": {
            "format": "tflite",
            "url": "https://oss-ap-southeast-3.aliyuncs.com/tng-finhack-models/credit/v3/model.tflite?Signature=placeholder",
            "sha256": "9f1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1",
            "sigstore_signature": "MEUCIQDx_placeholder",
        },
        "limits": {
            "hard_cap_per_tier": {"0": "20.00", "1": "150.00", "2": "500.00"},
            "global_cap_per_token_myr": "250.00",
            "max_token_validity_hours": 72,
        },
    })


# ─────────────────────────────────────────────
# GET /v1/publickeys/{kid}
# ─────────────────────────────────────────────

def publickeys_get(event, context):
    """Return a device's public key."""
    auth = get_auth_context(event)
    if not auth:
        return error_response("UNAUTHENTICATED", "Missing or invalid JWT", 401)

    path_params = event.get("pathParameters", {})
    kid = path_params.get("kid", "")

    if not kid:
        return error_response("BAD_REQUEST", "kid required")

    # In production: look up from Tablestore.devices or OSS pubkey directory
    return ok_response({
        "kid": kid,
        "alg": "EdDSA",
        "public_key": "BASE64URL_PLACEHOLDER_32_BYTES",
        "status": "ACTIVE",
        "registered_at": "2026-04-10T11:00:00Z",
        "revoked_at": None,
    })


# ─────────────────────────────────────────────
# POST /v1/merchants/onboard
# ─────────────────────────────────────────────

def merchants_onboard(event, context):
    """Stub merchant onboarding."""
    auth = get_auth_context(event)
    if not auth:
        return error_response("UNAUTHENTICATED", "Missing or invalid JWT", 401)

    body = json.loads(event.get("body", "{}"))
    import uuid
    merchant_id = f"m_{str(uuid.uuid4())[:22]}"

    return ok_response({"merchant_id": merchant_id}, status=201)


# ─────────────────────────────────────────────
# POST /v1/_internal/eb/aws-bridge
# ─────────────────────────────────────────────

def eb_cross_cloud_ingest(event, context):
    """Receive cross-cloud webhook events from AWS."""
    # In production: verify mTLS + HMAC signature
    body = json.loads(event.get("body", "{}"))
    detail_type = body.get("detail-type", "")
    detail = body.get("detail", {})

    logger.info(f"Cross-cloud event received: {detail_type}")

    if detail_type == "settlement.completed":
        # Update Tablestore wallet balance
        # Push notification to user
        logger.info(f"Settlement: {json.dumps(detail)}")

    return ok_response({"status": "received"})
