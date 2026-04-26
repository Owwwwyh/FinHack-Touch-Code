"""Event helpers for the cross-cloud settlement flow."""

from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone


def build_settlement_requested_event(
    *,
    batch_id: str,
    device_id: str,
    tokens: list[str],
    ack_signatures: list[dict],
) -> dict:
    return {
        "version": "0",
        "id": str(uuid.uuid4()),
        "detail-type": "tokens.settle.requested",
        "source": "tng.alibaba.fc.tokens-settle",
        "time": _utc_now(),
        "detail": {
            "batch_id": batch_id,
            "device_id": device_id,
            "tokens": tokens,
            "ack_signatures": ack_signatures,
        },
    }


def build_settlement_completed_event(*, batch_id: str, results: list[dict]) -> dict:
    return {
        "version": "0",
        "id": str(uuid.uuid4()),
        "detail-type": "settlement.completed",
        "source": "tng.aws.lambda.settle",
        "time": _utc_now(),
        "detail": {
            "batch_id": batch_id,
            "results": results,
        },
    }


def encode_event(event: dict) -> bytes:
    return json.dumps(event, separators=(",", ":"), sort_keys=True).encode("utf-8")


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()
