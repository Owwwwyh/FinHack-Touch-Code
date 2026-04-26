# S3 buckets for data lake, models, and logs
# See docs/05-aws-services.md §3

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Data lake bucket (synthetic data)
resource "aws_s3_bucket" "data" {
  bucket = "${local.project}-aws-data-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${local.project}-data-lake"
  }
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Models bucket (model artifacts)
resource "aws_s3_bucket" "models" {
  bucket = "${local.project}-aws-models-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${local.project}-models"
  }
}

resource "aws_s3_bucket_versioning" "models" {
  bucket = aws_s3_bucket.models.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "models" {
  bucket = aws_s3_bucket.models.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "models" {
  bucket = aws_s3_bucket.models.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Logs bucket (settlement logs)
resource "aws_s3_bucket" "logs" {
  bucket = "${local.project}-aws-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${local.project}-logs"
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policies: archive old synthetic data
resource "aws_s3_bucket_lifecycle_configuration" "data_lifecycle" {
  bucket = aws_s3_bucket.data.id

  rule {
    id     = "archive-old-synthetic-data"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    filter {
      prefix = "synthetic/v0/"
    }
  }
}

# Get current AWS account ID and Terraform variables
data "aws_caller_identity" "current" {}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
}

# Terraform locals (same as main.tf)
locals {
  project = "tng-finhack"
}

# Outputs
output "data_bucket_name" {
  value = aws_s3_bucket.data.id
}

output "data_bucket_arn" {
  value = aws_s3_bucket.data.arn
}

output "models_bucket_name" {
  value = aws_s3_bucket.models.id
}

output "models_bucket_arn" {
  value = aws_s3_bucket.models.arn
}

output "logs_bucket_name" {
  value = aws_s3_bucket.logs.id
}

output "logs_bucket_arn" {
  value = aws_s3_bucket.logs.arn
}
