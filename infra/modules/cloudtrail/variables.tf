variable "trail_name" {
  description = "Name of the CloudTrail trail"
  type        = string
}

variable "log_bucket_name" {
  description = "Globally-unique S3 bucket name to store trail logs in"
  type        = string
}

variable "log_retention_days" {
  description = "Days to retain trail logs in S3 before expiry"
  type        = number
  default     = 365
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt trail log files and the log bucket. Its key policy must include the CloudTrail encryption-context statements (see modules/kms's enable_cloudtrail)."
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
