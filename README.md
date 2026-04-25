# Touch 'n Go Offline Wallet — FINHACK 2026

> Pay anywhere, even when the network can't.

A Touch 'n Go (TNG) e-wallet extension that lets users transact **offline** via NFC,
with an on-device AI model determining a safe offline balance and cryptographically
signed tokens that settle automatically when the device is back online.

**Track:** Financial Inclusion
**Hackathon:** TNG Digital FINHACK 2026
**Clouds:** AWS (ledger, auth, training) + Alibaba Cloud (wallet APIs, storage, inference)

---

## Current Status

As of 2026-04-26, the repo has a working local vertical slice, but it is **not fully
done for live cloud deployment yet**.

- Working locally: Flutter app flow, Android NFC/keystore path, local backend settlement path.
- Verified locally: `flutter test`, `python3 -m pytest backend/tests tests`, `./gradlew app:compileDebugKotlin`.
- Real Terraform resources exist for AWS `s3`, `dynamodb`, `kms`, `cognito`, `eventbridge`, and `secrets`.
- Real Terraform resources exist for Alibaba `oss` and `tablestore`.
- Still missing for live deploy: AWS `lambda` + `apigw`, and Alibaba `fc` + `apigw` + `eas`, are still scaffold-only Terraform contract modules.

Docs `00`-`11` describe the target product and architecture. [docs/12-build-tasks.md](docs/12-build-tasks.md)
and [docs/13-deployment.md](docs/13-deployment.md) are the source of truth for what
still needs to ship.

## Why this matters

Cashless adoption still breaks in rural areas, basements, underground transit, and
packed event venues. This project removes the connectivity precondition so users can
still pay when the network is unreliable.

## What we're shipping

1. **Flutter Android app** with HCE-based NFC peer-to-peer transfer.
2. **Ed25519-signed transaction tokens** (JWS) that prove offline payments to the server.
3. **AI credit-score model** trained on AWS SageMaker, served on-device via TF Lite,
   with an Alibaba PAI-EAS endpoint for online refresh — outputs the user's safe
   offline balance.
4. **Multi-cloud backend**: AWS for ML + settlement ledger, Alibaba for APAC-resident
   wallet APIs, model distribution, and inference.

See [docs/00-overview.md](docs/00-overview.md) for the product overview and
[docs/13-deployment.md](docs/13-deployment.md) for the deploy reality.

## Documentation index

| # | Doc | Purpose |
|---|-----|---------|
| 0 | [docs/00-overview.md](docs/00-overview.md) | Problem, value prop, scope, success metrics |
| 1 | [docs/01-architecture.md](docs/01-architecture.md) | System diagram, multi-cloud split, data flows |
| 2 | [docs/02-user-flows.md](docs/02-user-flows.md) | User stories, screens, ASCII wireframes |
| 3 | [docs/03-token-protocol.md](docs/03-token-protocol.md) | JWS schema, Ed25519, NFC APDU, anti-replay |
| 4 | [docs/04-credit-score-ml.md](docs/04-credit-score-ml.md) | Features, model, training, OTA, inference |
| 5 | [docs/05-aws-services.md](docs/05-aws-services.md) | SageMaker, S3, DynamoDB, Lambda, Cognito, KMS, EventBridge |
| 6 | [docs/06-alibaba-services.md](docs/06-alibaba-services.md) | PAI-EAS, OSS, FC, Tablestore, RDS, KMS, Mobile Push |
| 7 | [docs/07-mobile-app.md](docs/07-mobile-app.md) | Flutter layout, packages, screens, HCE, key gen |
| 8 | [docs/08-backend-api.md](docs/08-backend-api.md) | REST contracts and JSON schemas |
| 9 | [docs/09-data-model.md](docs/09-data-model.md) | All datastore schemas and key designs |
| 10 | [docs/10-security-threat-model.md](docs/10-security-threat-model.md) | STRIDE, key lifecycle, KYC tiers |
| 11 | [docs/11-demo-and-test-plan.md](docs/11-demo-and-test-plan.md) | Device demo flow, manual NFC checklist, functional scenarios |
| 12 | [docs/12-build-tasks.md](docs/12-build-tasks.md) | Remaining engineering work to reach deployable state |
| 13 | [docs/13-deployment.md](docs/13-deployment.md) | Current deploy status, environment wiring, blockers, smoke tests |

Source idea documents (read-only inputs):
- [Idea.md](Idea.md) — original brainstorm
- [HackathonInfo.md](HackathonInfo.md) — judging criteria & deliverables
- [SpeakerNotes.md](SpeakerNotes.md) — speaker guidance

## Ship-First Checklist

- [x] Local Flutter offline request/pay/receive flow
- [x] Local backend settlement and replay-protection tests
- [x] Android compile path
- [x] Mobile settlement endpoint configurable via `--dart-define`
- [ ] Real AWS Lambda deploy + inbound bridge endpoint
- [ ] Real Alibaba FC/API Gateway/PAI-EAS deploy
- [ ] Live AWS↔Alibaba smoke test
- [ ] Two-device NFC dry run against deployed backend

## Quickstart for downstream build agents

1. Read [docs/12-build-tasks.md](docs/12-build-tasks.md) first.
2. Read [docs/13-deployment.md](docs/13-deployment.md) before touching cloud infra.
3. Run the local backend with `python3 backend/server.py`.
4. Verify the repo before changing behavior:

```bash
flutter test
python3 -m pytest backend/tests tests
(cd android && ./gradlew app:compileDebugKotlin)
```

5. Run the app against the local backend:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:3000/v1 \
  --dart-define=API_BEARER_TOKEN=demo-token \
  --dart-define=DEVICE_ID=did:tng:device:demo
```

## Repository layout

```
.
├── README.md
├── docs/
├── lib/                      # Flutter app
├── android/                  # Android NFC + keystore code
├── backend/                  # Local server, FC handlers, AWS Lambda handlers
├── ml/                       # training + synthetic data scripts
├── test/                     # Flutter tests
├── infra/
│   ├── aws/                  # Terraform for AWS
│   └── alibaba/              # Terraform for Alibaba
├── Idea.md
├── HackathonInfo.md
└── SpeakerNotes.md
```
