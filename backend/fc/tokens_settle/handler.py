"""POST /v1/tokens/settle settlement bridge entrypoint."""

import json
import logging
import os
import sys
import uuid
from datetime import datetime, timezone

import requests

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from aws_lambda.settle_batch import handler as settle_batch_handler
from fc.eb_cross_cloud_ingest import handler as ingest_handler
from lib.alibaba_runtime import create_tablestore_client, pending_batches_table_name
from lib import demo_state
from lib.bridge_auth import sign_body
from lib.jwt_middleware import JwtVerificationError, get_jwt_middleware
from lib.settlement_events import build_settlement_requested_event, encode_event

logger = logging.getLogger(__name__)

MAX_BATCH_SIZE = 50


def _error(start_response, http_status: str, code: str, message: str, request_id: str):
    body = {"error": {"code": code, "message": message, "request_id": request_id}}
    start_response(http_status, [
        ("Content-Type", "application/json; charset=utf-8"),
        ("X-Request-Id", request_id),
        ("X-API-Version", "v1"),
    ])
    return [json.dumps(body).encode("utf-8")]


def _record_pending_batch(environ, batch_id: str, device_id: str, token_count: int) -> None:
    if not os.environ.get("TABLESTORE_ENDPOINT"):
        demo_state.record_pending_batch(
            batch_id,
            device_id=device_id,
            token_count=token_count,
        )
        return

    try:
        import tablestore

        client = create_tablestore_client(environ)
        row = tablestore.Row(
            [("batch_id", batch_id)],
            [
                ("device_id", device_id),
                ("status", "PENDING"),
                ("token_count", token_count),
                ("created_at", datetime.now(timezone.utc).isoformat()),
            ],
        )
        client.put_row(
            pending_batches_table_name(),
            row,
            tablestore.Condition(tablestore.RowExistenceExpectation.IGNORE),
        )
    except Exception as exc:
        logger.warning("Failed to write pending_batches: %s", exc)


def _validate_ack_signatures(ack_signatures) -> bool:  # noqa: ANN001
    if not isinstance(ack_signatures, list):
        return False
    for entry in ack_signatures:
        if not isinstance(entry, dict):
            return False
        if not entry.get("tx_id") or not entry.get("ack_sig") or not entry.get("ack_kid"):
            return False
    return True


def _post_bridge_event(event: dict) -> tuple[int, object]:
    bridge_url = os.environ["AWS_BRIDGE_URL"]
    body = encode_event(event)
    headers = {"Content-Type": "application/json"}

    secret = os.environ.get("AWS_BRIDGE_HMAC_SECRET", "")
    if secret:
        headers["X-TNG-Signature"] = sign_body(secret, body)

    response = requests.post(bridge_url, data=body, headers=headers, timeout=1.5)
    return response.status_code, _parse_json(response.text)


def _parse_json(raw: str):
    if not raw:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw


def _normalise_bridge_response(batch_id: str, body):  # noqa: ANN001
    if not isinstance(body, dict):
        return 202, {"batch_id": batch_id, "status": "PROCESSING"}

    detail = body.get("detail")
    if isinstance(detail, dict) and isinstance(detail.get("results"), list):
        return 200, {
            "batch_id": detail.get("batch_id", batch_id),
            "results": detail["results"],
        }

    if isinstance(body.get("results"), list):
        return 200, {
            "batch_id": body.get("batch_id", batch_id),
            "results": body["results"],
        }

    if body.get("status") == "PROCESSING":
        return 202, {
            "batch_id": body.get("batch_id", batch_id),
            "status": "PROCESSING",
        }

    return 202, {"batch_id": batch_id, "status": "PROCESSING"}


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
    ack_signatures = body.get("ack_signatures", [])

    if not device_id:
        return _error(start_response, "400 Bad Request", "BAD_REQUEST", "device_id is required", request_id)
    if not isinstance(tokens, list) or len(tokens) == 0:
        return _error(start_response, "400 Bad Request", "BAD_REQUEST", "tokens array is required", request_id)
    if len(tokens) > MAX_BATCH_SIZE:
        return _error(start_response, "400 Bad Request", "BAD_REQUEST", f"Max {MAX_BATCH_SIZE} tokens per batch", request_id)
    if not _validate_ack_signatures(ack_signatures):
        return _error(
            start_response,
            "400 Bad Request",
            "BAD_REQUEST",
            "ack_signatures must be an array of {tx_id, ack_sig, ack_kid}",
            request_id,
        )

    _record_pending_batch(environ, batch_id, device_id, len(tokens))
    event = build_settlement_requested_event(
        batch_id=batch_id,
        device_id=device_id,
        tokens=tokens,
        ack_signatures=ack_signatures,
    )

    if os.environ.get("AWS_BRIDGE_URL"):
        try:
            _, bridge_body = _post_bridge_event(event)
        except Exception as exc:
            logger.error("AWS bridge request failed: %s", exc)
            return _error(
                start_response,
                "502 Bad Gateway",
                "INTERNAL",
                "Failed to forward settlement batch to AWS bridge",
                request_id,
            )

        status_code, response_body = _normalise_bridge_response(batch_id, bridge_body)
        start_response(
            "200 OK" if status_code == 200 else "202 Accepted",
            [
                ("Content-Type", "application/json; charset=utf-8"),
                ("X-Request-Id", request_id),
                ("X-API-Version", "v1"),
            ],
        )
        return [json.dumps(response_body).encode("utf-8")]

    completion_event = settle_batch_handler.process_settlement_request(event["detail"])
    ingest_handler.apply_settlement_completed_event(completion_event)
    response_body = {
        "batch_id": batch_id,
        "results": completion_event["detail"]["results"],
    }
    start_response("200 OK", [
        ("Content-Type", "application/json; charset=utf-8"),
        ("X-Request-Id", request_id),
        ("X-API-Version", "v1"),
    ])
    return [json.dumps(response_body).encode("utf-8")]
