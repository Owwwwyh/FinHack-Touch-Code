# Scaffolded Lambda deployment contract for Phase 1 demo wiring.
# The real cloud apply still needs credentials plus packaged artifacts or images.

variable "aws_region" {
  type = string
}

variable "aws_account_id" {
  type    = string
  default = ""
}

variable "environment" {
  type = string
}

variable "project_prefix" {
  type = string
}

variable "app_name" {
  type = string
}

variable "dynamo_ledger_table_name" {
  type = string
}

variable "dynamo_nonce_table_name" {
  type = string
}

variable "dynamo_pubkey_cache_table_name" {
  type = string
}

variable "cross_cloud_bus_name" {
  type = string
}

variable "models_bucket_name" {
  type = string
}

variable "alibaba_ingest_url_secret_name" {
  type = string
}

variable "bridge_hmac_secret_name" {
  type      = string
  sensitive = true
}

locals {
  project = "${var.project_prefix}-${var.app_name}"

  lambda_functions = {
    settle_batch = {
      function_name = "${local.project}-settle-batch"
      source_path   = "../../../backend/aws_lambda/settle_batch"
      handler       = "handler.handler"
      runtime       = "python3.12"
      timeout       = 30
      memory_size   = 512
      environment = {
        DYNAMO_LEDGER_TABLE = var.dynamo_ledger_table_name
        DYNAMO_NONCE_TABLE  = var.dynamo_nonce_table_name
        DYNAMO_PUBKEY_CACHE = var.dynamo_pubkey_cache_table_name
        AWS_CROSS_CLOUD_BUS = var.cross_cloud_bus_name
        MODEL_BUCKET        = var.models_bucket_name
        LOG_LEVEL           = "INFO"
      }
    }
    eb_cross_cloud_bridge_in = {
      function_name = "${local.project}-eb-cross-cloud-bridge-in"
      source_path   = "../../../backend/aws_lambda/eb_cross_cloud_bridge_in"
      handler       = "handler.handler"
      runtime       = "python3.12"
      timeout       = 15
      memory_size   = 256
      environment = {
        AWS_BRIDGE_HMAC_SECRET = "secret://${var.bridge_hmac_secret_name}"
        LOG_LEVEL              = "INFO"
      }
    }
    eb_cross_cloud_bridge_out = {
      function_name = "${local.project}-eb-cross-cloud-bridge-out"
      source_path   = "../../../backend/aws_lambda/eb_cross_cloud_bridge_out"
      handler       = "handler.handler"
      runtime       = "python3.12"
      timeout       = 15
      memory_size   = 256
      environment = {
        ALIBABA_INGEST_URL     = "secret://${var.alibaba_ingest_url_secret_name}"
        AWS_BRIDGE_HMAC_SECRET = "secret://${var.bridge_hmac_secret_name}"
        LOG_LEVEL              = "INFO"
      }
    }
  }
}

resource "terraform_data" "function_contracts" {
  for_each = local.lambda_functions
  input    = each.value
}

output "settle_batch_name" {
  value = terraform_data.function_contracts["settle_batch"].input.function_name
}

output "settle_batch_arn" {
  value = "arn:aws:lambda:${var.aws_region}:${var.aws_account_id}:function:${terraform_data.function_contracts["settle_batch"].input.function_name}"
}

output "eb_cross_cloud_bridge_in_name" {
  value = terraform_data.function_contracts["eb_cross_cloud_bridge_in"].input.function_name
}

output "eb_cross_cloud_bridge_in_arn" {
  value = "arn:aws:lambda:${var.aws_region}:${var.aws_account_id}:function:${terraform_data.function_contracts["eb_cross_cloud_bridge_in"].input.function_name}"
}

output "eb_cross_cloud_bridge_out_name" {
  value = terraform_data.function_contracts["eb_cross_cloud_bridge_out"].input.function_name
}

output "eb_cross_cloud_bridge_out_arn" {
  value = "arn:aws:lambda:${var.aws_region}:${var.aws_account_id}:function:${terraform_data.function_contracts["eb_cross_cloud_bridge_out"].input.function_name}"
}

output "lambda_role_arns" {
  value = [
    for function_name, config in local.lambda_functions :
    "arn:aws:iam::${var.aws_account_id}:role/${config.function_name}-role"
  ]
}

output "function_environment" {
  value = {
    for function_name, config in local.lambda_functions :
    function_name => config.environment
  }
}
