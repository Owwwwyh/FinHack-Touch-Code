---
name: 13-deployment
description: Local dev, IaC layout, env vars, secrets, CI, public URL, rollback
owner: DevOps
status: ready
depends-on: [05-aws-services, 06-alibaba-services]
last-updated: 2026-04-25
---

# Deployment

## 1. Environments

| Env | Purpose | URL |
|---|---|---|
| `local` | Developer laptops | `http://localhost:3000` (mock backend) |
| `demo` | Live hackathon demo | `https://api-finhack.example.com` |
| `staging` | (optional) pre-demo dry-run | same infra, separate Tablestore instance |

For the hackathon, only `local` and `demo` are required.

## 2. Local dev

`scripts/local-stack.sh` brings up:
- LocalStack for AWS-likes (DynamoDB, S3, EventBridge stubs).
- Tablestore + OSS local mocks aren't first-class → use the Alibaba SDK pointed at
  *real* dev resources but with a separate `tng-finhack-dev` Tablestore instance.
- A Python Flask shim that mimics the FC HTTP routes so mobile devs can iterate
  without deploying.

`docker-compose.yml`:
```yaml
version: "3.9"
services:
  localstack:
    image: localstack/localstack:3
    environment:
      SERVICES: dynamodb,s3,kms,events,lambda
    ports: ["4566:4566"]
  fc-shim:
    build: ./backend/fc-shim
    ports: ["3000:3000"]
    environment:
      AWS_ENDPOINT_URL: http://localstack:4566
      ALIBABA_OTS_ENDPOINT: ${ALIBABA_OTS_ENDPOINT}
      ALIBABA_OTS_INSTANCE: tng-finhack-dev
      COGNITO_JWKS_URL: ${COGNITO_JWKS_URL}
```

Mobile dev points to `http://10.0.2.2:3000/v1` on Android emulator.

## 3. IaC layout

```
infra/
├── aws/
│   ├── main.tf
│   ├── backend.tf            # remote state on S3 + DynamoDB lock
│   ├── s3/
│   ├── dynamodb/
│   ├── kms/
│   ├── cognito/
│   ├── eventbridge/
│   ├── lambda/
│   ├── stepfunctions/
│   ├── sagemaker/
│   ├── apigw/
│   └── secrets/
├── alibaba/
│   ├── main.ros
│   ├── backend.ros
│   ├── oss/
│   ├── tablestore/
│   ├── rds/
│   ├── fc/
│   ├── apigw/
│   ├── eas/
│   ├── kms/
│   ├── push/
│   ├── eb/
│   └── monitor/
└── migrations/
    └── 2026-04-25-init.sql
```

State management: AWS Terraform state in S3 + DynamoDB lock. Alibaba ROS uses ROS
state automatically; alternatively Alibaba Terraform provider with state in OSS.

## 4. Environment variable matrix

### Mobile app (`mobile/.env`)
| Var | local | demo |
|---|---|---|
| `API_BASE_URL` | `http://10.0.2.2:3000/v1` | `https://api-finhack.example.com/v1` |
| `COGNITO_DOMAIN` | (mock) | `tng-finhack.auth.ap-southeast-1.amazoncognito.com` |
| `COGNITO_CLIENT_ID` | (mock) | from Cognito output |
| `OSS_PUBKEY_BUCKET` | (n/a) | `tng-finhack-pubkeys` |

Loaded via `flutter_dotenv` at app start; baked into release APK from CI secrets for
demo build.

### AWS Lambdas (set in Terraform)
| Var | Notes |
|---|---|
| `DYNAMO_LEDGER_TABLE` | `tng_token_ledger` |
| `DYNAMO_NONCE_TABLE` | `tng_nonce_seen` |
| `DYNAMO_PUBKEY_CACHE` | `tng_pubkey_cache` |
| `EVENTBRIDGE_BUS` | `tng-cross-cloud` |
| `ALIBABA_INGEST_URL` | from Secrets Manager `tng-finhack/alibaba-ingest` |
| `ALIBABA_INGEST_HMAC_SECRET` | from Secrets Manager |
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

