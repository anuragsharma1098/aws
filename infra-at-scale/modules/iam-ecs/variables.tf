variable "name_prefix" {
  type = string
}

variable "secrets_arns" {
  description = "Secrets Manager ARNs the task execution role may read to inject as container env vars"
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  type = string
}

variable "task_role_policy_json" {
  description = "Additional IAM policy JSON granting the *application* (task role) access to AWS APIs it calls at runtime (e.g. S3, SES). Placeholder default grants nothing - fill in per service."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
