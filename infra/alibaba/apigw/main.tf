# Alibaba API Gateway per docs/06-alibaba-services.md §5

resource "alicloud_api_gateway_group" "public" {
  name        = "tng-finhack-public"
  description = "TNG FinHack public API gateway"
  base_domain = "api-finhack.example.com"
}

resource "alicloud_api_gateway_api" "wallet_balance" {
  name          = "wallet-balance"
  group_id      = alicloud_api_gateway_group.public.id
  visibility    = "PUBLIC"
  auth_type     = "JWT"
  request_config {
    protocol = "HTTPS"
    method   = "GET"
    path     = "/v1/wallet/balance"
  }
  fc_service_config {
    fc_region   = var.alibaba_region
    service_name = alicloud_fc_service.wallet_api.name
    function_name = alicloud_fc_function.wallet_balance.name
    role_arn    = var.fc_role_arn
  }
}

resource "alicloud_api_gateway_api" "tokens_settle" {
  name          = "tokens-settle"
  group_id      = alicloud_api_gateway_group.public.id
  visibility    = "PUBLIC"
  auth_type     = "JWT"
  request_config {
    protocol = "HTTPS"
    method   = "POST"
    path     = "/v1/tokens/settle"
  }
  fc_service_config {
    fc_region   = var.alibaba_region
    service_name = alicloud_fc_service.wallet_api.name
    function_name = alicloud_fc_function.tokens_settle.name
    role_arn    = var.fc_role_arn
  }
}

resource "alicloud_api_gateway_api" "score_refresh" {
  name          = "score-refresh"
  group_id      = alicloud_api_gateway_group.public.id
  visibility    = "PUBLIC"
  auth_type     = "JWT"
  request_config {
    protocol = "HTTPS"
    method   = "POST"
    path     = "/v1/score/refresh"
  }
  fc_service_config {
    fc_region   = var.alibaba_region
    service_name = alicloud_fc_service.wallet_api.name
    function_name = alicloud_fc_function.score_refresh.name
    role_arn    = var.fc_role_arn
  }
}

resource "alicloud_api_gateway_api" "eb_bridge" {
  name          = "eb-aws-bridge"
  group_id      = alicloud_api_gateway_group.public.id
  visibility    = "PUBLIC"
  auth_type     = "APP_CODE"
  request_config {
    protocol = "HTTPS"
    method   = "POST"
    path     = "/v1/_internal/eb/aws-bridge"
  }
  fc_service_config {
    fc_region   = var.alibaba_region
    service_name = alicloud_fc_service.wallet_api.name
    function_name = alicloud_fc_function.eb_cross_cloud_ingest.name
    role_arn    = var.fc_role_arn
  }
}

resource "alicloud_api_gateway_vpc_access" "main" {
  name       = "tng-finhack-vpc-access"
  vpc_id     = alicloud_vpc.main.id
  vswitch_id = alicloud_vswitch.main.id
}

output "api_group_id" { value = alicloud_api_gateway_group.public.id }
output "api_domain" { value = alicloud_api_gateway_group.public.sub_domain }
