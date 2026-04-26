# Scaffolded PAI-EAS contract for score-refresh wiring.

variable "endpoint" {
  type    = string
  default = ""
}

variable "model_bucket" {
  type = string
}

resource "terraform_data" "eas_contract" {
  input = {
    service_name = "tng-credit-score-refresh"
    endpoint     = var.endpoint
    model_bucket = var.model_bucket
    route        = "/score"
  }
}

output "endpoint" {
  value = terraform_data.eas_contract.input.endpoint
}
