# Alibaba Function Compute per docs/06-alibaba-services.md §4

resource "alicloud_fc_service" "wallet_api" {
  name        = "tng-wallet-api"
  description = "TNG Wallet API service"
  log_config {
    project  = alicloud_log_project.finhack.name
    logstore = alicloud_log_store.fc.name
  }
}

# Functions per docs/06-alibaba-services.md §4 Table
resource "alicloud_fc_function" "device_register" {
  service    = alicloud_fc_service.wallet_api.name
  name       = "device-register"
  handler    = "handler.handler"
  runtime    = "python3.11"
  memory_size = 256
  timeout    = 30
  environment_variables = {
    OTS_INSTANCE       = alicloud_ots_instance.finhack.name
    OSS_PUBKEY_BUCKET  = alicloud_oss_bucket.pubkeys.bucket
  }
}

resource "alicloud_fc_function" "device_attest" {
  service    = alicloud_fc_service.wallet_api.name
  name       = "device-attest"
  handler    = "handler.handler"
  runtime    = "python3.11"
  memory_size = 128
  timeout    = 15
}

resource "alicloud_fc_function" "wallet_balance" {
  service    = alicloud_fc_service.wallet_api.name
  name       = "wallet-balance"
  handler    = "handler.handler"
  runtime    = "python3.11"
  memory_size = 128
  timeout    = 10
  environment_variables = {
    OTS_INSTANCE = alicloud_ots_instance.finhack.name
  }
}

resource "alicloud_fc_function" "wallet_sync" {
  service    = alicloud_fc_service.wallet_api.name
  name       = "wallet-sync"
  handler    = "handler.handler"
  runtime    = "python3.11"
  memory_size = 128
  timeout    = 15
  environment_variables = {
    OTS_INSTANCE = alicloud_ots_instance.finhack.name
  }
}

resource "alicloud_fc_function" "tokens_settle" {
  service    = alicloud_fc_service.wallet_api.name
  name       = "tokens-settle"
  handler    = "handler.handler"
  runtime    = "python3.11"
  memory_size = 512
  timeout    = 30
  environment_variables = {
    OTS_INSTANCE         = alicloud_ots_instance.finhack.name
    AWS_BRIDGE_URL       = var.aws_bridge_url
    AWS_BRIDGE_HMAC_SECRET = var.hmac_secret
  }
}

resource "alicloud_fc_function" "tokens_dispute" {
  service    = alicloud_fc_service.wallet_api.name
  name       = "tokens-dispute"
  handler    = "handler.handler"
  runtime    = "python3.11"
  memory_size = 256
  timeout    = 15
  environment_variables = {
    RDS_DSN = var.rds_dsn
  }
}

resource "alicloud_fc_function" "score_refresh" {
  service    = alicloud_fc_service.wallet_api.name
  name       = "score-refresh"
  handler    = "handler.handler"
  runtime    = "python3.11"
  memory_size = 256
  timeout    = 10
  environment_variables = {
    EAS_ENDPOINT = var.eas_endpoint
  }
}

resource "alicloud_fc_function" "score_policy" {
  service    = alicloud_fc_service.wallet_api.name
  name       = "score-policy"
  handler    = "handler.handler"
  runtime    = "python3.11"
  memory_size = 128
  timeout    = 10
}

resource "alicloud_fc_function" "publickeys_get" {
  service    = alicloud_fc_service.wallet_api.name
  name       = "publickeys-get"
  handler    = "handler.handler"
  runtime    = "python3.11"
  memory_size = 128
  timeout    = 10
}

resource "alicloud_fc_function" "merchants_onboard" {
  service    = alicloud_fc_service.wallet_api.name
  name       = "merchants-onboard"
  handler    = "handler.handler"
  runtime    = "python3.11"
  memory_size = 128
  timeout    = 15
}

resource "alicloud_fc_function" "eb_cross_cloud_ingest" {
  service    = alicloud_fc_service.wallet_api.name
  name       = "eb-cross-cloud-ingest"
  handler    = "handler.handler"
  runtime    = "python3.11"
  memory_size = 256
  timeout    = 15
  environment_variables = {
    OTS_INSTANCE       = alicloud_ots_instance.finhack.name
    RDS_DSN            = var.rds_dsn
  }
}

output "fc_service_name" { value = alicloud_fc_service.wallet_api.name }
