# Instantiate this module with depends_on = [module.eks_node_group] at the call site -
# coredns in particular needs somewhere to schedule, and this module needing the node
# group's existence while the node group needs the cluster's existence (from modules/eks)
# is a straight line, not a cycle, as long as this module doesn't feed anything back into
# modules/eks itself.

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = var.cluster_name
  addon_name                  = "vpc-cni"
  addon_version               = var.addon_versions.vpc_cni
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = var.cluster_name
  addon_name                  = "kube-proxy"
  addon_version               = var.addon_versions.kube_proxy
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = var.cluster_name
  addon_name                  = "coredns"
  addon_version               = var.addon_versions.coredns
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = var.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = var.addon_versions.ebs_csi_driver
  service_account_role_arn    = var.ebs_csi_irsa_role_arn
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
}
