variable "name_prefix" {
  type = string
}

variable "data_subnet_ids" {
  type = list(string)
}

variable "redis_sg_id" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "major_engine_version" {
  type    = string
  default = "7"
}

variable "max_data_storage_gb" {
  description = "ElastiCache Serverless storage ceiling in GB"
  type        = number
  default     = 10
}

variable "max_ecpu_per_second" {
  description = "ElastiCache Serverless compute ceiling (ECPUs/sec)"
  type        = number
  default     = 5000
}

variable "snapshot_retention_limit" {
  type    = number
  default = 7
}

variable "tags" {
  type    = map(string)
  default = {}
}
