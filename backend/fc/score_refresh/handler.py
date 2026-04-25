"""POST /v1/score/refresh local inference handler."""

from __future__ import annotations

import json
import os
import sys
import uuid

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from lib import demo_state
from lib.jwt_middleware import JwtVerificationError, get_jwt_middleware
from lib.score_inference import ScoreInputError, compute_score_response


def _error(start_response, http_status: str, code: str, message: str, request_id: str):
    body = {"error": {"code": code, "message": message, "request_id": request_id}}
    start_response(
        http_status,
        [
            ("Content-Type", "application/json; charset=utf-8"),
            ("X-Request-Id", request_id),
            ("X-API-Version", "v1"),
        ],
    )
    return [json.dumps(body).encode("utf-8")]


def handler(environ, start_response):
    request_id = environ.get("HTTP_X_REQUEST_ID", f"req_{uuid.uuid4().hex[:12]}")

    auth_header = environ.get("HTTP_AUTHORIZATION", "")
    token = auth_header.removeprefix("Bearer ").strip()
    try:
        claims = get_jwt_middleware().verify(token)
    except JwtVerificationError as exc:
        return _error(start_response, "401 Unauthorized", exc.code, str(exc), request_id)

    content_length = int(environ.get("CONTENT_LENGTH", 0) or 0)
    raw_body = environ["wsgi.input"].read(content_length) if content_length > 0 else b""
    try:
        body = json.loads(raw_body)
    except json.JSONDecodeError:
        return _error(start_response, "400 Bad Request", "BAD_REQUEST", "Invalid JSON", request_id)

    user_id = body.get("user_id") or claims.get("sub") or "demo_user"
    wallet = demo_state.get_wallet(user_id)

    try:
        response_body = compute_score_response(
            body,
            cached_balance_cents=wallet["balance_cents"],
            default_manual_offline_cents=wallet["safe_offline_balance_cents"],
        )
    except ScoreInputError as exc:
        return _error(start_response, "400 Bad Request", "BAD_REQUEST", str(exc), request_id)

    start_response(
        "200 OK",
        [
            ("Content-Type", "application/json; charset=utf-8"),
            ("X-Request-Id", request_id),
            ("X-API-Version", "v1"),
        ],
    )
    return [json.dumps(response_body).encode("utf-8")]
