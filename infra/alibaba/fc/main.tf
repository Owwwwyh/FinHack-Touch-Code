# Real Alibaba Function Compute V3 deployment for the six live wallet API routes.

terraform {
  required_providers {
    alicloud = {
      source = "aliyun/alicloud"
    }
  }
}

variable "region" {
  type = string
}

variable "ots_instance" {
  type = string
}

variable "ots_endpoint" {
  type = string
}

variable "oss_pubkey_bucket" {
  type = string
}

variable "oss_model_bucket" {
  type = string
}

variable "eas_endpoint" {
  type    = string
  default = ""
}

variable "aws_bridge_url" {
  type    = string
  default = ""
}

variable "aws_bridge_hmac_secret" {
  type      = string
  default   = ""
  sensitive = true
}

variable "cognito_jwks_url" {
  type = string
}

variable "cognito_issuer" {
  type = string
}

variable "table_names" {
  type = object({
    devices         = string
    wallets         = string
    pending_batches = string
    score_policies  = string
  })
}

variable "package_path" {
  type    = string
  default = ""
}

locals {
  runtime_package_path = trimspace(var.package_path) != "" ? var.package_path : "${path.module}/dist/fc_bundle.zip"
  package_hash         = filesha256(local.runtime_package_path)
  package_object_key   = "fc/fc_bundle-${substr(local.package_hash, 0, 12)}.zip"

  common_env = {
    TABLESTORE_ENDPOINT        = var.ots_endpoint
    TABLESTORE_INSTANCE        = var.ots_instance
    OSS_ENDPOINT               = "https://oss-${var.region}.aliyuncs.com"
    OSS_BUCKET_PUBKEYS         = var.oss_pubkey_bucket
    OSS_MODEL_BUCKET           = var.oss_model_bucket
    COGNITO_JWKS_URL           = var.cognito_jwks_url
    COGNITO_ISSUER             = var.cognito_issuer
    AWS_BRIDGE_HMAC_SECRET     = var.aws_bridge_hmac_secret
    AWS_BRIDGE_URL             = var.aws_bridge_url
    EAS_ENDPOINT               = var.eas_endpoint
    EAS_TOKEN                  = ""
    EAS_TIMEOUT_SECONDS        = "0.8"
    TABLE_NAME_DEVICES         = var.table_names.devices
    TABLE_NAME_WALLETS         = var.table_names.wallets
    TABLE_NAME_PENDING_BATCHES = var.table_names.pending_batches
    TABLE_NAME_SCORE_POLICIES  = var.table_names.score_policies
    OTS_INSTANCE               = var.ots_instance
    OSS_PUBKEY_BUCKET          = var.oss_pubkey_bucket
  }

  routes = {
    device_register = {
      method        = "POST"
      path          = "/v1/devices/register"
      function_name = "device-register"
      handler_path  = "../../../backend/device_register_fc.py"
      handler       = "device_register_fc.handler"
      auth          = "jwt"
      cpu           = 0.25
      memory_size   = 512
      timeout       = 15
    }
    wallet_balance = {
      method        = "GET"
      path          = "/v1/wallet/balance"
      function_name = "wallet-balance"
      handler_path  = "../../../backend/wallet_balance_fc.py"
      handler       = "wallet_balance_fc.handler"
      auth          = "jwt"
      cpu           = 0.25
      memory_size   = 512
      timeout       = 15
    }
    tokens_settle = {
      method        = "POST"
      path          = "/v1/tokens/settle"
      function_name = "tokens-settle"
      handler_path  = "../../../backend/tokens_settle_fc.py"
      handler       = "tokens_settle_fc.handler"
      auth          = "jwt"
      cpu           = 0.5
      memory_size   = 768
      timeout       = 30
    }
    score_refresh = {
      method        = "POST"
      path          = "/v1/score/refresh"
      function_name = "score-refresh"
      handler_path  = "../../../backend/score_refresh_fc.py"
      handler       = "score_refresh_fc.handler"
      auth          = "jwt"
      cpu           = 0.25
      memory_size   = 512
      timeout       = 15
    }
    score_policy = {
      method        = "GET"
      path          = "/v1/score/policy"
      function_name = "score-policy"
      handler_path  = "../../../backend/score_policy_fc.py"
      handler       = "score_policy_fc.handler"
      auth          = "jwt"
      cpu           = 0.25
      memory_size   = 512
      timeout       = 15
    }
    aws_bridge = {
      method        = "POST"
      path          = "/v1/_internal/eb/aws-bridge"
      function_name = "eb-cross-cloud-ingest"
      handler_path  = "../../../backend/aws_bridge_ingest_fc.py"
      handler       = "aws_bridge_ingest_fc.handler"
      auth          = "hmac"
      cpu           = 0.25
      memory_size   = 512
      timeout       = 15
    }
  }
}

