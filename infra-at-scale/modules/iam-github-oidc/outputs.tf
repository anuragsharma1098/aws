output "role_arn" {
  description = "Set as the `role-to-assume` input of aws-actions/configure-aws-credentials in ci-cd/github-actions workflows"
  value       = aws_iam_role.github_actions.arn
}
