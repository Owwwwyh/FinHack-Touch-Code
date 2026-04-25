"""
GET /v1/wallet/balance
Returns authoritative balance + safe offline balance for the requesting user.
"""
import json
import logging
import os
import sys
import uuid
from datetime import datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from lib.alibaba_runtime import create_tablestore_client, wallets_table_name
from lib import demo_state
from lib.jwt_middleware import JwtVerificationError, get_jwt_middleware

logger = logging.getLogger()

def _error(start_response, http_status: str, code: str, message: str, request_id: str):
    body = {"error": {"code": code, "message": message, "request_id": request_id}}
    start_response(http_status, [
        ("Content-Type", "application/json; charset=utf-8"),
        ("X-Request-Id", request_id),
        ("X-API-Version", "v1"),
    ])
    return [json.dumps(body).encode("utf-8")]


def handler(environ, start_response):
    request_id = environ.get("HTTP_X_REQUEST_ID", f"req_{uuid.uuid4().hex[:12]}")

    # Auth
    auth_header = environ.get("HTTP_AUTHORIZATION", "")
    token = auth_header.removeprefix("Bearer ").strip()
    try:
        claims = get_jwt_middleware().verify(token)
    except JwtVerificationError as e:
        return _error(start_response, "401 Unauthorized", e.code, str(e), request_id)

    user_id = claims.get("sub") or claims.get("cognito:username", "")

    # Read from Tablestore
    endpoint = os.environ.get("TABLESTORE_ENDPOINT", "")
    if not endpoint:
        body = demo_state.get_wallet_response(user_id)
        start_response("200 OK", [
            ("Content-Type", "application/json; charset=utf-8"),
            ("X-Request-Id", request_id),
            ("X-API-Version", "v1"),
        ])
        return [json.dumps(body).encode("utf-8")]

    try:
        import tablestore

        client = create_tablestore_client(environ)
        primary_key = [("user_id", user_id)]
        columns_to_get = tablestore.ColumnsToGet([
            "balance_myr", "balance_version", "last_updated",
            "safe_offline_balance_myr", "policy_version",
        ])
        consumed, return_row, _ = client.get_row(
            wallets_table_name(), primary_key, columns_to_get, None, 1
        )
    except Exception as e:
        logger.error("Tablestore read failed: %s", e)
        return _error(start_response, "500 Internal Server Error", "INTERNAL", "Storage error", request_id)

    if return_row is None:
        return _error(start_response, "404 Not Found", "NOT_FOUND", "Wallet not found", request_id)

    attrs = {col[0]: col[1] for col in return_row.attribute_columns}
    body = {
        "user_id": user_id,
        "balance_myr": attrs.get("balance_myr", "0.00"),
        "currency": "MYR",
        "version": int(attrs.get("balance_version", 1)),
        "as_of": attrs.get("last_updated", datetime.now(timezone.utc).isoformat()),
        "safe_offline_balance_myr": attrs.get("safe_offline_balance_myr", "0.00"),
        "policy_version": attrs.get("policy_version", "v3.2026-04-22"),
    }

    start_response("200 OK", [
        ("Content-Type", "application/json; charset=utf-8"),
        ("X-Request-Id", request_id),
        ("X-API-Version", "v1"),
    ])
    return [json.dumps(body).encode("utf-8")]
