# Secrets Manager for storing Alibaba cloud credentials (AK/SK)
# Used by Lambda functions for cross-cloud bridge operations

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Secret for Alibaba API credentials (kept for future model publish automation)
resource "aws_secretsmanager_secret" "alibaba_credentials" {
  name                    = "${local.project}-alibaba-credentials"
  description             = "Alibaba Cloud AccessKey and SecretKey for cross-cloud bridge"
  recovery_window_in_days = 7

  tags = {
    Name = "${local.project}-alibaba-creds"
  }
}

# Secret version (in production, these would come from environment or vault)
resource "aws_secretsmanager_secret_version" "alibaba_credentials" {
  secret_id = aws_secretsmanager_secret.alibaba_credentials.id
  secret_string = jsonencode({
    access_key_id     = var.alibaba_access_key_id
    secret_access_key = var.alibaba_secret_access_key
    region            = var.alibaba_region
    account_id        = var.alibaba_account_id
  })
}

# Secret used by eb-cross-cloud-bridge-out for the callback target.
resource "aws_secretsmanager_secret" "alibaba_ingest" {
  name                    = "${local.project}-alibaba-ingest"
  description             = "Alibaba ingest URL for settlement.completed callbacks"
  recovery_window_in_days = 7

  tags = {
    Name = "${local.project}-alibaba-ingest"
  }
}

resource "aws_secretsmanager_secret_version" "alibaba_ingest" {
  secret_id     = aws_secretsmanager_secret.alibaba_ingest.id
  secret_string = var.alibaba_ingest_url
}

# Shared HMAC secret mirrored to Alibaba for bridge authentication.
resource "aws_secretsmanager_secret" "bridge_hmac_secret" {
  name                    = "${local.project}-aws-bridge-hmac-secret"
  description             = "Shared AWS<->Alibaba HMAC secret for bridge payload signing"
  recovery_window_in_days = 7

  tags = {
    Name = "${local.project}-bridge-hmac-secret"
  }
}

resource "aws_secretsmanager_secret_version" "bridge_hmac_secret" {
  secret_id     = aws_secretsmanager_secret.bridge_hmac_secret.id
  secret_string = var.bridge_hmac_secret
}

# Secret for Cognito client secret (if needed for backend calls)
resource "aws_secretsmanager_secret" "cognito_client_secret" {
  name                    = "${local.project}-cognito-client-secret"
  description             = "Cognito app client secret"
  recovery_window_in_days = 7

  tags = {
    Name = "${local.project}-cognito-secret"
  }
}

resource "aws_secretsmanager_secret_version" "cognito_client_secret" {
  secret_id     = aws_secretsmanager_secret.cognito_client_secret.id
  secret_string = var.cognito_client_secret
}

# Secret policy: allow Lambda to read
resource "aws_secretsmanager_secret_policy" "alibaba_lambda_read" {
  count     = length(var.lambda_role_arns) > 0 ? 1 : 0
  secret_id = aws_secretsmanager_secret.alibaba_credentials.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaRead"
        Effect = "Allow"
        Principal = {
          AWS = var.lambda_role_arns
        }
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
      }
    ]
  })
}

# Variables
variable "alibaba_access_key_id" {
  description = "Alibaba Cloud Access Key ID"
  type        = string
  sensitive   = true
  default     = ""
}

variable "alibaba_secret_access_key" {
  description = "Alibaba Cloud Secret Access Key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "alibaba_region" {
  description = "Alibaba Cloud region"
  type        = string
  default     = "cn-singapore"
}

variable "alibaba_account_id" {
  description = "Alibaba Cloud account ID"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cognito_client_secret" {
  description = "Cognito app client secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "alibaba_ingest_url" {
  description = "Alibaba ingest URL consumed by the outbound bridge"
  type        = string
  default     = ""
}

variable "bridge_hmac_secret" {
  description = "Shared HMAC secret for AWS<->Alibaba bridge traffic"
  type        = string
  sensitive   = true
  default     = ""
}

variable "lambda_role_arns" {
  description = "ARNs of Lambda IAM roles that can read secrets"
  type        = list(string)
  default     = []
}

# Locals
locals {
  project = "tng-finhack"
}

# Outputs
output "alibaba_credentials_secret_arn" {
  value = aws_secretsmanager_secret.alibaba_credentials.arn
}

output "alibaba_credentials_secret_name" {
  value = aws_secretsmanager_secret.alibaba_credentials.name
}

output "cognito_client_secret_arn" {
  value = aws_secretsmanager_secret.cognito_client_secret.arn
}

output "alibaba_ingest_secret_arn" {
  value = aws_secretsmanager_secret.alibaba_ingest.arn
}

output "alibaba_ingest_secret_name" {
  value = aws_secretsmanager_secret.alibaba_ingest.name
}

output "bridge_hmac_secret_arn" {
  value = aws_secretsmanager_secret.bridge_hmac_secret.arn
}

output "bridge_hmac_secret_name" {
  value = aws_secretsmanager_secret.bridge_hmac_secret.name
}
