variable "repository_names" {
  description = "Names of the ECR repositories to create"
  type        = list(string)
}

variable "image_tag_mutability" {
  description = "Whether image tags can be overwritten (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "IMMUTABLE"
}

variable "scan_on_push" {
  description = "Scan images for vulnerabilities on push"
  type        = bool
  default     = true
}

variable "untagged_image_expiry_days" {
  description = "Days after which untagged images are expired"
  type        = number
  default     = 14
}

variable "max_tagged_images" {
  description = "Maximum number of tagged images to retain per repository"
  type        = number
  default     = 20
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt repository images"
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
