---
name: 12-build-tasks
description: Work breakdown by track, milestones, parallelizable agent tasks with explicit dependencies and DoD
owner: PM
status: ready
depends-on: [00-overview, 01-architecture, 03-token-protocol, 04-credit-score-ml, 05-aws-services, 06-alibaba-services, 07-mobile-app, 08-backend-api, 09-data-model, 10-security-threat-model, 13-deployment]
last-updated: 2026-04-26
---

# Build Tasks

This is the **single execution-order doc**. Downstream agents pick tasks by their
agent tag, follow the linked spec doc, satisfy the Definition-of-Done, and check off.

## 1. Tracks & agent tags

| Tag | Track |
|---|---|
| `agent:cloud-aws-*` | AWS infra & Lambdas |
| `agent:cloud-ali-*` | Alibaba infra & FC |
| `agent:ml-*` | ML pipeline |
| `agent:backend-*` | API contracts, settlement bridge logic |
| `agent:mobile-*` | Flutter app + Kotlin HCE |
| `agent:security-*` | Crypto verification + threat-model checks |
| `agent:demo-*` | Demo prep + deck + video |

## 2. Milestones

| Day | Theme | Outcome |
|---|---|---|
| **Day 1 (today)** | Scaffolding | Both clouds bootstrapped, mobile project compiles, synthetic data generated, training run on toy data. |
| **Day 2** | Vertical slice | A single offline payment flows: sign → NFC → settle → ledger entry. AI score panel shows a number. |
| **Day 3** | Polish + demo | All TS-01..TS-20 scenarios pass; demo recorded; deck written. |

## 3. Day 1 — scaffolding (parallel)

### `agent:cloud-aws-1` — AWS bootstrap
**Spec:** [docs/05-aws-services.md](05-aws-services.md), [docs/13-deployment.md](13-deployment.md)
**Tasks:**
1. Create AWS account / use shared sandbox; configure SSO.
2. Write `infra/aws/main.tf` with provider + tags.
3. Create S3 buckets (`tng-finhack-aws-data`, `models`, `logs`).
4. Create DynamoDB tables (`tng_token_ledger`, `tng_nonce_seen`, `tng_idempotency`,
   `tng_pubkey_cache`).
5. Create KMS CMK + alias.
6. Create Cognito user pool + app client; output JWKS URL.
7. Create EventBridge buses.
**DoD:** `terraform apply` clean, `aws dynamodb list-tables` returns 4 tables, JWKS URL
returns valid JWKS.

### `agent:cloud-ali-1` — Alibaba bootstrap
**Spec:** [docs/06-alibaba-services.md](06-alibaba-services.md), [docs/13-deployment.md](13-deployment.md)
**Tasks:**
1. Configure Alibaba account with KL region.
2. Write `infra/alibaba/main.ros` + provider.
3. Create OSS buckets (`tng-finhack-models`, `pubkeys`, `static`).
4. Create Tablestore instance + 6 tables.
5. Create RDS MySQL instance + run schema DDL from [docs/09-data-model.md §3](09-data-model.md).
6. Provision PAI-EAS service shell (no model yet).
7. Create API Gateway group + custom domain placeholder.
**DoD:** All resources created, `tng-finhack-ots` accessible, RDS reachable from FC role.

### `agent:ml-1` — Synthetic data + first training
**Spec:** [docs/04-credit-score-ml.md §6, §7](04-credit-score-ml.md)
**Blocked by:** `agent:cloud-aws-1` (S3 buckets).
**Tasks:**
1. Write `ml/synth/generate.py`.
2. Run with `--num-users 1000 --days 30` initially; iterate until distributions look right.
3. Run with `--num-users 10000 --days 90`; upload to `s3://.../synthetic/v1/`.
4. Write SageMaker training notebook `ml/train.ipynb` using built-in XGBoost.
5. Train v0 model, log metrics to CloudWatch.
6. Convert to TF Lite via `ml/convert_tflite.py`; size ≤ 2 MB.
**DoD:** Both parquets in S3, model registered, `model.tflite` in
`s3://.../models/credit/v1/`.

### `agent:mobile-1` — Flutter project scaffold
**Spec:** [docs/07-mobile-app.md](07-mobile-app.md)
**Tasks:**
1. `flutter create mobile/`, configure as in §2.
2. Add packages from §3.
3. Set up Riverpod, go_router, theme, splash, onboarding placeholder.
4. Wire MaterialApp with empty Home/Request/PayConfirm/Receive routes.
5. Generate Drift code, create empty schemas (Outbox, Inbox, BalanceCache).
6. Configure Android `minSdk=26`, NFC + biometric permissions, HCE service stub.
**DoD:** `flutter run` shows splash → onboarding → home; APK built; HCE service visible
in Android NFC settings.

