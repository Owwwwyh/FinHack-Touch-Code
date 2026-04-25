# CloudWatch per docs/05-aws-services.md §10

resource "aws_cloudwatch_log_group" "settle_batch" {
  name              = "/aws/lambda/tng-settle-batch"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "fraud_score" {
  name              = "/aws/lambda/tng-fraud-score"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "pubkey_warmer" {
  name              = "/aws/lambda/tng-pubkey-warmer"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "bridge_out" {
  name              = "/aws/lambda/tng-eb-bridge-out"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "bridge_in" {
  name              = "/aws/lambda/tng-eb-bridge-in"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_cloudwatch_dashboard" "finhack" {
  dashboard_name = "tng-finhack"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          namespace = "TNG/Settlement"
          metrics   = [["SettledCount"], ["RejectedCount"]]
          period    = 60
          stat      = "Sum"
          title     = "Settlement Throughput"
        }
        x = 0; y = 0; width = 12; height = 6
      },
      {
        type = "metric"
        properties = {
          namespace = "TNG/Settlement"
          metrics   = [["LatencyP95"]]
          period    = 60
          stat      = "p95"
          title     = "Settlement Latency P95"
        }
        x = 12; y = 0; width = 12; height = 6
      },
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "high_rejection_rate" {
  alarm_name          = "tng-high-rejection-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RejectedCount"
  namespace           = "TNG/Settlement"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Rejection rate > 5% over 5 min"
  tags                = local.common_tags
}
