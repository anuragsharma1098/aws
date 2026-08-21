variable "domain_name" {
  description = "Apex domain, e.g. \"example.com\". Placeholder default is intentionally invalid-looking so plan/apply never silently uses it."
  type        = string
  default     = "CHANGE_ME.example.com"
}

variable "create_hosted_zone" {
  description = "true to create a new Route 53 public hosted zone; false to look up an existing one by domain_name"
  type        = bool
  default     = false
}

variable "environment" {
  type = string
}

variable "api_subdomain" {
  description = "Subdomain the ALB/API is served on, e.g. \"api\" -> api.<domain>"
  type        = string
  default     = "api"
}

variable "frontend_subdomain" {
  description = "Subdomain the CloudFront frontend is served on, e.g. \"www\" -> www.<domain>"
  type        = string
  default     = "www"
}

variable "live_subdomain" {
  description = "Subdomain the live-streaming CloudFront distribution is served on"
  type        = string
  default     = "live"
}

variable "tags" {
  type    = map(string)
  default = {}
}
