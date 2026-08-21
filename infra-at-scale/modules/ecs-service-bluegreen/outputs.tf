output "service_name" {
  value = aws_ecs_service.this.name
}

output "task_definition_family" {
  value = aws_ecs_task_definition.this.family
}

output "task_definition_arn" {
  description = "Initial revision only - CI/CD registers new revisions per deploy, this does not track them"
  value       = aws_ecs_task_definition.this.arn
}

output "codedeploy_app_name" {
  value = aws_codedeploy_app.this.name
}

output "codedeploy_deployment_group_name" {
  value = aws_codedeploy_deployment_group.this.deployment_group_name
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.service.name
}
