# python backend/server.py
import io
import json
import os
import sys
from datetime import datetime, timezone

# Ensure backend/ is on sys.path so fc/*, lib/*, aws_lambda/* all resolve.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from flask import Flask, Response, request  # noqa: E402

import fc.device_register.handler as _device_register
import fc.score_policy.handler as _score_policy
import fc.tokens_settle.handler as _tokens_settle
import fc.wallet_balance.handler as _wallet_balance
from lib import demo_state
from lib.jwt_middleware import get_jwt_middleware

app = Flask(__name__)


def _make_environ(flask_req):
    body = flask_req.get_data()
    environ = {
        "REQUEST_METHOD": flask_req.method,
        "wsgi.input": io.BytesIO(body),
        "CONTENT_LENGTH": str(len(body)),
        "CONTENT_TYPE": flask_req.content_type or "",
    }
    for key, value in flask_req.headers:
        environ["HTTP_" + key.upper().replace("-", "_")] = value
    # WSGI spec: CONTENT_TYPE / CONTENT_LENGTH have no HTTP_ prefix
    environ["CONTENT_TYPE"] = flask_req.content_type or ""
    return environ


def _call_handler(handler_fn, flask_req):
    environ = _make_environ(flask_req)
    status_holder = []
    headers_holder = []

    def start_response(status, headers, exc_info=None):
        status_holder.append(status)
        headers_holder.extend(headers)

    chunks = handler_fn(environ, start_response)
    body = b"".join(chunks)
    status_code = int(status_holder[0].split(" ", 1)[0]) if status_holder else 200
    return Response(body, status=status_code, headers=dict(headers_holder))


def _demo_user_id():
    auth = request.headers.get("Authorization", "")
    token = auth.removeprefix("Bearer ").strip()
    claims = get_jwt_middleware().verify(token) if token else {"sub": "demo_user"}
    return claims.get("sub") or claims.get("cognito:username", "demo_user")


@app.route("/v1/wallet/balance", methods=["GET"])
def wallet_balance():
    return _call_handler(_wallet_balance.handler, request)


@app.route("/v1/wallet/sync", methods=["POST"])
def wallet_sync():
    user_id = _demo_user_id()
    body = demo_state.get_wallet_response(user_id)
    body["synced_at"] = datetime.now(timezone.utc).isoformat()
    return Response(
        json.dumps(body),
        status=200,
        headers={"Content-Type": "application/json; charset=utf-8", "X-API-Version": "v1"},
    )


@app.route("/v1/devices/register", methods=["POST"])
def device_register():
    return _call_handler(_device_register.handler, request)


@app.route("/v1/score/policy", methods=["GET"])
def score_policy():
    return _call_handler(_score_policy.handler, request)


@app.route("/v1/score/refresh", methods=["POST"])
def score_refresh():
    body = {
        "safe_offline_balance_myr": "120.00",
        "confidence": 0.87,
        "policy_version": "v3.2026-04-22",
        "computed_at": datetime.now(timezone.utc).isoformat(),
    }
    return Response(
        json.dumps(body),
        status=200,
        headers={"Content-Type": "application/json; charset=utf-8", "X-API-Version": "v1"},
    )


@app.route("/v1/tokens/settle", methods=["POST"])
def tokens_settle():
    return _call_handler(_tokens_settle.handler, request)


@app.route("/v1/publickeys/<kid>", methods=["GET"])
def public_keys(kid):
    body = {
        "kid": kid,
        "alg": "EdDSA",
        "public_key": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
        "status": "ACTIVE",
    }
    return Response(
        json.dumps(body),
        status=200,
        headers={"Content-Type": "application/json; charset=utf-8", "X-API-Version": "v1"},
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=3000, debug=True)
