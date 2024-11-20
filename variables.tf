variable "zone" {
  type        = string
  default     = "zachtech.dev"
  description = "Hosted zone for domain"
}

variable "console_subdomain" {
  type        = string
  default     = "console"
  description = "Subdomain name for console web app"
}

variable "console_bucket" {
  type        = string
  default     = "console-zachtech-dev"
  description = "Bucket for the console web app"
}
variable "logs_bucket" {
  type        = string
  default     = "logs-zachtech-dev"
  description = "Bucket for the logs"
}


variable "default_tags" {
  type = map(string)
  default = {
    ManagedBy = "terraform"
    Project   = "zachtech"
  }
  description = "Default tags"
}
