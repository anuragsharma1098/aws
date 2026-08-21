variable "name" {
  description = "Name prefix for the boundary policy"
  type        = string
}

variable "allowed_regions" {
  description = "If non-empty, denies region-scoped API calls outside these regions. Empty list = no region restriction."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
