# CLAUDE.md - Touch 'n Go Offline Wallet (FINHACK 2026)

Read this before touching any code or infrastructure.

## What we're building

Offline NFC payments for Touch 'n Go e-wallet. Users transact peer-to-peer with no network via:

- Ed25519-signed JWS tokens exchanged over Android HCE NFC
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

| Doc | Covers |
|-----|--------|
| `docs/00-overview.md` | Problem, scope, success metrics |
| `docs/01-architecture.md` | System diagram, AWS/Alibaba boundary calls |
| `docs/02-user-flows.md` | User stories, screens, wireframes |
| `docs/03-token-protocol.md` | JWS schema, Ed25519, NFC APDU, anti-replay |
| `docs/04-credit-score-ml.md` | Features, model, training, OTA, inference |
| `docs/05-aws-services.md` | SageMaker, Lambda, DynamoDB, Cognito, KMS, EventBridge |
| `docs/06-alibaba-services.md` | PAI-EAS, OSS, FC, Tablestore, RDS, KMS, API Gateway |
| `docs/07-mobile-app.md` | Flutter layout, packages, HCE, key gen, Drift schema |
| `docs/08-backend-api.md` | REST contracts and JSON schemas |
| `docs/09-data-model.md` | All datastore schemas, key designs, residency rules |
| `docs/10-security-threat-model.md` | STRIDE table, key lifecycle, KYC tiers |
| `docs/11-demo-and-test-plan.md` | Demo storyline, TS-01..TS-20 test scenarios |
| `docs/12-build-tasks.md` | Task list with DoD and dependency DAG |
| `docs/13-deployment.md` | IaC layout, env vars, secrets, CI, rollback |

## Agent tags

| Tag | Track |
|-----|-------|
| `agent:cloud-aws-*` | AWS infra + Lambda |
| `agent:cloud-ali-*` | Alibaba infra + FC |
| `agent:ml-*` | ML pipeline |
| `agent:backend-*` | API + settlement bridge |
| `agent:mobile-*` | Flutter + Kotlin HCE |
| `agent:security-*` | Crypto verification |
| `agent:demo-*` | Pitch deck, video, submission |

Dependency graph: `docs/12-build-tasks.md §6`.

## Critical constants

```
NFC AID:         F0544E47504159   (7 bytes: "F0" + ASCII "TNGPAY")
JWS alg:         EdDSA
JWS typ:         tng-offline-tx+jws
JWS ver:         1
Token expiry:    iat + 72h
Max batch size:  50 tokens per POST /v1/tokens/settle
Android minSdk:  26 (HCE); Ed25519 requires API 33+
TF Lite cap:     2 MB
```

## Cloud regions

| Cloud | Region |
|-------|--------|
| AWS | `ap-southeast-1` Singapore |
| Alibaba | `ap-southeast-3` Kuala Lumpur (PAI-EAS falls back to `ap-southeast-1`) |

## Data ownership (one authoritative store per class)

| Data | Authoritative store |
|------|---------------------|
| Wallet balance | Alibaba Tablestore `wallets` |
| Token ledger | AWS DynamoDB `tng_token_ledger` |
| User PII | Alibaba RDS + Tablestore |
| Device public keys | Alibaba OSS + Tablestore `devices` |
| ML model origin | AWS S3 |
| ML model runtime | Alibaba OSS (EAS reads here only, never AWS) |

## Cross-cloud boundaries

- **B1** Model publish: Step Functions Lambda copies S3 -> Alibaba OSS. Once per release.
- **B2** Settlement request: Alibaba FC -> EventBridge webhook -> AWS Lambda.
- **B3** Settlement result: AWS Lambda POSTs result -> Alibaba EventBridge ingest.
- **B4** Auth: Alibaba FC fetches Cognito JWKS from AWS to verify JWTs.
- **B5** Analytics: AWS Lambda reads Alibaba RDS read-replica via FC proxy.

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
- Double-spend prevention is the DynamoDB conditional put on `nonce_seen`. No second path.
- mTLS + HMAC body signing on all cross-cloud bridge webhooks.
- OTA model: verify sigstore signature before swap. Reject on mismatch, keep old model.
- Cognito JWT required on every FC route.
- KYC tier caps enforced server-side only.

## KYC tiers

| Tier | Cap / token | Cap / 24h |
|------|-------------|-----------|
| 0 (phone OTP) | RM 20 | RM 50 |
| 1 (+ IC last 4) | RM 50 | RM 150 |
| 2 (+ eKYC) | RM 250 | RM 500 |

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

| Wrong | Right |
|-------|-------|
| EAS reads model from AWS S3 at inference | EAS reads from Alibaba OSS only |
| Storing Ed25519 key in flutter_secure_storage | Android Keystore via platform channel |
| Writing PII to DynamoDB or S3 | PII stays in Alibaba RDS + Tablestore KL only |
| Different AID value | AID is always `F0544E47504159` |
| Assuming Ed25519 Keystore on API < 33 | Fail-closed at onboarding with clear error |
| Trusting client-claimed KYC cap | Enforce caps server-side |

## Demo ready checklist

- [ ] TS-01 through TS-20 pass or documented with mitigation
- [ ] Offline NFC tap completes < 2s
- [ ] Settlement completes on reconnect with push notification
- [ ] Double-spend shows `NONCE_REUSED` in admin dashboard
- [ ] AI safe-balance updates after demo transactions
- [ ] Both cloud dashboards show live traffic
- [ ] Demo video uploaded
- [ ] Pitch deck at `deliverables/pitch.pdf`
- [ ] Deployment URL live
- [ ] GitHub repo public, README checklist complete
