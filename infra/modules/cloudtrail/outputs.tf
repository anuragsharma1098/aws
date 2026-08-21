output "trail_arn" {
  description = "ARN of the CloudTrail trail"
  value       = aws_cloudtrail.this.arn
}

output "log_bucket_name" {
  description = "S3 bucket holding trail logs"
  value       = aws_s3_bucket.trail.id
}
