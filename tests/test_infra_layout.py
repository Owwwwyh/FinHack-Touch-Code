from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def _read(rel_path: str) -> str:
    return (REPO_ROOT / rel_path).read_text(encoding="utf-8")


def test_aws_root_wires_required_demo_modules():
    text = _read("infra/aws/main.tf")

    for module_name in (
        "kms",
        "s3",
        "dynamodb",
        "cognito",
        "lambda",
        "eventbridge",
        "apigw",
        "secrets",
    ):
        assert f'module "{module_name}"' in text

    assert 'output "aws_bridge_invoke_url"' in text
    assert 'output "settle_batch_lambda_name"' in text


def test_aws_lambda_module_declares_bridge_functions_and_env_wiring():
    text = _read("infra/aws/lambda/main.tf")

    assert "eb_cross_cloud_bridge_in" in text
    assert "eb_cross_cloud_bridge_out" in text
    assert "settle_batch" in text

    for env_name in (
        "DYNAMO_LEDGER_TABLE",
        "DYNAMO_NONCE_TABLE",
        "DYNAMO_PUBKEY_CACHE",
        "AWS_CROSS_CLOUD_BUS",
        "ALIBABA_INGEST_URL",
        "AWS_BRIDGE_HMAC_SECRET",
    ):
        assert env_name in text


def test_alibaba_root_wires_required_public_demo_modules():
    text = _read("infra/alibaba/main.tf")

    for module_name in ("oss", "tablestore", "fc", "apigw", "eas"):
        assert f'module "{module_name}"' in text

    assert 'output "public_api_base_url"' in text
    assert 'output "score_refresh_endpoint"' in text


def test_alibaba_fc_module_contains_required_routes_and_env_matrix():
    text = _read("infra/alibaba/fc/main.tf")

    for route in (
        "/v1/devices/register",
        "/v1/wallet/balance",
        "/v1/tokens/settle",
        "/v1/score/refresh",
        "/v1/score/policy",
        "/v1/_internal/eb/aws-bridge",
    ):
        assert route in text

    for env_name in (
        "TABLESTORE_INSTANCE",
        "TABLESTORE_ENDPOINT",
        "OSS_BUCKET_PUBKEYS",
        "OSS_ENDPOINT",
        "OSS_MODEL_BUCKET",
        "EAS_ENDPOINT",
        "AWS_BRIDGE_URL",
        "AWS_BRIDGE_HMAC_SECRET",
        "COGNITO_JWKS_URL",
        "COGNITO_ISSUER",
        "TABLE_NAME_PENDING_BATCHES",
        "TABLE_NAME_SCORE_POLICIES",
    ):
        assert env_name in text

    assert "alicloud_fcv3_function" in text
    assert "alicloud_fcv3_trigger" in text


def test_alibaba_apigw_module_exposes_public_domain_contract():
    text = _read("infra/alibaba/apigw/main.tf")

    assert "backend_url" in text
    assert "public_api_base_url" in text
    assert "route_map" in text
