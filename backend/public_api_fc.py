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
from fc_http_adapter import invoke_wsgi_handler


_ROUTES = {
    ("POST", "/v1/devices/register"): _device_register.handler,
    ("GET", "/v1/wallet/balance"): _wallet_balance.handler,
    ("GET", "/v1/score/policy"): _score_policy.handler,
    ("POST", "/v1/score/refresh"): _score_refresh.handler,
    ("POST", "/v1/tokens/settle"): _tokens_settle.handler,
    ("POST", "/v1/_internal/eb/aws-bridge"): _aws_bridge.handler,
}


def handler(event, context):  # noqa: ANN001
    return invoke_wsgi_handler(_wsgi_handler, event, context)


def _wsgi_handler(environ, start_response):
    method = (environ.get("REQUEST_METHOD") or "GET").upper()
    path = _request_path(environ)
    if method == "GET" and path in {"/", "/index.html"}:
        return _landing_page(start_response)
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


def _landing_page(start_response):
    html = """<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>FinHack Demo Live</title>
    <style>
      :root {
        --bg: linear-gradient(135deg, #0f172a 0%, #1d4ed8 55%, #38bdf8 100%);
        --card: rgba(255, 255, 255, 0.16);
        --text: #f8fafc;
        --muted: rgba(248, 250, 252, 0.82);
        --line: rgba(255, 255, 255, 0.18);
        --accent: #facc15;
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        min-height: 100vh;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        background: var(--bg);
        color: var(--text);
        display: grid;
        place-items: center;
        padding: 24px;
      }
      .card {
        width: min(760px, 100%);
        background: var(--card);
        backdrop-filter: blur(18px);
        border: 1px solid var(--line);
        border-radius: 28px;
        padding: 32px;
        box-shadow: 0 24px 80px rgba(15, 23, 42, 0.3);
      }
      .eyebrow {
        display: inline-block;
        padding: 8px 12px;
        border-radius: 999px;
        background: rgba(250, 204, 21, 0.14);
        color: #fde68a;
        font-size: 12px;
        letter-spacing: 0.08em;
        text-transform: uppercase;
      }
      h1 {
        margin: 18px 0 10px;
        font-size: clamp(34px, 6vw, 60px);
        line-height: 0.96;
      }
      p {
        margin: 0;
        color: var(--muted);
        font-size: 17px;
        line-height: 1.55;
      }
      .actions {
        display: flex;
        flex-wrap: wrap;
        gap: 12px;
        margin-top: 24px;
      }
      a {
        text-decoration: none;
      }
      .btn {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-height: 48px;
        padding: 0 18px;
        border-radius: 14px;
        font-weight: 700;
      }
      .btn-primary {
        background: var(--accent);
        color: #111827;
      }
      .btn-secondary {
        background: rgba(255, 255, 255, 0.08);
        color: var(--text);
        border: 1px solid var(--line);
      }
      .grid {
        display: grid;
        gap: 12px;
        margin-top: 28px;
      }
      .item {
        padding: 14px 16px;
        border-radius: 16px;
        background: rgba(255, 255, 255, 0.08);
        border: 1px solid var(--line);
      }
      .label {
        display: block;
        font-size: 12px;
        text-transform: uppercase;
        letter-spacing: 0.08em;
        color: rgba(248, 250, 252, 0.68);
        margin-bottom: 6px;
      }
      code {
        word-break: break-all;
        font-size: 14px;
        color: #e2e8f0;
      }
    </style>
  </head>
  <body>
    <main class="card">
      <span class="eyebrow">FinHack Demo</span>
      <h1>Deployment is live.</h1>
      <p>This public page is running from the live cloud backend so judges and teammates can open a real link right now.</p>
      <div class="actions">
        <a class="btn btn-primary" href="/v1/score/policy">Open Live API Demo</a>
        <a class="btn btn-secondary" href="/v1/score/policy">Public JSON Endpoint</a>
      </div>
      <div class="grid">
        <div class="item">
          <span class="label">Public Demo Link</span>
          <code>https://public-api-luqnmpfywn.ap-southeast-3.fcapp.run/</code>
        </div>
        <div class="item">
          <span class="label">API Base URL</span>
          <code>https://public-api-luqnmpfywn.ap-southeast-3.fcapp.run/v1</code>
        </div>
      </div>
    </main>
  </body>
</html>
"""
    start_response(
        "200 OK",
        [("Content-Type", "text/html; charset=utf-8")],
    )
    return [html.encode("utf-8")]