## 5. Secrets

| Secret | Stored in | Used by |
|---|---|---|
| Alibaba AK/SK for AWS-side cross-cloud bridge | AWS Secrets Manager | Lambda `eb-cross-cloud-bridge-out`, `model-publish-bridge` |
| HMAC secret (AWS↔Alibaba bridge) | AWS Secrets Manager + Alibaba KMS (mirrored) | Both bridges |
| AWS AK/SK for Alibaba EAS to read S3 model | Alibaba KMS | PAI-EAS init |
| RDS DSN | Alibaba KMS | FC functions |
| Cognito client secret | none (PKCE public client) | — |
| Sigstore signing key | Cosign keyless via OIDC | Step Functions Lambda |

Rotation cadence: secret-manager-managed, 30d default.

## 6. CI/CD (GitHub Actions sketch)

`.github/workflows/build-mobile.yml`
- On push to `main`: lint, test, build APK, upload as artifact.

`.github/workflows/backend.yml`
- On push to `backend/**`: lint, test, packaging.
- On `release/*` tag: deploy Lambdas + FC functions.

`.github/workflows/infra.yml`
- On push to `infra/**`: `terraform plan` posted as PR comment; manual approve →
  `terraform apply` on protected branch.

Demo build path:
```
git tag demo-v1
git push origin demo-v1
# → CI builds signed APK, deploys IaC, prints public URL
```

## 7. Public deployment URL

- Custom domain `api-finhack.example.com` on Alibaba API Gateway.
- ACM certificate (Alibaba SSL) auto-issued + bound.
- DNS: CNAME from your demo domain to API GW canonical hostname.

## 8. Rollback plan

| Failure | Rollback action |
|---|---|
| Bad Lambda deploy | `terraform plan -var image_tag=previous && apply` (Lambdas pinned by image tag in ECR) |
| Bad FC deploy | FC versioning: switch alias `live` to previous version |
| Bad model OTA | Pull policy back to previous via `Tablestore.policy_versions` flip; mobile picks up on next `GET /score/policy` |
| Bad migration | RDS: revert via `migrations/<date>-revert-<slug>.sql`; demo seeds reseeded from snapshot |
| Cross-cloud bridge HMAC mismatch | Re-deploy with rotated secret on both sides |

## 9. Demo-day playbook

Pre-demo (T−60min):
1. `terraform apply` both clouds — confirm clean.
2. Run `scripts/seed-demo-users.sh` — Faiz + Aida wallets seeded.
3. Run `scripts/warmup.sh` — pre-warms PAI-EAS + Lambda.
4. Open both dashboards.
5. Verify both Pixel devices have latest demo APK.
6. Verify NFC tap test passes per [docs/11 §5](11-demo-and-test-plan.md).

Post-demo cleanup:
- `terraform destroy` only after submission complete.

## 10. Cost ceilings

Set AWS Budget alert at $25, Alibaba spending limit at $30 for the hackathon window.
Alarms ping Slack webhook (stubbed). Hard cutover not enabled — don't risk taking the
demo offline mid-judging.

## 11. Logs & observability

| Source | Destination |
|---|---|
| FC functions | Alibaba SLS `tng-finhack-logs` |
| EAS endpoint | Alibaba SLS + EAS metric stream |
| Lambdas | CloudWatch Logs |
| API Gateway access logs | both clouds, separate log stores |
| Cross-cloud bridge | both sides log full payload (PII-scrubbed) |

Dashboards live and screenshotted in `deliverables/screenshots/` before each dry run.

## 12. Disaster recovery (post-MVP)

Out of scope for hackathon, but the data residency choices already enable an
RTO/RPO discussion: ledger PITR on DynamoDB → 5-min RPO; Tablestore continuous
backup → seconds-RPO; RDS daily snapshots → 24h RPO acceptable for analytics.
