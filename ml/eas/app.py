"""
PAI-EAS refresh-score endpoint.
Per docs/04-credit-score-ml.md §9 and docs/06-alibaba-services.md §2.

Flask container that loads XGBoost model from Alibaba OSS and serves
POST /score for online safe-offline-balance computation.
"""

import os
import json
import time
import pickle
import logging
from flask import Flask, request, jsonify

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Model loaded at warmup
model_artifact = None
model_metadata = None
MODEL_PATH = os.environ.get("MODEL_PATH", "/app/model.pkl")


def load_model():
    """Load XGBoost model from local path (fetched from OSS at warmup)."""
    global model_artifact, model_metadata
    if model_artifact is not None:
        return

    if os.path.exists(MODEL_PATH):
        with open(MODEL_PATH, "rb") as f:
            artifact = pickle.load(f)
        model_artifact = artifact["model"]
        model_metadata = {
            "feature_cols": artifact.get("feature_cols", []),
            "calibrator": artifact.get("calibrator"),
        }
        logger.info(f"Model loaded from {MODEL_PATH}")
    else:
        logger.warning(f"Model not found at {MODEL_PATH}, using heuristic fallback")


def predict_safe_balance(features: dict) -> dict:
    """Compute safe offline balance from feature vector."""
    import numpy as np

    if model_artifact is not None:
        feature_cols = model_metadata.get("feature_cols", [])
        # Build feature array in correct order
        feature_values = []
        for col in feature_cols:
            key = col.split("_", 1)[1] if "_" in col else col
            # Map feature names from request format
            value = features.get(key, 0)
            if value is None:
                value = 0
            feature_values.append(float(value))

        X = np.array([feature_values])
        raw_pred = float(model_artifact.predict(X)[0])

        # Apply calibration
        calibrator = model_metadata.get("calibrator")
        if calibrator is not None:
            raw_pred = float(calibrator.predict([raw_pred])[0])

        # Clamp to non-negative
        safe_balance = max(0.0, raw_pred)
    else:
        # Fallback heuristic
        tx_count = features.get("tx_count_30d", 0)
        account_age = features.get("account_age_days", 0)
        kyc_tier = features.get("kyc_tier", 0)
        sync_age = features.get("last_sync_age_min", 0)

        base = 50.0 + tx_count * 1.0 + account_age * 0.5
        base *= (1 + kyc_tier * 0.5)
        base -= sync_age * 0.5
        safe_balance = max(0.0, base)

    # Compute confidence (simplified)
    confidence = min(1.0, max(0.0, 0.5 + len(features) * 0.02))

    return {
        "safe_offline_balance_myr": f"{safe_balance:.2f}",
        "confidence": round(confidence, 2),
        "computed_at": int(time.time()),
    }


@app.route("/score", methods=["POST"])
def score():
    """POST /score endpoint for PAI-EAS."""
    data = request.get_json()
    if not data:
        return jsonify({"error": {"code": "BAD_REQUEST", "message": "Empty request body"}}), 400

    user_id = data.get("user_id")
    features = data.get("features", {})
    policy = data.get("policy_version", "unknown")

    if not user_id:
        return jsonify({"error": {"code": "BAD_REQUEST", "message": "user_id required"}}), 400

    if not features:
        return jsonify({"error": {"code": "BAD_REQUEST", "message": "features required"}}), 400

    load_model()

    try:
        result = predict_safe_balance(features)
        result["policy_version"] = policy
        return jsonify(result)
    except Exception as e:
        logger.error(f"Score computation failed: {e}")
        return jsonify({"error": {"code": "INTERNAL", "message": str(e)}}), 500


@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint."""
    return jsonify({"status": "healthy", "model_loaded": model_artifact is not None})


@app.route("/warmup", methods=["POST"])
def warmup():
    """Trigger model loading."""
    load_model()
    return jsonify({"status": "warmed", "model_loaded": model_artifact is not None})


if __name__ == "__main__":
    load_model()
    port = int(os.environ.get("PORT", 8501))
    app.run(host="0.0.0.0", port=port)
