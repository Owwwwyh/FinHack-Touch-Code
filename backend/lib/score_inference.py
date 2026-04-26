"""Local score refresh inference for demo and offline development."""

from __future__ import annotations

from datetime import datetime, timezone

REQUIRED_FEATURES = (
    "tx_count_30d",
    "tx_count_90d",
    "tx_amount_p95_30d",
    "prior_offline_count",
    "prior_offline_settle_rate",
    "account_age_days",
    "kyc_tier",
    "last_sync_age_min",
    "device_attest_ok",
)


class ScoreInputError(ValueError):
    """Raised when the score refresh request body is invalid."""


def compute_score_response(
    payload: dict,
    *,
    cached_balance_cents: int,
    default_manual_offline_cents: int,
) -> dict:
    if not isinstance(payload, dict):
        raise ScoreInputError("Request body must be a JSON object")

    _require_string(payload, "user_id")
    policy_version = _require_string(payload, "policy_version")
    features = payload.get("features")
    if not isinstance(features, dict):
        raise ScoreInputError("features object is required")

    parsed = {name: _require_float(features, name) for name in REQUIRED_FEATURES}
    kyc_tier = int(round(parsed["kyc_tier"]))
    hard_cap_cents = hard_cap_for_tier(kyc_tier)

    resolved_cached_balance_cents = resolve_money_cents(
        payload.get("cached_balance_myr"),
        fallback=max(cached_balance_cents, 0),
        field_name="cached_balance_myr",
    )
    manual_offline_wallet_cents = resolve_money_cents(
        payload.get("manual_offline_wallet_myr"),
        fallback=max(default_manual_offline_cents, 0),
        field_name="manual_offline_wallet_myr",
    )
    lifetime_tx_count = resolve_int(payload.get("lifetime_tx_count"), default=600)

    if lifetime_tx_count < 600:
        safe_balance_cents = min(
            manual_offline_wallet_cents,
            resolved_cached_balance_cents,
            hard_cap_cents,
        )
        confidence = 0.0
    else:
        raw_safe_myr = (
            52.58
            + (_normalized(parsed["tx_count_30d"], 90) * 8.0)
            + (_normalized(parsed["prior_offline_settle_rate"], 1.0) * 24.0)
            + (_normalized(parsed["account_age_days"], 720) * 16.0)
            + (_normalized(kyc_tier, 2.0) * 10.0)
            + (_normalized(parsed["prior_offline_count"], 36.0) * 8.0)
            + (6.0 if parsed["device_attest_ok"] > 0.5 else -20.0)
            - (min(parsed["last_sync_age_min"], 60) * 0.35)
            - (max(parsed["tx_amount_p95_30d"] - 60, 0) * 0.08)
        )
        confidence = (
            0.58
            + (_normalized(parsed["prior_offline_settle_rate"], 1.0) * 0.14)
            + (_normalized(parsed["account_age_days"], 720) * 0.08)
            + (0.07 if parsed["device_attest_ok"] > 0.5 else -0.18)
            - (_normalized(parsed["last_sync_age_min"], 60) * 0.12)
        )
        model_out_cents = max(0, round(raw_safe_myr * 100))
        safe_balance_cents = min(
            model_out_cents,
            resolved_cached_balance_cents,
            hard_cap_cents,
        )

    return {
        "safe_offline_balance_myr": format_cents(safe_balance_cents),
        "confidence": round(min(max(confidence, 0.0), 0.99), 2),
        "policy_version": policy_version,
        "computed_at": datetime.now(timezone.utc).isoformat(),
    }


def hard_cap_for_tier(tier: int) -> int:
    if tier <= 0:
        return 2000
    if tier == 1:
        return 5000
    return 25000


def _normalized(value: float, max_value: float) -> float:
    if max_value <= 0:
        return 0.0
    return min(max(value / max_value, 0.0), 1.0)


def _require_string(payload: dict, field_name: str) -> str:
    value = payload.get(field_name)
    if not isinstance(value, str) or not value.strip():
        raise ScoreInputError(f"{field_name} is required")
    return value.strip()


def _require_float(features: dict, field_name: str) -> float:
    if field_name not in features:
        raise ScoreInputError(f"features.{field_name} is required")
    value = features.get(field_name)
    try:
        return float(value)
    except (TypeError, ValueError):
        raise ScoreInputError(f"features.{field_name} must be numeric") from None


def resolve_money_cents(value, *, fallback: int, field_name: str) -> int:  # noqa: ANN001
    if value is None:
        return fallback

    try:
        return max(0, round(float(value) * 100))
    except (TypeError, ValueError):
        raise ScoreInputError(f"{field_name} must be a money string/number") from None


def resolve_int(value, *, default: int) -> int:  # noqa: ANN001
    if value is None:
        return default

    try:
        return int(value)
    except (TypeError, ValueError):
        raise ScoreInputError("lifetime_tx_count must be an integer") from None


def format_cents(cents: int) -> str:
    whole = cents // 100
    fraction = str(cents % 100).zfill(2)
    return f"{whole}.{fraction}"
