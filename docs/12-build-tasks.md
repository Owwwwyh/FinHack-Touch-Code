---
name: 12-build-tasks
description: Current execution plan for shipping a working Flutter demo and real AWS + Alibaba deployment
owner: PM
status: active
depends-on: [00-overview, 01-architecture, 03-token-protocol, 04-credit-score-ml, 05-aws-services, 06-alibaba-services, 07-mobile-app, 08-backend-api, 09-data-model, 10-security-threat-model, 13-deployment]
last-updated: 2026-04-26
---

# Build Tasks

This is the **current execution-order doc**. A task is only done when the code runs
locally or on real cloud resources, not when a spec or Terraform contract exists.

## 1. Current status snapshot

| Area | Status | Notes |
|---|---|---|
| Flutter app | `working locally` | `flutter test` passes; request/pay/receive flow is implemented |
| Android path | `working locally` | `./gradlew app:compileDebugKotlin` passes |
| Local backend | `working locally` | `python3 -m pytest backend/tests tests` passes; `backend/server.py` serves the local `/v1` API |
| AWS foundation | `partially deployable` | `s3`, `dynamodb`, `kms`, `cognito`, `eventbridge`, `secrets` are real Terraform resources |
| AWS compute deploy | `blocked` | `infra/aws/lambda` and `infra/aws/apigw` are scaffold-only `terraform_data` contracts |
| Alibaba foundation | `partially deployable` | `oss` and `tablestore` are real Terraform resources |
| Alibaba compute deploy | `blocked` | `infra/alibaba/fc`, `infra/alibaba/apigw`, and `infra/alibaba/eas` are scaffold-only `terraform_data` contracts |
| Live cross-cloud smoke test | `not done` | requires real compute resources on both clouds |

## 2. Tracks & agent tags

| Tag | Track |
|---|---|
| `agent:cloud-aws-*` | AWS infra and compute deployment |
| `agent:cloud-ali-*` | Alibaba infra and compute deployment |
| `agent:backend-*` | Runtime handlers, packaging, smoke tests |
| `agent:mobile-*` | Flutter app, Android NFC, device-ready build config |
| `agent:ml-*` | Model training and online refresh path |
| `agent:security-*` | Crypto verification, replay tests, HMAC checks |
| `agent:deploy-*` | Environment wiring, seed data, end-to-end dry run |

## 3. Milestones

| Phase | Outcome | Status |
|---|---|---|
| **Phase 1** | Local vertical slice works end-to-end on developer machines | mostly done |
| **Phase 2** | Real multi-cloud compute deploy exists in AWS and Alibaba | not done |
| **Phase 3** | Two-device dry run succeeds against live cloud endpoints | not done |

## 4. Immediate priorities

1. Replace scaffold-only compute modules with real cloud resources.
2. Keep the mobile app configurable so one build can target local or deployed backends.
3. Wire the existing Python handlers into real AWS Lambda and Alibaba FC deploys.
4. Seed demo users and run live smoke tests through both clouds.
5. Only after that, spend time on polish.

## 5. Remaining execution tasks

### `agent:cloud-aws-1` — Finish deployable AWS compute
**Spec:** [docs/05-aws-services.md](05-aws-services.md), [docs/13-deployment.md](13-deployment.md)
**Current blocker:** `infra/aws/lambda/main.tf` and `infra/aws/apigw/main.tf` only publish `terraform_data` contracts today.
**Tasks:**
1. Replace the scaffold Lambda contract with real `aws_lambda_function`, IAM role/policy, and log group resources.
2. Package `backend/aws_lambda/settle_batch`, `backend/aws_lambda/eb_cross_cloud_bridge_in`, and `backend/aws_lambda/eb_cross_cloud_bridge_out`.
3. Replace the scaffold API Gateway contract with a real AWS HTTP API for inbound Alibaba bridge traffic.
4. Output the real invoke URL and wire it back into Alibaba config.
5. Apply and smoke-test the inbound bridge endpoint.
**DoD:** `terraform apply` creates real Lambda functions and a callable AWS bridge URL.

