# Alibaba Cloud Infrastructure - Main Provider
# Per docs/06-alibaba-services.md and docs/13-deployment.md

terraform {
  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = "~> 1.210"
    }
  }

  backend "oss" {
    bucket = "tng-finhack-terraform-state"
    prefix = "alibaba/"
  }
}

provider "alicloud" {
  region = var.alibaba_region
}

# Common tags
locals {
  common_tags = {
    Project = "tng-finhack"
    Env     = "demo"
  }
}

variable "alibaba_region" {
  default = "ap-southeast-3"
}

variable "alibaba_zone_id" {
  default = "ap-southeast-3a"
}

variable "rds_password" {
  description = "RDS app user password"
  type        = string
  sensitive   = true
}

variable "rds_dsn" {
  description = "RDS connection DSN for FC functions"
  type        = string
  default     = "mysql://tng_app:changeme@localhost:3306/tng_history"
}

variable "eas_endpoint" {
  description = "PAI-EAS endpoint URL"
  type        = string
  default     = "http://localhost:8080/score"
}

variable "eas_image_url" {
  description = "PAI-EAS container image URL from ACR"
  type        = string
  default     = "registry.ap-southeast-3.aliyuncs.com/tng-finhack/credit-score:latest"
}

variable "aws_bridge_url" {
  description = "AWS cross-cloud bridge URL"
  type        = string
  default     = ""
}

variable "hmac_secret" {
  description = "Cross-cloud HMAC secret"
  type        = string
  sensitive   = true
  default     = "demo-hmac-secret"
}

variable "cognito_jwks_url" {
  description = "AWS Cognito JWKS URL for JWT verification"
  type        = string
  default     = ""
}

variable "fc_role_arn" {
  description = "RAM role ARN for FC functions"
  type        = string
  default     = ""
}

variable "fc_wallet_update_endpoint" {
  description = "FC endpoint for wallet balance update on settlement"
  type        = string
  default     = ""
}
