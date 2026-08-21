output "hls_bucket_name" {
  value = aws_s3_bucket.hls.bucket
}

output "channel_id" {
  value = aws_medialive_channel.this.id
}

output "input_id" {
  value = aws_medialive_input.ingest.id
}

output "distribution_domain_name" {
  value = aws_cloudfront_distribution.hls.domain_name
}
