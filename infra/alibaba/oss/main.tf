# Alibaba OSS Buckets per docs/06-alibaba-services.md §3

resource "alicloud_oss_bucket" "models" {
  bucket = "tng-finhack-models"
  acl    = "private"
  tags   = local.common_tags

  lifecycle_rule {
    id      = "archive-old-models"
    enabled = true
    prefix  = "credit/"
    transition {
      days          = 60
      storage_class = "IA"
    }
  }

  server_side_encryption_configuration {
    rule {
      sse_algorithm = "KMS"
    }
  }
}

resource "alicloud_oss_bucket" "pubkeys" {
  bucket = "tng-finhack-pubkeys"
  acl    = "private"
  tags   = local.common_tags

  server_side_encryption_configuration {
    rule {
      sse_algorithm = "KMS"
    }
  }
}

resource "alicloud_oss_bucket" "static" {
  bucket = "tng-finhack-static"
  acl    = "private"
  tags   = local.common_tags
}

output "models_bucket_name" { value = alicloud_oss_bucket.models.bucket }
output "pubkeys_bucket_name" { value = alicloud_oss_bucket.pubkeys.bucket }
output "static_bucket_name" { value = alicloud_oss_bucket.static.bucket }
