"""AWS settle-batch Lambda for offline token settlement."""

from __future__ import annotations

import json
import logging
import os
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from lib.jws_verifier import JwsVerifier
from lib.settlement_events import build_settlement_completed_event

logger = logging.getLogger(__name__)

_demo_nonce_seen: dict[str, str] = {}
_demo_ledger: dict[str, dict] = {}


def handler(event, context):  # noqa: ANN001
    detail = event.get("detail", event) if isinstance(event, dict) else {}
    completion_event = process_settlement_request(detail)
    _emit_eventbridge(completion_event)
    return completion_event


def process_settlement_request(detail: dict) -> dict:
    batch_id = detail.get("batch_id", "batch-demo")
    tokens = detail.get("tokens", [])
    ack_signatures = detail.get("ack_signatures", [])
    ack_by_tx_id = {
        entry.get("tx_id"): entry
        for entry in ack_signatures
        if isinstance(entry, dict) and entry.get("tx_id")
    }

    results = []
    for token in tokens:
        result = _settle_single_token(token, ack_by_tx_id)
        results.append(result)

    return build_settlement_completed_event(batch_id=batch_id, results=results)


def reset_demo_state() -> None:
    _demo_nonce_seen.clear()
    _demo_ledger.clear()


def get_demo_ledger() -> dict[str, dict]:
    return dict(_demo_ledger)


def _settle_single_token(token: str, ack_by_tx_id: dict[str, dict]) -> dict:
    header, payload = _decode_unverified_jws(token)
    tx_id = payload.get("tx_id", "unknown")
    sender = payload.get("sender", {}) or {}
    receiver = payload.get("receiver", {}) or {}
    amount = payload.get("amount", {}) or {}
    ack_entry = ack_by_tx_id.get(tx_id)

    public_key = _lookup_public_key(header.get("kid", ""), sender.get("pub"))
    if not public_key:
        return {"status": "REJECTED", "reason": "UNKNOWN_KID", "tx_id": tx_id}

    verification = JwsVerifier.verify_compact(token, public_key)
    if not verification.get("valid"):
        return {
            "status": "REJECTED",
            "reason": _map_verify_error(verification.get("error")),
            "tx_id": tx_id,
        }

    nonce = payload.get("nonce", "")
    if not _reserve_nonce(nonce, tx_id, payload.get("iat")):
        return {"status": "REJECTED", "reason": "NONCE_REUSED", "tx_id": tx_id}

    settled_at = datetime.now(timezone.utc).isoformat()
    result = {
        "status": "SETTLED",
        "tx_id": tx_id,
        "settled_at": settled_at,
        "sender_user_id": sender.get("user_id"),
        "receiver_user_id": receiver.get("user_id"),
        "amount_cents": _amount_to_cents(amount),
        "currency": amount.get("currency", "MYR"),
        "kid": header.get("kid"),
        "policy_version": header.get("policy"),
    }
    if ack_entry:
        result["ack_kid"] = ack_entry.get("ack_kid")

    _write_ledger(
        token=token,
        header=header,
        payload=payload,
        settled_at=settled_at,
        ack_entry=ack_entry,
    )
    return result


def _decode_unverified_jws(token: str) -> tuple[dict, dict]:
    parts = token.split(".")
    if len(parts) != 3:
        return {}, {}

    try:
        header = json.loads(JwsVerifier.base64url_decode(parts[0]).decode("utf-8"))
    except Exception:
        header = {}

    try:
        payload = json.loads(JwsVerifier.base64url_decode(parts[1]).decode("utf-8"))
    except Exception:
        payload = {}

    return header, payload


def _map_verify_error(error_code: str | None) -> str:
    return {
        "EXPIRED_TOKEN": "EXPIRED_TOKEN",
        "BAD_SIGNATURE": "BAD_SIGNATURE",
        "MISSING_FIELD": "BAD_REQUEST",
        "INVALID_FORMAT": "BAD_REQUEST",
        "INVALID_HEADER": "BAD_REQUEST",
        "INVALID_PAYLOAD": "BAD_REQUEST",
    }.get(error_code or "", "BAD_SIGNATURE")


def _lookup_public_key(kid: str, fallback_pub: str | None) -> str | None:
    cached = _lookup_pubkey_cache(kid)
    if cached:
        return cached
    return fallback_pub


def _lookup_pubkey_cache(kid: str) -> str | None:
    table_name = os.environ.get("DYNAMO_PUBKEY_CACHE")
    if not table_name:
        return None

    try:
        client = _get_dynamodb_client()
        response = client.get_item(
            TableName=table_name,
            Key={"kid": {"S": kid}},
            ConsistentRead=True,
        )
        item = response.get("Item")
        if not item or item.get("status", {}).get("S") == "REVOKED":
            return None
        return item.get("pub_b64", {}).get("S")
    except Exception as exc:  # pragma: no cover - defensive for real AWS only
        logger.warning("Pubkey cache lookup failed for kid=%s: %s", kid, exc)
        return None


