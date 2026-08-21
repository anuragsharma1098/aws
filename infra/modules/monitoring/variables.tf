variable "name" {
  description = "Name prefix for alarms and the SNS topic"
  type        = string
}

variable "alarm_email" {
  description = "Email address to notify on alarm. Null skips the subscription (topic is still created)."
  type        = string
  default     = null
}

variable "enable_alb_alarms" {
  description = "Create ALB-related alarms. Requires alb_arn_suffix/target_group_arn_suffix. Set false when the ALB isn't Terraform-managed (e.g. the EKS path, where the AWS Load Balancer Controller creates it dynamically)."
  type        = bool
  default     = true
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the ALB (for CloudWatch dimensions). Required if enable_alb_alarms = true."
  type        = string
  default     = null
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the target group (for CloudWatch dimensions). Required if enable_alb_alarms = true."
  type        = string
  default     = null
}

variable "enable_ecs_alarms" {
  description = "Create ECS service CPU/memory alarms. Set false on the EKS path."
  type        = bool
  default     = true
}

variable "ecs_cluster_name" {
  description = "ECS cluster name. Required if enable_ecs_alarms = true."
  type        = string
  default     = null
}

variable "ecs_service_name" {
  description = "ECS service name. Required if enable_ecs_alarms = true."
  type        = string
  default     = null
}

variable "rds_instance_id" {
  description = "RDS instance identifier"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt the SNS topic. Its key policy must grant cloudwatch.amazonaws.com kms:Decrypt, or alarms can't publish to it."
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
