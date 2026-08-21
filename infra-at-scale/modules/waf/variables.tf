variable "name_prefix" {
  type = string
}

variable "rate_limit_per_5min" {
  description = "Max requests from a single IP per 5-minute window before WAF blocks it"
  type        = number
  default     = 2000
}

variable "tags" {
  type    = map(string)
  default = {}
}
