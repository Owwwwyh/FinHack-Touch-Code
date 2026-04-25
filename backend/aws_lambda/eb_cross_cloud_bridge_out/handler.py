"""AWS outbound bridge Lambda for settlement result delivery to Alibaba."""

from __future__ import annotations

import json
import os
import sys

import requests

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from lib.bridge_auth import sign_body
from lib.settlement_events import encode_event


def handler(event, context):  # noqa: ANN001
    ingest_url = os.environ["ALIBABA_INGEST_URL"]
    body = encode_event(event)
    headers = {"Content-Type": "application/json"}

    secret = os.environ.get("AWS_BRIDGE_HMAC_SECRET", "")
    if secret:
        headers["X-TNG-Signature"] = sign_body(secret, body)

    response = requests.post(ingest_url, data=body, headers=headers, timeout=3)
    response_body = _parse_json(response.text)
    return {
        "delivered": response.status_code < 300,
        "status_code": response.status_code,
        "response": response_body,
    }


def _parse_json(raw: str):
    if not raw:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw
