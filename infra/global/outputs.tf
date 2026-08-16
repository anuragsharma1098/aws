output "ecr_repository_urls" {
  description = "Map of repository name to URL - reference these from each environment's ecs-service container_image"
  value       = module.ecr.repository_urls
}

output "cloudtrail_arn" {
  description = "ARN of the account audit trail"
  value       = module.cloudtrail.trail_arn
}
