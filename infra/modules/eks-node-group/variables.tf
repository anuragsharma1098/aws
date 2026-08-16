variable "cluster_name" {
  description = "EKS cluster name this node group joins"
  type        = string
}

variable "node_group_name" {
  description = "Name of the node group"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs nodes launch into"
  type        = list(string)
}

variable "instance_types" {
  description = "EC2 instance types eligible for this node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "capacity_type" {
  description = "ON_DEMAND or SPOT"
  type        = string
  default     = "ON_DEMAND"
}

variable "disk_size" {
  description = "Root EBS volume size in GB per node"
  type        = number
  default     = 20
}

variable "desired_size" {
  description = "Desired node count"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum node count"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum node count"
  type        = number
  default     = 4
}

variable "labels" {
  description = "Kubernetes labels applied to every node in this group"
  type        = map(string)
  default     = {}
}

variable "permissions_boundary_arn" {
  description = "IAM permissions boundary applied to the node IAM role"
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
