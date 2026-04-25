"""
GET /v1/score/policy
Returns the latest active score policy including model metadata and limits.
"""
import json
import logging
import os
import sys
import uuid
from datetime import datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from lib.jwt_middleware import JwtVerificationError, get_jwt_middleware

logger = logging.getLogger()

_DEFAULT_POLICY = {
    "policy_version": "v3.2026-04-22",
    "released_at": "2026-04-22T08:00:00Z",
    "model": {
        "format": "tflite",
        "url": "https://oss-ap-southeast-3.aliyuncs.com/tng-finhack-models/credit/v1/model.tflite",
        "sha256": "0000000000000000000000000000000000000000000000000000000000000000",
        "sigstore_signature": "",
    },
    "limits": {
        "hard_cap_per_tier": {"0": "20.00", "1": "150.00", "2": "500.00"},
        "global_cap_per_token_myr": "250.00",
        "max_token_validity_hours": 72,
    },
}


def _error(start_response, http_status: str, code: str, message: str, request_id: str):
    body = {"error": {"code": code, "message": message, "request_id": request_id}}
    start_response(http_status, [
        ("Content-Type", "application/json; charset=utf-8"),
        ("X-Request-Id", request_id),
        ("X-API-Version", "v1"),
    ])
    return [json.dumps(body).encode("utf-8")]


def _get_ots_client():
    import tablestore

    return tablestore.OTSClient(
        os.environ["TABLESTORE_ENDPOINT"],
        os.environ["OTS_ACCESS_KEY_ID"],
        os.environ["OTS_ACCESS_KEY_SECRET"],
        os.environ["TABLESTORE_INSTANCE"],
    )


def handler(environ, start_response):
    request_id = environ.get("HTTP_X_REQUEST_ID", f"req_{uuid.uuid4().hex[:12]}")

    # Auth
    auth_header = environ.get("HTTP_AUTHORIZATION", "")
    token = auth_header.removeprefix("Bearer ").strip()
    try:
        claims = get_jwt_middleware().verify(token)  # noqa: F841 — claims not used here
    except JwtVerificationError as e:
        return _error(start_response, "401 Unauthorized", e.code, str(e), request_id)

    # Demo mode or no Tablestore configured
    if not os.environ.get("TABLESTORE_ENDPOINT"):
        start_response("200 OK", [
            ("Content-Type", "application/json; charset=utf-8"),
            ("X-Request-Id", request_id),
            ("X-API-Version", "v1"),
        ])
        return [json.dumps(_DEFAULT_POLICY).encode("utf-8")]

    try:
        import tablestore

        client = _get_ots_client()
        # Read the __latest__ pointer row
        pk = [("policy_version", "__latest__")]
        cols = tablestore.ColumnsToGet(["active_version"])
        _, pointer_row, _ = client.get_row("score_policies", pk, cols, None, 1)

        active_version = "v3.2026-04-22"
        if pointer_row:
            attrs = {c[0]: c[1] for c in pointer_row.attribute_columns}
            active_version = attrs.get("active_version", active_version)

        # Read the actual policy row
        policy_pk = [("policy_version", active_version)]
        policy_cols = tablestore.ColumnsToGet([
            "released_at", "model_format", "model_url", "model_sha256",
            "model_sigstore_sig", "limits_json",
        ])
        _, policy_row, _ = client.get_row("score_policies", policy_pk, policy_cols, None, 1)

        if policy_row is None:
            # Fall back to default
            policy = dict(_DEFAULT_POLICY)
            policy["policy_version"] = active_version
        else:
            attrs = {c[0]: c[1] for c in policy_row.attribute_columns}
            limits = json.loads(attrs.get("limits_json", "{}")) or _DEFAULT_POLICY["limits"]
            policy = {
                "policy_version": active_version,
                "released_at": attrs.get("released_at", _DEFAULT_POLICY["released_at"]),
                "model": {
                    "format": attrs.get("model_format", "tflite"),
                    "url": attrs.get("model_url", _DEFAULT_POLICY["model"]["url"]),
                    "sha256": attrs.get("model_sha256", "0" * 64),
                    "sigstore_signature": attrs.get("model_sigstore_sig", ""),
                },
                "limits": limits,
            }

    except Exception as e:
        logger.error("Tablestore read failed, returning default policy: %s", e)
        policy = _DEFAULT_POLICY

    start_response("200 OK", [
        ("Content-Type", "application/json; charset=utf-8"),
        ("X-Request-Id", request_id),
        ("X-API-Version", "v1"),
    ])
    return [json.dumps(policy).encode("utf-8")]
