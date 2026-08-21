variable "environment" {
  type    = string
  default = "staging"
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
  default = "10.30.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.30.0.0/24", "10.30.1.0/24"]
}

variable "app_subnet_cidrs" {
  type    = list(string)
  default = ["10.30.10.0/24", "10.30.11.0/24"]
}

variable "data_subnet_cidrs" {
  type    = list(string)
  default = ["10.30.20.0/24", "10.30.21.0/24"]
}

variable "single_nat_gateway" {
  description = "One NAT Gateway per AZ - staging mirrors prod's HA topology"
  type        = bool
  default     = false
}

# --- DNS/edge ---------------------------------------------------------------
variable "domain_name" {
  description = "PLACEHOLDER - this environment's domain"
  type        = string
  default     = "staging.CHANGE_ME.example.com"
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
  default = 3
}

variable "backend_min_capacity" {
  type    = number
  default = 3
}

variable "backend_max_capacity" {
  type    = number
  default = 10
}

variable "backend_cpu" {
  type    = number
  default = 1024
}

variable "backend_memory" {
  type    = number
  default = 2048
}

variable "admin_desired_count" {
  type    = number
  default = 2
}

variable "admin_min_capacity" {
  type    = number
  default = 2
}

variable "admin_max_capacity" {
  type    = number
  default = 4
}

variable "admin_cpu" {
  type    = number
  default = 512
}

variable "admin_memory" {
  type    = number
  default = 1024
}

variable "deployment_config_name" {
  description = "CodeDeploy ECS deployment config - linear shift with a bake window, mirrors prod"
  type        = string
  default     = "CodeDeployDefault.ECSLinear10PercentEvery1Minutes"
}

variable "termination_wait_time_minutes" {
  type    = number
  default = 15
}

# --- Data layer --------------------------------------------------------
variable "db_instance_class" {
  type    = string
  default = "db.r6g.large"
}

variable "db_multi_az" {
  type    = bool
  default = true
}

variable "db_create_read_replica" {
  type    = bool
  default = true
}

variable "db_allocated_storage" {
  type    = number
  default = 200
}

variable "db_deletion_protection" {
  type    = bool
  default = true
}

variable "db_skip_final_snapshot" {
  type    = bool
  default = false
}

variable "redis_max_data_storage_gb" {
  type    = number
  default = 10
}

variable "redis_max_ecpu_per_second" {
  type    = number
  default = 5000
}

# --- Live streaming ------------------------------------------------------
variable "enable_live_streaming" {
  type    = bool
  default = true
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
  description = "Only main promotes to staging, matching prod's promotion gate"
  type        = string
  default     = "refs/heads/main"
}
