---
name: 15-alibaba-manual-deploy-runbook
description: Step-by-step Alibaba deploy checklist for the current repo, including AWS handoff inputs, code blockers, apply order, and smoke tests
owner: DevOps
status: active
depends-on: [06-alibaba-services, 12-build-tasks, 13-deployment, 14-aws-manual-deploy-runbook]
last-updated: 2026-04-26
---

# Alibaba Manual Deploy Runbook

This is the **practical next move** for Alibaba after the AWS side is applied.

The Alibaba path is **not** blocked by account access anymore. It is blocked by
repo alignment work:

1. the Terraform root is still aimed at `alibabacloudstack`,
2. the FC/API Gateway/EAS modules are still scaffold contracts,
3. the Python FC handlers and the Terraform contracts do not yet agree on env vars
   and table names.

This runbook turns that into an exact execution order.

## 1. Important scope check

What Alibaba gives you from this repo **today**:
- real Terraform resources for `oss` and `tablestore`,
- six Python FC handler entrypoints under `backend/fc/`,
- a root module that already expects the AWS bridge URL and Cognito JWKS URL.

What Alibaba does **not** give you yet:
- real Function Compute services/functions,
- real API Gateway route bindings,
- a real PAI-EAS deployment,
- RDS, EventBridge, KMS, push, or monitor modules in Terraform,
- a packaging step for FC Python code and dependencies,
- one clean runtime contract between Terraform, Tablestore, and the FC handlers.

So the next Alibaba phase is not "run apply and test." It is:

1. finish the deployable compute path,
2. wire it to the already-deployed AWS outputs,
3. then run the first live smoke test.

## 2. Inputs to collect from AWS first

Run the AWS checklist in [docs/14-aws-manual-deploy-runbook.md](14-aws-manual-deploy-runbook.md) first.

From `infra/aws`, capture:

```bash
terraform output -raw aws_bridge_invoke_url
terraform output -raw cognito_jwks_uri
```

You need these Alibaba-side values:

| AWS value | Alibaba runtime/input | Why |
|---|---|---|
| `aws_bridge_invoke_url` | `AWS_BRIDGE_URL` | `tokens-settle` forwards settlement batches to AWS |
| `cognito_jwks_uri` | `COGNITO_JWKS_URL` | FC JWT verification |
| `cognito_jwks_uri` minus `/.well-known/jwks.json` | `COGNITO_ISSUER` | `backend/lib/jwt_middleware.py` validates issuer, not just keys |
| shared bridge secret | `AWS_BRIDGE_HMAC_SECRET` | HMAC protection for B2/B3 cross-cloud calls |

After Alibaba deploys, you will feed one value back into AWS:

| Alibaba value | AWS input | Why |
|---|---|---|
| `https://<public-api>/v1/_internal/eb/aws-bridge` | `alibaba_ingest_url` | AWS bridge-out Lambda needs a live callback target |

That means the real cross-cloud order is:

1. deploy AWS first,
2. capture AWS outputs,
3. deploy Alibaba,
4. record the Alibaba ingest URL,
5. re-apply AWS with the real `alibaba_ingest_url`.

## 3. Code blockers to fix before the first Alibaba live apply

These are the concrete repo gaps from the current codebase inspection.

### 3.1 Provider and auth choice

The current Alibaba root uses:

```hcl
source = "aliyun/alibabacloudstack"
```

That is the wrong starting point for a normal public Alibaba Cloud rollout of FC,
API Gateway, and EAS. The public-cloud path should be moved onto the official
`aliyun/alicloud` provider before building real compute resources.

Also note: the current root expects `alibaba_access_key` and `alibaba_secret_key`
variables. Fixing the `aliyun` CLI profile does **not** automatically make Terraform
use that profile. Decide the Terraform auth path before the first real apply.

### 3.2 FC module is still contract-only

[`infra/alibaba/fc/main.tf`](/Users/mkfoo/Desktop/FinHack-Touch-Code/infra/alibaba/fc/main.tf:1)
currently only exposes route metadata and environment placeholders through
`terraform_data`.

It needs to become real Function Compute resources for the **six handlers that
already exist today**:

