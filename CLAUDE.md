# CLAUDE.md - Touch 'n Go Offline Wallet (FINHACK 2026)

Read this before touching any code or infrastructure.

## What we're building

Offline NFC payments for Touch 'n Go e-wallet. Users transact peer-to-peer with no network via:

- Ed25519-signed JWS tokens exchanged over Android HCE NFC — **merchant-initiated two-tap flow**
- On-device TF Lite model computing a safe offline spending limit
- Multi-cloud settlement: Alibaba Cloud for wallet APIs + inference, AWS for ML + ledger

**Track:** Financial Inclusion. **Demo:** 4-min two-phone NFC tap, see `docs/11-demo-and-test-plan.md`.

## Repo layout

```
docs/          spec documents (read before implementing)
mobile/        Flutter Android app
backend/       Lambda + FC handlers
ml/            training scripts + EAS inference server
infra/aws/     Terraform
infra/alibaba/ ROS / Terraform
scripts/       helpers, seed scripts
```

## Docs index

| Doc                                | Covers                                                             |
| ---------------------------------- | ------------------------------------------------------------------ |
| `docs/00-overview.md`              | Problem, scope, success metrics                                    |
| `docs/01-architecture.md`          | System diagram, AWS/Alibaba boundary calls                         |
| `docs/02-user-flows.md`            | User stories, screens, wireframes — two-tap flow                   |
| `docs/03-token-protocol.md`        | JWS schema, payment request format, two-tap NFC APDU, anti-replay  |
| `docs/04-credit-score-ml.md`       | Features, model, training, OTA, inference                          |
| `docs/05-aws-services.md`          | SageMaker, Lambda, DynamoDB, Cognito, KMS, EventBridge             |
| `docs/06-alibaba-services.md`      | PAI-EAS, OSS, FC, Tablestore, RDS, KMS, API Gateway                |
| `docs/07-mobile-app.md`            | Flutter layout, packages, HCE two-tap roles, key gen, Drift schema |
| `docs/08-backend-api.md`           | REST contracts and JSON schemas                                    |
| `docs/09-data-model.md`            | All datastore schemas, key designs, residency rules                |
| `docs/10-security-threat-model.md` | STRIDE table, key lifecycle, KYC tiers                             |
| `docs/11-demo-and-test-plan.md`    | Demo storyline, TS-01..TS-21 test scenarios                        |
| `docs/12-build-tasks.md`           | Task list with DoD and dependency DAG                              |
| `docs/13-deployment.md`            | IaC layout, env vars, secrets, CI, rollback                        |

## Agent tags

| Tag                 | Track                         |
| ------------------- | ----------------------------- |
| `agent:cloud-aws-*` | AWS infra + Lambda            |
| `agent:cloud-ali-*` | Alibaba infra + FC            |
| `agent:ml-*`        | ML pipeline                   |
| `agent:backend-*`   | API + settlement bridge       |
| `agent:mobile-*`    | Flutter + Kotlin HCE          |
| `agent:security-*`  | Crypto verification           |
| `agent:demo-*`      | Pitch deck, video, submission |

Dependency graph: `docs/12-build-tasks.md §6`.

## Critical constants

```
NFC AID:               F0544E47504159   (7 bytes: "F0" + ASCII "TNGPAY")
JWS alg:               EdDSA
JWS typ:               tng-offline-tx+jws
JWS ver:               1
Token expiry:          iat + 72h
Payment request TTL:   300s (5 minutes) from issued_at
Max batch size:        50 tokens per POST /v1/tokens/settle
Android minSdk:        26 (HCE); Ed25519 requires API 33+
TF Lite cap:           2 MB
APDU PUT-REQUEST ins:  0x80 0xE0  (tap 1: merchant → payer)
APDU PUT-DATA ins:     0x80 0xD0  (tap 2: payer → merchant)
APDU GET-ACK ins:      0x80 0xC0  (tap 2: payer requests ack from merchant)
```

## Cloud regions

| Cloud   | Region                                                                 |
| ------- | ---------------------------------------------------------------------- |
| AWS     | `ap-southeast-1` Singapore                                             |
| Alibaba | `ap-southeast-3` Kuala Lumpur (PAI-EAS falls back to `ap-southeast-1`) |

## Data ownership (one authoritative store per class)

| Data               | Authoritative store                          |
| ------------------ | -------------------------------------------- |
| Wallet balance     | Alibaba Tablestore `wallets`                 |
| Token ledger       | AWS DynamoDB `tng_token_ledger`              |
| User PII           | Alibaba RDS + Tablestore                     |
| Device public keys | Alibaba OSS + Tablestore `devices`           |
| ML model origin    | AWS S3                                       |
| ML model runtime   | Alibaba OSS (EAS reads here only, never AWS) |

## Cross-cloud boundaries

- **B1** Model publish: Step Functions Lambda copies S3 -> Alibaba OSS. Once per release.
- **B2** Settlement request: Alibaba FC -> EventBridge webhook -> AWS Lambda.
- **B3** Settlement result: AWS Lambda POSTs result -> Alibaba EventBridge ingest.
- **B4** Auth: Alibaba FC fetches Cognito JWKS from AWS to verify JWTs.
- **B5** Analytics: AWS Lambda reads Alibaba RDS read-replica via FC proxy.

## NFC payment flow — two taps, merchant-initiated

