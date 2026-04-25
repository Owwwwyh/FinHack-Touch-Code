---
name: 05-aws-services
description: AWS services used — SageMaker, S3, Lambda, DynamoDB, Cognito, KMS, EventBridge, CloudWatch — with IAM and Terraform sketches
owner: Cloud-AWS
status: ready
depends-on: [01-architecture, 04-credit-score-ml, 09-data-model]
last-updated: 2026-04-25
---

# AWS Services

Account region: **`ap-southeast-1` (Singapore)** for latency to APAC users; SageMaker
training in `ap-southeast-1` too. Multi-AZ for production; single-AZ acceptable for
demo.

Terraform module root: `infra/aws/`.

## 1. Service inventory

| Service | Purpose | Module path |
|---|---|---|
| SageMaker | ML training, model registry, processing jobs | `infra/aws/sagemaker/` |
| S3 | Synthetic data lake, model artifacts | `infra/aws/s3/` |
| Lambda | Settlement workers, fraud-score, OTA bridge | `infra/aws/lambda/` |
| DynamoDB | Token ledger, idempotency, nonce-seen, pubkey cache | `infra/aws/dynamodb/` |
| Cognito | Auth (JWT issuer) | `infra/aws/cognito/` |
| KMS | Envelope encryption, signing-key wrapping | `infra/aws/kms/` |
| EventBridge | Cross-cloud event bus + internal events | `infra/aws/eventbridge/` |
| Step Functions | Model release pipeline orchestration | `infra/aws/stepfunctions/` |
| CloudWatch | Logs + metrics + dashboards | `infra/aws/cloudwatch/` |
| Secrets Manager | Cross-cloud creds (Alibaba AK/SK) | `infra/aws/secrets/` |
| API Gateway (HTTP) | Optional: settlement HTTPS endpoint when bypassing event bus | `infra/aws/apigw/` |

## 2. SageMaker

### 2.1 Resources
- **Domain + UserProfile** for notebooks (`finhack-team`).
- **Training job:** built-in XGBoost container, instance `ml.m5.xlarge` for the demo
  (synthetic dataset is small).
- **Model package group:** `tng-credit-score`, with manual approval workflow.
- **Pipeline definition** in `ml/sagemaker_pipeline.json` for reproducibility.

### 2.2 Inputs / outputs
- Input: `s3://tng-finhack-aws/synthetic/v1/`
- Output: `s3://tng-finhack-aws/models/credit/v{n}/model.tar.gz`
- Metrics: emitted to CloudWatch namespace `TNG/Credit`.

### 2.3 Model handoff to Alibaba
- Models published in SageMaker registry are copied to Alibaba OSS by the
  `model-publish-bridge` Lambda (boundary B1). PAI-EAS reads from OSS only — there
  is no AWS-side IAM credential issued to EAS at runtime. See
  [docs/04-credit-score-ml.md §9](04-credit-score-ml.md), [docs/06-alibaba-services.md §2.4](06-alibaba-services.md).

## 3. S3

| Bucket | Purpose | Encryption | Public? |
|---|---|---|---|
| `tng-finhack-aws-data` | synth data lake (`synthetic/`, `feature-store/`) | SSE-KMS (aws/s3) | no |
| `tng-finhack-aws-models` | model artifacts (`models/credit/v{n}/`) | SSE-KMS (`tng-finhack-key`) | no |
| `tng-finhack-aws-logs` | settlement service logs | SSE-S3 | no |

Lifecycle: `synth/v0/` → glacier after 30d. `models/` retained.

## 4. Lambda

All Lambdas in `infra/aws/lambda/`. Runtime Python 3.12.

| Function | Trigger | Purpose | Concurrency |
|---|---|---|---|
| `settle-batch` | Alibaba EventBridge (via bridge proxy) | Verify + settle JWS tokens | reserved 50 |
| `fraud-score` | settle-batch invokes | Geo/velocity heuristics | reserved 20 |
| `pubkey-warmer` | scheduled (every 15m) | Pull new pubkeys from Alibaba OSS into Dynamo cache | reserved 1 |
| `model-publish-bridge` | Step Functions | Copy model.tflite from S3 to Alibaba OSS (boundary B1) | reserved 1 |
| `eb-cross-cloud-bridge-out` | EventBridge "settlement-result" rule | POST to Alibaba EventBridge ingest webhook | reserved 5 |
| `eb-cross-cloud-bridge-in` | API GW HTTPS POST from Alibaba | Translate Alibaba EB events → internal EB | reserved 10 |
| `dispute-recorder` | API GW | Records disputes (writes both Dynamo + RDS via VPN) | reserved 5 |

### 4.1 `settle-batch` core logic
```python
def handler(event, ctx):
    batch = event['detail']
    results = []
    for jws in batch['tokens']:
        v = verify_token(jws)               # docs/03 §7
        if not v.ok:
            results.append({'tx_id': v.tx_id, 'status': 'REJECTED', 'reason': v.reason})
            continue
        try:
            ddb.put_item(
                TableName='nonce_seen',
                Item={'nonce': {'S': v.payload['nonce']}, 'tx_id': {'S': v.payload['tx_id']}},
                ConditionExpression='attribute_not_exists(nonce)'
            )
        except ClientError as e:
            if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
                results.append({'tx_id': v.tx_id, 'status': 'REJECTED', 'reason': 'NONCE_REUSED'})
                continue
            raise
        ddb.put_item(TableName='token_ledger', Item=ledger_item(v))
        eb.put_events(Entries=[settlement_result_event(v)])
        results.append({'tx_id': v.tx_id, 'status': 'SETTLED'})
    return {'results': results}
```