### `agent:security-1` — JWS reference implementation
**Spec:** [docs/03-token-protocol.md](03-token-protocol.md)
**Tasks:**
1. Implement `core/crypto/jws_signer.dart` (signing) + verifier reference (Dart).
2. Implement Python verifier in `backend/lib/jws.py`.
3. Generate test vectors `ml/test-vectors/token-001.jws` and 5 negative variants
   (see [docs/03 §8](03-token-protocol.md)).
4. Cross-test: Dart-signed token verifies in Python and vice versa.
**DoD:** All 6 vectors pass/fail as documented; CI test in `backend/tests/test_jws.py`.

## 4. Day 2 — vertical slice (parallel)

### `agent:backend-1` — Wallet API
**Spec:** [docs/08-backend-api.md](08-backend-api.md)
**Blocked by:** `agent:cloud-ali-1`.
**Tasks:**
1. Write `backend/fc/wallet-balance/handler.py` reading Tablestore.
2. Write `backend/fc/device-register/handler.py` writing Tablestore + OSS pubkey.
3. Write `backend/fc/score-policy/handler.py` returning latest active policy.
4. Bind to API Gateway routes; deploy via `infra/alibaba/fc/`.
5. JWT verification middleware using Cognito JWKS.
**DoD:** Curl all 3 endpoints returns expected JSON with valid JWT.

### `agent:backend-2` — Settlement bridge
**Spec:** [docs/05-aws-services.md §4, §8](05-aws-services.md), [docs/06-alibaba-services.md §10](06-alibaba-services.md)
**Blocked by:** `agent:cloud-aws-1`, `agent:cloud-ali-1`, `agent:security-1`.
**Tasks:**
1. Write Lambda `settle-batch`.
2. Write Lambda `eb-cross-cloud-bridge-out` (HMAC-signed POST).
3. Write FC `eb-cross-cloud-ingest` to receive AWS events.
4. Write FC `tokens-settle` that emits the originating event.
5. End-to-end test: POST a single-token batch to FC; observe ledger entry on AWS;
   observe wallet balance update on Alibaba.
**DoD:** TS-02 passes manually with single token.

### `agent:ml-2` — PAI-EAS endpoint
**Spec:** [docs/04-credit-score-ml.md §9](04-credit-score-ml.md), [docs/06-alibaba-services.md §2](06-alibaba-services.md)
**Blocked by:** `agent:ml-1`, `agent:cloud-ali-1`.
**Tasks:**
1. Write `ml/eas/Dockerfile` + `app.py` (Flask + xgboost).
2. Push to ACR; deploy as PAI-EAS service.
3. Wire FC `score-refresh` to call EAS.
**DoD:** `POST /score/refresh` returns valid number for the synthetic test user.

### `agent:mobile-2` — Sign + NFC vertical slice
**Spec:** [docs/03-token-protocol.md](03-token-protocol.md), [docs/07-mobile-app.md §6, §7](07-mobile-app.md)
**Blocked by:** `agent:security-1`, `agent:mobile-1`.
**Tasks:**
1. Implement `SigningKeyManager.kt` and platform channel.
2. Implement `JwsSigner` in Dart.
3. Implement HCE service `TngHostApduService.kt` with `PUT-REQUEST` and `PUT-DATA` chunk reassembly.
4. Implement Request Payment screen for tap 1 and Request Pending countdown screen for the merchant.
5. Implement Pay Confirm screen that auto-opens on tap 1, signs after authorization, and drives tap 2.
6. Implement Receive inbox/receipt state for the merchant after tap 2.
7. Pair-test on two devices; show request delivery, outbox/inbox rows, and ack-signature capture.
**DoD:** Two phones complete the full two-tap flow successfully; Pay Confirm opens automatically after tap 1; outbox/inbox rows visible after tap 2.

### `agent:mobile-3` — TF Lite scorer + offline state
**Spec:** [docs/04-credit-score-ml.md §8](04-credit-score-ml.md), [docs/07-mobile-app.md §5](07-mobile-app.md)
**Blocked by:** `agent:ml-1`, `agent:mobile-1`.
**Tasks:**
1. Bundle `model.tflite` in assets.
2. Implement `CreditScorer` Dart wrapper.
3. Implement connectivity state machine.
4. Show safe offline balance on Home + AI Score Panel.
5. Pull-to-refresh balance from `/wallet/balance`.
**DoD:** Toggle airplane mode; UI flips state; score number updates from on-device run.

