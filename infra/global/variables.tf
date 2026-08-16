variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name, used to derive resource names"
  type        = string
  default     = "myapp"
}

variable "ecr_repository_names" {
  description = "ECR repositories shared across all environments (images are tagged per-env/per-build, not duplicated per-env)"
  type        = list(string)
  default     = ["backend-app"]
}

variable "cloudtrail_log_bucket_suffix" {
  description = "Suffix to make the CloudTrail log bucket name globally unique, e.g. your AWS account ID"
  type        = string
}
