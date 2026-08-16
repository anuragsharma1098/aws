variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "access_entries" {
  description = <<-EOT
    Map of arbitrary key -> { principal_arn, policy_arns, namespaces }. Each principal_arn
    gets one access entry plus one access-policy association per policy_arn. `namespaces`
    scopes the association to those namespaces (empty list = cluster-wide) - use this to
    give Harness's deploy role edit access to just its own environment's namespace instead
    of the whole cluster.
  EOT
  type = map(object({
    principal_arn = string
    policy_arns   = list(string)
    namespaces    = optional(list(string), [])
  }))
  default = {}
}
