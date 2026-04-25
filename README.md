# Touch 'n Go Offline Wallet — FINHACK 2026

> Pay anywhere, even when the network can't.

A Touch 'n Go (TNG) e-wallet extension that lets users transact **offline** via NFC, with an
on-device AI model determining a "safe offline balance" and cryptographically signed
tokens that settle automatically when the device is back online.

**Track:** Financial Inclusion
**Hackathon:** TNG Digital FINHACK 2026
**Clouds:** AWS (training, settlement) + Alibaba Cloud (regional APIs, inference, storage)

---

## Why this matters

Speaker note from TNG: *"How do we involve those still using cash, who feel uncomfortable
going cashless?"* The answer is removing the connectivity precondition. Rural areas,
basements, transit, and event venues all break cashless flows today; this project
keeps the wallet usable in those moments — the wedge for inclusion.

## What we built

1. **Flutter Android app** with HCE-based NFC peer-to-peer transfer.
2. **Ed25519-signed transaction tokens** (JWS) that prove offline payments to the server.
3. **AI credit-score model** trained on AWS SageMaker, served on-device via TF Lite,
   with an Alibaba PAI-EAS endpoint for online refresh — outputs the user's safe
   offline balance.
4. **Multi-cloud backend**: AWS for ML + settlement ledger, Alibaba for APAC-resident
   wallet APIs, model distribution, and inference.

See **[docs/00-overview.md](docs/00-overview.md)** for the full pitch.

## Documentation index

| # | Doc | Purpose |
|---|-----|---------|
| 0 | [docs/00-overview.md](docs/00-overview.md) | Problem, value prop, scope, success metrics, criteria mapping |
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
| 11 | [docs/11-demo-and-test-plan.md](docs/11-demo-and-test-plan.md) | Demo storyline, test scenarios |
| 12 | [docs/12-build-tasks.md](docs/12-build-tasks.md) | Work breakdown, milestones, agent assignments |
| 13 | [docs/13-deployment.md](docs/13-deployment.md) | IaC, env vars, CI, public URL, rollback |

Source idea documents (read-only inputs):
- [Idea.md](Idea.md) — original brainstorm
- [HackathonInfo.md](HackathonInfo.md) — judging criteria & deliverables
- [SpeakerNotes.md](SpeakerNotes.md) — speaker guidance

## FINHACK submission deliverables checklist

- [ ] **Team Name** — *fill in submission portal*
- [ ] **Project Name** — *Touch 'n Go Offline Wallet (working title)*
- [ ] **Track** — Financial Inclusion
- [ ] **Implementation & Inspiration** — see [docs/00-overview.md](docs/00-overview.md)
- [ ] **Pitch Deck Link** — *to be added*
- [ ] **Demo Video Link** — *to be added; storyline in [docs/11-demo-and-test-plan.md](docs/11-demo-and-test-plan.md)*
- [ ] **Deployment Link** — *Alibaba API Gateway custom domain; see [docs/13-deployment.md](docs/13-deployment.md)*
- [ ] **GitHub Repo Link** — this repository

## Quickstart for downstream build agents

1. Read **[docs/12-build-tasks.md](docs/12-build-tasks.md)** — tells you what to build first.
2. Each task is tagged with the doc it depends on. Read the doc, then implement.
3. Tasks are tagged for parallel execution: `agent:mobile-*`, `agent:backend-*`,
   `agent:ml-*`, `agent:cloud-aws-*`, `agent:cloud-ali-*`.

## Repository layout (target)

```
.
├── README.md                 # this file
├── Idea.md                   # source brainstorm (read-only)
├── HackathonInfo.md          # judging criteria (read-only)
├── SpeakerNotes.md           # speaker hints (read-only)
├── docs/                     # build spec — start here
├── mobile/                   # Flutter Android app           (to be created)
├── backend/                  # Lambda + FC handlers          (to be created)
├── ml/                       # training notebook + scripts    (to be created)
├── infra/
│   ├── aws/                  # Terraform AWS                  (to be created)
│   └── alibaba/              # Terraform/ROS Alibaba          (to be created)
└── scripts/                  # synthetic data, helpers        (to be created)
```
