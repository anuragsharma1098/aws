variable "name" {
  description = "Name prefix for alarms and the SNS topic"
  type        = string
}

variable "alarm_email" {
  description = "Email address to notify on alarm. Null skips the subscription (topic is still created)."
  type        = string
  default     = null
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the ALB (for CloudWatch dimensions)"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the target group (for CloudWatch dimensions)"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name"
  type        = string
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
