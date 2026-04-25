terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "aws_region" {
  type = string
}

variable "custom_domain" {
  type    = string
  default = ""
}

variable "custom_domain_certificate_arn" {
  type    = string
  default = ""
}

variable "bridge_in_lambda_name" {
  type = string
}

variable "bridge_in_lambda_invoke_arn" {
  type = string
}

locals {
  bridge_route           = "/internal/alibaba/events"
  route_key              = "POST ${local.bridge_route}"
  custom_domain_enabled  = trimspace(var.custom_domain) != "" && trimspace(var.custom_domain_certificate_arn) != ""
}

resource "aws_apigatewayv2_api" "bridge" {
  name          = "tng-finhack-aws-bridge"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.bridge.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "bridge_in" {
  api_id                 = aws_apigatewayv2_api.bridge.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = var.bridge_in_lambda_invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 15000
}

resource "aws_apigatewayv2_route" "bridge_in" {
  api_id    = aws_apigatewayv2_api.bridge.id
  route_key = local.route_key
  target    = "integrations/${aws_apigatewayv2_integration.bridge_in.id}"
}

resource "aws_lambda_permission" "apigw_invoke_bridge_in" {
  statement_id  = "AllowHttpApiInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.bridge_in_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.bridge.execution_arn}/*/*"
}

resource "aws_apigatewayv2_domain_name" "bridge" {
  count = local.custom_domain_enabled ? 1 : 0

  domain_name = var.custom_domain

  domain_name_configuration {
    certificate_arn = var.custom_domain_certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "bridge" {
  count = local.custom_domain_enabled ? 1 : 0

  api_id      = aws_apigatewayv2_api.bridge.id
  domain_name = aws_apigatewayv2_domain_name.bridge[0].id
  stage       = aws_apigatewayv2_stage.default.name
}

output "aws_bridge_invoke_url" {
  value = local.custom_domain_enabled ? "https://${var.custom_domain}${local.bridge_route}" : "${aws_apigatewayv2_api.bridge.api_endpoint}${local.bridge_route}"
}

output "aws_bridge_api_endpoint" {
  value = aws_apigatewayv2_api.bridge.api_endpoint
}

output "aws_bridge_api_id" {
  value = aws_apigatewayv2_api.bridge.id
}

output "route_key" {
  value = local.route_key
}

output "custom_domain_target_domain_name" {
  value = local.custom_domain_enabled ? aws_apigatewayv2_domain_name.bridge[0].domain_name_configuration[0].target_domain_name : ""
}
