variable "name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes minor version, e.g. \"1.31\""
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for cluster ENIs and (typically) worker nodes"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs. Only needed if endpoint_public_access = true and you want internet-facing load balancers provisioned in them."
  type        = list(string)
  default     = []
}

variable "endpoint_private_access" {
  description = "Allow API server access from inside the VPC (required for nodes to join)"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Allow API server access from the internet (kubectl from a laptop, CI runners outside the VPC)"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint, if enabled. Never leave this at 0.0.0.0/0 for anything but a throwaway dev cluster."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "kms_key_arn" {
  description = "KMS key ARN used for envelope encryption of Kubernetes Secrets"
  type        = string
}

variable "permissions_boundary_arn" {
  description = "IAM permissions boundary applied to the EBS CSI driver's IRSA role"
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
