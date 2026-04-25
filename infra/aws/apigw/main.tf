# Scaffolded AWS HTTP API contract for Alibaba -> AWS bridge ingress.

variable "aws_region" {
  type = string
}

variable "custom_domain" {
  type    = string
  default = ""
}

variable "bridge_in_lambda_name" {
  type = string
}

locals {
  bridge_route  = "/internal/alibaba/events"
  route_key     = "POST ${local.bridge_route}"
  invoke_domain = var.custom_domain != "" ? var.custom_domain : ""
}

resource "terraform_data" "bridge_http_api" {
  input = {
    route_key            = local.route_key
    bridge_in_lambda     = var.bridge_in_lambda_name
    custom_domain        = local.invoke_domain
    integration_protocol = "HTTP API"
  }
}

output "aws_bridge_invoke_url" {
  value = local.invoke_domain != "" ? "https://${local.invoke_domain}${local.bridge_route}" : ""
}

output "route_key" {
  value = terraform_data.bridge_http_api.input.route_key
}
