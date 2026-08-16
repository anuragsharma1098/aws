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

variable "terraform_deploy_role_arn" {
  description = "IAM role ARN to assume in this account before applying, if using cross-account role assumption (multi-account setups) instead of a pre-scoped credential/profile. Null uses whatever credentials are already active."
  type        = string
  default     = null
}

variable "ecr_repository_names" {
  description = "ECR repositories for this account's environment (per-account, not shared - see README.md's account-topology section)"
  type        = list(string)
  default     = ["backend-app"]
}

variable "ecr_cross_account_pull_principals" {
  description = "Account-root or role ARNs allowed to pull cross-account from this account's ECR - e.g. dev sets this to [\"arn:aws:iam::<qa-account-id>:root\"] so qa's Harness role can copy an already-validated image in during promotion. Empty for the last environment in the promotion chain (nothing pulls from prd)."
  type        = list(string)
  default     = []
}