## 5. DynamoDB

See [docs/09-data-model.md](09-data-model.md) for full schemas.

Tables:
- `tng_token_ledger` (PK `tx_id`, GSI on `kid+iat`)
- `tng_nonce_seen` (PK `nonce`)
- `tng_idempotency` (PK `key`, TTL 24h)
- `tng_pubkey_cache` (PK `kid`, TTL 7d, refilled by warmer)

All on-demand billing. Point-in-time recovery on `token_ledger`.

## 6. Cognito

- **User Pool:** `tng-finhack-users`, custom attributes `kyc_tier`, `home_region`.
- **App client:** `tng-mobile`, OAuth2 with PKCE, refresh-token sliding 30d.
- **Identity Pool:** federates JWT to optional temporary AWS creds (only used by
  internal admin tools, not the mobile app).
- JWKS URL: published; Alibaba FC consumes for token verify (boundary B4).
- KYC stub: pre-signup Lambda issues tier 1 by default; tier 2 requires later upgrade.

## 7. KMS

- `alias/tng-finhack-key`: CMK used for S3, DynamoDB, Secrets Manager.
- `alias/tng-finhack-jwt-signer`: optional, for service-to-service JWT we sign in Lambda.
- Key policy grants:
  - SageMaker training role: encrypt/decrypt for S3.
  - Lambda settle role: decrypt nonce_seen, encrypt outbound events.
  - No human IAM users by default.

## 8. EventBridge

- Default bus + custom bus `tng-cross-cloud`.
- Rules:
  - `model-published` → triggers Step Functions.
  - `settlement-result` → triggers `eb-cross-cloud-bridge-out`.
- Cross-cloud bridge: native EB-to-EB across clouds doesn't exist; we use:
  - **Outbound:** Lambda `eb-cross-cloud-bridge-out` POSTs JSON to Alibaba EventBridge
    HTTPS Webhook ingest endpoint, signed with Alibaba AK/SK from Secrets Manager.
  - **Inbound:** API GW HTTPS endpoint (mTLS optional) → Lambda
    `eb-cross-cloud-bridge-in` puts the event onto our EB.

## 9. Step Functions

State machine `tng-model-release`:
```
Start → ConvertToTFLite → SignArtifact → CopyToAlibabaOSS → BumpPolicyVersion
      → NotifyMobilePush → End
```
Each state is a Lambda; failures route to `OnFailure` which Slack-notifies (stubbed).

## 10. CloudWatch

- Log groups: one per Lambda, retention 14 days.
- Metrics namespace `TNG/Settlement`:
  - `SettledCount`, `RejectedCount` (with dimension `reason`).
  - `LatencyP95`.
- Dashboard `tng-finhack` shown during demo: graphs of settlement throughput, rejection
  reasons (highlighting the live double-spend rejection demo).
- Alarms: rejected-rate > 5% over 5 min → SNS topic (stubbed).

## 11. IAM least-privilege sketches

```hcl
# Lambda settle-batch role
data "aws_iam_policy_document" "settle" {
  statement {
    actions = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Query"]
    resources = [
      "arn:aws:dynamodb:ap-southeast-1:*:table/tng_token_ledger",
      "arn:aws:dynamodb:ap-southeast-1:*:table/tng_nonce_seen",
      "arn:aws:dynamodb:ap-southeast-1:*:table/tng_pubkey_cache",
    ]
  }
  statement {
    actions = ["events:PutEvents"]
    resources = ["arn:aws:events:ap-southeast-1:*:event-bus/tng-cross-cloud"]
  }
  statement {
    actions = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [aws_kms_key.tng.arn]
  }
}
```

## 12. Cost estimate (demo-scale)

| Service | Demo cost (USD, 3 days) |
|---|---|
| SageMaker training (a few runs) | ~3 |
| S3 storage + transfer | < 1 |
| Lambda invocations | < 1 |
| DynamoDB on-demand | < 1 |
| Cognito | free tier |
| EventBridge | < 1 |
| KMS | < 1 |
| **Total** | **~6** |

Production at 10k DAU: roughly $50–150/mo, dominated by Lambda + Dynamo writes.

## 13. Terraform module skeleton

```
infra/aws/
├── main.tf            # provider, common tags
├── s3/                # buckets
├── dynamodb/          # 4 tables
├── lambda/            # function defs + IAM roles
│   ├── settle-batch/
│   ├── fraud-score/
│   ├── pubkey-warmer/
│   └── model-publish-bridge/
├── sagemaker/         # domain, registry
├── stepfunctions/     # release pipeline
├── cognito/           # user pool + app client
├── kms/               # key + aliases
├── eventbridge/       # buses + rules
├── apigw/             # cross-cloud inbound
└── secrets/           # Alibaba AK/SK
```

## 14. Account access

- Single SSO admin account for the demo team.
- All resources tagged `Project=tng-finhack`, `Env=demo`.
- `terraform destroy` cleanly tears down (no manual cleanup expected).
