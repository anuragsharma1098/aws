variable "bucket_name" {
  description = "Globally-unique S3 bucket name for CI test logs/reports"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt bucket contents"
  type        = string
}

variable "retention_days" {
  description = "Days to retain CI artifacts before expiry - these are debugging aids, not audit records, so a short retention is normal"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
