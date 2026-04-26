# Live public route exposure contract derived from Function Compute HTTP triggers.
# Classic CloudAPI in this account/region rejected the HTTP backend type, so the
# first working public slice uses the FC trigger URLs directly.

variable "custom_domain" {
  type    = string
  default = "api-finhack.example.com"
}

variable "route_map" {
  type = map(object({
    method        = string
    path          = string
    function_name = string
    handler_path  = string
    handler       = string
    auth          = string
    cpu           = number
    memory_size   = number
    timeout       = number
    backend_url   = string
  }))
}

variable "public_api_url" {
  type    = string
  default = ""
}

output "public_api_base_url" {
  value = var.public_api_url
}

output "route_map" {
  value = var.route_map
}
