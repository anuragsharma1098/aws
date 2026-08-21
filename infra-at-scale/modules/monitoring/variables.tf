variable "name_prefix" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "alarm_notification_email" {
  description = "PLACEHOLDER - on-call distribution list. Left as CHANGE_ME, no email subscription is created."
  type        = string
  default     = "CHANGE_ME@example.com"
}

variable "alb_arn_suffix" {
  type = string
}

variable "blue_target_group_arn_suffix" {
  type = string
}

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type = string
}

variable "rds_instance_id" {
  type = string
}

variable "rds_max_connections" {
  type    = number
  default = 500
}

variable "tags" {
  type    = map(string)
  default = {}
}
