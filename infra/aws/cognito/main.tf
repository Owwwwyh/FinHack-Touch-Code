# Cognito user pool and app client for mobile JWT authentication
# See docs/05-aws-services.md §6

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Cognito User Pool
resource "aws_cognito_user_pool" "tng" {
  name = "${local.project}-users"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  # Custom attributes for KYC
  schema {
    attribute_data_type = "String"
    name                = "kyc_tier"
    mutable             = true
    required            = false
  }

  schema {
    attribute_data_type = "String"
    name                = "home_region"
    mutable             = true
    required            = false
  }

  # Pre-signup Lambda to auto-approve and assign tier 1
  lambda_config {
    pre_sign_up = var.pre_signup_lambda_arn
  }

  user_attribute_update_settings {
    attributes_require_verification_before_update = ["email"]
  }

  account_recovery_setting {
    recovery_mechanism {
      name       = "verified_email"
      priority   = 1
    }
  }

  tags = {
    Name = "${local.project}-pool"
  }
}

# Resource server (for API scopes)
resource "aws_cognito_resource_server" "tng_api" {
  identifier   = "tng-api"
  name         = "${local.project} API"
  user_pool_id = aws_cognito_user_pool.tng.id

  scope {
    scope_description = "Read wallet balance"
    scope_name        = "wallet:read"
  }

  scope {
    scope_description = "Create payment transactions"
    scope_name        = "payment:create"
  }
}

# App client for mobile (OAuth2 with PKCE)
resource "aws_cognito_user_pool_client" "mobile" {
  name                                = "${local.project}-mobile"
  user_pool_id                        = aws_cognito_user_pool.tng.id
  generate_secret                     = false # PKCE doesn't require secret
  refresh_token_validity              = 30    # 30 days
  access_token_validity               = 1     # 1 hour
  id_token_validity                   = 1     # 1 hour
  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # PKCE for mobile
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  supported_identity_providers = ["COGNITO"]
  callback_urls                = var.callback_urls
  logout_urls                  = var.logout_urls
  allowed_oauth_flows          = ["code"]
  allowed_oauth_scopes         = ["email", "openid", "profile", "${aws_cognito_resource_server.tng_api.identifier}/wallet:read", "${aws_cognito_resource_server.tng_api.identifier}/payment:create"]
  allowed_oauth_flows_user_pool_client = true

  read_attributes  = ["email", "given_name", "family_name", "custom:kyc_tier", "custom:home_region"]
  write_attributes = ["given_name", "family_name", "custom:home_region"]

  depends_on = [aws_cognito_resource_server.tng_api]
}

# Identity Pool (optional, for internal admin tools)
resource "aws_cognito_identity_pool" "tng" {
  identity_pool_name               = "${local.project}-identity"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id              = aws_cognito_user_pool_client.mobile.id
    provider_name          = "cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.tng.id}"
    server_side_token_validation = false
  }
}

# IAM role for authenticated Cognito users (minimal permissions for mobile)
resource "aws_iam_role" "cognito_authenticated" {
  name = "${local.project}-cognito-authenticated"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.tng.id
          }
          ForAllValues = {
            "cognito-identity.amazonaws.com:auth_type" = "authenticated"
          }
        }
      }
    ]
  })
}

# Minimal IAM policy for authenticated users
resource "aws_iam_role_policy" "cognito_authenticated_policy" {
  name = "${local.project}-cognito-authenticated-policy"
  role = aws_iam_role.cognito_authenticated.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.models_bucket_name}/models/credit/v*/*"
        ]
      }
    ]
  })
}

# Attach identity pool roles
resource "aws_cognito_identity_pool_roles_attachment" "tng" {
  identity_pool_id = aws_cognito_identity_pool.tng.id

  roles = {
    authenticated = aws_iam_role.cognito_authenticated.arn
  }
}

# Variables
variable "pre_signup_lambda_arn" {
  description = "ARN of pre-signup Lambda (KYC stub)"
  type        = string
  default     = ""
}

variable "callback_urls" {
  description = "Callback URLs for OAuth2"
  type        = list(string)
  default     = ["http://localhost:8080/callback"]
}

variable "logout_urls" {
  description = "Logout URLs"
  type        = list(string)
  default     = ["http://localhost:8080/logout"]
}

variable "models_bucket_name" {
  description = "S3 bucket for model artifacts"
  type        = string
}

variable "aws_region" {
  description = "AWS region for issuer/JWKS rendering"
  type        = string
  default     = "ap-southeast-1"
}

# Locals (same as main.tf)
locals {
  project = "tng-finhack"
}

# Outputs
output "user_pool_id" {
  value = aws_cognito_user_pool.tng.id
}

output "user_pool_arn" {
  value = aws_cognito_user_pool.tng.arn
}

output "user_pool_endpoint" {
  value = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.tng.id}"
}

output "app_client_id" {
  value = aws_cognito_user_pool_client.mobile.id
}

output "app_client_secret" {
  value     = aws_cognito_user_pool_client.mobile.client_secret
  sensitive = true
}

output "jwks_uri" {
  value = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.tng.id}/.well-known/jwks.json"
}

output "issuer" {
  value = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.tng.id}"
}

output "identity_pool_id" {
  value = aws_cognito_identity_pool.tng.id
}
