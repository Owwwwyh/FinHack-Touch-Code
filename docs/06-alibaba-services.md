---
name: 06-alibaba-services
description: Alibaba Cloud services — PAI-EAS, OSS, Function Compute, Tablestore, ApsaraDB RDS, KMS, Mobile Push, API Gateway, EventBridge — with RAM and ROS sketches
owner: Cloud-Ali
status: ready
depends-on: [01-architecture, 04-credit-score-ml, 09-data-model]
last-updated: 2026-04-25
---

# Alibaba Cloud Services

Account region: **`ap-southeast-3` (Kuala Lumpur)** — closest to TNG's user base. KL
region is GA for FC, OSS, Tablestore, KMS, RDS. PAI-EAS deployed in `ap-southeast-1`
(Singapore) if KL availability changes.

ROS / Terraform module root: `infra/alibaba/`.

## 1. Service inventory

| Service | Purpose | Module path |
|---|---|---|
| PAI-EAS | Online refresh-score endpoint | `infra/alibaba/eas/` |
| OSS | Model artifact bucket, pubkey directory, app static | `infra/alibaba/oss/` |
| Function Compute | Wallet API + ingress for cross-cloud events | `infra/alibaba/fc/` |
| API Gateway | Public HTTPS endpoint | `infra/alibaba/apigw/` |
| Tablestore | User / device / wallet / cache state | `infra/alibaba/tablestore/` |
| ApsaraDB RDS (MySQL) | Settled-history OLTP, KYC, merchants | `infra/alibaba/rds/` |
| KMS | Per-device cert issuance, envelope keys | `infra/alibaba/kms/` |
| Mobile Push (EMAS) | Push notifications | `infra/alibaba/push/` |
| EventBridge | Cross-cloud event ingress | `infra/alibaba/eb/` |
| CloudMonitor | Metrics + dashboards | `infra/alibaba/monitor/` |
| Log Service (SLS) | FC + EAS logs | `infra/alibaba/sls/` |

## 2. PAI-EAS — refresh-score endpoint

### 2.1 Setup
- **Service name:** `tng-credit-score-refresh`
- **Resource group:** dedicated, autoscaled 1–4 instances of `ecs.gn5-c8g1.2xlarge`
  (CPU enough — model is XGBoost, no GPU needed; smaller `ecs.c6.large` actually fine).
- **Container image:** built from `ml/eas/Dockerfile`, pushed to Alibaba Container
  Registry (ACR).
- **Model storage:** Alibaba OSS path `oss://tng-finhack-models/credit/v{n}/model.pkl`
  is the **sole runtime source**. Container fetches at warmup; AWS S3 is publish-time
  origin only (not read by EAS at inference). See [docs/04-credit-score-ml.md §9](04-credit-score-ml.md).
- **Endpoint authentication:** EAS token-based; FC stores token in KMS-wrapped form.

### 2.2 Request shape
See [docs/04-credit-score-ml.md §9](04-credit-score-ml.md). Request fields validated;
responses are deterministic given inputs.

### 2.3 Cold start hedge
- Mobile timeout 800ms; on timeout, fall back to on-device TF Lite estimate.
- EAS warm-up cron via FC every 4 minutes during the hackathon demo window.

### 2.4 Model source (single authoritative path)
EAS reads models exclusively from **Alibaba OSS**. Cross-cloud transfer happens
at *publish* time via boundary call B1 (AWS S3 → OSS) in the Step Functions
release pipeline. There is no runtime cross-cloud fetch from EAS — this avoids
warm-up latency variance and a second cross-cloud credential surface.

## 3. OSS

| Bucket | Purpose | Region |
|---|---|---|
| `tng-finhack-models` | TF Lite model artifacts (`credit/v{n}/`), signing manifests | KL |
| `tng-finhack-pubkeys` | Device public-key directory (`{kid}.pem`) | KL |
| `tng-finhack-static` | App config, splash assets, Terms, Privacy | KL |

ACL: private. Mobile reads via signed URLs issued by FC `GET /score/policy` and
`GET /publickeys/{kid}`. Lifecycle: model versions older than 60d move to IA storage.

## 4. Function Compute

Runtime Node.js 20 (or Python 3.11) — pick one and stay consistent.
Service: `tng-wallet-api`. Functions wired to API Gateway.

| Function | Route | Purpose |
|---|---|---|
| `device-register` | `POST /devices/register` | Register device pub + attestation |
| `device-attest` | `POST /devices/attest` | Refresh attestation |
| `wallet-balance` | `GET /wallet/balance` | Read Tablestore wallet |
| `wallet-sync` | `POST /wallet/sync` | Apply pending top-ups + return latest |
| `tokens-settle` | `POST /tokens/settle` | Validate batch, emit cross-cloud event |
| `tokens-dispute` | `POST /tokens/dispute` | Create dispute record |
| `score-refresh` | `POST /score/refresh` | Proxy to PAI-EAS |
| `score-policy` | `GET /score/policy` | Return current policy + signed model URL |
| `publickeys-get` | `GET /publickeys/{kid}` | Sign URL to OSS pubkey |
| `merchants-onboard` | `POST /merchants/onboard` | Stub |
| `eb-cross-cloud-ingest` | webhook (HTTPS) | Receive AWS settlement-result events |

All functions require Cognito-issued JWT (boundary B4: JWKS fetched from AWS).

### 4.1 Concurrency / instance limits
- `tokens-settle` reserved 10 concurrency for the demo.
- Others 5 concurrency.

