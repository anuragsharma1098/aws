variable "name_prefix" {
  type = string
}

variable "data_subnet_ids" {
  type = list(string)
}

variable "rds_sg_id" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "engine" {
  type    = string
  default = "postgres"
}

variable "engine_version" {
  type    = string
  default = "16.4"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.medium"
}

variable "allocated_storage" {
  type    = number
  default = 100
}

variable "max_allocated_storage" {
  description = "Storage autoscaling ceiling"
  type        = number
  default     = 500
}

variable "database_name" {
  type    = string
  default = "appdb"
}

variable "master_username" {
  type    = string
  default = "app_admin"
}

variable "multi_az" {
  description = "Multi-AZ standby for the primary - enable for staging/prod"
  type        = bool
  default     = true
}

variable "create_read_replica" {
  type    = bool
  default = true
}

variable "read_replica_instance_class" {
  type    = string
  default = "db.t4g.medium"
}

variable "backup_retention_period" {
  type    = number
  default = 7
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "skip_final_snapshot" {
  description = "true only for dev/qa so terraform destroy doesn't hang on a snapshot"
  type        = bool
  default     = false
}

variable "performance_insights_enabled" {
  type    = bool
  default = true
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0 disables)"
  type        = number
  default     = 60
}

variable "enable_proxy" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