def _reserve_nonce(nonce: str, tx_id: str, iat: int | None) -> bool:
    table_name = os.environ.get("DYNAMO_NONCE_TABLE")
    if not table_name:
        if nonce in _demo_nonce_seen:
            return False
        _demo_nonce_seen[nonce] = tx_id
        return True

    ttl = int(iat or 0) + (90 * 24 * 3600)
    try:
        client = _get_dynamodb_client()
        client.put_item(
            TableName=table_name,
            Item={
                "nonce": {"S": nonce},
                "tx_id": {"S": tx_id},
                "expires_at": {"N": str(ttl)},
            },
            ConditionExpression="attribute_not_exists(nonce)",
        )
        return True
    except Exception as exc:  # pragma: no cover - defensive for real AWS only
        error_code = getattr(exc, "response", {}).get("Error", {}).get("Code")
        if error_code == "ConditionalCheckFailedException":
            return False
        raise


def _write_ledger(
    *,
    token: str,
    header: dict,
    payload: dict,
    settled_at: str,
    ack_entry: dict | None,
) -> None:
    tx_id = payload.get("tx_id", "unknown")
    item = {
        "tx_id": tx_id,
        "kid": header.get("kid", ""),
        "iat": int(payload.get("iat", 0) or 0),
        "nonce": payload.get("nonce", ""),
        "amount_cents": _amount_to_cents(payload.get("amount", {})),
        "currency": payload.get("amount", {}).get("currency", "MYR"),
        "sender_user_id": payload.get("sender", {}).get("user_id", ""),
        "receiver_user_id": payload.get("receiver", {}).get("user_id", ""),
        "status": "SETTLED",
        "reject_reason": None,
        "settled_at": settled_at,
        "policy_version": header.get("policy", ""),
        "jws": token,
    }
    if ack_entry:
        item["ack_kid"] = ack_entry.get("ack_kid")
        item["ack_signature"] = ack_entry.get("ack_sig")

    table_name = os.environ.get("DYNAMO_LEDGER_TABLE")
    if not table_name:
        _demo_ledger[tx_id] = item
        return

    ddb_item = {
        "tx_id": {"S": tx_id},
        "kid": {"S": item["kid"]},
        "kid_iat": {"S": f"{item['kid']}#{item['iat']}"},
        "iat": {"N": str(item["iat"])},
        "nonce": {"S": item["nonce"]},
        "amount_cents": {"N": str(item["amount_cents"])},
        "currency": {"S": item["currency"]},
        "sender_user_id": {"S": item["sender_user_id"]},
        "receiver_user_id": {"S": item["receiver_user_id"]},
        "status": {"S": "SETTLED"},
        "settled_at": {"N": str(int(datetime.fromisoformat(settled_at).timestamp()))},
        "policy_version": {"S": item["policy_version"]},
        "jws": {"B": token.encode("utf-8")},
    }
    if item.get("ack_kid"):
        ddb_item["ack_kid"] = {"S": item["ack_kid"]}
    if item.get("ack_signature"):
        ddb_item["ack_signature"] = {"S": item["ack_signature"]}

    client = _get_dynamodb_client()
    client.put_item(TableName=table_name, Item=ddb_item)


def _emit_eventbridge(event: dict) -> bool:
    bus_name = os.environ.get("AWS_CROSS_CLOUD_BUS")
    if not bus_name:
        return False

    try:
        client = _get_eventbridge_client()
        response = client.put_events(
            Entries=[
                {
                    "Source": event["source"],
                    "DetailType": event["detail-type"],
                    "Detail": json.dumps(event["detail"]),
                    "EventBusName": bus_name,
                    "Time": datetime.fromisoformat(event["time"]),
                },
            ],
        )
        return response.get("FailedEntryCount", 0) == 0
    except Exception as exc:  # pragma: no cover - defensive for real AWS only
        logger.warning("Failed to emit settlement.completed event: %s", exc)
        return False


def _amount_to_cents(amount: dict) -> int:
    value = str(amount.get("value", "0.00"))
    try:
        whole, fraction = value.split(".", 1)
    except ValueError:
        whole, fraction = value, "00"
    return int(whole) * 100 + int((fraction + "00")[:2])


def _get_dynamodb_client():
    import boto3  # pragma: no cover - imported lazily for real AWS only

    return boto3.client("dynamodb")


def _get_eventbridge_client():
    import boto3  # pragma: no cover - imported lazily for real AWS only

    return boto3.client("events")
