"""POST /v1/_internal/eb/aws-bridge handler."""

from __future__ import annotations

import json
import logging
import os
import sys
import uuid
from datetime import datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from lib.alibaba_runtime import create_tablestore_client, pending_batches_table_name, wallets_table_name
from lib import demo_state
from lib.bridge_auth import verify_body

logger = logging.getLogger(__name__)


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
    content_length = int(environ.get("CONTENT_LENGTH", 0) or 0)
    raw_body = environ["wsgi.input"].read(content_length) if content_length > 0 else b""

    try:
        event = json.loads(raw_body)
    except json.JSONDecodeError:
        return _error(start_response, "400 Bad Request", "BAD_REQUEST", "Invalid JSON", request_id)

    secret = os.environ.get("AWS_BRIDGE_HMAC_SECRET", "")
    signature = environ.get("HTTP_X_TNG_SIGNATURE", "")
    if secret and not verify_body(secret, raw_body, signature):
        return _error(
            start_response,
            "403 Forbidden",
            "FORBIDDEN",
            "Invalid cross-cloud bridge signature",
            request_id,
        )

    if event.get("detail-type") != "settlement.completed":
        return _error(
            start_response,
            "400 Bad Request",
            "BAD_REQUEST",
            "Unsupported event type",
            request_id,
        )

    detail = event.get("detail") or {}
    batch_id = detail.get("batch_id", "")
    results = detail.get("results", [])
    if not batch_id or not isinstance(results, list):
        return _error(
            start_response,
            "400 Bad Request",
            "BAD_REQUEST",
            "batch_id and results are required",
            request_id,
        )

    detail["_fc_environ"] = environ
    applied_count = apply_settlement_completed_event(event)

    start_response("200 OK", [
        ("Content-Type", "application/json; charset=utf-8"),
        ("X-Request-Id", request_id),
        ("X-API-Version", "v1"),
    ])
    return [
        json.dumps(
            {
                "status": "accepted",
                "batch_id": batch_id,
                "applied_results": applied_count,
            },
        ).encode("utf-8"),
    ]


def apply_settlement_completed_event(event: dict) -> int:
    detail = event.get("detail") or {}
    batch_id = detail.get("batch_id", "")
    results = detail.get("results", [])

    if not os.environ.get("TABLESTORE_ENDPOINT"):
        return demo_state.apply_settlement_results(batch_id, results)

    return _apply_results_tablestore(batch_id, results, detail.get("_fc_environ"))


def _apply_results_tablestore(batch_id: str, results: list[dict], environ: dict | None) -> int:
    import tablestore

    client = create_tablestore_client(environ or {})
    applied = 0

    pending_row = tablestore.Row(
        [("batch_id", batch_id)],
        [
            ("status", "COMPLETED"),
            ("token_count", len(results)),
            ("results_json", json.dumps(results)),
            ("updated_at", _utc_now()),
        ],
    )
    client.put_row(
        pending_batches_table_name(),
        pending_row,
        tablestore.Condition(tablestore.RowExistenceExpectation.IGNORE),
    )

    for result in results:
        if result.get("status") != "SETTLED":
            continue

        amount_cents = int(result.get("amount_cents", 0) or 0)
        sender_user_id = result.get("sender_user_id")
        receiver_user_id = result.get("receiver_user_id")

        if sender_user_id:
            _update_wallet_balance(
                client,
                sender_user_id,
                -amount_cents,
                result.get("policy_version", demo_state.DEFAULT_POLICY_VERSION),
            )
        if receiver_user_id:
            _update_wallet_balance(
                client,
                receiver_user_id,
                amount_cents,
                result.get("policy_version", demo_state.DEFAULT_POLICY_VERSION),
            )

        applied += 1

    return applied


def _update_wallet_balance(client, user_id: str, delta_cents: int, policy_version: str):  # noqa: ANN001
    import tablestore

    pk = [("user_id", user_id)]
    cols = tablestore.ColumnsToGet([
        "balance_myr",
        "balance_version",
        "safe_offline_balance_myr",
        "policy_version",
    ])
    _, row, _ = client.get_row(wallets_table_name(), pk, cols, None, 1)

    attrs = {col[0]: col[1] for col in row.attribute_columns} if row else {}
    balance_cents = _parse_myr(attrs.get("balance_myr", "0.00"))
    safe_balance_cents = _parse_myr(attrs.get("safe_offline_balance_myr", "0.00"))
    new_balance_cents = max(balance_cents + delta_cents, 0)

    updated = tablestore.Row(
        pk,
        [
            ("balance_myr", _format_myr(new_balance_cents)),
            ("balance_version", int(attrs.get("balance_version", 0)) + 1),
            (
                "safe_offline_balance_myr",
                _format_myr(min(safe_balance_cents, new_balance_cents)),
            ),
            ("policy_version", attrs.get("policy_version", policy_version)),
            ("last_updated", _utc_now()),
        ],
    )
    client.put_row(
        wallets_table_name(),
        updated,
        tablestore.Condition(tablestore.RowExistenceExpectation.IGNORE),
    )


def _parse_myr(value: str) -> int:
    whole, fraction = f"{value}".split(".", 1) if "." in f"{value}" else (f"{value}", "00")
    return int(whole) * 100 + int((fraction + "00")[:2])


def _format_myr(cents: int) -> str:
    whole = cents // 100
    fraction = str(cents % 100).zfill(2)
    return f"{whole}.{fraction}"


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()
