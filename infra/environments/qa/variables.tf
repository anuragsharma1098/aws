variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name, used to derive resource names"
  type        = string
  default     = "myapp"
}

variable "environment" {
  description = "Environment name: dev, qa, or prd"
  type        = string
}

variable "state_bucket" {
  description = "Name of the shared Terraform state bucket (from infra/bootstrap), used to read infra/global's outputs"
  type        = string
}

# --- Networking ---

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use a single shared NAT Gateway instead of one per AZ"
  type        = bool
  default     = true
}

variable "alb_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the ALB on 443"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "alb_deletion_protection" {
  description = "Enable deletion protection on the ALB"
  type        = bool
  default     = false
}

# --- DNS / TLS (optional - off until a real domain exists) ---

variable "enable_dns" {
  description = "Create a Route 53 hosted zone + ACM certificate for this environment"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Domain name for this environment, e.g. dev.myapp.com. Required if enable_dns = true."
  type        = string
  default     = ""
}

variable "api_subdomain" {
  description = "Subdomain the backend API is served on, e.g. \"api\" -> api.<domain_name>. Only used when enable_dns = true."
  type        = string
  default     = "api"
}

variable "frontend_subdomain" {
  description = "Subdomain the frontend is served on, e.g. \"www\" -> www.<domain_name>. Only used when enable_dns = true."
  type        = string
  default     = "www"
}

# --- Backend (ECS Fargate) ---

variable "container_port" {
  description = "Port the backend container listens on"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "ALB target group health check path"
  type        = string
  default     = "/health"
}

variable "backend_image_tag" {
  description = "Tag of the backend-app image (in the shared ECR repo from infra/global) to deploy"
  type        = string
  default     = "latest"
}

variable "ecs_cpu" {
  description = "Fargate task vCPU units"
  type        = number
  default     = 256
}

variable "ecs_memory" {
  description = "Fargate task memory in MiB"
  type        = number
  default     = 512
}

variable "ecs_desired_count" {
  description = "Desired number of running tasks"
  type        = number
  default     = 1
}

variable "ecs_min_capacity" {
  description = "Minimum tasks for autoscaling"
  type        = number
  default     = 1
}

variable "ecs_max_capacity" {
  description = "Maximum tasks for autoscaling"
  type        = number
  default     = 2
}

# --- Database (RDS Postgres) ---

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "appdb"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Storage autoscaling ceiling in GB"
  type        = number
  default     = 50
}

variable "db_multi_az" {
  description = "Enable Multi-AZ standby"
  type        = bool
  default     = false
}

variable "db_backup_retention_period" {
  description = "Automated backup retention in days"
  type        = number
  default     = 3
}

variable "db_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot on destroy"
  type        = bool
  default     = true
}

# --- Storage ---

variable "frontend_bucket_name" {
  description = "Globally-unique S3 bucket name for built frontend assets"
  type        = string
}

variable "uploads_bucket_name" {
  description = "Globally-unique S3 bucket name for user uploads"
  type        = string
}

variable "uploads_cors_origins" {
  description = "Origins allowed to upload directly to the uploads bucket"
  type        = list(string)
  default     = []
}

# --- Security & monitoring ---

variable "enable_waf" {
  description = "Attach a WAF Web ACL to the ALB"
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "Max requests per 5-minute window from a single IP"
  type        = number
  default     = 2000
}

variable "alarm_email" {
  description = "Email to notify on CloudWatch alarms. Null skips the subscription."
  type        = string
  default     = null
}