```
TAP 1  Aida (reader) ──────────────────────────> Faiz (HCE)
       SELECT AID <- Faiz pub returned
       PUT-REQUEST (0xE0) chunks <- payment request JSON
                                    {request_id, receiver, amount, memo, expires_at}
       Faiz HCE fires EventChannel -> Flutter shows Pay Confirm screen automatically

       [Faiz reviews amount + memo, authorizes with biometric, JWS is signed]

TAP 2  Faiz (reader) ──────────────────────────> Aida (HCE)
       SELECT AID <- Aida pub returned (Faiz verifies matches tap-1 pub)
       PUT-DATA (0xD0) chunks <- signed JWS payment token
       GET-ACK (0xC0) <- Aida signs sha256(jws) with her key -> ack-signature
```

HCE service distinguishes tap 1 vs tap 2 by instruction byte (`0xE0` vs `0xD0`). Both phones
always run `TngHostApduService` — roles are determined by screen open, not device config.

Ack-signature is **audit-only** in v1 — settlement proceeds on JWS alone.

## Settlement flow

```
Mobile POST /v1/tokens/settle
  -> Alibaba FC validates + writes pending_batches
  -> Alibaba EventBridge (B2)
  -> AWS Lambda settle-batch
       -> verify Ed25519 (pubkey from DynamoDB cache)
       -> conditional put on nonce_seen  <-- double-spend guard, do not bypass
       -> write token_ledger
       -> emit settlement-result (B3)
  -> Alibaba FC updates Tablestore wallet + RDS history
  -> Mobile Push to receiver
```

## Security rules

- Ed25519 private key lives in Android Keystore only. Never in Dart or SharedPreferences.
- `setUserAuthenticationRequired(true)` on signing key. Biometric/PIN per sign (except amounts <= RM 5).
- Biometric fires between tap 1 and tap 2 — JWS is signed **after** biometric clears, before tap 2.
- Double-spend prevention is the DynamoDB conditional put on `nonce_seen`. No second path.
- Payment request expiry (`expires_at = issued_at + 300s`) is enforced client-side before tap 2.
- mTLS + HMAC body signing on all cross-cloud bridge webhooks.
- OTA model: verify sigstore signature before swap. Reject on mismatch, keep old model.
- Cognito JWT required on every FC route.
- KYC tier caps enforced server-side only.

## KYC tiers

| Tier            | Cap / token | Cap / 24h |
| --------------- | ----------- | --------- |
| 0 (phone OTP)   | RM 20       | RM 50     |
| 1 (+ IC last 4) | RM 50       | RM 150    |
| 2 (+ eKYC)      | RM 250      | RM 500    |

600 lifetime transactions rule is independent of KYC tier:

- `< 600 txns` -> manual pre-load wallet, no AI
- `>= 600 txns` -> AI dynamic safe balance

## ML quick reference

- Algorithm: XGBoost regressor -> TF Lite via Treelite
- Output: `safe_offline_balance` in [0, cached_balance]
- 20 features (f01-f20); only `f19` (last_sync_age_min) is live at inference time
- On-device clamp: `min(model_out, cached_balance, hard_cap_per_kyc_tier)`
- EAS container: `ml/eas/Dockerfile` reads from Alibaba OSS at warmup, never AWS

## API

Base URL (demo): `https://api-finhack.example.com/v1`
Base URL (local, Android emulator): `http://10.0.2.2:3000/v1`
Auth: `Authorization: Bearer <cognito_jwt>` on all routes except `_internal/eb/aws-bridge` (mTLS).

## Common mistakes

| Wrong                                         | Right                                                           |
| --------------------------------------------- | --------------------------------------------------------------- |
| EAS reads model from AWS S3 at inference      | EAS reads from Alibaba OSS only                                 |
| Storing Ed25519 key in flutter_secure_storage | Android Keystore via platform channel                           |
| Writing PII to DynamoDB or S3                 | PII stays in Alibaba RDS + Tablestore KL only                   |
| Different AID value                           | AID is always `F0544E47504159`                                  |
| Assuming Ed25519 Keystore on API < 33         | Fail-closed at onboarding with clear error                      |
| Trusting client-claimed KYC cap               | Enforce caps server-side                                        |
| Payer (Faiz) entering the amount              | Merchant (Aida) enters amount on Request Payment screen         |
| Signing JWS before biometric clears           | Sign JWS only after biometric approved, between tap 1 and tap 2 |
| Same APDU instruction for tap 1 and tap 2     | `0xE0` PUT-REQUEST for tap 1; `0xD0` PUT-DATA for tap 2         |
| Requiring ack-signature for settlement        | Ack-sig is audit-only; settlement succeeds on JWS alone         |

## Demo ready checklist

- [ ] TS-01 through TS-21 pass or documented with mitigation
- [ ] Tap 1 (request delivery) completes < 1.5s
- [ ] Tap 2 (JWS + ack) completes < 2s
- [ ] Pay Confirm screen appears automatically after tap 1 (no manual navigation)
- [ ] Settlement completes on reconnect with push notification
- [ ] Double-spend shows `NONCE_REUSED` in admin dashboard
- [ ] AI safe-balance updates after demo transactions
- [ ] Both cloud dashboards show live traffic
- [ ] Demo video uploaded
- [ ] Pitch deck at `deliverables/pitch.pdf`
- [ ] Deployment URL live
- [ ] GitHub repo public, README checklist complete
