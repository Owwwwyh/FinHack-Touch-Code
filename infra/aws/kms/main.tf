# KMS key for envelope encryption of S3, DynamoDB, Secrets Manager
# See docs/05-aws-services.md §7

locals {
  project = "tng-finhack"
}

resource "aws_kms_key" "tng" {
  description             = "TNG Finhack encryption key for S3, DynamoDB, Secrets Manager"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name = "${local.project}-key"
  }
}

resource "aws_kms_alias" "tng" {
  name          = "alias/${local.project}-key"
  target_key_id = aws_kms_key.tng.key_id
}

# Key policy: allow Lambda and SageMaker to use
resource "aws_kms_key_policy" "tng" {
  key_id = aws_kms_key.tng.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Lambda to use key"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow SageMaker to use key"
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Outputs
output "kms_key_id" {
  value = aws_kms_key.tng.id
}

output "kms_key_arn" {
  value = aws_kms_key.tng.arn
}

output "kms_alias" {
  value = aws_kms_alias.tng.name
}
