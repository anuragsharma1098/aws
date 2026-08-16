variable "name" {
  description = "Name for the key alias, e.g. myapp-dev"
  type        = string
}

variable "description" {
  description = "Key description. Defaults to a generic description based on name."
  type        = string
  default     = null
}

variable "deletion_window_in_days" {
  description = "Waiting period before the key is actually deleted after a destroy"
  type        = number
  default     = 30
}

variable "enable_key_rotation" {
  description = "Enable automatic annual key rotation"
  type        = bool
  default     = true
}

variable "service_principals" {
  description = "AWS service principals (e.g. s3.amazonaws.com, rds.amazonaws.com) granted standard Encrypt/Decrypt/GenerateDataKey/DescribeKey/CreateGrant usage of this key"
  type        = list(string)
  default     = []
}

variable "enable_cloudwatch_logs" {
  description = "Add the CloudWatch Logs key-policy statement (logs has a non-standard, region-scoped principal + encryption-context condition)"
  type        = bool
  default     = false
}

variable "enable_cloudtrail" {
  description = "Add the CloudTrail key-policy statements (also non-standard: requires an encryption-context condition)"
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "Region, required when enable_cloudwatch_logs = true (CloudWatch Logs' principal is region-scoped: logs.<region>.amazonaws.com)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
