# API Gateway for cross-cloud inbound per docs/05-aws-services.md §8

resource "aws_api_gateway_rest_api" "cross_cloud" {
  name        = "tng-cross-cloud-ingest"
  description = "Inbound cross-cloud events from Alibaba"
  tags        = local.common_tags
}

resource "aws_api_gateway_resource" "events" {
  rest_api_id = aws_api_gateway_rest_api.cross_cloud.id
  parent_id   = aws_api_gateway_rest_api.cross_cloud.root_resource_id
  path_part   = "events"
}

resource "aws_api_gateway_method" "post_events" {
  rest_api_id   = aws_api_gateway_rest_api.cross_cloud.id
  resource_id   = aws_api_gateway_resource.events.id
  http_method   = "POST"
  authorization = "NONE" # mTLS handled by Lambda
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id             = aws_api_gateway_rest_api.cross_cloud.id
  resource_id             = aws_api_gateway_resource.events.id
  http_method             = aws_api_gateway_method.post_events.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.eb_bridge_in.invoke_arn
}

resource "aws_api_gateway_deployment" "cross_cloud" {
  rest_api_id = aws_api_gateway_rest_api.cross_cloud.id
  depends_on  = [aws_api_gateway_integration.lambda]
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.cross_cloud.id
  rest_api_id   = aws_api_gateway_rest_api.cross_cloud.id
  stage_name    = "prod"
  tags          = local.common_tags
}

output "ingest_url" { value = aws_api_gateway_stage.prod.invoke_url }
