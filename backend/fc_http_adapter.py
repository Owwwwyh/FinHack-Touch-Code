"""Adapters for running existing WSGI-style handlers on Alibaba FC v3."""

from __future__ import annotations

import base64
import io
import json
from typing import Any


def invoke_wsgi_handler(wsgi_handler, event: Any, context: Any):
    environ = build_environ(event, context)
    status_holder: list[str] = []
    headers_holder: list[tuple[str, str]] = []

    def start_response(status, headers, exc_info=None):  # noqa: ANN001
        status_holder.append(status)
        headers_holder.extend(headers)

    chunks = wsgi_handler(environ, start_response)
    body = b"".join(chunks)
    status_code = int(status_holder[0].split(" ", 1)[0]) if status_holder else 200
    response = {
        "statusCode": status_code,
        "headers": {key: value for key, value in headers_holder},
        "body": "",
    }
    try:
        response["body"] = body.decode("utf-8")
    except UnicodeDecodeError:
        response["body"] = base64.b64encode(body).decode("ascii")
        response["isBase64Encoded"] = True
    return response


def build_environ(event: Any, context: Any) -> dict[str, Any]:
    payload = _coerce_payload(event)
    method = _first_non_empty(
        _payload_get(payload, "httpMethod"),
        _nested_get(payload, "requestContext", "http", "method"),
        _context_attr(context, "method", "request_method"),
        "GET",
    )
    path = _normalize_path(
        _first_non_empty(
            _payload_get(payload, "path"),
            _payload_get(payload, "rawPath"),
            _context_attr(context, "path", "request_path", "request_uri", "raw_path"),
            "/",
        )
    )
    headers = _normalize_headers(
        _first_non_empty(
            _payload_get(payload, "headers"),
            _context_attr(context, "headers", "http_headers"),
            {},
        )
    )
    raw_body = _body_bytes(payload, event)

    environ: dict[str, Any] = {
        "REQUEST_METHOD": method.upper(),
        "PATH_INFO": path,
        "REQUEST_URI": path,
        "RAW_URI": path,
        "wsgi.input": io.BytesIO(raw_body),
        "CONTENT_LENGTH": str(len(raw_body)),
        "CONTENT_TYPE": headers.get("content-type", ""),
        "fc.context": context,
    }

    for key, value in headers.items():
        header_name = "HTTP_" + key.upper().replace("-", "_")
        environ[header_name] = value
    if "content-type" in headers:
        environ["CONTENT_TYPE"] = headers["content-type"]
    return environ


def _coerce_payload(event: Any) -> dict[str, Any] | None:
    if isinstance(event, dict):
        return event
    if isinstance(event, (bytes, bytearray)):
        text = bytes(event).decode("utf-8", errors="ignore")
    elif isinstance(event, str):
        text = event
    else:
        return None
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        return None
    return parsed if isinstance(parsed, dict) else None


def _body_bytes(payload: dict[str, Any] | None, event: Any) -> bytes:
    if payload and "body" in payload:
        body = payload.get("body")
        if body is None:
            return b""
        if payload.get("isBase64Encoded") or payload.get("isBase64Encoding"):
            return base64.b64decode(body)
        if isinstance(body, str):
            return body.encode("utf-8")
        if isinstance(body, (bytes, bytearray)):
            return bytes(body)
        return json.dumps(body).encode("utf-8")
    if isinstance(event, (bytes, bytearray)):
        return bytes(event)
    if isinstance(event, str):
        return event.encode("utf-8")
    return b""


def _normalize_headers(headers: Any) -> dict[str, str]:
    if not isinstance(headers, dict):
        return {}
    return {str(key).lower(): str(value) for key, value in headers.items() if value is not None}


def _normalize_path(path: Any) -> str:
    text = str(path or "/").split("?", 1)[0]
    if text.startswith("http://") or text.startswith("https://"):
        parts = text.split("/", 3)
        return "/" + parts[3] if len(parts) > 3 else "/"
    return text if text.startswith("/") else f"/{text}"


def _payload_get(payload: dict[str, Any] | None, key: str) -> Any:
    if not isinstance(payload, dict):
        return None
    return payload.get(key)


def _nested_get(payload: dict[str, Any] | None, *keys: str) -> Any:
    current: Any = payload
    for key in keys:
        if not isinstance(current, dict):
            return None
        current = current.get(key)
    return current


def _context_attr(context: Any, *names: str) -> Any:
    if context is None:
        return None
    if isinstance(context, dict):
        for name in names:
            if name in context and context[name] not in (None, ""):
                return context[name]
    for name in names:
        value = getattr(context, name, None)
        if value not in (None, ""):
            return value
    return None


def _first_non_empty(*values: Any) -> Any:
    for value in values:
        if value not in (None, "", {}):
            return value
    return None
