# Secrets Manager per docs/05-aws-services.md §10 and docs/13-deployment.md §5

resource "aws_secretsmanager_secret" "alibaba_creds" {
  name                    = "tng-finhack/alibaba-creds"
  recovery_window_in_days = 7
  tags                    = local.common_tags
}

resource "aws_secretsmanager_secret_version" "alibaba_creds" {
  secret_id = aws_secretsmanager_secret.alibaba_creds.id
  secret_string = jsonencode({
    access_key_id     = var.alibaba_access_key_id
    access_key_secret = var.alibaba_access_key_secret
  })
}

resource "aws_secretsmanager_secret" "alibaba_ingest" {
  name                    = "tng-finhack/alibaba-ingest"
  recovery_window_in_days = 7
  tags                    = local.common_tags
}

resource "aws_secretsmanager_secret_version" "alibaba_ingest" {
  secret_id = aws_secretsmanager_secret.alibaba_ingest.id
  secret_string = jsonencode({
    url          = var.alibaba_ingest_url
    hmac_secret  = var.hmac_secret
  })
}

output "alibaba_creds_secret_arn" { value = aws_secretsmanager_secret.alibaba_creds.arn }
output "alibaba_ingest_secret_arn" { value = aws_secretsmanager_secret.alibaba_ingest.arn }
