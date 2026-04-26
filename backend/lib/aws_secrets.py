"""Helpers for resolving Secrets Manager references inside AWS Lambdas."""

from __future__ import annotations

import base64
import os
from functools import lru_cache


def resolve_secret_env(name: str, default: str = "") -> str:
    """Return the env var value, resolving ``secret://`` references when present."""
    return resolve_secret_reference(os.environ.get(name, default))


@lru_cache(maxsize=32)
def resolve_secret_reference(value: str) -> str:
    if not value or not value.startswith("secret://"):
        return value

    secret_id = value.removeprefix("secret://")
    response = _get_secrets_client().get_secret_value(SecretId=secret_id)

    secret_string = response.get("SecretString")
    if secret_string is not None:
        return secret_string

    secret_binary = response.get("SecretBinary")
    if secret_binary is None:
        return ""

    return base64.b64decode(secret_binary).decode("utf-8")


def _get_secrets_client():
    import boto3  # pragma: no cover - imported lazily for real AWS only

    region_name = os.environ.get("AWS_REGION") or os.environ.get("AWS_DEFAULT_REGION")
    return boto3.client("secretsmanager", region_name=region_name)
