# Alibaba Tablestore tables for user state, devices, wallets, and settlement
# See docs/06-alibaba-services.md §6 and docs/09-data-model.md

terraform {
  required_providers {
    alicloud = {
      source = "aliyun/alicloud"
    }
  }
}

# Tablestore instance
resource "alicloud_ots_instance" "tng" {
  name        = "tngfinhackots"
  description = "${local.project} tablestore"
  accessed_by = "Any"
  tags        = merge(local.common_tags, { Name = "${local.project}-tablestore" })
}

# Users table: user profile and KYC tier
resource "alicloud_ots_table" "users" {
  instance_name = alicloud_ots_instance.tng.name
  table_name    = "${local.project}_users"

  primary_key {
    name = "user_id"
    type = "String"
  }

  time_to_live = -1 # Infinite
  max_version  = 1
}

# Devices table: public key directory and device attestation
resource "alicloud_ots_table" "devices" {
  instance_name = alicloud_ots_instance.tng.name
  table_name    = "${local.project}_devices"

  primary_key {
    name = "kid"
    type = "String"
  }

  time_to_live = -1
  max_version  = 1
}

# Wallets table: user wallet balance and version
resource "alicloud_ots_table" "wallets" {
  instance_name = alicloud_ots_instance.tng.name
  table_name    = "${local.project}_wallets"

  primary_key {
    name = "user_id"
    type = "String"
  }

  time_to_live = -1
  max_version  = 1
}

# Offline balance cache: cached safe balance for offline transactions
resource "alicloud_ots_table" "offline_balance_cache" {
  instance_name = alicloud_ots_instance.tng.name
  table_name    = "${local.project}_offline_balance_cache"

  primary_key {
    name = "user_id"
    type = "String"
  }

  primary_key {
    name = "kid"
    type = "String"
  }

  time_to_live = 604800 # 7 days
  max_version  = 1
}

# Pending tokens inbox: optimistic user-side view of received payment tokens
resource "alicloud_ots_table" "pending_tokens_inbox" {
  instance_name = alicloud_ots_instance.tng.name
  table_name    = "${local.project}_pending_tokens_inbox"

  primary_key {
    name = "user_id"
    type = "String"
  }

  primary_key {
    name = "ts"
    type = "Integer"
  }

  time_to_live = 2592000 # 30 days
  max_version  = 1
}

# Policy versions table: tracks active credit score model versions
resource "alicloud_ots_table" "policy_versions" {
  instance_name = alicloud_ots_instance.tng.name
  table_name    = "${local.project}_policy_versions"

  primary_key {
    name = "policy_id"
    type = "String"
  }

  time_to_live = -1
  max_version  = 1
}

resource "alicloud_ots_table" "pending_batches" {
  instance_name = alicloud_ots_instance.tng.name
  table_name    = "${local.project}_pending_batches"

  primary_key {
    name = "batch_id"
    type = "String"
  }

  time_to_live = 2592000
  max_version  = 1
}

resource "alicloud_ots_table" "score_policies" {
  instance_name = alicloud_ots_instance.tng.name
  table_name    = "${local.project}_score_policies"

  primary_key {
    name = "policy_version"
    type = "String"
  }

  time_to_live = -1
  max_version  = 1
}

# Variables
variable "account_id" {
  description = "Alibaba account ID"
  type        = string
}

variable "region" {
  description = "Alibaba region"
  type        = string
}

# Locals
locals {
  project = "tng_finhack"
  common_tags = {
    Project = "tng-finhack"
    Env     = "demo"
  }
}

# Outputs
output "tablestore_instance_name" {
  value = alicloud_ots_instance.tng.name
}

output "users_table_name" {
  value = alicloud_ots_table.users.table_name
}

output "devices_table_name" {
  value = alicloud_ots_table.devices.table_name
}

output "wallets_table_name" {
  value = alicloud_ots_table.wallets.table_name
}

output "offline_balance_cache_table_name" {
  value = alicloud_ots_table.offline_balance_cache.table_name
}

output "pending_tokens_inbox_table_name" {
  value = alicloud_ots_table.pending_tokens_inbox.table_name
}

output "policy_versions_table_name" {
  value = alicloud_ots_table.policy_versions.table_name
}

output "pending_batches_table_name" {
  value = alicloud_ots_table.pending_batches.table_name
}

output "score_policies_table_name" {
  value = alicloud_ots_table.score_policies.table_name
}

output "public_endpoint" {
  value = "https://${alicloud_ots_instance.tng.name}.${var.region}.ots.aliyuncs.com"
}
