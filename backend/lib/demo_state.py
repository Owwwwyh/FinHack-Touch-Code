"""Shared in-memory demo state for local backend vertical-slice tests."""

from __future__ import annotations

from datetime import datetime, timezone

DEFAULT_POLICY_VERSION = "v3.2026-04-22"
DEFAULT_SAFE_OFFLINE_CENTS = 5000

_wallets: dict[str, dict] = {}
_pending_batches: dict[str, dict] = {}


def reset() -> None:
    _wallets.clear()
    _pending_batches.clear()


def seed_wallet(
    user_id: str,
    *,
    balance_cents: int,
    safe_offline_balance_cents: int | None = None,
    version: int = 1,
    policy_version: str = DEFAULT_POLICY_VERSION,
) -> dict:
    wallet = {
        "user_id": user_id,
        "balance_cents": max(balance_cents, 0),
        "safe_offline_balance_cents": max(
            0,
            min(
                safe_offline_balance_cents
                if safe_offline_balance_cents is not None
                else min(balance_cents, DEFAULT_SAFE_OFFLINE_CENTS),
                max(balance_cents, 0),
            ),
        ),
        "version": version,
        "policy_version": policy_version,
        "as_of": _utc_now(),
    }
    _wallets[user_id] = wallet
    return dict(wallet)


def get_wallet(user_id: str) -> dict:
    return dict(_ensure_wallet(user_id))


def get_wallet_response(user_id: str) -> dict:
    wallet = _ensure_wallet(user_id)
    return {
        "user_id": user_id,
        "balance_myr": _format_cents(wallet["balance_cents"]),
        "currency": "MYR",
        "version": wallet["version"],
        "as_of": wallet["as_of"],
        "safe_offline_balance_myr": _format_cents(
            wallet["safe_offline_balance_cents"],
        ),
        "policy_version": wallet["policy_version"],
    }


def record_pending_batch(
    batch_id: str,
    *,
    device_id: str,
    token_count: int,
    status: str = "PENDING",
    results: list[dict] | None = None,
) -> dict:
    batch = {
        "batch_id": batch_id,
        "device_id": device_id,
        "status": status,
        "token_count": token_count,
        "results": list(results or []),
        "updated_at": _utc_now(),
    }
    _pending_batches[batch_id] = batch
    return dict(batch)


def get_pending_batch(batch_id: str) -> dict | None:
    batch = _pending_batches.get(batch_id)
    return dict(batch) if batch is not None else None


def apply_settlement_results(batch_id: str, results: list[dict]) -> int:
    applied = 0

    for result in results:
        if result.get("status") != "SETTLED":
            continue

        amount_cents = int(result.get("amount_cents", 0) or 0)
        sender_user_id = result.get("sender_user_id")
        receiver_user_id = result.get("receiver_user_id")

        if sender_user_id:
            _adjust_wallet(sender_user_id, -amount_cents)
        if receiver_user_id:
            _adjust_wallet(receiver_user_id, amount_cents)

        applied += 1

    batch = _pending_batches.get(batch_id, {})
    batch.update(
        {
            "batch_id": batch_id,
            "status": "COMPLETED",
            "token_count": batch.get("token_count", len(results)),
            "device_id": batch.get("device_id", ""),
            "results": list(results),
            "updated_at": _utc_now(),
        },
    )
    _pending_batches[batch_id] = batch

    return applied


def _ensure_wallet(user_id: str) -> dict:
    if user_id not in _wallets:
        default_balance = 24850 if user_id == "demo_user" else 0
        seed_wallet(user_id, balance_cents=default_balance)
    return _wallets[user_id]


def _adjust_wallet(user_id: str, delta_cents: int) -> None:
    wallet = _ensure_wallet(user_id)
    wallet["balance_cents"] = max(wallet["balance_cents"] + delta_cents, 0)
    wallet["safe_offline_balance_cents"] = min(
        wallet["safe_offline_balance_cents"],
        wallet["balance_cents"],
    )
    wallet["version"] += 1
    wallet["as_of"] = _utc_now()


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _format_cents(cents: int) -> str:
    whole = cents // 100
    fraction = str(cents % 100).zfill(2)
    return f"{whole}.{fraction}"
