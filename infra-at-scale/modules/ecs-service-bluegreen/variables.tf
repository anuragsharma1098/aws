variable "name_prefix" {
  description = "e.g. \"myapp-prod-backend\" - unique per service (backend, admin are separate instantiations)"
  type        = string
}

variable "cluster_arn" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "app_subnet_ids" {
  type = list(string)
}

variable "ecs_tasks_sg_id" {
  type = string
}

variable "execution_role_arn" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "codedeploy_role_arn" {
  type = string
}

variable "https_listener_arn" {
  type = string
}

variable "blue_target_group_name" {
  type = string
}

variable "green_target_group_name" {
  type = string
}

variable "blue_target_group_arn" {
  type = string
}

variable "green_target_group_arn" {
  type = string
}

variable "container_name" {
  type    = string
  default = "app"
}

variable "container_image" {
  description = "PLACEHOLDER - your CI pipeline's ECR image URI, e.g. 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp:CHANGE_ME"
  type        = string
  default     = "CHANGE_ME/placeholder-image:latest"
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "cpu" {
  description = "Fargate task vCPU units (256 = 0.25 vCPU)"
  type        = number
  default     = 512
}

variable "memory" {
  description = "Fargate task memory in MiB"
  type        = number
  default     = 1024
}

variable "environment_variables" {
  description = "Plain (non-secret) container env vars"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "map(container env var name -> Secrets Manager ARN); injected securely, never in the task def as plaintext"
  type        = map(string)
  default     = {}
}

variable "desired_count" {
  type    = number
  default = 2
}

variable "min_capacity" {
  type    = number
  default = 2
}

variable "max_capacity" {
  type    = number
  default = 10
}

variable "cpu_target_value" {
  description = "Target-tracking autoscaling: average CPU utilization %"
  type        = number
  default     = 60
}

variable "memory_target_value" {
  description = "Target-tracking autoscaling: average memory utilization %"
  type        = number
  default     = 70
}

variable "deployment_config_name" {
  description = "CodeDeploy ECS deployment config - controls blue/green traffic-shift speed"
  type        = string
  default     = "CodeDeployDefault.ECSAllAtOnce"

  validation {
    condition = contains([
      "CodeDeployDefault.ECSAllAtOnce",
      "CodeDeployDefault.ECSLinear10PercentEvery1Minutes",
      "CodeDeployDefault.ECSLinear10PercentEvery3Minutes",
      "CodeDeployDefault.ECSCanary10Percent5Minutes",
      "CodeDeployDefault.ECSCanary10Percent15Minutes",
    ], var.deployment_config_name)
    error_message = "Must be one of the standard AWS-provided ECS CodeDeploy deployment configs."
  }
}

variable "termination_wait_time_minutes" {
  description = "How long CodeDeploy keeps the old (blue) task set running after traffic shifts fully to green, before terminating it - the rollback safety window"
  type        = number
  default     = 5
}

variable "alarm_arns" {
  description = "CloudWatch alarm ARNs that trigger automatic deployment rollback"
  type        = list(string)
  default     = []
}

variable "enable_auto_rollback" {
  type    = bool
  default = true
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
