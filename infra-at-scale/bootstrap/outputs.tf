output "state_bucket" {
  description = "S3 bucket name to use as `bucket` in environments/*/backend.hcl"
  value       = aws_s3_bucket.state.bucket
}

output "lock_table" {
  description = "DynamoDB table name to use as `dynamodb_table` in environments/*/backend.hcl"
  value       = aws_dynamodb_table.lock.name
}

output "kms_key_arn" {
  description = "KMS key ARN used to encrypt state; reference as `kms_key_id` in backend.hcl"
  value       = aws_kms_key.state.arn
}
