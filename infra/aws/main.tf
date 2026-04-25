# AWS Terraform main configuration
# Per docs/05-aws-services.md §13, docs/13-deployment.md §3

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "tng-finhack-aws-terraform-state"
    key            = "terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "tng-finhack-terraform-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-southeast-1"

  default_tags {
    tags = {
      Project = "tng-finhack"
      Env     = "demo"
    }
  }
}

# ──────────────────────────────────────
# S3 Buckets
# ──────────────────────────────────────

resource "aws_kms_key" "tng" {
  description             = "TNG FinHack CMK"
  deletion_window_in_days = 7
  tags                    = { Name = "tng-finhack-key" }
}

resource "aws_kms_alias" "tng" {
  name          = "alias/tng-finhack-key"
  target_key_id = aws_kms_key.tng.key_id
}

resource "aws_s3_bucket" "data" {
  bucket = "tng-finhack-aws-data"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
      kms_master_key_id = aws_kms_key.tng.arn
    }
  }
}

resource "aws_s3_bucket" "models" {
  bucket = "tng-finhack-aws-models"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "models" {
  bucket = aws_s3_bucket.models.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
      kms_master_key_id = aws_kms_key.tng.arn
    }
  }
}

resource "aws_s3_bucket" "logs" {
  bucket = "tng-finhack-aws-logs"
}

# ──────────────────────────────────────
# DynamoDB Tables
# ──────────────────────────────────────

resource "aws_dynamodb_table" "token_ledger" {
  name         = "tng_token_ledger"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "tx_id"

  attribute {
    name = "tx_id"
    type = "S"
  }

  attribute {
    name = "kid"
    type = "S"
  }

  attribute {
    name = "iat"
    type = "N"
  }

  attribute {
    name = "sender_user_id"
    type = "S"
  }

  global_secondary_index {
    name            = "kid-iat-index"
    hash_key        = "kid"
    range_key       = "iat"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "sender-iat-index"
    hash_key        = "sender_user_id"
    range_key       = "iat"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }
}

resource "aws_dynamodb_table" "nonce_seen" {
  name         = "tng_nonce_seen"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "nonce"

  attribute {
    name = "nonce"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}

resource "aws_dynamodb_table" "idempotency" {
  name         = "tng_idempotency"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "key"

  attribute {
    name = "key"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}

resource "aws_dynamodb_table" "pubkey_cache" {
  name         = "tng_pubkey_cache"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "kid"

  attribute {
    name = "kid"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}

# ──────────────────────────────────────
# Cognito User Pool
# ──────────────────────────────────────

resource "aws_cognito_user_pool" "tng" {
  name = "tng-finhack-users"

  schema {
    name                = "kyc_tier"
    attribute_data_type = "Number"
    mutable             = true
  }

  schema {
    name                = "home_region"
    attribute_data_type = "String"
    mutable             = true
  }
}

resource "aws_cognito_user_pool_client" "mobile" {
  name                                 = "tng-mobile"
  user_pool_id                         = aws_cognito_user_pool.tng.id
  explicit_auth_flows                  = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "profile"]
  callback_urls                        = ["tngfinhack://"]
  logout_urls                          = ["tngfinhack://"]
}

# ──────────────────────────────────────
# EventBridge
# ──────────────────────────────────────

resource "aws_cloudwatch_event_bus" "cross_cloud" {
  name = "tng-cross-cloud"
}

# ──────────────────────────────────────
# IAM Role for Lambda
# ──────────────────────────────────────

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "settle" {
  name               = "tng-settle-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "settle" {
  statement {
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
    ]
    resources = [
      aws_dynamodb_table.token_ledger.arn,
      aws_dynamodb_table.nonce_seen.arn,
      aws_dynamodb_table.pubkey_cache.arn,
    ]
  }

  statement {
    actions   = ["events:PutEvents"]
    resources = [aws_cloudwatch_event_bus.cross_cloud.arn]
  }

  statement {
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [aws_kms_key.tng.arn]
  }
}

resource "aws_iam_role_policy" "settle" {
  role   = aws_iam_role.settle.id
  policy = data.aws_iam_policy_document.settle.json
}

# ──────────────────────────────────────
# Outputs
# ──────────────────────────────────────

output "cognito_jwks_url" {
  value = "https://cognito-idp.ap-southeast-1.amazonaws.com/${aws_cognito_user_pool.tng.id}/.well-known/jwks.json"
}

output "event_bus_arn" {
  value = aws_cloudwatch_event_bus.cross_cloud.arn
}

output "s3_data_bucket" {
  value = aws_s3_bucket.data.bucket
}

output "s3_models_bucket" {
  value = aws_s3_bucket.models.bucket
}
