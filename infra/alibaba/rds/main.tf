# Alibaba RDS (MySQL 8.0) per docs/06-alibaba-services.md §7

resource "alicloud_vpc" "main" {
  vpc_name   = "tng-finhack-vpc"
  cidr_block = "10.0.0.0/16"
  tags       = local.common_tags
}

resource "alicloud_vswitch" "main" {
  vpc_id     = alicloud_vpc.main.id
  zone_id    = var.alibaba_zone_id
  cidr_block = "10.0.1.0/24"
  vswitch_name = "tng-finhack-vswitch"
  tags       = local.common_tags
}

resource "alicloud_security_group" "rds" {
  name        = "tng-finhack-rds-sg"
  vpc_id      = alicloud_vpc.main.id
  description = "Security group for RDS access"
  tags        = local.common_tags
}

resource "alicloud_db_instance" "main" {
  engine               = "MySQL"
  engine_version       = "8.0"
  instance_type        = "mysql.n2.medium.2c"
  instance_storage     = 20
  instance_name        = "tng-finhack-rds"
  vswitch_id           = alicloud_vswitch.main.id
  security_group_ids   = [alicloud_security_group.rds.id]
  db_instance_storage_type = "cloud_essd"
  tags                 = local.common_tags
}

resource "alicloud_db_database" "history" {
  instance_id = alicloud_db_instance.main.id
  name        = "tng_history"
  charset     = "utf8mb4"
}

resource "alicloud_db_account" "app" {
  instance_id = alicloud_db_instance.main.id
  name        = "tng_app"
  password    = var.rds_password
}

resource "alicloud_db_account_privilege" "app" {
  instance_id  = alicloud_db_instance.main.id
  account_name = alicloud_db_account.app.name
  privilege    = "ReadWrite"
  db_names     = [alicloud_db_database.history.name]
}

output "rds_connection_string" { value = alicloud_db_instance.main.connection_string }
output "rds_instance_id" { value = alicloud_db_instance.main.id }
