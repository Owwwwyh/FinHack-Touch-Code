"""Helpers for Alibaba FC runtime configuration."""

from __future__ import annotations

import os


def device_table_name() -> str:
    return os.environ.get("TABLE_NAME_DEVICES", "devices")


def wallets_table_name() -> str:
    return os.environ.get("TABLE_NAME_WALLETS", "wallets")


def pending_batches_table_name() -> str:
    return os.environ.get("TABLE_NAME_PENDING_BATCHES", "pending_batches")


def score_policies_table_name() -> str:
    return os.environ.get("TABLE_NAME_SCORE_POLICIES", "score_policies")


def create_tablestore_client(environ):
    import tablestore

    access_key_id, access_key_secret, security_token = _resolve_credentials(environ)
    kwargs = {"sts_token": security_token} if security_token else {}
    return tablestore.OTSClient(
        os.environ["TABLESTORE_ENDPOINT"],
        access_key_id,
        access_key_secret,
        os.environ["TABLESTORE_INSTANCE"],
        **kwargs,
    )


def create_oss_bucket(environ):
    import oss2

    access_key_id, access_key_secret, security_token = _resolve_credentials(environ)
    if security_token:
        auth = oss2.StsAuth(access_key_id, access_key_secret, security_token)
    else:
        auth = oss2.Auth(access_key_id, access_key_secret)

    return oss2.Bucket(
        auth,
        os.environ["OSS_ENDPOINT"],
        os.environ.get("OSS_BUCKET_PUBKEYS", "tng-finhack-pubkeys"),
    )


def _resolve_credentials(environ) -> tuple[str, str, str]:
    access_key_id = (
        os.environ.get("ALIBABA_CLOUD_ACCESS_KEY_ID")
        or os.environ.get("TABLESTORE_ACCESS_KEY_ID")
        or os.environ.get("OSS_ACCESS_KEY_ID")
        or os.environ.get("OTS_ACCESS_KEY_ID")
    )
    access_key_secret = (
        os.environ.get("ALIBABA_CLOUD_ACCESS_KEY_SECRET")
        or os.environ.get("TABLESTORE_ACCESS_KEY_SECRET")
        or os.environ.get("OSS_ACCESS_KEY_SECRET")
        or os.environ.get("OTS_ACCESS_KEY_SECRET")
    )
    security_token = (
        os.environ.get("ALIBABA_CLOUD_SECURITY_TOKEN")
        or os.environ.get("TABLESTORE_SESSION_TOKEN")
        or os.environ.get("ALIBABA_SECURITY_TOKEN", "")
    )

    if access_key_id and access_key_secret:
        return access_key_id, access_key_secret, security_token

    context = environ.get("fc.context") if isinstance(environ, dict) else None
    credentials = getattr(context, "credentials", None)
    if credentials:
        access_key_id = getattr(credentials, "access_key_id", "")
        access_key_secret = getattr(credentials, "access_key_secret", "")
        security_token = getattr(credentials, "security_token", "")
        if access_key_id and access_key_secret:
            return access_key_id, access_key_secret, security_token

    raise KeyError("Alibaba access credentials are not configured in env vars or fc.context")
