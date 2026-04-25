# EventBridge bus and rules for settlement events and optional model-publish hooks.

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "bridge_out_lambda_arn" {
  description = "ARN of eb-cross-cloud-bridge-out Lambda"
  type        = string
}

variable "stepfunctions_arn" {
  description = "ARN of Step Functions state machine"
  type        = string
  default     = ""
}

variable "dlq_arn" {
  description = "ARN of dead-letter queue for failed events"
  type        = string
  default     = ""
}

variable "cross_cloud_bus_name" {
  description = "Name of the custom EventBridge bus used for cross-cloud settlement events"
  type        = string
}

locals {
  project                    = "tng-finhack"
  has_stepfunctions_target   = trimspace(var.stepfunctions_arn) != ""
  has_dead_letter_queue      = trimspace(var.dlq_arn) != ""
}

resource "aws_cloudwatch_event_bus" "cross_cloud" {
  name = var.cross_cloud_bus_name

  tags = {
    Name = "${local.project}-cross-cloud-bus"
  }
}

resource "aws_cloudwatch_event_rule" "settlement_result" {
  name           = "${local.project}-settlement-result"
  event_bus_name = aws_cloudwatch_event_bus.cross_cloud.name
  description    = "Route settlement.completed events to the Alibaba callback bridge"

  event_pattern = jsonencode({
    source      = ["tng.aws.lambda.settle"]
    detail-type = ["settlement.completed"]
  })
}

resource "aws_cloudwatch_event_target" "settlement_result_bridge" {
  rule           = aws_cloudwatch_event_rule.settlement_result.name
  event_bus_name = aws_cloudwatch_event_bus.cross_cloud.name
  arn            = var.bridge_out_lambda_arn

  dynamic "dead_letter_config" {
    for_each = local.has_dead_letter_queue ? [1] : []

    content {
      arn = var.dlq_arn
    }
  }
}

resource "aws_lambda_permission" "allow_cross_cloud_bus_invoke_bridge_out" {
  statement_id  = "AllowSettlementResultRuleInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.bridge_out_lambda_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.settlement_result.arn
}

resource "aws_cloudwatch_event_rule" "model_published" {
  count = local.has_stepfunctions_target ? 1 : 0

  name        = "${local.project}-model-published"
  description = "Trigger the model release pipeline"

  event_pattern = jsonencode({
    source      = ["tng.ml"]
    detail-type = ["ModelPublished"]
  })
}

resource "aws_cloudwatch_event_target" "model_published_stepfunctions" {
  count = local.has_stepfunctions_target ? 1 : 0

  rule     = aws_cloudwatch_event_rule.model_published[0].name
  arn      = var.stepfunctions_arn
  role_arn = aws_iam_role.eventbridge_invoke_stepfunctions[0].arn

  dynamic "dead_letter_config" {
    for_each = local.has_dead_letter_queue ? [1] : []

    content {
      arn = var.dlq_arn
    }
  }
}

resource "aws_iam_role" "eventbridge_invoke_stepfunctions" {
  count = local.has_stepfunctions_target ? 1 : 0

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

resource "aws_iam_role_policy" "eventbridge_invoke_stepfunctions" {
  count = local.has_stepfunctions_target ? 1 : 0

  name = "${local.project}-eventbridge-invoke-stepfunctions-policy"
  role = aws_iam_role.eventbridge_invoke_stepfunctions[0].id

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

output "cross_cloud_bus_name" {
  value = aws_cloudwatch_event_bus.cross_cloud.name
}

output "cross_cloud_bus_arn" {
  value = aws_cloudwatch_event_bus.cross_cloud.arn
}
