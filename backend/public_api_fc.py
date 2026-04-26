"""Alibaba FC entrypoint exposing the full public /v1 API on one trigger URL."""

from __future__ import annotations

import json
import os
import sys
import uuid

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import fc.device_register.handler as _device_register
import fc.eb_cross_cloud_ingest.handler as _aws_bridge
import fc.score_policy.handler as _score_policy
import fc.score_refresh.handler as _score_refresh
import fc.tokens_settle.handler as _tokens_settle
import fc.wallet_balance.handler as _wallet_balance


_ROUTES = {
    ("POST", "/v1/devices/register"): _device_register.handler,
    ("GET", "/v1/wallet/balance"): _wallet_balance.handler,
    ("GET", "/v1/score/policy"): _score_policy.handler,
    ("POST", "/v1/score/refresh"): _score_refresh.handler,
    ("POST", "/v1/tokens/settle"): _tokens_settle.handler,
    ("POST", "/v1/_internal/eb/aws-bridge"): _aws_bridge.handler,
}


def handler(environ, start_response):
    method = (environ.get("REQUEST_METHOD") or "GET").upper()
    path = _request_path(environ)
    route_handler = _ROUTES.get((method, path))
    if route_handler is None:
        return _not_found(start_response, path)
    return route_handler(environ, start_response)


def _request_path(environ) -> str:
    candidates = [
        environ.get("PATH_INFO"),
        environ.get("FC_REQUEST_PATH"),
        environ.get("REQUEST_URI"),
        environ.get("RAW_URI"),
    ]
    for candidate in candidates:
        if not candidate:
            continue
        path = str(candidate).split("?", 1)[0]
        if path.startswith("http://") or path.startswith("https://"):
            path = "/" + path.split("/", 3)[3] if path.count("/") >= 3 else "/"
        if path:
            return path
    return "/"


def _not_found(start_response, path: str):
    request_id = f"req_{uuid.uuid4().hex[:12]}"
    body = {
        "error": {
            "code": "NOT_FOUND",
            "message": f"No route for {path}",
            "request_id": request_id,
        }
    }
    start_response(
        "404 Not Found",
        [
            ("Content-Type", "application/json; charset=utf-8"),
            ("X-Request-Id", request_id),
            ("X-API-Version", "v1"),
        ],
    )
    return [json.dumps(body).encode("utf-8")]