resource "alicloud_ram_role" "fc_runtime" {
  role_name = "tng-finhack-fc-runtime"
  assume_role_policy_document = jsonencode({
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = ["fc.aliyuncs.com"]
        }
      }
    ]
    Version = "1"
  })
  description = "Runtime role for TNG FinHack Alibaba FC functions"
  force       = true
}

resource "alicloud_ram_role_policy_attachment" "fc_oss" {
  role_name   = alicloud_ram_role.fc_runtime.role_name
  policy_name = "AliyunOSSFullAccess"
  policy_type = "System"
}

resource "alicloud_ram_role_policy_attachment" "fc_ots" {
  role_name   = alicloud_ram_role.fc_runtime.role_name
  policy_name = "AliyunOTSFullAccess"
  policy_type = "System"
}

resource "alicloud_oss_bucket_object" "package" {
  bucket       = var.oss_model_bucket
  key          = local.package_object_key
  source       = local.runtime_package_path
  content_type = "application/zip"
}

resource "alicloud_fcv3_function" "routes" {
  for_each = local.routes

  function_name         = each.value.function_name
  description           = "TNG FinHack route ${each.value.method} ${each.value.path}"
  role                  = alicloud_ram_role.fc_runtime.arn
  runtime               = "python3.10"
  handler               = each.value.handler
  cpu                   = each.value.cpu
  memory_size           = each.value.memory_size
  timeout               = each.value.timeout
  disk_size             = 512
  internet_access       = true
  instance_concurrency  = 10
  environment_variables = local.common_env

  code {
    oss_bucket_name = var.oss_model_bucket
    oss_object_name = alicloud_oss_bucket_object.package.key
  }

  log_config {
    log_begin_rule = "None"
  }
}

resource "alicloud_fcv3_function" "public_api" {
  function_name         = "public-api"
  description           = "TNG FinHack aggregated public API entrypoint"
  role                  = alicloud_ram_role.fc_runtime.arn
  runtime               = "python3.10"
  handler               = "public_api_fc.handler"
  cpu                   = 0.5
  memory_size           = 768
  timeout               = 30
  disk_size             = 512
  internet_access       = true
  instance_concurrency  = 10
  environment_variables = local.common_env

  code {
    oss_bucket_name = var.oss_model_bucket
    oss_object_name = alicloud_oss_bucket_object.package.key
  }

  log_config {
    log_begin_rule = "None"
  }
}

resource "alicloud_fcv3_trigger" "http" {
  for_each = local.routes

  function_name = alicloud_fcv3_function.routes[each.key].function_name
  qualifier     = "LATEST"
  trigger_type  = "http"
  trigger_name  = "${each.value.function_name}-http"
  description   = "Public HTTP trigger for ${each.value.path}"
  trigger_config = jsonencode({
    authType           = "anonymous"
    disableURLInternet = false
    methods            = [each.value.method]
  })
}

resource "alicloud_fcv3_trigger" "public_api" {
  function_name = alicloud_fcv3_function.public_api.function_name
  qualifier     = "LATEST"
  trigger_type  = "http"
  trigger_name  = "public-api-http"
  description   = "Shared HTTP trigger for the public /v1 API surface"
  trigger_config = jsonencode({
    authType           = "anonymous"
    disableURLInternet = false
    methods            = ["GET", "POST"]
  })
}

output "routes" {
  value = {
    for route_name, route in local.routes :
    route_name => merge(route, {
      backend_url = alicloud_fcv3_trigger.http[route_name].http_trigger[0].url_internet
    })
  }
}

output "function_environment" {
  value = {
    for route_name, route in local.routes :
    route.function_name => local.common_env
  }
}

output "public_api_url" {
  value = alicloud_fcv3_trigger.public_api.http_trigger[0].url_internet
}
