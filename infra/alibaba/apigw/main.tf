# Scaffolded Alibaba API Gateway public contract for the demo URL.

variable "custom_domain" {
  type    = string
  default = "api-finhack.example.com"
}

variable "route_map" {
  type = map(object({
    method        = string
    path          = string
    function_name = string
    handler_path  = string
    auth          = string
  }))
  default = {
    score_refresh = {
      method        = "POST"
      path          = "/v1/score/refresh"
      function_name = "score-refresh"
      handler_path  = "../../../backend/fc/score_refresh/handler.py"
      auth          = "jwt"
    }
  }
}

locals {
  custom_domain       = var.custom_domain
  public_api_base_url = "https://${local.custom_domain}"
}

resource "terraform_data" "public_api_contract" {
  input = {
    custom_domain = local.custom_domain
    routes        = var.route_map
  }
}

output "public_api_base_url" {
  value = local.public_api_base_url
}

output "route_map" {
  value = terraform_data.public_api_contract.input.routes
}
