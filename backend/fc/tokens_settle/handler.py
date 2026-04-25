"""
POST /v1/tokens/settle
Submits a batch of JWS tokens for settlement.
Validates locally in demo mode; emits EventBridge event in production.
"""
import json
import logging
import os
import sys
import uuid
from datetime import datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from lib.jwt_middleware import JwtVerificationError, get_jwt_middleware
from lib.jws_verifier import JwsVerifier, JwsVerificationError

logger = logging.getLogger()

MAX_BATCH_SIZE = 50
# In-memory nonce cache for demo (process-local, not distributed)
_seen_nonces: set = set()


def _error(start_response, http_status: str, code: str, message: str, request_id: str):
    body = {"error": {"code": code, "message": message, "request_id": request_id}}
    start_response(http_status, [
        ("Content-Type", "application/json; charset=utf-8"),
        ("X-Request-Id", request_id),
        ("X-API-Version", "v1"),
    ])
    return [json.dumps(body).encode("utf-8")]


def _get_ots_client():
    import tablestore

    return tablestore.OTSClient(
        os.environ["TABLESTORE_ENDPOINT"],
        os.environ["OTS_ACCESS_KEY_ID"],
        os.environ["OTS_ACCESS_KEY_SECRET"],
        os.environ["TABLESTORE_INSTANCE"],
    )


def _lookup_pubkey_ots(kid: str) -> str | None:
    """Look up a device public key from Tablestore devices table."""
    try:
        import tablestore

        client = _get_ots_client()
        pk = [("kid", kid)]
        cols = tablestore.ColumnsToGet(["public_key", "status"])
        _, row, _ = client.get_row("devices", pk, cols, None, 1)
        if row is None:
            return None
        attrs = {c[0]: c[1] for c in row.attribute_columns}
        if attrs.get("status") == "REVOKED":
            return None
        return attrs.get("public_key")
    except Exception as e:
        logger.error("Tablestore pubkey lookup failed: %s", e)
        return None


def _lookup_pubkey_oss(kid: str) -> str | None:
    """Fallback: look up public key from OSS bucket."""
    try:
        import oss2

        auth = oss2.Auth(os.environ["OSS_ACCESS_KEY_ID"], os.environ["OSS_ACCESS_KEY_SECRET"])
        bucket = oss2.Bucket(
            auth,
            os.environ["OSS_ENDPOINT"],
            os.environ.get("OSS_BUCKET_PUBKEYS", "tng-finhack-pubkeys"),
        )
        result = bucket.get_object(f"{kid}.pub")
        return result.read().decode("utf-8").strip()
    except Exception as e:
        logger.warning("OSS pubkey lookup failed for kid=%s: %s", kid, e)
        return None


def _process_token_local(jws: str) -> dict:
    """Validate a single JWS token locally (demo mode / fallback)."""
    import base64

    # Extract kid from header
    parts = jws.split(".")
    if len(parts) != 3:
        return {"status": "REJECTED", "reason": "INVALID_FORMAT"}

    try:
        header_padding = parts[0] + "=="
        header = json.loads(base64.urlsafe_b64decode(header_padding).decode("utf-8"))
        payload_padding = parts[1] + "=="
        payload = json.loads(base64.urlsafe_b64decode(payload_padding).decode("utf-8"))
    except Exception:
        return {"status": "REJECTED", "reason": "BAD_REQUEST"}

    kid = header.get("kid", "")
    tx_id = payload.get("tx_id", "unknown")
    nonce = payload.get("nonce", "")

    # Look up public key
    pub_key = None
    if os.environ.get("TABLESTORE_ENDPOINT"):
        pub_key = _lookup_pubkey_ots(kid)
        if pub_key is None:
            pub_key = _lookup_pubkey_oss(kid)
    else:
        # Demo mode: extract sender.pub from payload directly
        sender = payload.get("sender", {})
        pub_key = sender.get("pub")

    if not pub_key:
        return {"status": "REJECTED", "reason": "UNKNOWN_KID", "tx_id": tx_id}

    # Verify JWS signature + expiry
    result = JwsVerifier.verify_compact(jws, pub_key)
    if not result["valid"]:
        error_code = result.get("error", "BAD_SIGNATURE")
        reason_map = {
            "EXPIRED_TOKEN": "EXPIRED_TOKEN",
            "BAD_SIGNATURE": "BAD_SIGNATURE",
            "MISSING_FIELD": "BAD_REQUEST",
        }
        return {
            "status": "REJECTED",
            "reason": reason_map.get(error_code, error_code),
            "tx_id": tx_id,
        }

    # Double-spend check (in-memory for demo; production uses DynamoDB conditional put)
    if nonce in _seen_nonces:
        return {"status": "REJECTED", "reason": "NONCE_REUSED", "tx_id": tx_id}
    _seen_nonces.add(nonce)

    settled_at = datetime.now(timezone.utc).isoformat()
    return {"status": "SETTLED", "tx_id": tx_id, "settled_at": settled_at}


