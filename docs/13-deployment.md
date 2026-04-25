---
name: 13-deployment
description: Current local run path, infra reality, deploy blockers, environment wiring, smoke tests
owner: DevOps
status: active
depends-on: [05-aws-services, 06-alibaba-services]
last-updated: 2026-04-26
---

# Deployment

## 1. Reality Check

This doc is the source of truth for **what can actually be deployed from this repo today**.

| Area | Current state | Notes |
|---|---|---|
| Flutter app | works locally | tested with `flutter test` |
| Android build | works locally | `./gradlew app:compileDebugKotlin` passes |
| Local backend | works locally | run `python3 backend/server.py` |
| AWS base infra | real Terraform resources | `s3`, `dynamodb`, `kms`, `cognito`, `eventbridge`, `secrets` |
| AWS compute | not deployable yet | `infra/aws/lambda` and `infra/aws/apigw` are scaffold-only `terraform_data` modules |
| Alibaba base infra | real Terraform resources | `oss`, `tablestore` |
| Alibaba compute | not deployable yet | `infra/alibaba/fc`, `infra/alibaba/apigw`, `infra/alibaba/eas` are scaffold-only `terraform_data` modules |
| Public demo URL | not live yet | no real compute-backed public deployment exists from this repo yet |

## 2. Environments

| Env | Purpose | URL |
|---|---|---|
| `local` | Developer laptops | `http://localhost:3000` |
| `demo` | Live hackathon demo | `https://api-finhack.example.com` once compute modules are real |

Only `local` is real today. `demo` is the target environment.

## 3. Local Dev

The current working local path is the Python server in [backend/server.py](/Users/mkfoo/Desktop/FinHack-Touch-Code/backend/server.py:1).

Start it with:

```bash
python3 backend/server.py
```

Run the Flutter app against that server with:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:3000/v1 \
  --dart-define=API_BEARER_TOKEN=demo-token \
  --dart-define=DEVICE_ID=did:tng:device:demo
```

The repo does **not** currently contain `scripts/local-stack.sh`, `docker-compose.yml`,
`scripts/seed-demo-users.sh`, or `scripts/warmup.sh`, so do not rely on those paths.

## 4. IaC Layout In The Repo

```
infra/
├── aws/
│   ├── main.tf
│   ├── s3/
│   ├── dynamodb/
│   ├── kms/
│   ├── cognito/
│   ├── eventbridge/
│   ├── lambda/
│   ├── apigw/
│   └── secrets/
├── alibaba/
│   ├── main.tf
│   ├── oss/
│   ├── tablestore/
│   ├── fc/
│   ├── apigw/
│   └── eas/
```

Status by module:

| Path | Status |
|---|---|
| `infra/aws/s3` | real resources |
| `infra/aws/dynamodb` | real resources |
| `infra/aws/kms` | real resources |
| `infra/aws/cognito` | real resources |
| `infra/aws/eventbridge` | real resources |
| `infra/aws/secrets` | real resources |
| `infra/aws/lambda` | scaffold-only contract |
| `infra/aws/apigw` | scaffold-only contract |
| `infra/alibaba/oss` | real resources |
| `infra/alibaba/tablestore` | real resources |
| `infra/alibaba/fc` | scaffold-only contract |
| `infra/alibaba/apigw` | scaffold-only contract |
| `infra/alibaba/eas` | scaffold-only contract |

## 5. Critical Blockers To A Real Deploy

1. [infra/aws/lambda/main.tf](/Users/mkfoo/Desktop/FinHack-Touch-Code/infra/aws/lambda/main.tf:1) only outputs names and env contracts. It does not create `aws_lambda_function`, IAM roles, or packaged artifacts.
2. [infra/aws/apigw/main.tf](/Users/mkfoo/Desktop/FinHack-Touch-Code/infra/aws/apigw/main.tf:1) only outputs a route contract. It does not create an AWS HTTP API.
3. [infra/alibaba/fc/main.tf](/Users/mkfoo/Desktop/FinHack-Touch-Code/infra/alibaba/fc/main.tf:1) only defines route and environment contracts. It does not create Function Compute services or functions.
4. [infra/alibaba/apigw/main.tf](/Users/mkfoo/Desktop/FinHack-Touch-Code/infra/alibaba/apigw/main.tf:1) only defines a public domain contract. It does not create real API Gateway routes.
5. [infra/alibaba/eas/main.tf](/Users/mkfoo/Desktop/FinHack-Touch-Code/infra/alibaba/eas/main.tf:1) only defines an endpoint contract. It does not create a PAI-EAS deployment.
6. The mobile app used to hardcode the local backend URL. It now reads build-time values via `--dart-define`, which still needs to be wired into the release workflow.

## 6. Environment Wiring

### Flutter build flags

| Var | local | demo |
|---|---|---|
| `API_BASE_URL` | `http://10.0.2.2:3000/v1` | `https://api-finhack.example.com/v1` |
| `API_BEARER_TOKEN` | `demo-token` | real Cognito access token or a demo token accepted by the deployed API |
| `DEVICE_ID` | `did:tng:device:demo` | real device id from registration |

