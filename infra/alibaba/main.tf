terraform {
  required_version = ">= 1.5"
  required_providers {
    alibabacloudstack = {
      source  = "aliyun/alibabacloudstack"
      version = "~> 1.0"
    }
  }
}

provider "alibabacloudstack" {
  access_key = var.alibaba_access_key
  secret_key = var.alibaba_secret_key
  region     = var.alibaba_region

  skip_region_validation = true
}

# Variables
variable "alibaba_access_key" {
  description = "Alibaba Cloud access key"
  type        = string
  sensitive   = true
}

variable "alibaba_secret_key" {
  description = "Alibaba Cloud secret key"
  type        = string
  sensitive   = true
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

# Locals
locals {
  project    = "tng-finhack"
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
