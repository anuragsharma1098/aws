# EKS access entries: the modern replacement for hand-editing the aws-auth ConfigMap.
# Every principal that needs kubectl/helm access - human or CI - gets an explicit entry
# here instead of an implicit grant.

locals {
  # Flatten {key => {principal_arn, policy_arns, namespaces}} into one row per
  # (entry, policy) pair, since aws_eks_access_policy_association is 1:1 with a policy.
  policy_associations = merge([
    for key, entry in var.access_entries : {
      for policy_arn in entry.policy_arns : "${key}-${md5(policy_arn)}" => {
        principal_arn = entry.principal_arn
        policy_arn    = policy_arn
        namespaces    = entry.namespaces
      }
    }
  ]...)
}

resource "aws_eks_access_entry" "this" {
  for_each      = var.access_entries
  cluster_name  = var.cluster_name
  principal_arn = each.value.principal_arn
}

resource "aws_eks_access_policy_association" "this" {
  for_each      = local.policy_associations
  cluster_name  = var.cluster_name
  principal_arn = each.value.principal_arn
  policy_arn    = each.value.policy_arn

  access_scope {
    type       = length(each.value.namespaces) > 0 ? "namespace" : "cluster"
    namespaces = length(each.value.namespaces) > 0 ? each.value.namespaces : null
  }

  depends_on = [aws_eks_access_entry.this]
}
