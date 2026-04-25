# AWS Infrastructure (Terraform)

TNG Finhack Phase 2 AWS cloud resources for offline payment settlement, ML training, and cross-cloud integration.

**Documentation**: See [docs/05-aws-services.md](../../docs/05-aws-services.md) for detailed service architecture.

## Structure

```
infra/aws/
├── main.tf              # Provider config, variables, locals
├── kms/                 # Encryption key (hardware-backed KMS)
├── s3/                  # Data lake, models, logs buckets
├── dynamodb/            # Token ledger, nonce dedup, pubkey cache, idempotency
├── cognito/             # User pool, mobile app client, identity pool
├── eventbridge/         # Settlement event bus, cross-cloud bridge rules
├── secrets/             # Alibaba credentials, Cognito client secret
├── lambda/              # Lambda functions (placeholder structure)
├── sagemaker/           # ML training infrastructure (placeholder)
├── stepfunctions/       # Model release pipeline (placeholder)
├── apigw/               # API Gateway for cross-cloud inbound (placeholder)
└── terraform.tfvars     # (gitignored) local variable values
```

## Prerequisites

- Terraform >= 1.5
- AWS CLI configured with credentials (ap-southeast-1 region)
- AWS account with suitable IAM permissions

## Quick Start

1. **Initialize Terraform**:

   ```bash
   cd infra/aws
   terraform init
   ```

