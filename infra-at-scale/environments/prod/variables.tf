variable "environment" {
  type    = string
  default = "prod"
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
  description = "prod spreads across 3 AZs; other environments use 2"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# --- Networking ------------------------------------------------------------
variable "vpc_cidr" {
  type    = string
  default = "10.40.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.40.0.0/24", "10.40.1.0/24", "10.40.2.0/24"]
}

variable "app_subnet_cidrs" {
  type    = list(string)
  default = ["10.40.10.0/24", "10.40.11.0/24", "10.40.12.0/24"]
}

variable "data_subnet_cidrs" {
  type    = list(string)
  default = ["10.40.20.0/24", "10.40.21.0/24", "10.40.22.0/24"]
}

variable "single_nat_gateway" {
  description = "One NAT Gateway per AZ - never share a single NAT in prod"
  type        = bool
  default     = false
}

# --- DNS/edge ---------------------------------------------------------------
variable "domain_name" {
  description = "PLACEHOLDER - the apex domain (prod serves the bare domain, other envs use subdomains)"
  type        = string
  default     = "CHANGE_ME.example.com"
}

variable "create_hosted_zone" {
  type    = bool
  default = true
}

# --- Compute ------------------------------------------------------------
variable "container_image" {
  description = "PLACEHOLDER - CI-built ECR image URI, pinned by digest for prod, not a mutable tag"
  type        = string
  default     = "CHANGE_ME/placeholder-image@sha256:CHANGE_ME"
}

variable "backend_desired_count" {
  type    = number
  default = 6
}

variable "backend_min_capacity" {
  type    = number
  default = 6
}

variable "backend_max_capacity" {
  type    = number
  default = 40
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
  default = 6
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
  description = "CodeDeploy ECS deployment config - canary with a bake window; the release itself is additionally gated on manual approval in CI, not just this config"
  type        = string
  default     = "CodeDeployDefault.ECSCanary10Percent15Minutes"
}

variable "termination_wait_time_minutes" {
  description = "Longer rollback safety window than staging - prod bake time is expensive to rush"
  type        = number
  default     = 30
}

# --- Data layer --------------------------------------------------------
variable "db_instance_class" {
  type    = string
  default = "db.r6g.xlarge"
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
  default = 500
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
  default = 50
}

variable "redis_max_ecpu_per_second" {
  type    = number
  default = 15000
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
  description = "Narrowest of every environment - only main, and CI additionally requires a GitHub Environment manual-approval gate before this role is ever assumed for a prod deploy"
  type        = string
  default     = "refs/heads/main"
}
