# Alibaba CloudMonitor per docs/06-alibaba-services.md §11

resource "alicloud_cms_alarm" "eas_latency" {
  name   = "tng-eas-high-latency"
  metric = "EAS_LatencyP95"

  dimensions = {
    service = "tng-credit-score-refresh"
  }

  evaluation_count  = 1
  period            = 60
  operator          = "GreaterThanThreshold"
  threshold         = "250"
  alert_state       = true
  contact_groups    = ["tng-finhack-ops"]
  notify_type       = 1
}

resource "alicloud_cms_alarm" "fc_error_rate" {
  name   = "tng-fc-high-error-rate"
  metric = "FC_ErrorRate"

  dimensions = {
    service = "tng-wallet-api"
  }

  evaluation_count  = 1
  period            = 60
  operator          = "GreaterThanThreshold"
  threshold         = "5"
  alert_state       = true
  contact_groups    = ["tng-finhack-ops"]
  notify_type       = 1
}
