"""AWS inbound bridge Lambda for Alibaba settlement requests."""

from __future__ import annotations

import base64
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from aws_lambda.settle_batch.handler import (
    handler as settle_batch_handler,
    reset_demo_state as _reset_settle_demo_state,
)
from lib.aws_secrets import resolve_secret_env
from lib.bridge_auth import verify_body


def handler(event, context):  # noqa: ANN001
    raw_body = _extract_body(event)
    secret = resolve_secret_env("AWS_BRIDGE_HMAC_SECRET")
    signature = _header(event, "x-tng-signature")

    if secret and not verify_body(secret, raw_body, signature):
        return _response(
            403,
            {
                "error": {
                    "code": "FORBIDDEN",
                    "message": "Invalid cross-cloud bridge signature",
                },
            },
        )

    try:
        request_event = _json_loads(raw_body.decode("utf-8") if raw_body else "{}")
    except json.JSONDecodeError:
        return _response(
            400,
            {
                "error": {
                    "code": "BAD_REQUEST",
                    "message": "Invalid JSON",
                },
            },
        )

    if request_event.get("detail-type") != "tokens.settle.requested":
        return _response(
            400,
            {
                "error": {
                    "code": "BAD_REQUEST",
                    "message": "Unsupported event type",
                },
            },
        )

    detail = request_event.get("detail") or {}
    if not detail.get("batch_id") or not isinstance(detail.get("tokens"), list):
        return _response(
            400,
            {
                "error": {
                    "code": "BAD_REQUEST",
                    "message": "batch_id and tokens are required",
                },
            },
        )

    completion_event = settle_batch_handler({"detail": detail}, context)
    return _response(200, completion_event)


def reset_demo_state() -> None:
    _reset_settle_demo_state()


def _extract_body(event: dict) -> bytes:
    body = event.get("body", "")
    if event.get("isBase64Encoded"):
        return base64.b64decode(body or "")
    if isinstance(body, bytes):
        return body
    return str(body).encode("utf-8")


def _header(event: dict, name: str) -> str:
    headers = event.get("headers") or {}
    lowered = {str(key).lower(): value for key, value in headers.items()}
    return str(lowered.get(name.lower(), ""))


def _response(status_code: int, body: dict) -> dict:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json; charset=utf-8",
            "X-API-Version": "v1",
        },
        "body": _json_dumps(body),
    }


def _json_dumps(payload: dict) -> str:
    return json.dumps(payload, separators=(",", ":"), sort_keys=True)


def _json_loads(raw: str) -> dict:
    return json.loads(raw)