### `agent:cloud-aws-2` — Step Functions OTA pipeline
**Spec:** [docs/04-credit-score-ml.md §10](04-credit-score-ml.md), [docs/05-aws-services.md §9](05-aws-services.md)
**Blocked by:** `agent:cloud-aws-1`, `agent:ml-1`.
**Tasks:**
1. Lambda `model-publish-bridge` to copy artifact S3→OSS.
2. Lambda to bump policy version in Tablestore.
3. Lambda to trigger Mobile Push.
4. Wire as Step Functions state machine.
**DoD:** Trigger pipeline manually; new model file appears in OSS; policy bumps; push
notification arrives on test device.

## 5. Day 3 — polish, scenarios, demo (parallel)

### `agent:backend-3` — Remaining endpoints
**Spec:** [docs/08-backend-api.md](08-backend-api.md)
**Tasks:** Implement `dispute`, `merchants/onboard`, `publickeys/{kid}`, `wallet/sync`,
batch settlement (50 tokens), idempotency-key handling.
**DoD:** All endpoints from doc 08 callable; integration tests TS-04, TS-06, TS-14 pass.

### `agent:mobile-4` — UX polish
**Tasks:**
1. Onboarding KYC tier 1 stub flow.
2. History screen with pull-to-refresh.
3. Pending tokens list.
4. AI Score Panel with model version + features breakdown.
5. Settings: device info, key rotation, sign-out.
6. Localization stubs (en, ms).
**DoD:** Whole demo storyline executable on the device.

### `agent:ml-3` — Better model + OTA validation
**Tasks:**
1. Tune XGBoost (depth, n_estimators); achieve RMSE target.
2. Add monotonic constraints.
3. Calibrate; validate calibration on holdout.
4. Sigstore-sign the tflite; embed root in mobile.
5. Test OTA: poison the model file → verify mobile rejects (TS-13).
**DoD:** TS-12, TS-13 pass.

### `agent:security-2` — Negative testing
**Spec:** [docs/10-security-threat-model.md](10-security-threat-model.md)
**Tasks:**
1. Run all 6 JWS test vectors against deployed `tokens-settle`.
2. Replay attack: TS-04.
3. Tampered amount: TS-05.
4. Cross-cloud HMAC tampering: TS-16.
5. Document any deviations.
**DoD:** All TS-04, TS-05, TS-15, TS-16 pass.

### `agent:demo-1` — Pitch deck
**Spec:** [docs/00-overview.md](00-overview.md), [docs/11-demo-and-test-plan.md §1, §7](11-demo-and-test-plan.md)
**Tasks:** Slides per the deck mapping; export architecture image from doc 01.
**DoD:** 10-slide deck PDF in `deliverables/pitch.pdf`.

### `agent:demo-2` — Demo video
**Spec:** [docs/11-demo-and-test-plan.md §1](11-demo-and-test-plan.md)
**Blocked by:** all functional agents.
**Tasks:**
1. Record 4-min screen capture with the storyline.
2. Edit, add captions.
3. Upload to YouTube unlisted; capture link.
**DoD:** Public link in `deliverables/demo-video-link.txt`.

### `agent:demo-3` — Submission packaging
**Tasks:**
1. Fill the FINHACK submission form per [README.md §FINHACK deliverables](../README.md).
2. Confirm deployment URL.
3. Confirm GitHub repo public.
**DoD:** Submission complete.

## 6. Dependency graph (DAG)

```
                cloud-aws-1 ───┬── ml-1 ── ml-2 ── ml-3
                               │           │
                               │           └─ cloud-aws-2
                cloud-ali-1 ───┤
                               ├── backend-1
                               ├── backend-2 ─── (e2e settle)
                               └── backend-3
mobile-1 ── mobile-2 (uses security-1, security-1 standalone)
mobile-1 ── mobile-3 (uses ml-1)
mobile-1 ── mobile-4
security-1 standalone ── security-2 (uses backend-2)

demo-1 (after architecture stable)
demo-2 blocked by all functional
demo-3 last
```

## 7. Definition of "demo-ready"

All of:
- [ ] TS-01..TS-20 green (or documented exception with mitigation)
- [ ] Demo video uploaded
- [ ] Pitch deck PDF in `deliverables/`
- [ ] Public deployment URL responding
- [ ] GitHub repo public, `README.md` deliverables checklist all checked
- [ ] Both cloud dashboards show traffic during a dry run
