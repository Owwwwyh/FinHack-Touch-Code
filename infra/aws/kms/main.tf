# KMS Keys per docs/05-aws-services.md §7

# Main data encryption key
resource "aws_kms_key" "tng" {
  description             = "TNG FinHack main encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.common_tags
}

resource "aws_kms_alias" "tng" {
  name          = "alias/tng-finhack-key"
  target_key_id = aws_kms_key.tng.key_id
}

# JWT signing key
resource "aws_kms_key" "jwt_signer" {
  description             = "TNG FinHack JWT signing key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.common_tags
}

resource "aws_kms_alias" "jwt_signer" {
  name          = "alias/tng-finhack-jwt-signer"
  target_key_id = aws_kms_key.jwt_signer.key_id
}

output "main_key_arn" { value = aws_kms_key.tng.arn }
output "jwt_signer_key_arn" { value = aws_kms_key.jwt_signer.arn }
