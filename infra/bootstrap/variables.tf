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
