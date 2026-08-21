variable "name" {
  description = "Name prefix for all VPC resources, e.g. myapp-dev"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across (2+ required)"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ, in the same order as var.azs"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ, in the same order as var.azs"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use a single shared NAT Gateway instead of one per AZ. Cheaper, less resilient - fine for dev/qa, not recommended for prd."
  type        = bool
  default     = false
}

variable "eks_cluster_name" {
  description = "If set, tags subnets for EKS/ELB auto-discovery: kubernetes.io/cluster/<name>=shared on all subnets, kubernetes.io/role/elb=1 on public, kubernetes.io/role/internal-elb=1 on private. Null skips these tags entirely."
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
