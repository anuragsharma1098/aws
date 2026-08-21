variable "environment" {
  type    = string
  default = "qa"
}

variable "project" {
  type    = string
  default = "infra-at-scale"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

# --- Networking ------------------------------------------------------------
variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "app_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.10.0/24", "10.20.11.0/24"]
}

variable "data_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.20.0/24", "10.20.21.0/24"]
}

variable "single_nat_gateway" {
  description = "One shared NAT Gateway - cheaper, acceptable for qa"
  type        = bool
  default     = true
}

# --- DNS/edge ---------------------------------------------------------------
variable "domain_name" {
  description = "PLACEHOLDER - this environment's domain"
  type        = string
  default     = "qa.CHANGE_ME.example.com"
}

variable "create_hosted_zone" {
  type    = bool
  default = true
}

# --- Compute ------------------------------------------------------------
variable "container_image" {
  description = "PLACEHOLDER - CI-built ECR image URI"
  type        = string
  default     = "CHANGE_ME/placeholder-image:latest"
}

variable "backend_desired_count" {
  type    = number
  default = 2
}

variable "backend_min_capacity" {
  type    = number
  default = 2
}

variable "backend_max_capacity" {
  type    = number
  default = 6
}

variable "backend_cpu" {
  type    = number
  default = 512
}

variable "backend_memory" {
  type    = number
  default = 1024
}

variable "admin_desired_count" {
  type    = number
  default = 1
}

variable "admin_min_capacity" {
  type    = number
  default = 1
}

variable "admin_max_capacity" {
  type    = number
  default = 2
}

variable "admin_cpu" {
  type    = number
  default = 256
}

variable "admin_memory" {
  type    = number
  default = 512
}

variable "deployment_config_name" {
  description = "CodeDeploy ECS deployment config - fast, still all-at-once for qa"
  type        = string
  default     = "CodeDeployDefault.ECSAllAtOnce"
}

variable "termination_wait_time_minutes" {
  type    = number
  default = 5
}

# --- Data layer --------------------------------------------------------
variable "db_instance_class" {
  type    = string
  default = "db.t4g.medium"
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "db_create_read_replica" {
  type    = bool
  default = true
}

variable "db_allocated_storage" {
  type    = number
  default = 100
}

variable "db_deletion_protection" {
  type    = bool
  default = false
}

variable "db_skip_final_snapshot" {
  type    = bool
  default = true
}

variable "redis_max_data_storage_gb" {
  type    = number
  default = 5
}

variable "redis_max_ecpu_per_second" {
  type    = number
  default = 3000
}

# --- Live streaming ------------------------------------------------------
variable "enable_live_streaming" {
  description = "MediaLive bills hourly while running - enable only when actively testing the pipeline"
  type        = bool
  default     = false
}

# --- Observability / CI ---------------------------------------------------
variable "alarm_notification_email" {
  type    = string
  default = "CHANGE_ME@example.com"
}

variable "github_repository" {
  type    = string
  default = "CHANGE_ME/CHANGE_ME"
}

variable "github_allowed_ref" {
  description = "Narrower than dev - qa deploys only from main"
  type        = string
  default     = "refs/heads/main"
}
