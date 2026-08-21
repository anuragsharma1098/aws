variable "name_prefix" {
  type = string
}

variable "frontend_fqdn" {
  description = "FQDN the frontend is served on, e.g. www.example.com"
  type        = string
}

variable "cloudfront_certificate_arn" {
  description = "us-east-1 ACM certificate ARN covering frontend_fqdn"
  type        = string
}

variable "web_acl_arn" {
  description = "CLOUDFRONT-scope WAFv2 web ACL ARN"
  type        = string
}

variable "kms_key_arn" {
  type = string
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

variable "log_retention_days" {
  type    = number
  default = 90
}

variable "tags" {
  type    = map(string)
  default = {}
}
