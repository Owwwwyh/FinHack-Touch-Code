# EventBridge per docs/05-aws-services.md §8

# Custom bus for cross-cloud events
resource "aws_cloudwatch_event_bus" "cross_cloud" {
  name = "tng-cross-cloud"
  tags = local.common_tags
}

# Default bus rules
resource "aws_cloudwatch_event_rule" "model_published" {
  name           = "model-published"
  event_bus_name = "default"
  event_pattern = jsonencode({
    source      = ["aws.sagemaker"]
    detail-type = ["SageMaker Model Package State Change"]
    detail = { ModelPackageGroupName = ["tng-credit-score"] }
  })
  tags = local.common_tags
}

resource "aws_cloudwatch_event_rule" "settlement_result" {
  name           = "settlement-result"
  event_bus_name = aws_cloudwatch_event_bus.cross_cloud.name
  event_pattern = jsonencode({
    source      = ["tng.aws.lambda.settle"]
    detail-type = ["settlement.completed"]
  })
  tags = local.common_tags
}

# Target: bridge out to Alibaba
resource "aws_cloudwatch_event_target" "bridge_out" {
  rule           = aws_cloudwatch_event_rule.settlement_result.name
  event_bus_name = aws_cloudwatch_event_bus.cross_cloud.name
  target_id      = "eb-cross-cloud-bridge-out"
  arn            = aws_lambda_function.eb_bridge_out.arn
}

output "cross_cloud_bus_name" { value = aws_cloudwatch_event_bus.cross_cloud.name }
