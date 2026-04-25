# EventBridge buses and rules for settlement events and cross-cloud integration
# See docs/05-aws-services.md §8

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Default event bus (for internal settlement events)
# AWS creates this by default; we just define rules here

# Custom bus for cross-cloud events
resource "aws_cloudwatch_event_bus" "cross_cloud" {
  name = "${local.project}-cross-cloud"

  tags = {
    Name = "${local.project}-cross-cloud-bus"
  }
}

# EventBridge rule: settlement-result → bridge-out Lambda
# When a settlement is completed, forward it to Alibaba
resource "aws_cloudwatch_event_rule" "settlement_result" {
  name           = "${local.project}-settlement-result"
  event_bus_name = "default"
  description    = "Route settlement results to cross-cloud bridge"

  event_pattern = jsonencode({
    source      = ["tng.settlement"]
    detail-type = ["SettlementComplete"]
  })
}

resource "aws_cloudwatch_event_target" "settlement_result_bridge" {
  rule     = aws_cloudwatch_event_rule.settlement_result.name
  arn      = var.bridge_out_lambda_arn
  role_arn = aws_iam_role.eventbridge_invoke_lambda.arn

  dead_letter_config {
    arn = var.dlq_arn
  }
}

# EventBridge rule: model-published → Step Functions
# When a new model is published, start the release pipeline
resource "aws_cloudwatch_event_rule" "model_published" {
  name           = "${local.project}-model-published"
  event_bus_name = "default"
  description    = "Trigger model release pipeline"

  event_pattern = jsonencode({
    source      = ["tng.ml"]
    detail-type = ["ModelPublished"]
  })
}

resource "aws_cloudwatch_event_target" "model_published_stepfunctions" {
  rule     = aws_cloudwatch_event_rule.model_published.name
  arn      = var.stepfunctions_arn
  role_arn = aws_iam_role.eventbridge_invoke_stepfunctions.arn

  dead_letter_config {
    arn = var.dlq_arn
  }
}

# Cross-cloud inbound rule: API Gateway HTTPS POST → bridge-in Lambda
resource "aws_cloudwatch_event_rule" "cross_cloud_inbound" {
  name           = "${local.project}-cross-cloud-inbound"
  event_bus_name = aws_cloudwatch_event_bus.cross_cloud.name
  description    = "Relay events from Alibaba to internal bus"

  # Accept events from source "alibaba.settlement"
  event_pattern = jsonencode({
    source = ["alibaba.settlement"]
  })
}

resource "aws_cloudwatch_event_target" "cross_cloud_inbound_local_bus" {
  rule     = aws_cloudwatch_event_rule.cross_cloud_inbound.name
  arn      = "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/default"
  role_arn = aws_iam_role.eventbridge_put_events.arn
}

# IAM role for EventBridge to invoke Lambda
resource "aws_iam_role" "eventbridge_invoke_lambda" {
  name = "${local.project}-eventbridge-invoke-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "eventbridge_invoke_lambda_policy" {
  name = "${local.project}-eventbridge-invoke-lambda-policy"
  role = aws_iam_role.eventbridge_invoke_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          "${var.bridge_out_lambda_arn}*"
        ]
      }
    ]
  })
}

# IAM role for EventBridge to invoke Step Functions
resource "aws_iam_role" "eventbridge_invoke_stepfunctions" {
  name = "${local.project}-eventbridge-invoke-stepfunctions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "eventbridge_invoke_stepfunctions_policy" {
  name = "${local.project}-eventbridge-invoke-stepfunctions-policy"
  role = aws_iam_role.eventbridge_invoke_stepfunctions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = [
          "${var.stepfunctions_arn}*"
        ]
      }
    ]
  })
}

# IAM role for EventBridge to put events on default bus
resource "aws_iam_role" "eventbridge_put_events" {
  name = "${local.project}-eventbridge-put-events"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "eventbridge_put_events_policy" {
  name = "${local.project}-eventbridge-put-events-policy"
  role = aws_iam_role.eventbridge_put_events.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "events:PutEvents"
        ]
        Resource = [
          "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/default"
        ]
      }
    ]
  })
}

# Variables
variable "bridge_out_lambda_arn" {
  description = "ARN of eb-cross-cloud-bridge-out Lambda"
  type        = string
}

variable "stepfunctions_arn" {
  description = "ARN of Step Functions state machine"
  type        = string
}

variable "dlq_arn" {
  description = "ARN of dead-letter queue for failed events"
  type        = string
  default     = ""
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Locals
locals {
  project = "tng-finhack"
}

# Outputs
output "cross_cloud_bus_name" {
  value = aws_cloudwatch_event_bus.cross_cloud.name
}

output "cross_cloud_bus_arn" {
  value = aws_cloudwatch_event_bus.cross_cloud.arn
}