### `agent:cloud-ali-1` — Finish deployable Alibaba compute
**Spec:** [docs/06-alibaba-services.md](06-alibaba-services.md), [docs/13-deployment.md](13-deployment.md)
**Current blocker:** `infra/alibaba/fc/main.tf`, `infra/alibaba/apigw/main.tf`, and `infra/alibaba/eas/main.tf` only publish `terraform_data` contracts today.
**Tasks:**
1. Replace the scaffold FC module with real Function Compute service/function resources.
2. Replace the scaffold API Gateway module with real public route bindings.
3. Replace the scaffold EAS module with a real score-refresh deployment, or document and wire a temporary fallback if EAS is unavailable.
4. Output the real public API base URL.
5. Apply and curl `/v1/wallet/balance`, `/v1/score/policy`, `/v1/score/refresh`, and `/v1/tokens/settle`.
**DoD:** Alibaba exposes real public routes backed by deployed compute.

### `agent:backend-1` — Harden runtime handlers for cloud deploy
**Spec:** [docs/08-backend-api.md](08-backend-api.md), [docs/13-deployment.md](13-deployment.md)
**Tasks:**
1. Keep local demo-state fallbacks, but make sure every handler reads real cloud env vars when present.
2. Add packaging metadata or helper scripts needed for Lambda/FC deployments.
3. Add smoke tests for deployed `/v1/wallet/balance`, `/v1/score/refresh`, and `/v1/tokens/settle`.
4. Verify settlement batch results stay compatible between local and deployed modes.
**DoD:** The same handlers run locally and in cloud with only environment differences.

### `agent:mobile-1` — Make the device build deployment-ready
**Spec:** [docs/07-mobile-app.md](07-mobile-app.md), [docs/11-demo-and-test-plan.md](11-demo-and-test-plan.md)
**Tasks:**
1. Keep backend config externalized through `--dart-define` so the app can point at local or deployed backends.
2. Verify the request/pay/receive flow on two Android devices.
3. Verify settlement flushes correctly against the deployed `/v1/tokens/settle` endpoint.
4. Produce the APK used for the dry run.
**DoD:** The same app code works against local and live backend URLs without source edits.

### `agent:ml-1` — Publish a real refresh-score path
**Spec:** [docs/04-credit-score-ml.md](04-credit-score-ml.md), [docs/06-alibaba-services.md](06-alibaba-services.md)
**Tasks:**
1. Finish the model artifact export path from `ml/train.py`.
2. Package the model for Alibaba EAS.
3. Verify `/v1/score/refresh` returns a live value in deployed mode.
4. Keep on-device fallback working when the cloud scorer times out.
**DoD:** Online score refresh works in cloud; offline fallback still works on-device.

### `agent:deploy-1` — Environment wiring and seed data
**Spec:** [docs/13-deployment.md](13-deployment.md)
**Tasks:**
1. Create `.tfvars` or equivalent secret inputs for both clouds.
2. Apply AWS foundation first, then Alibaba foundation, then compute layers.
3. Seed at least two demo users and their wallet/device rows.
4. Record the exact deployed API base URL, JWKS URL, and bridge endpoints.
**DoD:** Fresh engineers can reproduce the demo environment from documented inputs.

### `agent:security-1` — Negative tests against deployed infra
**Spec:** [docs/10-security-threat-model.md](10-security-threat-model.md)
**Tasks:**
1. Replay attack against deployed settlement path.
2. Tampered JWS against deployed settlement path.
3. Cross-cloud HMAC tamper against deployed bridge.
4. Verify the rejected reasons match the local tests.
**DoD:** TS-04, TS-05, and TS-17 pass against live infrastructure.

## 6. Definition of workable

All of:
- [x] `flutter test` green
- [x] `python3 -m pytest backend/tests tests` green
- [x] `./gradlew app:compileDebugKotlin` green
- [ ] AWS scaffold modules replaced by real deploy resources
- [ ] Alibaba scaffold modules replaced by real deploy resources
- [ ] Public deployed endpoint responds to wallet/score/settle routes
- [ ] AWS ledger records a real settlement and rejects replay
- [ ] Two phones complete the offline two-tap flow and settle through the live cloud path
- [ ] [docs/13-deployment.md](13-deployment.md) reflects the actual deployed values
