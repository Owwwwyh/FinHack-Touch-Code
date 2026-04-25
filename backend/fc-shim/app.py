"""
Local FC shim for development.
Mimics the Alibaba Function Compute HTTP routes so mobile devs can iterate locally.
"""

import json
import time
import os
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app, origins=["*"])


@app.route("/v1/wallet/balance", methods=["GET"])
def wallet_balance():
    return jsonify({
        "user_id": "u_demo",
        "balance_myr": "248.50",
        "currency": "MYR",
        "version": 4321,
        "as_of": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "safe_offline_balance_myr": "120.00",
        "policy_version": "v3.2026-04-22",
    })


@app.route("/v1/wallet/sync", methods=["POST"])
def wallet_sync():
    data = request.get_json(force=True)
    return jsonify({
        "user_id": data.get("user_id", "u_demo"),
        "balance_myr": "248.50",
        "currency": "MYR",
        "version": 4322,
        "as_of": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "safe_offline_balance_myr": "120.00",
        "policy_version": "v3.2026-04-22",
        "delta_events": [],
    })


@app.route("/v1/devices/register", methods=["POST"])
def device_register():
    data = request.get_json(force=True)
    import uuid
    kid = str(uuid.uuid4())[:26]
    return jsonify({
        "device_id": f"did:tng:device:{kid}",
        "kid": kid,
        "policy_version": "v3.2026-04-22",
        "initial_safe_offline_balance_myr": "50.00",
        "registered_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    })


@app.route("/v1/tokens/settle", methods=["POST"])
def tokens_settle():
    data = request.get_json(force=True)
    tokens = data.get("tokens", [])
    results = []
    for t in tokens:
        try:
            import base64
            parts = t.split(".")
            payload = json.loads(base64.urlsafe_b64decode(parts[1] + "=="))
            results.append({
                "tx_id": payload.get("tx_id", "unknown"),
                "status": "SETTLED",
                "settled_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            })
        except Exception:
            results.append({"tx_id": "unknown", "status": "REJECTED", "reason": "PARSE_ERROR"})
    return jsonify({
        "batch_id": data.get("batch_id", ""),
        "results": results,
    })


@app.route("/v1/tokens/dispute", methods=["POST"])
def tokens_dispute():
    data = request.get_json(force=True)
    import uuid
    return jsonify({
        "dispute_id": f"dsp_{str(uuid.uuid4())[:22]}",
        "status": "RECEIVED",
    }), 201


@app.route("/v1/score/refresh", methods=["POST"])
def score_refresh():
    data = request.get_json(force=True)
    features = data.get("features", {})
    tx_count = features.get("tx_count_30d", 0)
    kyc = features.get("kyc_tier", 0)
    safe = 50.0 + tx_count * 1.0
    safe *= (1 + kyc * 0.5)
    return jsonify({
        "safe_offline_balance_myr": f"{min(safe, 500):.2f}",
        "confidence": 0.87,
        "policy_version": data.get("policy_version", "v3.2026-04-22"),
        "computed_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    })


@app.route("/v1/score/policy", methods=["GET"])
def score_policy():
    return jsonify({
        "policy_version": "v3.2026-04-22",
        "released_at": "2026-04-22T08:00:00Z",
        "model": {
            "format": "tflite",
            "url": "https://placeholder/model.tflite",
            "sha256": "placeholder",
            "sigstore_signature": "placeholder",
        },
        "limits": {
            "hard_cap_per_tier": {"0": "20.00", "1": "150.00", "2": "500.00"},
            "global_cap_per_token_myr": "250.00",
            "max_token_validity_hours": 72,
        },
    })


@app.route("/v1/publickeys/<kid>", methods=["GET"])
def publickeys_get(kid):
    return jsonify({
        "kid": kid,
        "alg": "EdDSA",
        "public_key": "PLACEHOLDER",
        "status": "ACTIVE",
        "registered_at": "2026-04-10T11:00:00Z",
        "revoked_at": None,
    })


@app.route("/v1/merchants/onboard", methods=["POST"])
def merchants_onboard():
    import uuid
    return jsonify({"merchant_id": f"m_{str(uuid.uuid4())[:22]}"}), 201


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 3000))
    app.run(host="0.0.0.0", port=port, debug=True)
