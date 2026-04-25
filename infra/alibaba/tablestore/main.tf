# Alibaba Tablestore per docs/06-alibaba-services.md §6 and docs/09-data-model.md §1

resource "alicloud_ots_instance" "finhack" {
  name                  = "tng-finhack-ots"
  description           = "TNG FinHack Tablestore instance"
  accessed_by           = "Any"
  instance_type         = "HighPerformance"
  capacity_unit_limit   = 200
  tags                  = local.common_tags
}

# Users table
resource "alicloud_ots_table" "users" {
  instance_name = alicloud_ots_instance.finhack.name
  table_name    = "users"
  primary_key {
    name = "user_id"
    type = "STRING"
  }
  time_to_live = -1
  max_version  = 1
}

# Devices table
resource "alicloud_ots_table" "devices" {
  instance_name = alicloud_ots_instance.finhack.name
  table_name    = "devices"
  primary_key {
    name = "device_id"
    type = "STRING"
  }
  time_to_live = -1
  max_version  = 1
}

# Wallets table
resource "alicloud_ots_table" "wallets" {
  instance_name = alicloud_ots_instance.finhack.name
  table_name    = "wallets"
  primary_key {
    name = "user_id"
    type = "STRING"
  }
  time_to_live = -1
  max_version  = 1
}

# Offline balance cache
resource "alicloud_ots_table" "offline_balance_cache" {
  instance_name = alicloud_ots_instance.finhack.name
  table_name    = "offline_balance_cache"
  primary_key {
    name = "user_id"
    type = "STRING"
  }
  primary_key {
    name = "device_id"
    type = "STRING"
  }
  time_to_live = 1800  # 30 minutes
  max_version  = 1
}

# Pending tokens inbox
resource "alicloud_ots_table" "pending_tokens_inbox" {
  instance_name = alicloud_ots_instance.finhack.name
  table_name    = "pending_tokens_inbox"
  primary_key {
    name = "user_id"
    type = "STRING"
  }
  primary_key {
    name = "received_at"
    type = "INTEGER"
  }
  time_to_live = -1
  max_version  = 1
}

# Policy versions
resource "alicloud_ots_table" "policy_versions" {
  instance_name = alicloud_ots_instance.finhack.name
  table_name    = "policy_versions"
  primary_key {
    name = "policy_id"
    type = "STRING"
  }
  time_to_live = -1
  max_version  = 1
}

output "ots_instance_name" { value = alicloud_ots_instance.finhack.name }
