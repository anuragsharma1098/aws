output "boundary_arn" {
  description = "ARN of the permissions boundary policy"
  value       = aws_iam_policy.boundary.arn
}

output "boundary_name" {
  description = "Name of the permissions boundary policy"
  value       = aws_iam_policy.boundary.name
}
