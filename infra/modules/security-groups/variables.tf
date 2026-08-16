variable "name_prefix" {
  description = "Name prefix for security groups, e.g. myapp-dev"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID the security groups belong to"
  type        = string
}

variable "alb_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the ALB on 80/443"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "container_port" {
  description = "Port the backend application container listens on"
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Port the database listens on"
  type        = number
  default     = 5432
}

variable "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID (modules/eks output cluster_security_group_id). If set, the database also accepts ingress from it - the EKS path, where pods use the cluster SG directly instead of this module's app_sg."
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
