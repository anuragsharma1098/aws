variable "aws_region" {
  description = "AWS region to create the state bucket and lock table in"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name, used to derive resource names"
  type        = string
  default     = "myapp"
}

variable "state_bucket_suffix" {
  description = "Suffix to make the state bucket name globally unique, e.g. your AWS account ID"
  type        = string
}

variable "terraform_deploy_role_arn" {
  description = "IAM role ARN to assume in this account before applying, if using cross-account role assumption (multi-account setups) instead of a pre-scoped credential/profile. Null uses whatever credentials are already active."
  type        = string
  default     = null
}
