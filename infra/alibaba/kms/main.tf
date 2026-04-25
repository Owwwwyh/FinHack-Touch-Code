# Alibaba KMS per docs/06-alibaba-services.md §8

resource "alicloud_kms_key" "cert_ca" {
  description             = "TNG FinHack cert CA signing key"
  key_state               = "Enabled"
  key_spec                = "RSA_2048"
  key_usage               = "SIGN_VERIFY"
  origin                  = "Aliyun_KMS"
  pending_window_in_days  = 7
  tags                    = local.common_tags
}

resource "alicloud_kms_alias" "cert_ca" {
  alias_name = "alias/tng-finhack-cert-ca"
  key_id     = alicloud_kms_key.cert_ca.id
}

resource "alicloud_kms_key" "envelope" {
  description             = "TNG FinHack envelope encryption key"
  key_state               = "Enabled"
  key_spec                = "AES_256"
  key_usage               = "ENCRYPT_DECRYPT"
  origin                  = "Aliyun_KMS"
  pending_window_in_days  = 7
  tags                    = local.common_tags
}

resource "alicloud_kms_alias" "envelope" {
  alias_name = "alias/tng-finhack-envelope"
  key_id     = alicloud_kms_key.envelope.id
}

# Secret for RDS DSN
resource "alicloud_kms_secret" "rds_dsn" {
  secret_name   = "tng-finhack/rds-dsn"
  description   = "RDS connection DSN"
  secret_data   = var.rds_dsn
  version_id    = "v1"
  encryption_key_id = alicloud_kms_key.envelope.id
  tags           = local.common_tags
}

# Secret for EAS endpoint
resource "alicloud_kms_secret" "eas_endpoint" {
  secret_name   = "tng-finhack/eas-endpoint"
  description   = "PAI-EAS endpoint URL"
  secret_data   = var.eas_endpoint
  version_id    = "v1"
  encryption_key_id = alicloud_kms_key.envelope.id
  tags           = local.common_tags
}

# Secret for AWS bridge URL
resource "alicloud_kms_secret" "aws_bridge_url" {
  secret_name   = "tng-finhack/aws-bridge-url"
  description   = "AWS cross-cloud bridge URL"
  secret_data   = var.aws_bridge_url
  version_id    = "v1"
  encryption_key_id = alicloud_kms_key.envelope.id
  tags           = local.common_tags
}

# Secret for HMAC secret
resource "alicloud_kms_secret" "hmac_secret" {
  secret_name   = "tng-finhack/aws-bridge-hmac-secret"
  description   = "Cross-cloud HMAC secret"
  secret_data   = var.hmac_secret
  version_id    = "v1"
  encryption_key_id = alicloud_kms_key.envelope.id
  tags           = local.common_tags
}

# Secret for Cognito JWKS URL
resource "alicloud_kms_secret" "cognito_jwks" {
  secret_name   = "tng-finhack/cognito-jwks-url"
  description   = "AWS Cognito JWKS URL"
  secret_data   = var.cognito_jwks_url
  version_id    = "v1"
  encryption_key_id = alicloud_kms_key.envelope.id
  tags           = local.common_tags
}

output "cert_ca_key_id" { value = alicloud_kms_key.cert_ca.id }
output "envelope_key_id" { value = alicloud_kms_key.envelope.id }
