output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "frontend_url" {
  value = "https://${module.dns.frontend_fqdn}"
}

output "api_url" {
  value = "https://${module.dns.api_fqdn}"
}

output "hosted_zone_id" {
  value = module.dns.zone_id
}

output "hosted_zone_name_servers" {
  description = "If create_hosted_zone = true, delegate your registrar's NS records to these"
  value       = var.create_hosted_zone ? "see: aws route53 get-hosted-zone --id ${module.dns.zone_id}" : "using existing zone - no delegation needed"
}

output "rds_proxy_endpoint" {
  value = module.rds.proxy_endpoint
}

output "redis_endpoint" {
  value = module.elasticache.endpoint_address
}

output "ecs_cluster_name" {
  value = module.ecs_cluster.cluster_name
}

output "backend_codedeploy_app" {
  value = module.ecs_backend.codedeploy_app_name
}

output "backend_codedeploy_deployment_group" {
  value = module.ecs_backend.codedeploy_deployment_group_name
}

output "admin_codedeploy_app" {
  value = module.ecs_admin.codedeploy_app_name
}

output "github_actions_role_arn" {
  description = "Set as role-to-assume in the GitHub Actions workflow for this environment"
  value       = module.github_oidc.role_arn
}

output "cloudwatch_dashboard_name" {
  value = module.monitoring.dashboard_name
}

output "live_streaming_hls_bucket" {
  value = var.enable_live_streaming ? module.live_streaming[0].hls_bucket_name : null
}
