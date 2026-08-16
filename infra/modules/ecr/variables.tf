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

variable "cross_account_pull_principals" {
  description = "Account-root or role ARNs in OTHER AWS accounts allowed to pull images from these repos - e.g. [\"arn:aws:iam::<qa-account-id>:root\", \"arn:aws:iam::<prd-account-id>:root\"] when ECR is centralized in one account (typically dev/build) and other environments' EKS clusters pull the same built image cross-account instead of rebuilding it. Empty list grants no cross-account access. Actual restriction still comes from each account's own IAM policy on the calling principal (e.g. the node role's AmazonEC2ContainerRegistryReadOnly) - this only opens the door at the resource-policy layer."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
