output "ecr_repository_urls" {
  description = "Map of repository name to URL - reference these from the Helm chart's image values"
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "Map of repository name to ARN - used to scope the Harness deploy role's ECR push permissions"
  value       = module.ecr.repository_arns
}
