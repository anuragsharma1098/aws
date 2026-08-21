variable "environment" {
  description = "Environment this state backend serves (dev, qa, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "qa", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, qa, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region to create the state bucket/lock table in"
  type        = string
  default     = "us-east-1"
}
