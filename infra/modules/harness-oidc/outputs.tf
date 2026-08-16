output "role_arn" {
  description = "ARN of the Harness delegate's IAM role - configure this as the OIDC role in Harness's AWS connector"
  value       = aws_iam_role.this.arn
}

output "oidc_provider_arn" {
  description = "ARN of the Harness IAM OIDC provider"
  value       = aws_iam_openid_connect_provider.harness.arn
}
