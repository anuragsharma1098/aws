variable "name" {
  description = "Name for the ALB and related resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs to place the ALB in"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for the ALB"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS. Null means HTTP-only (no domain yet)."
  type        = string
  default     = null
}

variable "target_port" {
  description = "Port on the targets (containers/instances) to route traffic to"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Path used for target group health checks"
  type        = string
  default     = "/health"
}

variable "deletion_protection" {
  description = "Enable deletion protection on the ALB"
  type        = bool
  default     = false
}

variable "access_logs_bucket" {
  description = "S3 bucket to write ALB access logs to. Null disables access logging."
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
