variable "name_prefix" {
  description = "Prefix applied to every resource name, e.g. \"myapp-prod\""
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "Availability zones to spread subnets across (2 minimum for HA)"
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2
    error_message = "At least 2 availability zones are required for Multi-AZ resilience."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR per public subnet, one per AZ (ALB, NAT Gateways)"
  type        = list(string)
}

variable "app_subnet_cidrs" {
  description = "CIDR per private application-layer subnet, one per AZ (ECS tasks)"
  type        = list(string)
}

variable "data_subnet_cidrs" {
  description = "CIDR per private data-layer subnet, one per AZ (RDS, ElastiCache)"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use one shared NAT Gateway instead of one per AZ. Cheaper, less resilient - use for dev/qa only."
  type        = bool
  default     = false
}

variable "flow_logs_retention_days" {
  description = "CloudWatch Logs retention for VPC flow logs"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common tags applied to every resource in this module"
  type        = map(string)
  default     = {}
}
