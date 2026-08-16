variable "name" {
  description = "Name of the secret"
  type        = string
}

variable "description" {
  description = "Description of the secret"
  type        = string
  default     = ""
}

variable "recovery_window_in_days" {
  description = "Days before a deleted secret is permanently removed (0 = immediate)"
  type        = number
  default     = 7
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt the secret"
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