def _emit_eventbridge(batch_id: str, device_id: str, tokens: list[str]) -> bool:
    """Emit settlement event to Alibaba EventBridge. Returns True on success."""
    eb_endpoint = os.environ.get("ALIBABA_EB_ENDPOINT", "")
    eb_bus = os.environ.get("ALIBABA_EB_BUS_NAME", "tng-finhack-bus")
    if not eb_endpoint:
        return False

    import hmac
    import hashlib
    import requests

    event = {
        "specversion": "1.0",
        "type": "tokens.settle.requested",
        "source": "tng.alibaba.fc.settle",
        "id": str(uuid.uuid4()),
        "time": datetime.now(timezone.utc).isoformat(),
        "datacontenttype": "application/json",
        "data": {
            "batch_id": batch_id,
            "device_id": device_id,
            "tokens": tokens,
        },
    }

    # HMAC-signed body for cross-cloud bridge
    body = json.dumps(event).encode("utf-8")
    secret = os.environ.get("EB_HMAC_SECRET", "").encode("utf-8")
    if secret:
        sig = hmac.new(secret, body, hashlib.sha256).hexdigest()
        headers = {"Content-Type": "application/json", "X-TNG-Signature": sig}
    else:
        headers = {"Content-Type": "application/json"}

    try:
        resp = requests.post(f"{eb_endpoint}/bus/{eb_bus}/events", data=body, headers=headers, timeout=3)
        return resp.status_code < 300
    except Exception as e:
        logger.warning("EventBridge emit failed: %s", e)
        return False


def handler(environ, start_response):
    request_id = environ.get("HTTP_X_REQUEST_ID", f"req_{uuid.uuid4().hex[:12]}")

    # Auth
    auth_header = environ.get("HTTP_AUTHORIZATION", "")
    token_str = auth_header.removeprefix("Bearer ").strip()
    try:
        claims = get_jwt_middleware().verify(token_str)  # noqa: F841
    except JwtVerificationError as e:
        return _error(start_response, "401 Unauthorized", e.code, str(e), request_id)

    # Parse body
    content_length = int(environ.get("CONTENT_LENGTH", 0) or 0)
    raw_body = environ["wsgi.input"].read(content_length) if content_length > 0 else b""
    try:
        body = json.loads(raw_body)
    except json.JSONDecodeError:
        return _error(start_response, "400 Bad Request", "BAD_REQUEST", "Invalid JSON", request_id)

    tokens = body.get("tokens", [])
    device_id = body.get("device_id", "")
    batch_id = body.get("batch_id", str(uuid.uuid4()))

    if not isinstance(tokens, list) or len(tokens) == 0:
        return _error(start_response, "400 Bad Request", "BAD_REQUEST", "tokens array is required", request_id)
    if len(tokens) > MAX_BATCH_SIZE:
        return _error(start_response, "400 Bad Request", "BAD_REQUEST", f"Max {MAX_BATCH_SIZE} tokens per batch", request_id)

    # Write pending_batches to Tablestore (best effort)
    if os.environ.get("TABLESTORE_ENDPOINT"):
        try:
            import tablestore

            client = _get_ots_client()
            pk = [("batch_id", batch_id)]
            attrs = [
                ("device_id", device_id),
                ("status", "PENDING"),
                ("token_count", len(tokens)),
                ("created_at", datetime.now(timezone.utc).isoformat()),
            ]
            row = tablestore.Row(pk, attrs)
            client.put_row("pending_batches", row, tablestore.Condition(tablestore.RowExistenceExpectation.IGNORE))
        except Exception as e:
            logger.warning("Failed to write pending_batches: %s", e)

    # Try EventBridge path; fall back to local validation
    eb_emitted = _emit_eventbridge(batch_id, device_id, tokens)

    if eb_emitted:
        # Production path: return 202, client polls
        start_response("202 Accepted", [
            ("Content-Type", "application/json; charset=utf-8"),
            ("X-Request-Id", request_id),
            ("X-API-Version", "v1"),
        ])
        return [json.dumps({"batch_id": batch_id, "status": "PROCESSING"}).encode("utf-8")]

    # Demo/fallback path: process locally
    results = []
    for jws in tokens:
        r = _process_token_local(jws)
        results.append(r)

    response_body = {"batch_id": batch_id, "results": results}
    start_response("200 OK", [
        ("Content-Type", "application/json; charset=utf-8"),
        ("X-Request-Id", request_id),
        ("X-API-Version", "v1"),
    ])
    return [json.dumps(response_body).encode("utf-8")]
