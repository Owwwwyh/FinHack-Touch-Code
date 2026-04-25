# SageMaker per docs/05-aws-services.md §2

resource "aws_iam_role" "sagemaker" {
  name = "tng-sagemaker-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "sagemaker.amazonaws.com" }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy" "sagemaker" {
  name = "tng-sagemaker-policy"
  role = aws_iam_role.sagemaker.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow"; Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]; Resource = ["${aws_s3_bucket.data.arn}", "${aws_s3_bucket.data.arn}/*", "${aws_s3_bucket.models.arn}", "${aws_s3_bucket.models.arn}/*"] },
      { Effect = "Allow"; Action = ["kms:Decrypt", "kms:GenerateDataKey"]; Resource = [aws_kms_key.tng.arn] },
      { Effect = "Allow"; Action = ["cloudwatch:PutMetricData"]; Resource = "*" },
      { Effect = "Allow"; Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]; Resource = "*" },
    ]
  })
}

resource "aws_sagemaker_domain" "finhack" {
  domain_name = "finhack-team"
  auth_mode   = "SSO"
  vpc_id      = var.vpc_id
  subnet_ids  = var.subnet_ids
  default_user_settings {
    execution_role = aws_iam_role.sagemaker.arn
  }
  tags = local.common_tags
}

resource "aws_sagemaker_model_package_group" "credit_score" {
  name = "tng-credit-score"
  tags = local.common_tags
}

output "sagemaker_role_arn" { value = aws_iam_role.sagemaker.arn }
output "model_package_group_arn" { value = aws_sagemaker_model_package_group.credit_score.arn }
