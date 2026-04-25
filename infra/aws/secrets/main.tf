# Secrets Manager for storing Alibaba cloud credentials (AK/SK)
# Used by Lambda functions for cross-cloud bridge operations

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Secret for Alibaba API credentials
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
