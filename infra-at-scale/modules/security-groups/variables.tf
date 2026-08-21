variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "container_port" {
  description = "Port the ECS task's app container listens on"
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Port RDS/RDS Proxy listens on"
  type        = number
  default     = 5432
}

variable "redis_port" {
  description = "Port ElastiCache Redis listens on"
  type        = number
  default     = 6379
}

variable "tags" {
  type    = map(string)
  default = {}
}
