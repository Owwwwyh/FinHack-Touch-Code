# Alibaba SLS (Log Service) per docs/06-alibaba-services.md §11

resource "alicloud_log_project" "finhack" {
  name        = "tng-finhack-logs"
  description = "TNG FinHack centralized logs"
  tags        = local.common_tags
}

resource "alicloud_log_store" "fc" {
  project                 = alicloud_log_project.finhack.name
  name                    = "fc-logs"
  retention_period        = 14
  shard_count             = 1
  auto_split              = true
  max_split_shard_count   = 4
}

resource "alicloud_log_store" "eas" {
  project                 = alicloud_log_project.finhack.name
  name                    = "eas-logs"
  retention_period        = 14
  shard_count             = 1
}

resource "alicloud_log_store" "apigw" {
  project                 = alicloud_log_project.finhack.name
  name                    = "apigw-logs"
  retention_period        = 14
  shard_count             = 1
}

output "log_project_name" { value = alicloud_log_project.finhack.name }
output "fc_logstore_name" { value = alicloud_log_store.fc.name }
