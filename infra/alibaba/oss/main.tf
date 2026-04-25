# Alibaba OSS buckets for model artifacts, pubkeys, and static assets
# See docs/06-alibaba-services.md §3

terraform {
  required_providers {
    alibabacloudstack = {
      source = "aliyun/alibabacloudstack"
    }
  }
}

# Models bucket (TF Lite artifacts)
resource "alibabacloudstack_oss_bucket" "models" {
  bucket = "${local.project}-models-${var.account_id}"

  acl = "private"

  sse_rule {
    sse_algorithm = "AES256"
  }

  tags = {
    Name = "${local.project}-models"
  }
}

resource "alibabacloudstack_oss_bucket_lifecycle" "models_lifecycle" {
  bucket = alibabacloudstack_oss_bucket.models.bucket

  rule {
    id     = "archive-old-models"
    status = "Enabled"

    prefix = "credit/v"

    noncurrent_version_expiration {
      days = 60
    }

    transition {
      days          = 60
      storage_class = "IA"
    }
  }
}

# Pubkeys bucket (device public key directory)
resource "alibabacloudstack_oss_bucket" "pubkeys" {
  bucket = "${local.project}-pubkeys-${var.account_id}"

  acl = "private"

  sse_rule {
    sse_algorithm = "AES256"
  }

  tags = {
    Name = "${local.project}-pubkeys"
  }
}

# Static assets bucket (app config, splash, ToS, Privacy)
resource "alibabacloudstack_oss_bucket" "static" {
  bucket = "${local.project}-static-${var.account_id}"

  acl = "private"

  sse_rule {
    sse_algorithm = "AES256"
  }

  tags = {
    Name = "${local.project}-static"
  }
}

# Bucket CORS policy for mobile app
resource "alibabacloudstack_oss_bucket_cors" "static_cors" {
  bucket = alibabacloudstack_oss_bucket.static.bucket

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
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

# Locals
locals {
  project = "tng-finhack"
}

# Outputs
output "models_bucket" {
  value = alibabacloudstack_oss_bucket.models.bucket
}

output "models_bucket_domain" {
  value = alibabacloudstack_oss_bucket.models.bucket_domain_name
}

output "pubkeys_bucket" {
  value = alibabacloudstack_oss_bucket.pubkeys.bucket
}

output "pubkeys_bucket_domain" {
  value = alibabacloudstack_oss_bucket.pubkeys.bucket_domain_name
}

output "static_bucket" {
  value = alibabacloudstack_oss_bucket.static.bucket
}

output "static_bucket_domain" {
  value = alibabacloudstack_oss_bucket.static.bucket_domain_name
}
