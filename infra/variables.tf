variable "app_name" {
  description = "Application name"
  default     = "diy-dyn-dns"
}

variable "app_env" {
  description = "Application environment tag"
  default     = "dev"
}

variable "api_key" {
  description = "API key value"
  type        = string
  sensitive   = true
}

variable "dns_dyn_record_name" {
  description = "Route53 record name for the dynamic DNS"
  type        = string
}

variable "dns_hosted_zone" {
  description = "Route53 hosted zone id"
  type        = string
}

locals {
  app_id = "${lower(var.app_name)}-${lower(var.app_env)}-${random_id.unique_suffix.hex}"
}
