variable "name_prefix" {
  type = string
}

variable "github_repository" {
  description = "PLACEHOLDER - \"org/repo\" allowed to assume this role via GitHub Actions OIDC"
  type        = string
  default     = "CHANGE_ME/CHANGE_ME"
}

variable "allowed_ref" {
  description = "Git ref allowed to deploy this environment, e.g. \"refs/heads/main\" for prod, \"refs/heads/*\" for dev. Narrower for prod is safer."
  type        = string
  default     = "refs/heads/*"
}

variable "ecr_repository_arns" {
  description = "ECR repo ARNs this role may push/pull images from"
  type        = list(string)
  default     = []
}

variable "ecs_cluster_arns" {
  type    = list(string)
  default = []
}

variable "codedeploy_application_arns" {
  type    = list(string)
  default = []
}

variable "terraform_state_bucket_arn" {
  description = "Optional: grant this role rights to run terraform plan/apply against this environment's state"
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
