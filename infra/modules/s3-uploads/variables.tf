variable "bucket_name" {
  description = "Globally-unique S3 bucket name for user-uploaded files/media"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt bucket contents"
  type        = string
}

variable "cors_allowed_origins" {
  description = "Origins allowed to upload directly to this bucket (e.g. presigned PUT from the browser)"
  type        = list(string)
  default     = []
}

variable "noncurrent_version_expiration_days" {
  description = "Days to retain noncurrent object versions before expiry"
  type        = number
  default     = 90
}

variable "ia_transition_days" {
  description = "Days before transitioning current objects to Standard-IA"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
