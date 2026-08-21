output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "API server endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA certificate, for kubeconfig"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "EKS-managed cluster security group ID - use this as the node group's security group so kubelet<->API traffic works without hand-written rules"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cluster_iam_role_arn" {
  description = "ARN of the cluster's own IAM role (not a node or pod role)"
  value       = aws_iam_role.cluster.arn
}

output "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC provider - required by modules/irsa"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "URL of the cluster's OIDC issuer - required by modules/irsa"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "ebs_csi_irsa_role_arn" {
  description = "IRSA role ARN for the EBS CSI driver addon - pass to modules/eks-addons"
  value       = aws_iam_role.ebs_csi.arn
}
