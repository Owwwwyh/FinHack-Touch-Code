# Alibaba OSS buckets for model artifacts, pubkeys, and static assets
# See docs/06-alibaba-services.md §3

terraform {
  required_providers {
    alicloud = {
      source = "aliyun/alicloud"
    }
  }
}

# Models bucket (TF Lite artifacts)
resource "alicloud_oss_bucket" "models" {
  bucket = "${local.project}-models-${var.account_id}"

  acl = "private"

  tags = {
    Name = "${local.project}-models"
  }
}

# Static assets bucket (app config, splash, ToS, Privacy)
resource "alicloud_oss_bucket" "static" {
  bucket = "${local.project}-static-${var.account_id}"

  acl = "private"

  tags = {
    Name = "${local.project}-static"
  }
}

# Bucket CORS policy for mobile app
resource "alicloud_oss_bucket_cors" "static_cors" {
  bucket = alicloud_oss_bucket.static.bucket

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = [
      "https://*.tngfinhack.app",
      "tngfinhack://"
    ]
    max_age_seconds = 3600
  }
}

# Variables
variable "account_id" {
  description = "Alibaba account ID (for unique bucket naming)"
  type        = string
}

variable "region" {
  description = "Alibaba region used to render bucket hostnames"
  type        = string
}

# Locals
locals {
  project = "tng-finhack"
}

# Outputs
output "models_bucket" {
  value = alicloud_oss_bucket.models.bucket
}

output "models_bucket_domain" {
  value = format("%s.oss-%s.aliyuncs.com", alicloud_oss_bucket.models.bucket, var.region)
}

output "pubkeys_bucket" {
  # Temporary hackathon simplification: store device public keys in the models
  # bucket under a dedicated prefix until the account allows a separate OSS bucket.
  value = alicloud_oss_bucket.models.bucket
}

output "pubkeys_bucket_domain" {
  value = format("%s.oss-%s.aliyuncs.com", alicloud_oss_bucket.models.bucket, var.region)
}

output "static_bucket" {
  value = alicloud_oss_bucket.static.bucket
}

output "static_bucket_domain" {
  value = format("%s.oss-%s.aliyuncs.com", alicloud_oss_bucket.static.bucket, var.region)
}
