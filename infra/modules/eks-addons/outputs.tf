output "addon_names" {
  description = "Names of the addons created"
  value = [
    aws_eks_addon.vpc_cni.addon_name,
    aws_eks_addon.kube_proxy.addon_name,
    aws_eks_addon.coredns.addon_name,
    aws_eks_addon.ebs_csi.addon_name,
  ]
}
