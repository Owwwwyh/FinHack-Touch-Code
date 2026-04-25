# Alibaba Tablestore tables for user state, devices, wallets, and settlement
# See docs/06-alibaba-services.md §6 and docs/09-data-model.md

terraform {
  required_providers {
    alibabacloudstack = {
      source = "aliyun/alibabacloudstack"
    }
  }
}

# Tablestore instance
resource "alibabacloudstack_tablestore_instance" "tng" {
  name              = "${local.project}-tablestore"
  instance_type     = "HighPerformance"
  tags              = merge(local.common_tags, { Name = "${local.project}-tablestore" })
  timeouts          = { create = "10m" }
}

# Users table: user profile and KYC tier
resource "alibabacloudstack_tablestore_table" "users" {
  instance_name = alibabacloudstack_tablestore_instance.tng.name
  table_name    = "${local.project}_users"

  primary_key {
    name = "user_id"
    type = "String"
  }

  time_to_live = -1 # Infinite
  max_version  = 1

  reserved_read_capacity_units  = 10
  reserved_write_capacity_units = 10
}

# Devices table: public key directory and device attestation
resource "alibabacloudstack_tablestore_table" "devices" {
  instance_name = alibabacloudstack_tablestore_instance.tng.name
  table_name    = "${local.project}_devices"

  primary_key {
    name = "kid"
    type = "String"
  }

  time_to_live = -1
  max_version  = 1

  reserved_read_capacity_units  = 10
  reserved_write_capacity_units = 10
}

# Wallets table: user wallet balance and version
resource "alibabacloudstack_tablestore_table" "wallets" {
  instance_name = alibabacloudstack_tablestore_instance.tng.name
  table_name    = "${local.project}_wallets"

  primary_key {
    name = "user_id"
    type = "String"
  }

  time_to_live = -1
  max_version  = 1

  reserved_read_capacity_units  = 20
  reserved_write_capacity_units = 20
}

# Offline balance cache: cached safe balance for offline transactions
resource "alibabacloudstack_tablestore_table" "offline_balance_cache" {
  instance_name = alibabacloudstack_tablestore_instance.tng.name
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

  reserved_read_capacity_units  = 5
  reserved_write_capacity_units = 5
}

# Pending tokens inbox: optimistic user-side view of received payment tokens
resource "alibabacloudstack_tablestore_table" "pending_tokens_inbox" {
  instance_name = alibabacloudstack_tablestore_instance.tng.name
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

  reserved_read_capacity_units  = 5
  reserved_write_capacity_units = 5
}

# Policy versions table: tracks active credit score model versions
resource "alibabacloudstack_tablestore_table" "policy_versions" {
  instance_name = alibabacloudstack_tablestore_instance.tng.name
  table_name    = "${local.project}_policy_versions"

  primary_key {
    name = "policy_id"
    type = "String"
  }

  time_to_live = -1
  max_version  = 1

  reserved_read_capacity_units  = 5
  reserved_write_capacity_units = 5
}

# Variables
variable "account_id" {
  description = "Alibaba account ID"
  type        = string
}

# Locals
locals {
  project = "tng-finhack"
  common_tags = {
    Project = "tng-finhack"
    Env     = "demo"
  }
}

# Outputs
output "tablestore_instance_name" {
  value = alibabacloudstack_tablestore_instance.tng.name
}

output "users_table_name" {
  value = alibabacloudstack_tablestore_table.users.table_name
}

output "devices_table_name" {
  value = alibabacloudstack_tablestore_table.devices.table_name
}

output "wallets_table_name" {
  value = alibabacloudstack_tablestore_table.wallets.table_name
}

output "offline_balance_cache_table_name" {
  value = alibabacloudstack_tablestore_table.offline_balance_cache.table_name
}

output "pending_tokens_inbox_table_name" {
  value = alibabacloudstack_tablestore_table.pending_tokens_inbox.table_name
}

output "policy_versions_table_name" {
  value = alibabacloudstack_tablestore_table.policy_versions.table_name
}
