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

# Outputs
output "region" {
  value = var.aws_region
}

output "environment" {
  value = var.environment
}

# Local values
locals {
  project    = "${var.project_prefix}-${var.app_name}"
  common_tags = {
    Project = "tng-finhack"
    Env     = var.environment
  }
}