### AWS Lambdas (set in Terraform)
| Var | Notes |
|---|---|
| `DYNAMO_LEDGER_TABLE` | `tng_token_ledger` |
| `DYNAMO_NONCE_TABLE` | `tng_nonce_seen` |
| `DYNAMO_PUBKEY_CACHE` | `tng_pubkey_cache` |
| `AWS_CROSS_CLOUD_BUS` | `tng-cross-cloud` |
| `ALIBABA_INGEST_URL` | from Secrets Manager `tng-finhack/alibaba-ingest` |
| `AWS_BRIDGE_HMAC_SECRET` | from Secrets Manager |
| `MODEL_BUCKET` | `tng-finhack-aws-models` |
| `LOG_LEVEL` | `INFO` |

### Alibaba FC functions (set in ROS)
| Var | Notes |
|---|---|
| `OTS_INSTANCE` | `tng-finhack` |
| `OSS_PUBKEY_BUCKET` | `tng-finhack-pubkeys` |
| `OSS_MODEL_BUCKET` | `tng-finhack-models` |
| `RDS_DSN` | from Alibaba KMS `tng-finhack/rds-dsn` |
| `EAS_ENDPOINT` | from KMS `tng-finhack/eas-endpoint` |
| `AWS_BRIDGE_URL` | from KMS `tng-finhack/aws-bridge-url` |
| `AWS_BRIDGE_HMAC_SECRET` | from KMS |
| `COGNITO_JWKS_URL` | from KMS |

These variables are correct for the runtime handlers, but the compute modules that
should apply them are still scaffold-only.

## 7. Secrets

| Secret | Stored in | Used by |
|---|---|---|
| Alibaba AK/SK for AWS-side cross-cloud bridge | AWS Secrets Manager | Lambda `eb-cross-cloud-bridge-out`, `model-publish-bridge` |
| HMAC secret (AWS↔Alibaba bridge) | AWS Secrets Manager + Alibaba KMS (mirrored) | Both bridges |
| AWS AK/SK for Alibaba EAS to read S3 model | Alibaba KMS | PAI-EAS init |
| RDS DSN | Alibaba KMS | FC functions |
| Cognito client secret | none (PKCE public client) | — |
| Sigstore signing key | Cosign keyless via OIDC | Step Functions Lambda |

## 8. Suggested Apply Order

1. Apply AWS foundation modules that are already real.
2. Apply Alibaba foundation modules that are already real.
3. Replace the scaffold compute modules with real deploy resources.
4. Apply AWS compute.
5. Apply Alibaba compute.
6. Seed two demo users, devices, and balances.
7. Run the smoke tests below.

## 9. Smoke Tests

| Source | Destination |
|---|---|
| Local wallet read | `curl -H 'Authorization: Bearer demo' http://localhost:3000/v1/wallet/balance` |
| Local score refresh | `curl -X POST -H 'Content-Type: application/json' -H 'Authorization: Bearer demo' http://localhost:3000/v1/score/refresh -d '{"user_id":"demo_user","features":{"tx_count_30d":10}}'` |
| Local settlement | `curl -X POST -H 'Content-Type: application/json' -H 'Authorization: Bearer demo' http://localhost:3000/v1/tokens/settle -d '{"device_id":"did:tng:device:demo","batch_id":"batch-local","tokens":["<JWS>"],"ack_signatures":[]}'` |
| Deployed wallet read | same route against the live base URL with a real token |
| Deployed score refresh | same route against the live base URL with a real token |
| Deployed settlement | same route against the live base URL with a real token and a real JWS |

## 10. Deployment Done Means

- AWS Lambda and AWS API Gateway are real resources, not `terraform_data` outputs.
- Alibaba FC, API Gateway, and EAS are real resources, not `terraform_data` outputs.
- The Flutter build can target the deployed base URL without editing source.
- One phone can reconnect and settle an offline payment through the live cloud path.
- Replay is rejected in the deployed environment.