2. **Create terraform.tfvars** (template below):

   ```bash
   cat > terraform.tfvars <<EOF
   aws_region    = "ap-southeast-1"
   environment   = "demo"

   # Alibaba credentials (for cross-cloud bridge)
   alibaba_access_key_id      = "your_alibaba_ak"
   alibaba_secret_access_key  = "your_alibaba_sk"
   alibaba_region             = "cn-singapore"
   alibaba_account_id         = "your_alibaba_account_id"

   # Cognito (optional if not using auth yet)
   cognito_client_secret = ""

   # Lambda role ARNs (populated after Lambda module created)
   lambda_role_arns = []
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

### KMS (Key Management Service)

- **Encryption key**: `alias/tng-finhack-key`
- **Purpose**: Envelope encryption for S3, DynamoDB, Secrets Manager
- **Key rotation**: Enabled (automatic)

### S3 Buckets

- **Data Lake** (`tng-finhack-aws-data-{account_id}`): Synthetic training data
  - Versioning enabled
  - Encryption: KMS
  - Lifecycle: Archive old data to Glacier after 30 days
- **Models** (`tng-finhack-aws-models-{account_id}`): Trained model artifacts
  - Versioning enabled
  - Encryption: KMS
  - Retention: Indefinite
- **Logs** (`tng-finhack-aws-logs-{account_id}`): Settlement service logs
  - Encryption: SSE-S3
  - Retention: As configured in Lambda

### DynamoDB Tables

All use on-demand billing (pay-per-request).

- **token_ledger**: All settled offline payments
  - PK: `tx_id`
  - GSI: `kid_iat` (query by device + timestamp)
  - Stream: Enabled (NEW_AND_OLD_IMAGES)
  - PITR: Enabled
  - Encryption: KMS

- **nonce_seen**: Deduplication of offline transactions
  - PK: `nonce` (unique replay protection)
  - TTL: 24 hours
  - Encryption: KMS

- **idempotency**: Lambda retry idempotency keys
  - PK: `idempotency_key`
  - TTL: 24 hours
  - Encryption: KMS

- **pubkey_cache**: Cached public keys from Alibaba
  - PK: `kid`
  - TTL: 7 days (refilled by pubkey-warmer Lambda)
  - Encryption: KMS

### Cognito

- **User Pool**: `tng-finhack-users`
  - SCRAM password policy (8 chars, mixed case, numbers, symbols)
  - Custom attributes: `kyc_tier`, `home_region`
  - Pre-signup Lambda: Auto-approves and assigns tier 1
- **App Client**: `tng-finhack-mobile`
  - OAuth2 with PKCE (for mobile security)
  - Refresh token validity: 30 days
  - Access token validity: 1 hour
  - Scopes: `wallet:read`, `payment:create`
- **Identity Pool**: Optional federation to temporary AWS credentials (admin tools only)

### EventBridge

- **Default Bus**: Internal settlement events
- **Custom Bus** (`tng-finhack-cross-cloud`): Cross-cloud events from Alibaba

**Rules**:

- `settlement-result`: Settlement complete → bridges to Alibaba
- `model-published`: New ML model → triggers release pipeline
- `cross-cloud-inbound`: Events from Alibaba → internal bus

### Secrets Manager

- **Alibaba Credentials**: API keys, region, account ID
  - Rotation window: 7 days
  - Accessed by: Lambda bridge functions
- **Cognito Client Secret**: For backend JWT calls
  - Accessed by: Internal Lambdas

## Cost Estimate (Demo 3 Days)

| Service              | Cost               |
| -------------------- | ------------------ |
| DynamoDB (on-demand) | < $1               |
| S3                   | < $1               |
| Lambda invocations   | < $1               |
| Cognito              | Free (< 50k users) |
| EventBridge          | < $1               |
| KMS                  | < $1               |
| **Total**            | **~$6**            |

Production at 10k DAU: $50–150/month

## Outputs

After `terraform apply`, retrieve outputs:

```bash
terraform output
```

Key outputs:

- `kms_key_id`: KMS key for encryption
- `data_bucket_name`, `models_bucket_name`: S3 bucket names
- `token_ledger_table_name`, `nonce_seen_table_name`: DynamoDB table names
- `user_pool_id`, `app_client_id`: Cognito identifiers
- `jwks_uri`: JWT public key endpoint (used by Alibaba FC for verification)
- `cross_cloud_bus_name`: EventBridge bus for cross-cloud events

## Integration with Other Tracks

- **Track B (Alibaba)**: Uses Cognito JWKS URI, sends events to `tng-finhack-cross-cloud` bus
- **Track C (ML)**: SageMaker training reads from `tng-finhack-aws-data` S3 bucket
- **Track D (Mobile)**: Uses Cognito user pool for auth, accesses models via S3 (via IAM)
- **Track E (Backend API)**: Lambda functions read token ledger, write settlement results

## Troubleshooting

### Terraform State

State is stored locally by default. For multi-team development, use S3 backend:

```hcl
terraform {
  backend "s3" {
    bucket         = "tng-finhack-terraform-state"
    key            = "aws/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}
```

### KMS Key Access

If Lambda cannot decrypt S3 or DynamoDB, check:

1. Lambda IAM role includes `kms:Decrypt`, `kms:GenerateDataKey`
2. KMS key policy grants the Lambda role permission

### DynamoDB Capacity

All tables use on-demand billing (pay-per-request). No capacity provisioning needed. Scales automatically.

### EventBridge Rules

Check that:

1. Event source matches pattern (e.g., `source: "tng.settlement"`)
2. Target Lambda/Step Functions ARN is correct
3. Target IAM role has permission to invoke Lambda/states:StartExecution

## Next Steps

1. **Deploy Lambda Functions** (infra/aws/lambda/): Implement settle-batch, fraud-score, pubkey-warmer, bridge functions
2. **Deploy SageMaker** (infra/aws/sagemaker/): Training infrastructure, model registry
3. **Deploy Step Functions** (infra/aws/stepfunctions/): Model release pipeline
4. **Deploy API Gateway** (infra/aws/apigw/): Cross-cloud inbound HTTPS endpoint
5. **Link to Track B** (Alibaba): Configure EventBridge cross-cloud relay, sync pubkeys

## Tags

All resources are tagged with:

- `Project = tng-finhack`
- `Env = demo`

Optionally add:

- `Owner = team-email@company.com`
- `CostCenter = ...`

---

**Questions?** Refer to [docs/05-aws-services.md](../../docs/05-aws-services.md) for architecture details.