- `device-register`
- `wallet-balance`
- `tokens-settle`
- `score-refresh`
- `score-policy`
- `eb-cross-cloud-ingest`

The 11-function target design in [docs/06-alibaba-services.md](06-alibaba-services.md)
is still ahead of the code. For the first live slice, deploy the six real handlers
that already exist in `backend/fc/`.

### 3.3 API Gateway module is still contract-only

[`infra/alibaba/apigw/main.tf`](/Users/mkfoo/Desktop/FinHack-Touch-Code/infra/alibaba/apigw/main.tf:1)
currently returns a synthetic base URL only.

It needs to create real route bindings for:

- `POST /v1/devices/register`
- `GET /v1/wallet/balance`
- `POST /v1/tokens/settle`
- `POST /v1/score/refresh`
- `GET /v1/score/policy`
- `POST /v1/_internal/eb/aws-bridge`

### 3.4 EAS is optional for the first live slice

[`backend/fc/score_refresh/handler.py`](/Users/mkfoo/Desktop/FinHack-Touch-Code/backend/fc/score_refresh/handler.py:1)
already falls back cleanly when `EAS_ENDPOINT` is empty.

That means the fastest first Alibaba deploy is:

1. keep `score-refresh` live through the existing in-process fallback,
2. ship wallet + settlement first,
3. add real EAS only after the app-facing API is live.

EAS is important, but it is **not** the blocker for the first public `/v1/...` deploy.

### 3.5 Env var contract mismatch

The FC Terraform scaffold and the Python handlers do not currently agree on their
runtime env names.

| Concern | Python handler expects | Current Terraform scaffold emits |
|---|---|---|
| Tablestore instance | `TABLESTORE_INSTANCE` | `OTS_INSTANCE` |
| Pubkey bucket | `OSS_BUCKET_PUBKEYS` | `OSS_PUBKEY_BUCKET` |
| Cognito issuer | `COGNITO_ISSUER` | not set |
| Tablestore endpoint | `TABLESTORE_ENDPOINT` | not set |
| OTS credentials | `OTS_ACCESS_KEY_ID`, `OTS_ACCESS_KEY_SECRET` | not set |
| OSS credentials | `OSS_ACCESS_KEY_ID`, `OSS_ACCESS_KEY_SECRET` | not set |
| OSS endpoint | `OSS_ENDPOINT` | not set |
| EAS token/timeout | `EAS_TOKEN`, `EAS_TIMEOUT_SECONDS` | not set |

The safest fix is to make the FC deploy module set the exact env names the Python
handlers already read, rather than inventing a second contract.

### 3.6 Tablestore contract mismatch

The handlers currently hard-code tables such as:

- `devices`
- `wallets`
- `pending_batches`
- `score_policies`

But the Terraform module currently provisions:

- `tng-finhack_devices`
- `tng-finhack_wallets`
- `tng-finhack_pending_tokens_inbox`
- `tng-finhack_policy_versions`

and does **not** create `pending_batches` or `score_policies`.

Before the first live apply, pick one canonical contract and wire it end to end.

Recommended approach:

1. stop hard-coding table names in handlers,
2. inject them explicitly as env vars,
3. then either rename the Terraform tables or add the missing tables without touching
   handler code again.

### 3.7 FC packaging step is missing

There is no Alibaba equivalent yet to
[`infra/aws/lambda/build_package.sh`](/Users/mkfoo/Desktop/FinHack-Touch-Code/infra/aws/lambda/build_package.sh:1).

The Alibaba side still needs a repeatable package/build step that bundles:

- `backend/fc/`
- `backend/lib/`
- Python dependencies from [`backend/requirements.txt`](/Users/mkfoo/Desktop/FinHack-Touch-Code/backend/requirements.txt:1)

At minimum, the deployed artifact has to include:
- `requests`
- `tablestore`
- `oss2`
- `PyJWT`
- `cryptography`

## 4. Recommended implementation order

This is the concrete order that unblocks the fastest working Alibaba slice.

1. Switch the Terraform provider in `infra/alibaba` from `aliyun/alibabacloudstack`
   to the public-cloud `aliyun/alicloud` provider.
