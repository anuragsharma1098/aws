variable "cluster_name" {
  description = "EKS cluster name (modules/eks output cluster_name)"
  type        = string
}

variable "ebs_csi_irsa_role_arn" {
  description = "IRSA role ARN for the EBS CSI driver (modules/eks output ebs_csi_irsa_role_arn)"
  type        = string
}

variable "addon_versions" {
  description = "Explicit versions for core addons. Null = let EKS pick the default compatible version."
  type = object({
    vpc_cni        = optional(string)
    coredns        = optional(string)
    kube_proxy     = optional(string)
    ebs_csi_driver = optional(string)
  })
  default = {}
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
