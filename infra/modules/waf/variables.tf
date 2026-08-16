variable "name" {
  description = "Name of the WAF Web ACL"
  type        = string
}

variable "alb_arn" {
  description = "ARN of the ALB to associate the Web ACL with. Null skips the association - use this on EKS, where the AWS Load Balancer Controller creates the ALB dynamically and associates this Web ACL itself via the alb.ingress.kubernetes.io/wafv2-acl-arn Ingress annotation instead."
  type        = string
  default     = null
}

variable "rate_limit" {
  description = "Max requests per 5-minute window from a single IP before it's blocked"
  type        = number
  default     = 2000
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
