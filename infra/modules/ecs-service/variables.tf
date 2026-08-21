variable "name" {
  description = "Name of the ECS service and task family"
  type        = string
}

variable "cluster_arn" {
  description = "ARN of the ECS cluster to run in"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs to run tasks in"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for the tasks"
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN to register tasks with"
  type        = string
}

variable "container_image" {
  description = "Full image URI (including tag) to run, e.g. <account>.dkr.ecr.<region>.amazonaws.com/backend-app:latest"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "Fargate task vCPU units (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargate task memory in MiB"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of running tasks"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Minimum number of tasks for autoscaling"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum number of tasks for autoscaling"
  type        = number
  default     = 6
}

variable "cpu_target_value" {
  description = "Target average CPU utilization percentage for autoscaling"
  type        = number
  default     = 60
}

variable "environment_variables" {
  description = "Plain (non-secret) environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Map of container env var name to Secrets Manager / SSM ARN, injected securely at task start"
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 30
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt the CloudWatch Logs group"
  type        = string
}

variable "permissions_boundary_arn" {
  description = "IAM permissions boundary policy ARN applied to the execution and task roles. Null attaches no boundary."
  type        = string
  default     = null
}

variable "assign_public_ip" {
  description = "Assign a public IP to tasks. Should stay false - tasks live in private subnets and reach the internet via NAT."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
