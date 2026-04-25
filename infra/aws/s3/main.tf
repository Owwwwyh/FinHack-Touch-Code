# S3 Buckets per docs/05-aws-services.md §3
# Per docs/09-data-model.md §4 for bucket layouts

resource "aws_kms_key" "s3" {
  description             = "TNG FinHack S3 encryption key"
  deletion_window_in_days = 7
  tags                    = local.common_tags
}

resource "aws_kms_alias" "s3" {
  name          = "alias/tng-finhack-key"
  target_key_id = aws_kms_key.s3.key_id
}

# Data lake bucket
resource "aws_s3_bucket" "data" {
  bucket = "tng-finhack-aws-data"
  tags   = merge(local.common_tags, { Name = "tng-finhack-aws-data" })
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    id     = "archive-old-synth"
    status = "Enabled"
    filter { prefix = "synthetic/v0/" }
    transition {
      days          = 30
      storage_class = "GLACIER"
    }
  }
}

# Models bucket
resource "aws_s3_bucket" "models" {
  bucket = "tng-finhack-aws-models"
  tags   = merge(local.common_tags, { Name = "tng-finhack-aws-models" })
}

resource "aws_s3_bucket_versioning" "models" {
  bucket = aws_s3_bucket.models.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "models" {
  bucket = aws_s3_bucket.models.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
  }
}

# Logs bucket
resource "aws_s3_bucket" "logs" {
  bucket = "tng-finhack-aws-logs"
  tags   = merge(local.common_tags, { Name = "tng-finhack-aws-logs" })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

# Terraform state bucket
resource "aws_s3_bucket" "terraform_state" {
  bucket = "tng-finhack-terraform-state"
  tags   = merge(local.common_tags, { Name = "tng-finhack-terraform-state" })
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration { status = "Enabled" }
}

output "data_bucket_arn" { value = aws_s3_bucket.data.arn }
output "models_bucket_arn" { value = aws_s3_bucket.models.arn }
output "logs_bucket_arn" { value = aws_s3_bucket.logs.arn }
