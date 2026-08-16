output "api_endpoint" {
  description = "Public URL for the backend API once enable_dns = true. Before that, there's no stable Terraform-known URL - the AWS Load Balancer Controller assigns the ALB's DNS name when the Ingress is deployed; check `kubectl get ingress` after the Helm release."
  value       = var.enable_dns ? "https://${var.api_subdomain}.${var.domain_name}" : null
}

output "frontend_endpoint" {
  description = "Public URL for the frontend - the real domain once enable_dns = true, otherwise the raw CloudFront domain name"
  value       = var.enable_dns ? "https://${var.frontend_subdomain}.${var.domain_name}" : "https://${module.frontend.cloudfront_domain_name}"
}

output "kms_key_arn" {
  description = "Environment's customer-managed KMS key ARN"
  value       = module.kms.key_arn
}

output "cloudtrail_arn" {
  description = "ARN of this account's audit trail"
  value       = module.cloudtrail.trail_arn
}

output "permissions_boundary_arn" {
  description = "IAM permissions boundary policy ARN attached to this environment's app roles"
  value       = module.iam_boundary.boundary_arn
}

output "cloudfront_domain_name" {
  description = "CloudFront domain for the frontend - point your apex/www subdomain here, or hit it directly"
  value       = module.frontend.cloudfront_domain_name
}

output "frontend_bucket_name" {
  description = "S3 bucket to sync built frontend assets to"
  value       = module.frontend.bucket_name
}

output "uploads_bucket_name" {
  description = "S3 bucket for user uploads"
  value       = module.uploads.bucket_name
}

output "ci_artifacts_bucket_name" {
  description = "S3 bucket Harness CI writes test logs/reports to"
  value       = module.ci_artifacts.bucket_name
}

output "ecr_repository_urls" {
  description = "Shared ECR repository URLs (from infra/global) - the Helm chart's image values reference these"
  value       = data.terraform_remote_state.global.outputs.ecr_repository_urls
}

output "db_endpoint" {
  description = "RDS connection endpoint"
  value       = module.rds.db_endpoint
}

output "db_secret_arn" {
  description = "Secrets Manager ARN holding DB credentials"
  value       = module.rds.secret_arn
}

output "app_secrets_arn" {
  description = "Secrets Manager ARN for application secrets - populate its value out-of-band"
  value       = module.app_secrets.secret_arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

# --- EKS / Harness ---

output "eks_cluster_name" {
  description = "EKS cluster name - use with `aws eks update-kubeconfig --name <this>`"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "lb_controller_irsa_role_arn" {
  description = "IRSA role ARN for the AWS Load Balancer Controller - set as eks.amazonaws.com/role-arn on its service account (or the Helm chart's serviceAccount.annotations value)"
  value       = module.irsa_lb_controller.role_arn
}

output "external_secrets_irsa_role_arn" {
  description = "IRSA role ARN for the External Secrets Operator - same annotation pattern as the LB controller"
  value       = module.irsa_external_secrets.role_arn
}

output "external_dns_irsa_role_arn" {
  description = "IRSA role ARN for external-dns. Null until enable_dns = true - there's no zone for it to manage before then."
  value       = var.enable_dns ? module.irsa_external_dns[0].role_arn : null
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN - set as the Ingress annotation alb.ingress.kubernetes.io/wafv2-acl-arn to associate it with the ALB the Load Balancer Controller creates"
  value       = var.enable_waf ? module.waf[0].web_acl_arn : null
}

output "alb_security_group_id" {
  description = "Security group ID for the ALB - set as the Ingress annotation alb.ingress.kubernetes.io/security-groups if you want Terraform-managed ingress rules instead of a controller-generated security group"
  value       = module.security_groups.alb_sg_id
}

output "harness_role_arn" {
  description = "IAM role ARN to configure as the OIDC role in Harness's AWS connector"
  value       = module.harness_oidc.role_arn
}
