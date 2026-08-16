output "state_bucket_name" {
  description = "S3 bucket name to use as `bucket` in every other config's backend.hcl"
  value       = aws_s3_bucket.state.id
}

output "lock_table_name" {
  description = "DynamoDB table name to use as `dynamodb_table` in every other config's backend.hcl"
  value       = aws_dynamodb_table.locks.name
}

output "state_bucket_kms_key_arn" {
  description = "CMK protecting the state bucket - informational only, not needed elsewhere"
  value       = module.kms.key_arn
}
