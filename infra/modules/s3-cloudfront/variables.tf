variable "bucket_name" {
  description = "Globally-unique S3 bucket name for the built static assets"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt bucket contents. Its key policy must grant cloudfront.amazonaws.com kms:Decrypt, or CloudFront can't read objects."
  type        = string
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100" # US, Canada, Europe
}

variable "certificate_arn" {
  description = "ACM certificate ARN (must be in us-east-1) for custom domain aliases. Null uses the default *.cloudfront.net cert."
  type        = string
  default     = null
}

variable "aliases" {
  description = "Custom domain names (CNAMEs) for the distribution. Requires certificate_arn."
  type        = list(string)
  default     = []
}

variable "default_root_object" {
  description = "Default object served at the root URL"
  type        = string
  default     = "index.html"
}

variable "spa_mode" {
  description = "Route 403/404s to index.html with a 200, for single-page-app client-side routing"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