### 4.2 Settlement event emission
`tokens-settle` writes a Tablestore "pending_batches" row, then emits an Alibaba
EventBridge event. A separate FC handler relays it to AWS via the cross-cloud webhook
(boundary B2).

## 5. API Gateway

- **Group:** `tng-finhack-public`.
- **Custom domain:** `api-finhack.example.com` (used as deployment URL).
- **Throttling:** 100 rps per API key.
- **Auth plugin:** JWT verifier with Cognito's JWKS, custom claim mapping
  (`sub` → `user_id`, `cognito:groups` → roles).
- **CORS:** allow `tngfinhack://` deeplink + `https://*.example.com`.

## 6. Tablestore

See [docs/09-data-model.md](09-data-model.md). Tables:

| Table | PK | Purpose |
|---|---|---|
| `users` | `user_id` | Profile + KYC |
| `devices` | `device_id` (kid) | Pubkey, attestation, status |
| `wallets` | `user_id` | Balance, version, currency |
| `offline_balance_cache` | `user_id+kid` | Cached estimates |
| `pending_tokens_inbox` | `user_id+ts` | Optimistic inbox view |
| `policy_versions` | `policy_id` | Active model versions |

CapacityUnits: reserved capacity 200 R/W for demo; autoscale otherwise.

## 7. ApsaraDB RDS (MySQL 8.0)

- **Instance class:** `mysql.n2.medium.2c` (demo size).
- **Database:** `tng_history`.
- **Tables:** `settled_transactions`, `merchants`, `kyc_records`, `disputes`.
- See [docs/09-data-model.md](09-data-model.md) for DDL.
- Read-replica for analytics + cross-cloud read by AWS Lambda fraud-score (boundary B5,
  via VPN tunnel).
- Backup: daily, 7-day retention.

## 8. KMS

- CMK `tng-finhack-cert-ca`: used to sign per-device certificates (X.509) issued at
  registration.
- CMK `tng-finhack-envelope`: envelope encryption for Tablestore-at-rest sensitive
  fields.
- Imported / managed inside Alibaba KMS BYOK for production; software-managed for demo.

## 9. Mobile Push (EMAS)

- Push channel: `tng-finhack`.
- Triggers:
  - Settlement complete (target user_id receives toast).
  - Model OTA available.
  - Online sync nudge after long offline.
- Integration: FC `tokens-settle` → after AWS event roundtrip (boundary B3) → Alibaba
  Push API call.

## 10. EventBridge (Alibaba)

- Bus `tng-cross-cloud-in`: receives cross-cloud webhook posts from AWS Lambda
  `eb-cross-cloud-bridge-out` (boundary B3).
- Rules:
  - `settlement-result` → FC `wallet-balance-update` to write back to Tablestore + push.
- Bus `tng-internal`: FC publishes events that AWS may consume.

## 11. CloudMonitor + SLS

- All FC functions ship logs to SLS project `tng-finhack-logs`.
- EAS endpoint metrics: latency, qps, error rate.
- Dashboard `tng-finhack-ops` on CloudMonitor for live demo.

## 12. RAM (least-privilege)

```yaml
# RAM role for FC functions
RoleName: TngFcWalletRole
AssumeRolePolicyDocument:
  Version: "1"
  Statement:
    - Action: "sts:AssumeRole"
      Principal: { Service: ["fc.aliyuncs.com"] }
      Effect: Allow
Policies:
  - PolicyName: TngFcWalletPolicy
    PolicyDocument:
      Version: "1"
      Statement:
        - Effect: Allow
          Action:
            - "ots:GetRow"
            - "ots:PutRow"
            - "ots:UpdateRow"
            - "ots:GetRange"
          Resource: "acs:ots:*:*:instance/tng-finhack/table/*"
        - Effect: Allow
          Action: ["oss:GetObject"]
          Resource: "acs:oss:*:*:tng-finhack-models/*"
        - Effect: Allow
          Action: ["eventbridge:PutEvents"]
          Resource: "*"
```

## 13. ROS (Resource Orchestration Service) skeleton

```
infra/alibaba/
├── main.ros            # provider + tags
├── tablestore/         # 6 tables
├── oss/                # 3 buckets
├── fc/                 # service + 11 functions
├── apigw/              # api group + routes
├── rds/                # mysql 8.0 instance + db init
├── eas/                # PAI-EAS service
├── kms/                # 2 CMKs
├── push/               # mobile push channel
├── eb/                 # cross-cloud + internal buses
└── monitor/            # dashboards + alarms
```

## 14. Cost estimate (demo-scale)

| Service | 3-day demo cost (USD) |
|---|---|
| FC invocations | < 1 |
| Tablestore | ~2 |
| OSS | < 1 |
| RDS (mysql.n2.medium.2c) | ~3 |
| PAI-EAS (1 instance, 3d) | ~5 |
| API Gateway | < 1 |
| Mobile Push | free tier |
| KMS | < 1 |
| **Total** | **~12** |

## 15. Cross-cloud connectivity

- AWS↔Alibaba mostly over the public internet with TLS 1.3 + mTLS for the bridge
  webhooks.
- For the Lambda↔RDS read (boundary B5), a Site-to-Site VPN between AWS VPC and
  Alibaba VPC. For the demo, a simpler approach: read-replica fronted by an FC API
  with strict IP allowlist of AWS NAT gateway IPs.
