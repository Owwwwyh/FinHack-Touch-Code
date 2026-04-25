# DynamoDB tables for token ledger, nonce tracking, idempotency, pubkey cache
# See docs/05-aws-services.md §5 and docs/09-data-model.md

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Token ledger table: log of all offline payments settled
resource "aws_dynamodb_table" "token_ledger" {
  name           = "${local.project}-token-ledger"
  billing_mode   = "PAY_PER_REQUEST" # on-demand
  hash_key       = "tx_id"
  stream_specification {
    stream_view_type = "NEW_AND_OLD_IMAGES"
  }
  point_in_time_recovery {
    enabled = true
  }

  attribute {
    name = "tx_id"
    type = "S"
  }

  attribute {
    name = "kid_iat"
    type = "S"
  }

  # Global secondary index for queries by (kid, iat)
  global_secondary_index {
    name            = "kid-iat-gsi"
    hash_key        = "kid_iat"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  tags = {
    Name = "${local.project}-token-ledger"
  }
}

# Nonce-seen table: deduplication for offline payments
# PK: nonce
# TTL: 24 hours (to save storage)
resource "aws_dynamodb_table" "nonce_seen" {
  name           = "${local.project}-nonce-seen"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "nonce"
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  attribute {
    name = "nonce"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  tags = {
    Name = "${local.project}-nonce-seen"
  }
}

# Idempotency table: for Lambda retries
# PK: idempotency_key (request_id + endpoint + method)
# TTL: 24 hours
resource "aws_dynamodb_table" "idempotency" {
  name           = "${local.project}-idempotency"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "idempotency_key"
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  attribute {
    name = "idempotency_key"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  tags = {
    Name = "${local.project}-idempotency"
  }
}

# Pubkey cache: caches public keys from Alibaba (pulled by warmer Lambda)
# PK: kid (device key ID)
# TTL: 7 days (refilled by pubkey-warmer Lambda every 15 min)
resource "aws_dynamodb_table" "pubkey_cache" {
  name           = "${local.project}-pubkey-cache"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "kid"
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  attribute {
    name = "kid"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  tags = {
    Name = "${local.project}-pubkey-cache"
  }
}

# Variables
variable "kms_key_arn" {
  description = "KMS key ARN for DynamoDB encryption"
  type        = string
}

# Locals (same as main.tf)
locals {
  project = "tng-finhack"
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Outputs
output "token_ledger_table_name" {
  value = aws_dynamodb_table.token_ledger.name
}

output "token_ledger_table_arn" {
  value = aws_dynamodb_table.token_ledger.arn
}

output "nonce_seen_table_name" {
  value = aws_dynamodb_table.nonce_seen.name
}

output "nonce_seen_table_arn" {
  value = aws_dynamodb_table.nonce_seen.arn
}

output "idempotency_table_name" {
  value = aws_dynamodb_table.idempotency.name
}

output "idempotency_table_arn" {
  value = aws_dynamodb_table.idempotency.arn
}

output "pubkey_cache_table_name" {
  value = aws_dynamodb_table.pubkey_cache.name
}

output "pubkey_cache_table_arn" {
  value = aws_dynamodb_table.pubkey_cache.arn
}
