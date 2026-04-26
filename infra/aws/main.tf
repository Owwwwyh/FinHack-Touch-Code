terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project = "tng-finhack"
      Env     = var.environment
    }
  }
}

# Variables
variable "aws_region" {
  description = "AWS region (ap-southeast-1 for Singapore)"
  type        = string
  default     = "ap-southeast-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "demo"
}

variable "project_prefix" {
  description = "Project name prefix"
  type        = string
  default     = "tng"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "finhack"
}

variable "aws_account_id" {
  description = "AWS account ID used to render deploy-time ARNs in scaffold outputs"
  type        = string
  default     = ""
}

variable "pre_signup_lambda_arn" {
  description = "ARN of the Cognito pre-signup Lambda"
  type        = string
  default     = ""
}

variable "callback_urls" {
  description = "OAuth callback URLs for the mobile app"
  type        = list(string)
  default     = ["http://localhost:8080/callback"]
}

variable "logout_urls" {
  description = "OAuth logout URLs for the mobile app"
  type        = list(string)
  default     = ["http://localhost:8080/logout"]
}

variable "alibaba_access_key_id" {
  description = "Alibaba Cloud Access Key ID for future cross-cloud automation"
  type        = string
  default     = ""
  sensitive   = true
}

variable "alibaba_secret_access_key" {
  description = "Alibaba Cloud Secret Access Key for future cross-cloud automation"
  type        = string
  default     = ""
  sensitive   = true
}

variable "alibaba_region" {
  description = "Alibaba Cloud region"
  type        = string
  default     = "ap-southeast-3"
}

variable "alibaba_account_id" {
  description = "Alibaba Cloud account ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "alibaba_ingest_url" {
  description = "HTTPS ingress URL on Alibaba for settlement.completed callbacks"
  type        = string
  default     = ""
}

variable "bridge_hmac_secret" {
  description = "Shared HMAC secret for AWS<->Alibaba bridge calls"
  type        = string
  default     = ""
  sensitive   = true
}

variable "cognito_client_secret" {
  description = "Optional Cognito client secret placeholder"
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_bridge_custom_domain" {
  description = "Optional custom domain for the AWS inbound bridge HTTP endpoint"
  type        = string
  default     = ""
}

variable "aws_bridge_custom_domain_certificate_arn" {
  description = "Optional ACM certificate ARN for the AWS bridge custom domain"
  type        = string
  default     = ""
}

variable "stepfunctions_arn" {
  description = "Optional Step Functions ARN for model publish events"
  type        = string
  default     = ""
}

variable "dlq_arn" {
  description = "Optional dead-letter queue ARN for EventBridge rules"
  type        = string
  default     = ""
}

variable "lambda_package_zip" {
  description = "Path to the packaged shared AWS Lambda zip built by infra/aws/lambda/build_package.sh"
  type        = string
  default     = ""
}

module "kms" {
  source = "./kms"
}

module "s3" {
  source      = "./s3"
  kms_key_arn = module.kms.kms_key_arn
}

module "dynamodb" {
  source      = "./dynamodb"
  kms_key_arn = module.kms.kms_key_arn
}

module "secrets" {
  source = "./secrets"

  alibaba_access_key_id     = var.alibaba_access_key_id
  alibaba_secret_access_key = var.alibaba_secret_access_key
  alibaba_region            = var.alibaba_region
  alibaba_account_id        = var.alibaba_account_id
  alibaba_ingest_url        = var.alibaba_ingest_url
  bridge_hmac_secret        = var.bridge_hmac_secret
  cognito_client_secret     = var.cognito_client_secret
  lambda_role_arns          = []
}

module "lambda" {
  source = "./lambda"

  aws_region                     = var.aws_region
  aws_account_id                 = var.aws_account_id
  environment                    = var.environment
  project_prefix                 = var.project_prefix
  app_name                       = var.app_name
  dynamo_ledger_table_name       = module.dynamodb.token_ledger_table_name
  dynamo_nonce_table_name        = module.dynamodb.nonce_seen_table_name
  dynamo_pubkey_cache_table_name = module.dynamodb.pubkey_cache_table_name
  cross_cloud_bus_name           = local.cross_cloud_bus_name
  models_bucket_name             = module.s3.models_bucket_name
  alibaba_ingest_url_secret_name = module.secrets.alibaba_ingest_secret_name
  alibaba_ingest_url_secret_arn  = module.secrets.alibaba_ingest_secret_arn
  bridge_hmac_secret_name        = module.secrets.bridge_hmac_secret_name
  bridge_hmac_secret_arn         = module.secrets.bridge_hmac_secret_arn
  lambda_package_zip             = var.lambda_package_zip
}

module "cognito" {
  source = "./cognito"

  aws_region            = var.aws_region
  pre_signup_lambda_arn = var.pre_signup_lambda_arn
  callback_urls         = var.callback_urls
  logout_urls           = var.logout_urls
  models_bucket_name    = module.s3.models_bucket_name
}

module "eventbridge" {
  source = "./eventbridge"

  bridge_out_lambda_arn = module.lambda.eb_cross_cloud_bridge_out_arn
  stepfunctions_arn     = var.stepfunctions_arn
  dlq_arn               = var.dlq_arn
  cross_cloud_bus_name  = local.cross_cloud_bus_name
}

module "apigw" {
  source = "./apigw"

  aws_region                    = var.aws_region
  custom_domain                 = var.aws_bridge_custom_domain
  custom_domain_certificate_arn = var.aws_bridge_custom_domain_certificate_arn
  bridge_in_lambda_name         = module.lambda.eb_cross_cloud_bridge_in_name
  bridge_in_lambda_invoke_arn   = module.lambda.eb_cross_cloud_bridge_in_invoke_arn
}

# Outputs
output "region" {
  value = var.aws_region
}

output "environment" {
  value = var.environment
}

output "aws_bridge_invoke_url" {
  value = module.apigw.aws_bridge_invoke_url
}

output "settle_batch_lambda_name" {
  value = module.lambda.settle_batch_name
}

output "eb_cross_cloud_bridge_in_name" {
  value = module.lambda.eb_cross_cloud_bridge_in_name
}

output "eb_cross_cloud_bridge_out_name" {
  value = module.lambda.eb_cross_cloud_bridge_out_name
}

output "cognito_jwks_uri" {
  value = module.cognito.jwks_uri
}

# Local values
locals {
  project              = "${var.project_prefix}-${var.app_name}"
  cross_cloud_bus_name = "${var.project_prefix}-${var.app_name}-cross-cloud"
  common_tags = {
    Project = "tng-finhack"
    Env     = var.environment
  }
}
