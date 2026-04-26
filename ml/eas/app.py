"""Alibaba PAI-EAS style scoring container for refresh-score requests."""

from __future__ import annotations

import io
import logging
import os
import pickle
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from flask import Flask, jsonify, request
try:
    import oss2
except ImportError:  # pragma: no cover - optional outside the container image
    oss2 = None

REPO_ROOT = Path(__file__).resolve().parents[2]
BACKEND_ROOT = REPO_ROOT / "backend"
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from lib.score_inference import ScoreInputError, compute_score_response, format_cents

logger = logging.getLogger(__name__)

FEATURE_ORDER = (
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

FEATURE_ALIASES = {
    "f01": "tx_count_30d",
    "f02": "tx_count_90d",
    "f05": "tx_amount_p95_30d",
    "f15": "prior_offline_count",
    "f16": "prior_offline_settle_rate",
    "f17": "account_age_days",
    "f18": "kyc_tier",
    "f19": "last_sync_age_min",
    "f20": "device_attest_ok",
}


@dataclass
class ModelBundle:
    predictor: Any
    source: str


class HeuristicPredictor:
    """Predictor that reuses the repo's local scoring contract."""

    def predict(self, payload: dict) -> dict:
        response = compute_score_response(
            {
                "user_id": payload["user_id"],
                "policy_version": payload["policy"],
                "features": payload["features"],
                "cached_balance_myr": payload.get("cached_balance_myr", "999999.99"),
                "manual_offline_wallet_myr": payload.get("manual_offline_wallet_myr", "999999.99"),
                "lifetime_tx_count": payload.get("lifetime_tx_count", 600),
            },
            cached_balance_cents=99_999_999,
            default_manual_offline_cents=99_999_999,
        )
        return {
            "safe_offline_balance_myr": response["safe_offline_balance_myr"],
            "confidence": response["confidence"],
            "policy": response["policy_version"],
            "computed_at": response["computed_at"],
        }


class XGBoostPredictor:
    """Thin adapter around a loaded XGBoost/sklearn-style model."""

    def __init__(self, model: Any):
        self._model = model

    def predict(self, payload: dict) -> dict:
        features = _normalise_feature_map(payload["features"])
        vector = [[float(features[name]) for name in FEATURE_ORDER]]
        raw_output = self._invoke_model(vector)
        safe_balance_myr = max(float(raw_output), 0.0)
        return {
            "safe_offline_balance_myr": format_cents(round(safe_balance_myr * 100)),
            "confidence": round(_confidence_from_features(features), 2),
            "policy": payload["policy"],
            "computed_at": datetime.now(timezone.utc).isoformat(),
        }

    def _invoke_model(self, vector: list[list[float]]) -> float:
        if hasattr(self._model, "predict"):
            result = self._model.predict(vector)
            if isinstance(result, (list, tuple)):
                return float(result[0])
            try:
                return float(result[0])  # numpy-like
            except (TypeError, IndexError, KeyError):
                return float(result)

        if hasattr(self._model, "inplace_predict"):
            result = self._model.inplace_predict(vector)
            return float(result[0])

        raise TypeError("Loaded model does not expose a supported predict method")


def create_app() -> Flask:
    app = Flask(__name__)
    app.config["predictor_bundle"] = _load_model_bundle()

    @app.get("/healthz")
    def healthz():
        bundle: ModelBundle = app.config["predictor_bundle"]
        return jsonify({"ok": True, "model_source": bundle.source})

    @app.post("/score")
    def score():
        expected_token = os.environ.get("EAS_TOKEN", "").strip()
        if expected_token:
            provided_token = _extract_bearer_token(request.headers.get("Authorization", ""))
            if provided_token != expected_token:
                return _error("UNAUTHORIZED", "Invalid or missing EAS token", 401)

        payload = request.get_json(silent=True)
        if not isinstance(payload, dict):
            return _error("BAD_REQUEST", "Request body must be a JSON object", 400)

        try:
            normalised_payload = _normalise_payload(payload)
            bundle = app.config["predictor_bundle"]
            response = bundle.predictor.predict(normalised_payload)
        except ScoreInputError as exc:
            return _error("BAD_REQUEST", str(exc), 400)
        except Exception as exc:  # pragma: no cover - defensive logging path
            logger.exception("Score request failed")
            return _error("INFERENCE_ERROR", str(exc), 500)

        return jsonify(response)

    return app


def _error(code: str, message: str, status: int):
    return jsonify({"error": {"code": code, "message": message}}), status


def _normalise_payload(payload: dict) -> dict:
    user_id = payload.get("user_id")
    if not isinstance(user_id, str) or not user_id.strip():
        raise ScoreInputError("user_id is required")

    policy = payload.get("policy") or payload.get("policy_version")
    if not isinstance(policy, str) or not policy.strip():
        raise ScoreInputError("policy is required")

    features = payload.get("features")
    if not isinstance(features, dict):
        raise ScoreInputError("features object is required")

    return {
        "user_id": user_id.strip(),
        "policy": policy.strip(),
        "features": _normalise_feature_map(features),
        "cached_balance_myr": payload.get("cached_balance_myr"),
        "manual_offline_wallet_myr": payload.get("manual_offline_wallet_myr"),
        "lifetime_tx_count": payload.get("lifetime_tx_count", 600),
    }


def _normalise_feature_map(features: dict) -> dict:
    normalised: dict[str, float] = {}
    for key, value in features.items():
        target_key = FEATURE_ALIASES.get(key, key)
        normalised[target_key] = value

    missing = [name for name in FEATURE_ORDER if name not in normalised]
    if missing:
        raise ScoreInputError(f"features.{missing[0]} is required")

    for name in FEATURE_ORDER:
        try:
            normalised[name] = float(normalised[name])
        except (TypeError, ValueError):
            raise ScoreInputError(f"features.{name} must be numeric") from None

    return normalised


def _confidence_from_features(features: dict[str, float]) -> float:
    confidence = (
        0.60
        + min(max(features["prior_offline_settle_rate"], 0.0), 1.0) * 0.18
        + min(max(features["account_age_days"] / 720.0, 0.0), 1.0) * 0.10
        - min(max(features["last_sync_age_min"] / 60.0, 0.0), 1.0) * 0.12
    )
    if features["device_attest_ok"] <= 0.5:
        confidence -= 0.18
    return min(max(confidence, 0.0), 0.99)


def _extract_bearer_token(header: str) -> str:
    raw = header.strip()
    if not raw:
        return ""
    if raw.lower().startswith("bearer "):
        return raw[7:].strip()
    return raw


def _load_model_bundle() -> ModelBundle:
    local_path = os.environ.get("MODEL_PATH", "").strip()
    if local_path:
        try:
            predictor = _load_predictor_from_bytes(Path(local_path).read_bytes(), local_path)
            logger.info("Loaded EAS model from %s", local_path)
            return ModelBundle(predictor=predictor, source=local_path)
        except Exception as exc:  # pragma: no cover - defensive logging path
            logger.warning("Failed to load MODEL_PATH %s: %s", local_path, exc)

    oss_bucket = os.environ.get("MODEL_OSS_BUCKET", "").strip()
    oss_key = os.environ.get("MODEL_OSS_KEY", "").strip()
    if oss_bucket and oss_key:
        try:
            blob = _download_model_from_oss(oss_bucket, oss_key)
            predictor = _load_predictor_from_bytes(blob, f"oss://{oss_bucket}/{oss_key}")
            logger.info("Loaded EAS model from oss://%s/%s", oss_bucket, oss_key)
            return ModelBundle(predictor=predictor, source=f"oss://{oss_bucket}/{oss_key}")
        except Exception as exc:  # pragma: no cover - defensive logging path
            logger.warning("Failed to load OSS model %s/%s: %s", oss_bucket, oss_key, exc)

    logger.info("No model configured, using heuristic predictor")
    return ModelBundle(predictor=HeuristicPredictor(), source="heuristic")


def _download_model_from_oss(bucket_name: str, key: str) -> bytes:
    if oss2 is None:
        raise RuntimeError("oss2 is required for OSS-backed model loading")

    auth = oss2.Auth(
        os.environ.get("OSS_ACCESS_KEY_ID", "").strip(),
        os.environ.get("OSS_ACCESS_KEY_SECRET", "").strip(),
    )
    endpoint = os.environ.get("OSS_ENDPOINT", "").strip()
    if not endpoint:
        raise ValueError("OSS_ENDPOINT is required for OSS-backed model loading")

    bucket = oss2.Bucket(auth, endpoint, bucket_name)
    return bucket.get_object(key).read()


def _load_predictor_from_bytes(blob: bytes, source: str):
    suffix = Path(source).suffix.lower()
    if suffix in {".json", ".ubj"}:
        try:
            import xgboost as xgb
        except ImportError as exc:  # pragma: no cover - depends on runtime image
            raise RuntimeError("xgboost is required to load JSON/UBJ models") from exc

        booster = xgb.Booster()
        temp_path = Path("/tmp") / f"tng-eas-model{suffix}"
        temp_path.write_bytes(blob)
        booster.load_model(str(temp_path))
        return XGBoostPredictor(booster)

    model = pickle.load(io.BytesIO(blob))
    return XGBoostPredictor(model)


app = create_app()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
