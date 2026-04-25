# Scaffolded Function Compute route and environment contract for the demo API.

variable "public_api_domain" {
  type = string
}

variable "ots_instance" {
  type = string
}

variable "oss_pubkey_bucket" {
  type = string
}

variable "oss_model_bucket" {
  type = string
}

variable "eas_endpoint" {
  type    = string
  default = ""
}

variable "aws_bridge_url" {
  type    = string
  default = ""
}

variable "aws_bridge_hmac_secret" {
  type      = string
  default   = ""
  sensitive = true
}

variable "cognito_jwks_url" {
  type = string
}

locals {
  common_env = {
    OTS_INSTANCE             = var.ots_instance
    OSS_PUBKEY_BUCKET        = var.oss_pubkey_bucket
    OSS_MODEL_BUCKET         = var.oss_model_bucket
    COGNITO_JWKS_URL         = var.cognito_jwks_url
    AWS_BRIDGE_HMAC_SECRET   = var.aws_bridge_hmac_secret
    AWS_BRIDGE_URL           = var.aws_bridge_url
    EAS_ENDPOINT             = var.eas_endpoint
  }

  routes = {
    device_register = {
      method        = "POST"
      path          = "/v1/devices/register"
      function_name = "device-register"
      handler_path  = "../../../backend/fc/device_register/handler.py"
      auth          = "jwt"
    }
    wallet_balance = {
      method        = "GET"
      path          = "/v1/wallet/balance"
      function_name = "wallet-balance"
      handler_path  = "../../../backend/fc/wallet_balance/handler.py"
      auth          = "jwt"
    }
    tokens_settle = {
      method        = "POST"
      path          = "/v1/tokens/settle"
      function_name = "tokens-settle"
      handler_path  = "../../../backend/fc/tokens_settle/handler.py"
      auth          = "jwt"
    }
    score_refresh = {
      method        = "POST"
      path          = "/v1/score/refresh"
      function_name = "score-refresh"
      handler_path  = "../../../backend/fc/score_refresh/handler.py"
      auth          = "jwt"
    }
    score_policy = {
      method        = "GET"
      path          = "/v1/score/policy"
      function_name = "score-policy"
      handler_path  = "../../../backend/fc/score_policy/handler.py"
      auth          = "jwt"
    }
    aws_bridge = {
      method        = "POST"
      path          = "/v1/_internal/eb/aws-bridge"
      function_name = "eb-cross-cloud-ingest"
      handler_path  = "../../../backend/fc/eb_cross_cloud_ingest/handler.py"
      auth          = "hmac"
    }
  }

  function_environment = {
    for route_name, route in local.routes :
    route.function_name => merge(
      local.common_env,
      {
        FC_ROUTE_METHOD = route.method
        FC_ROUTE_PATH   = route.path
      },
    )
  }
}

resource "terraform_data" "functions" {
  for_each = local.routes
  input = {
    route       = each.value
    environment = local.function_environment[each.value.function_name]
  }
}

output "routes" {
  value = local.routes
}

output "function_environment" {
  value = local.function_environment
}
