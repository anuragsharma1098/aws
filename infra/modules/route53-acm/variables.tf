variable "enabled" {
  description = "Whether to create the hosted zone and certificate at all. False = module is a no-op (no domain yet)."
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Root domain name to manage, e.g. myapp.example.com. Required if enabled = true."
  type        = string
  default     = ""
}

variable "subject_alternative_names" {
  description = "Additional names to cover on the certificate, e.g. [\"www.myapp.example.com\"]"
  type        = list(string)
  default     = []
}

variable "create_zone" {
  description = "Create a new Route 53 hosted zone. Set false if the zone already exists and you only want the ACM certificate."
  type        = bool
  default     = true
}

variable "existing_zone_id" {
  description = "Reuse this zone ID instead of creating/looking one up - for a second instantiation of this module (e.g. a us-east-1-provider CloudFront cert) that validates against the same zone a prior instance already created."
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
