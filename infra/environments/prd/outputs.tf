output "alb_dns_name" {
  description = "Public DNS name of the ALB - point your API subdomain here, or hit it directly"
  value       = module.alb.alb_dns_name
}

output "api_endpoint" {
  description = "Public URL for the backend API - the real domain once enable_dns = true, otherwise the raw ALB DNS name"
  value       = var.enable_dns ? "https://${var.api_subdomain}.${var.domain_name}" : "http://${module.alb.alb_dns_name}"
}

output "frontend_endpoint" {
  description = "Public URL for the frontend - the real domain once enable_dns = true, otherwise the raw CloudFront domain name"
  value       = var.enable_dns ? "https://${var.frontend_subdomain}.${var.domain_name}" : "https://${module.frontend.cloudfront_domain_name}"
}

output "kms_key_arn" {
  description = "Environment's customer-managed KMS key ARN"
  value       = module.kms.key_arn
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

output "ecr_repository_urls" {
  description = "Shared ECR repository URLs (from infra/global) - push images here, then set backend_image_tag"
  value       = data.terraform_remote_state.global.outputs.ecr_repository_urls
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs_cluster.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs_service.service_name
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
