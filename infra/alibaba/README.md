# Alibaba Cloud Infrastructure (Terraform)

TNG Finhack Phase 2 Alibaba cloud resources for wallet API, offline payment settlement, model hosting, and cross-cloud integration.

**Documentation**: See [docs/06-alibaba-services.md](../../docs/06-alibaba-services.md) for detailed service architecture.

## Structure

```
infra/alibaba/
├── main.tf              # Provider config, variables, locals
├── oss/                 # Object Storage Service (models, pubkeys, static)
├── tablestore/          # Tablestore (user, device, wallet state)
├── rds/                 # ApsaraDB RDS MySQL (transaction history, KYC, merchants)
├── fc/                  # Function Compute (wallet API functions)
├── apigw/               # API Gateway (public HTTPS endpoint)
├── eas/                 # PAI-EAS (credit score refresh endpoint)
├── kms/                 # Key Management Service (cert CA, envelope keys)
├── eb/                  # EventBridge (settlement events, cross-cloud ingress)
├── push/                # Mobile Push (EMAS)
├── monitor/             # CloudMonitor (dashboards) + Log Service (logs)
└── terraform.tfvars     # (gitignored) local variable values
```

## Prerequisites

- Terraform >= 1.5
- Alibaba Cloud CLI configured with credentials (ap-southeast-3 region)
- Alibaba account with suitable RAM permissions
- AWS account details (for cross-cloud setup)

## Quick Start

1. **Initialize Terraform**:

   ```bash
   cd infra/alibaba
   terraform init
   ```

2. **Create terraform.tfvars** (template below):

   ```bash
   cat > terraform.tfvars <<EOF
   alibaba_access_key       = "your_alibaba_access_key"
   alibaba_secret_key       = "your_alibaba_secret_key"
   alibaba_region           = "ap-southeast-3"
   environment              = "demo"
   account_id               = "your_alibaba_account_id"
   aws_cognito_jwks_uri     = "https://cognito-idp.ap-southeast-1.amazonaws.com/ap-southeast-1_XXXXXXXXX/.well-known/jwks.json"
   aws_account_id           = "123456789012"
   aws_lambda_bridge_out_arn = "arn:aws:lambda:ap-southeast-1:123456789012:function:tng-finhack-eb-cross-cloud-bridge-out"
   EOF
   ```

3. **Validate**:

   ```bash
   terraform validate
   terraform plan
   ```

4. **Apply** (creates all resources):

   ```bash
   terraform apply
   ```

5. **Destroy** (cleans up all resources):
   ```bash
   terraform destroy
   ```

## Services Deployed

### OSS (Object Storage Service)

- **Models Bucket** (`tng-finhack-models-{account_id}`): TF Lite model artifacts
  - Private ACL
  - Encryption: AES256
  - Lifecycle: Archive models > 60 days to IA storage
  - Used by: PAI-EAS at warmup, mobile via signed URLs
- **Pubkeys Bucket** (`tng-finhack-pubkeys-{account_id}`): Device public key directory
  - Private ACL
  - Path format: `{kid}.pem` (X.509 PEM)
  - Used by: Settlement Lambda to verify signatures, mobile to pull pubkey cache
- **Static Bucket** (`tng-finhack-static-{account_id}`): App config, ToS, Privacy
  - Private ACL
  - CORS enabled for mobile app
  - Served via signed URLs or CDN

### Tablestore

All tables use reserved capacity (10–20 RU/WU) for demo; autoscale to 40,000 RU/WU max.

- **users**: User profile + KYC tier
  - PK: `user_id`
  - Columns: `kyc_tier`, `name`, `email`, `home_region`, `created_at`, `updated_at`
- **devices**: Device pubkey + attestation
  - PK: `kid` (key ID, derived from public key)
  - Columns: `pub_pem`, `attestation_cert`, `status` (active/revoked), `created_at`
- **wallets**: User wallet balance + version
  - PK: `user_id`
  - Columns: `balance`, `currency`, `version`, `last_sync_at`
- **offline_balance_cache**: Safe balance for offline transactions
  - PK: `user_id` + `kid`
  - Columns: `safe_balance`, `model_version`, `ttl: 7 days`
- **pending_tokens_inbox**: Optimistic inbox of received payments
  - PK: `user_id` + `ts` (timestamp)
  - Columns: `token_id`, `amount`, `sender_id`, `status` (pending/settled), `ttl: 30 days`
- **policy_versions**: Active model version tracking
  - PK: `policy_id`
  - Columns: `model_version`, `created_at`, `expires_at`, `eas_model_path`

### Cost Estimate (Demo 3 Days)

| Service                           | Cost      |
| --------------------------------- | --------- |
| Function Compute                  | < $1      |
| Tablestore (reserved + on-demand) | ~2        |
| OSS                               | < $1      |
| API Gateway                       | < $1      |
| RDS (mysql.n2.medium.2c, 3 days)  | ~3        |
| PAI-EAS (1 instance, 3 days)      | ~5        |
| Mobile Push                       | Free tier |
| KMS                               | < $1      |
| **Total**                         | **~12**   |

## Integration with AWS (Boundary Calls)

### B1: Model Publish (AWS → Alibaba OSS)

