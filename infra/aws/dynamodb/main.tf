# DynamoDB Tables per docs/05-aws-services.md §5 and docs/09-data-model.md §2

# Token ledger
resource "aws_dynamodb_table" "token_ledger" {
  name         = "tng_token_ledger"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "tx_id"
  point_in_time_recovery { enabled = true }
  tags = merge(local.common_tags, { Name = "tng-token-ledger" })

  attribute { name = "tx_id"; type = "S" }
  attribute { name = "kid"; type = "S" }
  attribute { name = "iat"; type = "N" }
  attribute { name = "sender_user_id"; type = "S" }

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
}

# Nonce seen (double-spend prevention)
resource "aws_dynamodb_table" "nonce_seen" {
  name         = "tng_nonce_seen"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "nonce"
  ttl { attribute_name = "ttl"; enabled = true }
  tags = merge(local.common_tags, { Name = "tng-nonce-seen" })

  attribute { name = "nonce"; type = "S" }
}

# Idempotency
resource "aws_dynamodb_table" "idempotency" {
  name         = "tng_idempotency"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "key"
  ttl { attribute_name = "ttl"; enabled = true }
  tags = merge(local.common_tags, { Name = "tng-idempotency" })

  attribute { name = "key"; type = "S" }
}

# Pubkey cache
resource "aws_dynamodb_table" "pubkey_cache" {
  name         = "tng_pubkey_cache"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "kid"
  ttl { attribute_name = "ttl"; enabled = true }
  tags = merge(local.common_tags, { Name = "tng-pubkey-cache" })

  attribute { name = "kid"; type = "S" }
}

output "token_ledger_table_name" { value = aws_dynamodb_table.token_ledger.name }
output "nonce_seen_table_name" { value = aws_dynamodb_table.nonce_seen.name }
output "idempotency_table_name" { value = aws_dynamodb_table.idempotency.name }
output "pubkey_cache_table_name" { value = aws_dynamodb_table.pubkey_cache.name }
