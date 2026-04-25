# Alibaba PAI-EAS per docs/06-alibaba-services.md §2

resource "alicloud_cpnp_eas_service" "credit_score" {
  service_name   = "tng-credit-score-refresh"
  service_type   = "COMMAND"
  resource       = "ecs.c6.large"
  resource_spec  = jsonencode({
    image   = var.eas_image_url
    command = ["python", "app.py"]
    env     = {
      OSS_MODEL_PATH = "oss://${alicloud_oss_bucket.models.bucket}/credit/v3/model.pkl"
    }
  })
  depends_on = [alicloud_oss_bucket.models]
}

output "eas_service_name" { value = alicloud_cpnp_eas_service.credit_score.service_name }
output "eas_endpoint" { value = alicloud_cpnp_eas_service.credit_score.endpoint }
