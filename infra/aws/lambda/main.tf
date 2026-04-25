# Lambda functions per docs/05-aws-services.md §4
# IAM roles and function definitions for all 7 Lambda functions

# Common IAM role for settlement workers
resource "aws_iam_role" "settle" {
  name = "tng-lambda-settle-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy" "settle" {
  name = "tng-lambda-settle-policy"
  role = aws_iam_role.settle.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow"; Action = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Query"]; Resource = [aws_dynamodb_table.token_ledger.arn, aws_dynamodb_table.nonce_seen.arn, aws_dynamodb_table.pubkey_cache.arn] },
      { Effect = "Allow"; Action = ["events:PutEvents"]; Resource = [aws_cloudwatch_event_bus.cross_cloud.arn] },
      { Effect = "Allow"; Action = ["kms:Decrypt", "kms:GenerateDataKey"]; Resource = [aws_kms_key.tng.arn] },
      { Effect = "Allow"; Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]; Resource = "arn:aws:logs:*:*:*" },
      { Effect = "Allow"; Action = ["secretsmanager:GetSecretValue"]; Resource = [aws_secretsmanager_secret.alibaba_ingest.arn] },
    ]
  })
}

# Common IAM role for bridge functions
resource "aws_iam_role" "bridge" {
  name = "tng-lambda-bridge-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy" "bridge" {
  name = "tng-lambda-bridge-policy"
  role = aws_iam_role.bridge.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow"; Action = ["events:PutEvents"]; Resource = [aws_cloudwatch_event_bus.cross_cloud.arn] },
      { Effect = "Allow"; Action = ["secretsmanager:GetSecretValue"]; Resource = [aws_secretsmanager_secret.alibaba_creds.arn, aws_secretsmanager_secret.alibaba_ingest.arn] },
      { Effect = "Allow"; Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]; Resource = "arn:aws:logs:*:*:*" },
    ]
  })
}

# settle-batch
resource "aws_lambda_function" "settle_batch" {
  function_name = "tng-settle-batch"
  role_arn      = aws_iam_role.settle.arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  filename      = "${path.module}/settle-batch.zip"
  timeout       = 30
  reserved_concurrent_executions = 50
  environment {
    variables = {
      DYNAMO_LEDGER_TABLE   = aws_dynamodb_table.token_ledger.name
      DYNAMO_NONCE_TABLE    = aws_dynamodb_table.nonce_seen.name
      DYNAMO_PUBKEY_CACHE   = aws_dynamodb_table.pubkey_cache.name
      EVENTBRIDGE_BUS       = aws_cloudwatch_event_bus.cross_cloud.name
    }
  }
  tags = local.common_tags
}

# fraud-score
resource "aws_lambda_function" "fraud_score" {
  function_name = "tng-fraud-score"
  role_arn      = aws_iam_role.settle.arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  filename      = "${path.module}/fraud-score.zip"
  timeout       = 15
  reserved_concurrent_executions = 20
  tags = local.common_tags
}

# pubkey-warmer
resource "aws_lambda_function" "pubkey_warmer" {
  function_name = "tng-pubkey-warmer"
  role_arn      = aws_iam_role.settle.arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  filename      = "${path.module}/pubkey-warmer.zip"
  timeout       = 60
  reserved_concurrent_executions = 1
  tags = local.common_tags
}

# model-publish-bridge
resource "aws_lambda_function" "model_publish_bridge" {
  function_name = "tng-model-publish-bridge"
  role_arn      = aws_iam_role.bridge.arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  filename      = "${path.module}/model-publish-bridge.zip"
  timeout       = 120
  reserved_concurrent_executions = 1
  tags = local.common_tags
}

# eb-cross-cloud-bridge-out
resource "aws_lambda_function" "eb_bridge_out" {
  function_name = "tng-eb-bridge-out"
  role_arn      = aws_iam_role.bridge.arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  filename      = "${path.module}/eb-cross-cloud-bridge-out.zip"
  timeout       = 15
  reserved_concurrent_executions = 5
  tags = local.common_tags
}

# eb-cross-cloud-bridge-in
resource "aws_lambda_function" "eb_bridge_in" {
  function_name = "tng-eb-bridge-in"
  role_arn      = aws_iam_role.bridge.arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  filename      = "${path.module}/eb-cross-cloud-bridge-in.zip"
  timeout       = 15
  reserved_concurrent_executions = 10
  tags = local.common_tags
}

# dispute-recorder
resource "aws_lambda_function" "dispute_recorder" {
  function_name = "tng-dispute-recorder"
  role_arn      = aws_iam_role.settle.arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  filename      = "${path.module}/dispute-recorder.zip"
  timeout       = 15
  reserved_concurrent_executions = 5
  tags = local.common_tags
}