2. Decide the Terraform auth method. If you keep the current root shape, you still
   need local `alibaba_access_key` and `alibaba_secret_key` values.
3. Keep the scope to the six existing handlers in `backend/fc/` for the first live deploy.
4. Add an Alibaba FC build/package step for `backend/fc`, `backend/lib`, and
   `backend/requirements.txt`.
5. Replace `infra/alibaba/fc` with real Function Compute service/function resources.
6. Replace `infra/alibaba/apigw` with real public route bindings.
7. Align the handler env contract:
   - add `COGNITO_ISSUER`,
   - rename `OTS_INSTANCE` to `TABLESTORE_INSTANCE`,
   - rename `OSS_PUBKEY_BUCKET` to `OSS_BUCKET_PUBKEYS`,
   - provide the missing OTS/OSS endpoint and credential env vars.
8. Align the Tablestore contract:
   - externalize table names as env vars,
   - then rename/add the actual tables the handlers need.
9. Leave `EAS_ENDPOINT = ""` for the first live slice if needed so `score-refresh`
   still responds.
10. Apply Alibaba foundation and compute.
11. Record the real Alibaba ingest URL:

```text
https://<public_api_base_url>/v1/_internal/eb/aws-bridge
```

12. Re-apply AWS with that value as `alibaba_ingest_url`.
13. Run the cross-cloud smoke tests.

## 5. Local tfvars template for Alibaba

After the provider/auth decision is settled, the current root expects values like:

```hcl
alibaba_access_key   = "YOUR_ALIBABA_AK"
alibaba_secret_key   = "YOUR_ALIBABA_SK"
alibaba_region       = "ap-southeast-3"
environment          = "demo"
account_id           = "YOUR_ALIBABA_ACCOUNT_ID"

aws_cognito_jwks_uri = "https://cognito-idp.ap-southeast-1.amazonaws.com/<pool_id>/.well-known/jwks.json"
aws_account_id       = "YOUR_AWS_ACCOUNT_ID"

public_api_domain      = "api-finhack.example.com"
aws_bridge_url         = "https://<aws-bridge>"
aws_bridge_hmac_secret = "REPLACE_WITH_SHARED_SECRET"

eas_endpoint           = ""
```

Keep `terraform.tfvars` local and uncommitted.

## 6. First smoke-test target

The first real Alibaba success condition is **not** the full target architecture.
It is this smaller slice:

1. Cognito JWT validates in Alibaba FC.
2. `GET /v1/wallet/balance` returns from live Alibaba compute.
3. `GET /v1/score/policy` returns from live Alibaba compute.
4. `POST /v1/score/refresh` returns from live Alibaba compute, even if EAS is still disabled.
5. `POST /v1/tokens/settle` forwards to the live AWS bridge URL.
6. AWS can call back into `POST /v1/_internal/eb/aws-bridge`.

Use curls like:

```bash
curl -H "Authorization: Bearer <cognito_token>" \
  https://<public_api_base_url>/v1/wallet/balance
```

```bash
curl -H "Authorization: Bearer <cognito_token>" \
  https://<public_api_base_url>/v1/score/policy
```

```bash
curl -X POST \
  -H "Authorization: Bearer <cognito_token>" \
  -H "Content-Type: application/json" \
  https://<public_api_base_url>/v1/score/refresh \
  -d '{"user_id":"demo_user","features":{"tx_count_30d":10}}'
```

```bash
curl -X POST \
  -H "Authorization: Bearer <cognito_token>" \
  -H "Content-Type: application/json" \
  https://<public_api_base_url>/v1/tokens/settle \
  -d '{"device_id":"did:tng:device:demo","batch_id":"batch-live","tokens":["<JWS>"],"ack_signatures":[]}'
```

## 7. Alibaba done means

For this repo, the Alibaba side is only "done" when all of these are true:

- `infra/alibaba/fc` creates real FC resources, not `terraform_data`
- `infra/alibaba/apigw` creates real routes, not a synthetic base URL
- the handler env vars match the deployed runtime
- the Tablestore table contract is consistent between docs, Terraform, and handlers
- the public `/v1/...` routes answer with live compute
- AWS can call the Alibaba ingest route successfully
- the live settle path completes one AWS↔Alibaba round trip
