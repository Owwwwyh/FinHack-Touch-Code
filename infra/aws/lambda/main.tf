terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

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

variable "alibaba_ingest_url_secret_arn" {
  type = string
}

variable "bridge_hmac_secret_name" {
  type      = string
  sensitive = true
}

variable "bridge_hmac_secret_arn" {
  type      = string
  sensitive = true
}

variable "lambda_package_zip" {
  description = "Path to the packaged shared AWS Lambda zip built by build_package.sh"
  type        = string
  default     = ""
}

variable "log_retention_in_days" {
  type    = number
  default = 14
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

locals {
  project = "${var.project_prefix}-${var.app_name}"

  account_id         = trimspace(var.aws_account_id) != "" ? var.aws_account_id : data.aws_caller_identity.current.account_id
  lambda_package_zip = trimspace(var.lambda_package_zip) != "" ? var.lambda_package_zip : "${path.module}/dist/aws_lambda_bundle.zip"
  cross_cloud_bus_arn = format(
    "arn:%s:events:%s:%s:event-bus/%s",
    data.aws_partition.current.partition,
    var.aws_region,
    local.account_id,
    var.cross_cloud_bus_name,
  )

  lambda_functions = {
    settle_batch = {
      function_name                   = "${local.project}-settle-batch"
      handler                         = "aws_lambda.settle_batch.handler.handler"
      runtime                         = "python3.12"
      timeout                         = 30
      memory_size                     = 512
      reserved_concurrent_executions  = 50
      environment = {
        DYNAMO_LEDGER_TABLE = var.dynamo_ledger_table_name
        DYNAMO_NONCE_TABLE  = var.dynamo_nonce_table_name
        DYNAMO_PUBKEY_CACHE = var.dynamo_pubkey_cache_table_name
        AWS_CROSS_CLOUD_BUS = var.cross_cloud_bus_name
        MODEL_BUCKET        = var.models_bucket_name
        LOG_LEVEL           = "INFO"
      }
      statements = [
        {
          sid = "LedgerWrites"
          actions = [
            "dynamodb:GetItem",
            "dynamodb:PutItem",
          ]
          resources = [
            format(
              "arn:%s:dynamodb:%s:%s:table/%s",
              data.aws_partition.current.partition,
              var.aws_region,
              local.account_id,
              var.dynamo_ledger_table_name,
            ),
            format(
              "arn:%s:dynamodb:%s:%s:table/%s",
              data.aws_partition.current.partition,
              var.aws_region,
              local.account_id,
              var.dynamo_nonce_table_name,
            ),
            format(
              "arn:%s:dynamodb:%s:%s:table/%s",
              data.aws_partition.current.partition,
              var.aws_region,
              local.account_id,
              var.dynamo_pubkey_cache_table_name,
            ),
          ]
        },
        {
          sid       = "EmitCrossCloudEvents"
          actions   = ["events:PutEvents"]
          resources = [local.cross_cloud_bus_arn]
        },
      ]
    }
    eb_cross_cloud_bridge_in = {
      function_name                   = "${local.project}-eb-cross-cloud-bridge-in"
      handler                         = "aws_lambda.eb_cross_cloud_bridge_in.handler.handler"
      runtime                         = "python3.12"
      timeout                         = 15
      memory_size                     = 256
      reserved_concurrent_executions  = 10
      environment = {
        DYNAMO_LEDGER_TABLE      = var.dynamo_ledger_table_name
        DYNAMO_NONCE_TABLE       = var.dynamo_nonce_table_name
        DYNAMO_PUBKEY_CACHE      = var.dynamo_pubkey_cache_table_name
        AWS_CROSS_CLOUD_BUS      = var.cross_cloud_bus_name
        AWS_BRIDGE_HMAC_SECRET   = "secret://${var.bridge_hmac_secret_name}"
        MODEL_BUCKET             = var.models_bucket_name
        LOG_LEVEL                = "INFO"
      }
      statements = [
        {
          sid = "LedgerWrites"
          actions = [
            "dynamodb:GetItem",
            "dynamodb:PutItem",
          ]
          resources = [
            format(
              "arn:%s:dynamodb:%s:%s:table/%s",
              data.aws_partition.current.partition,
              var.aws_region,
              local.account_id,
              var.dynamo_ledger_table_name,
            ),
            format(
              "arn:%s:dynamodb:%s:%s:table/%s",
              data.aws_partition.current.partition,
              var.aws_region,
              local.account_id,
              var.dynamo_nonce_table_name,
            ),
            format(
              "arn:%s:dynamodb:%s:%s:table/%s",
              data.aws_partition.current.partition,
              var.aws_region,
              local.account_id,
              var.dynamo_pubkey_cache_table_name,
            ),
          ]
        },
        {
          sid       = "EmitCrossCloudEvents"
          actions   = ["events:PutEvents"]
          resources = [local.cross_cloud_bus_arn]
        },
        {
          sid       = "ReadBridgeSecret"
          actions   = ["secretsmanager:GetSecretValue"]
          resources = [var.bridge_hmac_secret_arn]
        },
      ]
    }
    eb_cross_cloud_bridge_out = {
      function_name                   = "${local.project}-eb-cross-cloud-bridge-out"
      handler                         = "aws_lambda.eb_cross_cloud_bridge_out.handler.handler"
      runtime                         = "python3.12"
      timeout                         = 15
      memory_size                     = 256
      reserved_concurrent_executions  = 5
      environment = {
        ALIBABA_INGEST_URL     = "secret://${var.alibaba_ingest_url_secret_name}"
        AWS_BRIDGE_HMAC_SECRET = "secret://${var.bridge_hmac_secret_name}"
        LOG_LEVEL              = "INFO"
      }
      statements = [
        {
          sid = "ReadBridgeSecrets"
          actions = [
            "secretsmanager:GetSecretValue",
          ]
          resources = [
            var.alibaba_ingest_url_secret_arn,
            var.bridge_hmac_secret_arn,
          ]
        },
      ]
    }
  }
}

data "aws_iam_policy_document" "lambda_inline" {
  for_each = local.lambda_functions

  dynamic "statement" {
    for_each = each.value.statements

    content {
      sid       = statement.value.sid
      effect    = "Allow"
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role" "lambda" {
  for_each = local.lambda_functions

  name               = "${each.value.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Name = "${each.value.function_name}-role"
  }
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  for_each = local.lambda_functions

  role       = aws_iam_role.lambda[each.key].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "function" {
  for_each = local.lambda_functions

  name   = "${each.value.function_name}-policy"
  role   = aws_iam_role.lambda[each.key].id
  policy = data.aws_iam_policy_document.lambda_inline[each.key].json
}

resource "aws_cloudwatch_log_group" "function" {
  for_each = local.lambda_functions

  name              = "/aws/lambda/${each.value.function_name}"
  retention_in_days = var.log_retention_in_days
}

resource "aws_lambda_function" "function" {
  for_each = local.lambda_functions

  function_name                  = each.value.function_name
  description                    = "TNG Finhack ${replace(each.key, "_", "-")} Lambda"
  role                           = aws_iam_role.lambda[each.key].arn
  runtime                        = each.value.runtime
  handler                        = each.value.handler
  filename                       = local.lambda_package_zip
  source_code_hash               = filebase64sha256(local.lambda_package_zip)
  timeout                        = each.value.timeout
  memory_size                    = each.value.memory_size
  reserved_concurrent_executions = each.value.reserved_concurrent_executions
  architectures                  = ["x86_64"]

  environment {
    variables = each.value.environment
  }

  depends_on = [
    aws_cloudwatch_log_group.function,
    aws_iam_role_policy.function,
    aws_iam_role_policy_attachment.basic_execution,
  ]
}

output "settle_batch_name" {
  value = aws_lambda_function.function["settle_batch"].function_name
}

output "settle_batch_arn" {
  value = aws_lambda_function.function["settle_batch"].arn
}

output "settle_batch_invoke_arn" {
  value = aws_lambda_function.function["settle_batch"].invoke_arn
}

output "eb_cross_cloud_bridge_in_name" {
  value = aws_lambda_function.function["eb_cross_cloud_bridge_in"].function_name
}

output "eb_cross_cloud_bridge_in_arn" {
  value = aws_lambda_function.function["eb_cross_cloud_bridge_in"].arn
}

output "eb_cross_cloud_bridge_in_invoke_arn" {
  value = aws_lambda_function.function["eb_cross_cloud_bridge_in"].invoke_arn
}

output "eb_cross_cloud_bridge_out_name" {
  value = aws_lambda_function.function["eb_cross_cloud_bridge_out"].function_name
}

output "eb_cross_cloud_bridge_out_arn" {
  value = aws_lambda_function.function["eb_cross_cloud_bridge_out"].arn
}

output "eb_cross_cloud_bridge_out_invoke_arn" {
  value = aws_lambda_function.function["eb_cross_cloud_bridge_out"].invoke_arn
}

output "lambda_role_arns" {
  value = [
    for function_name, role in aws_iam_role.lambda :
    role.arn
  ]
}

output "function_environment" {
  value = {
    for function_name, config in local.lambda_functions :
    function_name => config.environment
  }
}
