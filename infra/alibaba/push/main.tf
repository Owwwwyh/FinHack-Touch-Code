# Alibaba Mobile Push per docs/06-alibaba-services.md §9

resource "alicloud_push_app" "finhack" {
  app_name  = "tng-finhack"
  ios       = false  # Android-first
  android   = true
}

output "push_app_id" { value = alicloud_push_app.finhack.id }
