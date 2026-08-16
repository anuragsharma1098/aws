variable "name" {
  description = "Name for the Harness IAM role"
  type        = string
}

variable "oidc_issuer_url" {
  description = <<-EOT
    Harness's OIDC issuer URL (including https://), from your Harness account's OIDC/identity
    provider settings. There is no universal default - this is account-specific and must come
    from Harness's own docs/UI for your org, not guessed.
  EOT
  type        = string
}

variable "audience" {
  description = "Expected 'aud' claim in tokens Harness presents - check Harness's OIDC setup docs for the exact value your account uses"
  type        = string
  default     = "sts.amazonaws.com"
}

variable "subject_claim" {
  description = <<-EOT
    Expected 'sub' claim, scoping which Harness pipeline/account can assume this role (e.g.
    a specific Harness account ID or pipeline identifier). Leaving this at "*" trusts ANY
    token this issuer signs - narrow it before using this in anything but a throwaway
    environment.
  EOT
  type        = string
  default     = "*"
}

variable "ecr_push_repository_arns" {
  description = "This environment's own ECR repository ARNs - Harness CI/CD can push and pull here freely"
  type        = list(string)
}

variable "ecr_pull_repository_arns" {
  description = "The PREVIOUS environment's ECR repository ARNs (e.g. qa's Harness role gets dev's repo ARNs here) - pull-only, used to copy an already-validated image in by digest during promotion. Empty for the first environment in the chain (nothing precedes it)."
  type        = list(string)
  default     = []
}

variable "ci_artifacts_bucket_arn" {
  description = "S3 bucket ARN Harness CI writes test logs/reports to"
  type        = string
}

variable "eks_cluster_arn" {
  description = "EKS cluster ARN Harness CD deploys to - actual deploy permissions come from an EKS access entry (modules/eks-access) for this role's ARN, not from this IAM policy alone"
  type        = string
}

variable "permissions_boundary_arn" {
  description = "IAM permissions boundary policy ARN"
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
