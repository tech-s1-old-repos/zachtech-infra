variable "zone" {
  type        = string
  default     = "zachtech.dev"
  description = "Hosted zone for domain"
}

variable "default_tags" {
  type = map(string)
  default = {
    ManagedBy = "terraform"
    Project   = "zachtech-infra"
  }
  description = "Default tags"
}
