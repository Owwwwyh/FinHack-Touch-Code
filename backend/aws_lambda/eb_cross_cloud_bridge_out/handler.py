"""AWS outbound bridge Lambda for settlement result delivery to Alibaba."""

from __future__ import annotations

import json
import os
import sys
from urllib import error, request

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from lib.aws_secrets import resolve_secret_env
from lib.bridge_auth import sign_body
from lib.settlement_events import encode_event


def handler(event, context):  # noqa: ANN001
    ingest_url = resolve_secret_env("ALIBABA_INGEST_URL")
    body = encode_event(event)
    headers = {"Content-Type": "application/json"}

    secret = resolve_secret_env("AWS_BRIDGE_HMAC_SECRET")
    if secret:
        headers["X-TNG-Signature"] = sign_body(secret, body)

    response = _post(ingest_url, body, headers=headers, timeout=3)
    response_body = _parse_json(response["body"])
    return {
        "delivered": response["status_code"] < 300,
        "status_code": response["status_code"],
        "response": response_body,
    }


def _parse_json(raw: str):
    if not raw:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw


def _post(url: str, data: bytes, *, headers: dict[str, str], timeout: float) -> dict:
    req = request.Request(url, data=data, headers=headers, method="POST")
    try:
        with request.urlopen(req, timeout=timeout) as response:  # noqa: S310
            return {
                "status_code": response.getcode(),
                "body": response.read().decode("utf-8"),
            }
    except error.HTTPError as exc:
        return {
            "status_code": exc.code,
            "body": exc.read().decode("utf-8"),
        }
