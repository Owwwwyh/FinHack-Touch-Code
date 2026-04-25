terraform {
  required_version = ">= 1.5"
  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = "~> 1.274"
    }
  }
}

provider "alicloud" {
  access_key = trimspace(var.alibaba_access_key) != "" ? var.alibaba_access_key : null
  secret_key = trimspace(var.alibaba_secret_key) != "" ? var.alibaba_secret_key : null
  account_id = trimspace(var.account_id) != "" ? var.account_id : null
  profile    = var.alibaba_profile
  region     = var.alibaba_region

  skip_region_validation = true
}

# Variables
variable "alibaba_access_key" {
  description = "Alibaba Cloud access key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "alibaba_secret_key" {
  description = "Alibaba Cloud secret key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "alibaba_profile" {
  description = "Alibaba Cloud CLI profile to use when AK/SK are not provided"
  type        = string
  default     = "finhack-ali"
}

variable "alibaba_region" {
  description = "Alibaba region (ap-southeast-3 for KL)"
  type        = string
  default     = "ap-southeast-3"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "demo"
}

variable "aws_cognito_jwks_uri" {
  description = "AWS Cognito JWKS URI for JWT verification"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID (for EventBridge cross-cloud)"
  type        = string
}

variable "account_id" {
  description = "Alibaba Cloud account ID for globally-unique OSS bucket naming"
  type        = string
  default     = ""
}

variable "public_api_domain" {
  description = "Public custom domain for the hackathon demo API"
  type        = string
  default     = "api-finhack.example.com"
}

variable "aws_bridge_url" {
  description = "AWS inbound bridge URL used by tokens-settle"
  type        = string
  default     = ""
}

variable "aws_bridge_hmac_secret" {
  description = "Shared HMAC secret for bridge requests"
  type        = string
  default     = ""
  sensitive   = true
}

variable "eas_endpoint" {
  description = "PAI-EAS HTTPS endpoint for score refresh"
  type        = string
  default     = ""
}

# Locals
locals {
  project        = "tng-finhack"
  cognito_issuer = trimsuffix(var.aws_cognito_jwks_uri, "/.well-known/jwks.json")
  common_tags = {
    Project = "tng-finhack"
    Env     = var.environment
  }
}

# Outputs
output "region" {
  value = var.alibaba_region
}

output "environment" {
  value = var.environment
}

module "oss" {
  source = "./oss"

  account_id = var.account_id
  region     = var.alibaba_region
}

module "tablestore" {
  source = "./tablestore"

  account_id = var.account_id
  region     = var.alibaba_region
}

module "eas" {
  source = "./eas"

  endpoint     = var.eas_endpoint
  model_bucket = module.oss.models_bucket
}

module "fc" {
  source = "./fc"

  region                 = var.alibaba_region
  ots_instance           = module.tablestore.tablestore_instance_name
  ots_endpoint           = module.tablestore.public_endpoint
  oss_pubkey_bucket      = module.oss.pubkeys_bucket
  oss_model_bucket       = module.oss.models_bucket
  eas_endpoint           = module.eas.endpoint
  aws_bridge_url         = var.aws_bridge_url
  aws_bridge_hmac_secret = var.aws_bridge_hmac_secret
  cognito_jwks_url       = var.aws_cognito_jwks_uri
  cognito_issuer         = local.cognito_issuer
  table_names = {
    devices         = module.tablestore.devices_table_name
    wallets         = module.tablestore.wallets_table_name
    pending_batches = module.tablestore.pending_batches_table_name
    score_policies  = module.tablestore.score_policies_table_name
  }
}

module "apigw" {
  source = "./apigw"

  custom_domain = var.public_api_domain
  route_map     = module.fc.routes
}

output "public_api_base_url" {
  value = module.apigw.public_api_base_url
}

output "public_api_routes" {
  value = {
    for route_name, route in module.apigw.route_map :
    route_name => {
      method      = route.method
      path        = route.path
      backend_url = route.backend_url
      auth        = route.auth
    }
  }
}

output "score_refresh_endpoint" {
  value = module.eas.endpoint
}
