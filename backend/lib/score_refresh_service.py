"""Online-first score refresh service with local fallback."""

from __future__ import annotations

import logging
import os
from datetime import datetime, timezone

import requests

from lib.score_inference import (
    ScoreInputError,
    compute_score_response,
    format_cents,
    hard_cap_for_tier,
    resolve_int,
    resolve_money_cents,
)

logger = logging.getLogger(__name__)

DEFAULT_TIMEOUT_SECONDS = 0.8


def refresh_score_response(
    payload: dict,
    *,
    cached_balance_cents: int,
    default_manual_offline_cents: int,
    eas_endpoint: str | None = None,
    eas_token: str | None = None,
    timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS,
) -> dict:
    local_response = compute_score_response(
        payload,
        cached_balance_cents=cached_balance_cents,
        default_manual_offline_cents=default_manual_offline_cents,
    )

    lifetime_tx_count = resolve_int(payload.get("lifetime_tx_count"), default=600)
    if lifetime_tx_count < 600:
        return local_response

    resolved_endpoint = (eas_endpoint if eas_endpoint is not None else os.environ.get("EAS_ENDPOINT", "")).strip()
    if not resolved_endpoint:
        return local_response

    try:
        online_response = _call_pai_eas(
            resolved_endpoint,
            payload,
            eas_token=eas_token if eas_token is not None else os.environ.get("EAS_TOKEN", ""),
            timeout_seconds=timeout_seconds,
        )
        return _normalise_online_response(
            payload,
            online_response,
            local_response,
            cached_balance_cents=cached_balance_cents,
        )
    except requests.Timeout:
        logger.warning("PAI-EAS timeout, using local fallback")
        return local_response
    except (requests.RequestException, ScoreInputError, TypeError, ValueError) as exc:
        logger.warning("PAI-EAS unavailable, using local fallback: %s", exc)
        return local_response


def _call_pai_eas(
    eas_endpoint: str,
    payload: dict,
    *,
    eas_token: str,
    timeout_seconds: float,
) -> dict:
    url = eas_endpoint.rstrip("/")
    if not url.endswith("/score"):
        url = f"{url}/score"

    headers = {"Content-Type": "application/json"}
    if eas_token:
        headers["Authorization"] = _authorisation_header(eas_token)

    response = requests.post(
        url,
        json={
            "user_id": payload.get("user_id"),
            "features": payload.get("features"),
            "policy": payload.get("policy_version"),
        },
        headers=headers,
        timeout=timeout_seconds,
    )
    response.raise_for_status()
    data = response.json()
    if not isinstance(data, dict):
        raise ValueError("PAI-EAS response must be a JSON object")
    return data


def _normalise_online_response(
    payload: dict,
    online_response: dict,
    local_response: dict,
    *,
    cached_balance_cents: int,
) -> dict:
    features = payload.get("features") or {}
    kyc_tier = int(round(float(features.get("kyc_tier", 0))))
    safe_balance_cents = resolve_money_cents(
        online_response.get("safe_offline_balance_myr"),
        fallback=resolve_money_cents(
            local_response.get("safe_offline_balance_myr"),
            fallback=0,
            field_name="safe_offline_balance_myr",
        ),
        field_name="safe_offline_balance_myr",
    )
    safe_balance_cents = min(
        safe_balance_cents,
        max(cached_balance_cents, 0),
        hard_cap_for_tier(kyc_tier),
    )
    confidence = round(
        min(max(float(online_response.get("confidence", local_response["confidence"])), 0.0), 0.99),
        2,
    )

    return {
        "safe_offline_balance_myr": format_cents(safe_balance_cents),
        "confidence": confidence,
        "policy_version": (
            online_response.get("policy_version")
            or online_response.get("policy")
            or local_response["policy_version"]
        ),
        "computed_at": online_response.get("computed_at") or datetime.now(timezone.utc).isoformat(),
    }


def _authorisation_header(token: str) -> str:
    return token if token.lower().startswith("bearer ") else f"Bearer {token}"