- **Trigger**: AWS Step Functions model-release pipeline completes
- **Action**: AWS Lambda `model-publish-bridge` copies `model.tflite` from S3 to Alibaba OSS
- **Authentication**: Alibaba AK/SK stored in AWS Secrets Manager
- **Path**: `s3://tng-finhack-aws-models/credit/v{n}/model.tar.gz` → `oss://tng-finhack-models/credit/v{n}/model.tflite`

### B2: Settlement Relay (Alibaba → AWS EventBridge)

- **Trigger**: Alibaba FC `tokens-settle` writes to Tablestore, emits EventBridge event
- **Action**: Alibaba EventBridge rule → FC webhook → AWS EventBridge ingest
- **Authentication**: mTLS + HMAC-SHA256 signature with AWS Lambda shared secret

### B3: Result Callback (AWS → Alibaba FC)

- **Trigger**: AWS Lambda `eb-cross-cloud-bridge-out` after settlement verification
- **Action**: HTTPS POST to Alibaba `POST /eb-cross-cloud-ingest` with settlement result
- **Authentication**: AWS Cognito JWT (verified via Alibaba API Gateway JWT plugin)
- **Callback**: Updates Tablestore wallet, triggers mobile push

### B4: JWT Verification (AWS Cognito JWKS → Alibaba API Gateway)

- **JWKS URL**: AWS Cognito endpoint (provided via terraform variable)
- **Plugin**: API Gateway JWT verifier configured to fetch JWKS at startup and every 1 hour
- **Verification**: Validates mobile app ID tokens before routing to FC functions

### B5: Analytics Read (AWS Lambda → Alibaba RDS)

- **Connection**: VPN tunnel or IP allowlist (RDS read-replica fronted by FC API)
- **Usage**: AWS Lambda `fraud-score` queries RDS `settled_transactions` for geo/velocity heuristics
- **Authentication**: RDS username/password in AWS Secrets Manager

## Outputs

After `terraform apply`, retrieve outputs:

```bash
terraform output
```

Key outputs:

- `tablestore_instance_name`: Instance for all tables
- `users_table_name`, `wallets_table_name`: Tablestore table names
- `models_bucket`, `pubkeys_bucket`: OSS bucket names
- `api_gateway_group_id`: API Gateway for FC function routes

## Cross-Cloud Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│ AWS (ap-southeast-1)                                             │
│ ┌─────────────────────────────────────────────────────────────┐  │
│ │ Cognito: JWKS endpoint (public)                            │  │
│ └─────────────────────────────────────────────────────────────┘  │
│ ┌─────────────────────────────────────────────────────────────┐  │
│ │ Step Functions: Model release pipeline                     │  │
│ └─────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
  │ B1: Model artifact                    B4: JWT JWKS
  │ (S3 → OSS)                           (Cognito → API GW)
  ▼                                         ▼
┌──────────────────────────────────────────────────────────────────┐
│ Alibaba (ap-southeast-3)                                         │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │ OSS: Model artifacts, pubkeys                               │ │
│ │ PAI-EAS: Credit score refresh (reads model from OSS)        │ │
│ └──────────────────────────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │ Function Compute: Wallet API, settlement                    │ │
│ │ Tablestore: User, device, wallet state                      │ │
│ └──────────────────────────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │ API Gateway: JWT auth, public HTTPS endpoint                │ │
│ └──────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
  │ B2: Settlement batch            B3: Settlement result
  │ (Tablestore → AWS EB)          (AWS Lambda → FC webhook)
  ▼                                  ▼
(EventBridge cross-cloud bus) → (RDS analytics read, push notifications)
```

## Next Steps

1. **Deploy Function Compute** (`infra/alibaba/fc/`): Implement 11 wallet API functions
2. **Deploy API Gateway** (`infra/alibaba/apigw/`): Public HTTPS endpoint with JWT auth
3. **Deploy RDS** (`infra/alibaba/rds/`): Transaction history, KYC, merchants
4. **Deploy PAI-EAS** (`infra/alibaba/eas/`): Credit score refresh service
5. **Deploy EventBridge** (`infra/alibaba/eb/`): Cross-cloud event relay
6. **Link to AWS** (Track B): Configure cross-cloud bridges B1, B2, B3

## Troubleshooting

### Terraform Provider Issues

If provider not found:

```bash
terraform init -upgrade
```

### Tablestore Quota

Tablestore reserved capacity 10–20 RU/WU per table may be insufficient for load testing. Increase in main.tf:

```hcl
reserved_read_capacity_units  = 100
reserved_write_capacity_units = 100
```

### OSS Access

Test bucket access:

```bash
aliyun oss ls oss://tng-finhack-models-{account_id}/
```

### Cross-Cloud Network

For testing cross-cloud connectivity, curl the Alibaba endpoint from AWS:

```bash
curl -X POST https://api-finhack.example.com/tokens/settle \
  -H "Authorization: Bearer <cognito_token>" \
  -H "Content-Type: application/json" \
  -d '{"tokens": [...]}'
```

---

**Questions?** Refer to [docs/06-alibaba-services.md](../../docs/06-alibaba-services.md) for architecture details.
