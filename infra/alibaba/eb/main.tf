# Alibaba EventBridge per docs/06-alibaba-services.md §10

# Cross-cloud inbound bus (receives from AWS)
resource "alicloud_event_bridge_event_bus" "cross_cloud_in" {
  event_bus_name = "tng-cross-cloud-in"
  description    = "Receives settlement-result events from AWS"
}

# Internal bus (FC publishes events for AWS consumption)
resource "alicloud_event_bridge_event_bus" "internal" {
  event_bus_name = "tng-internal"
  description    = "Internal events that AWS may consume"
}

# Rule: settlement result → FC wallet-balance-update
resource "alicloud_event_bridge_rule" "settlement_result" {
  event_bus_name = alicloud_event_bridge_event_bus.cross_cloud_in.name
  rule_name      = "settlement-result"
  description    = "Route settlement results to wallet update"
  status         = "ENABLED"

  filter_pattern = jsonencode({
    source      = ["tng.aws.lambda.settle"]
    detail-type = ["settlement.completed"]
  })

  targets {
    target_id = "wallet-balance-update"
    endpoint  = var.fc_wallet_update_endpoint
    type      = "fc"
    role_arn  = var.fc_role_arn
  }
}

# Rule: tokens settle request → forward to AWS
resource "alicloud_event_bridge_rule" "tokens_settle_requested" {
  event_bus_name = alicloud_event_bridge_event_bus.internal.name
  rule_name      = "tokens-settle-requested"
  description    = "Route settlement requests to AWS cross-cloud bridge"
  status         = "ENABLED"

  filter_pattern = jsonencode({
    source      = ["tng.alibaba.fc"]
    detail-type = ["tokens.settle.requested"]
  })

  targets {
    target_id = "aws-bridge"
    endpoint  = var.aws_bridge_url
    type      = "https"
  }
}

output "cross_cloud_bus_name" { value = alicloud_event_bridge_event_bus.cross_cloud_in.name }
output "internal_bus_name" { value = alicloud_event_bridge_event_bus.internal.name }
