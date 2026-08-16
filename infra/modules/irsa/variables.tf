variable "name" {
  description = "Name for the IAM role"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC provider (modules/eks output oidc_provider_arn)"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the cluster's OIDC issuer, including https:// (modules/eks output oidc_provider_url)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace the service account lives in"
  type        = string
}

variable "service_account_name" {
  description = "Kubernetes service account name this role is scoped to - only pods running as this exact service account can assume the role"
  type        = string
}

variable "policy_json" {
  description = "IAM policy document (JSON) granting this role its AWS permissions"
  type        = string
}

variable "permissions_boundary_arn" {
  description = "IAM permissions boundary policy ARN. Null attaches no boundary."
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
