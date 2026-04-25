# Cognito User Pool per docs/05-aws-services.md §6

resource "aws_cognito_user_pool" "tng_users" {
  name = "tng-finhack-users"
  tags = merge(local.common_tags, { Name = "tng-finhack-users" })

  auto_verified_attributes = ["email"]
  username_attributes      = ["email"]

  schema {
    name                = "kyc_tier"
    attribute_data_type = "Number"
    mutable             = true
  }

  schema {
    name                = "home_region"
    attribute_data_type = "String"
    mutable             = true
  }

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  verification_message_template {
    default_email_option  = "CONFIRM_WITH_CODE"
    email_subject         = "TNG FinHack Verification Code"
    email_message         = "Your verification code is {####}."
  }
}

resource "aws_cognito_user_pool_client" "mobile" {
  name                                 = "tng-mobile"
  user_pool_id                         = aws_cognito_user_pool.tng_users.id
  generate_secret                      = false  # PKCE public client
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  callback_urls                        = ["tngfinhack://callback"]
  logout_urls                          = ["tngfinhack://logout"]
  supported_identity_providers         = ["COGNITO"]
  refresh_token_validity               = 30 # days
  access_token_validity                = 1  # hours (15 min ideal but min 1h)
  id_token_validity                    = 1  # hours
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "tng-finhack"
  user_pool_id = aws_cognito_user_pool.tng_users.id
}

output "user_pool_id" { value = aws_cognito_user_pool.tng_users.id }
output "user_pool_arn" { value = aws_cognito_user_pool.tng_users.arn }
output "client_id" { value = aws_cognito_user_pool_client.mobile.id }
output "jwks_url" { value = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.tng_users.id}/.well-known/jwks.json" }
