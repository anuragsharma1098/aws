variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "certificate_arn" {
  description = "Regional ACM certificate ARN, used on every HTTPS listener"
  type        = string
}

variable "web_acl_arn" {
  description = "REGIONAL-scope WAFv2 web ACL ARN to associate with this ALB"
  type        = string
}

variable "logs_bucket_name" {
  type = string
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "services" {
  description = <<-EOT
    map(service key -> config) - one HTTPS listener + blue/green target group
    pair per entry, all on the same ALB. CodeDeploy deployment groups target
    a listener, not a path rule, so distinct services get distinct listener
    ports on one ALB rather than path-based routing on a shared listener.
  EOT
  type = map(object({
    listener_port     = number
    container_port    = number
    health_check_path = string
  }))
  default = {
    backend = {
      listener_port     = 443
      container_port    = 8080
      health_check_path = "/healthz"
    }
    admin = {
      listener_port     = 8443
      container_port    = 8081
      health_check_path = "/admin/healthz"
    }
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
