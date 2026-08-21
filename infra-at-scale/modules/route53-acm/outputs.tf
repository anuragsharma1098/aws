output "zone_id" {
  value = local.zone_id
}

output "api_fqdn" {
  value = local.api_fqdn
}

output "frontend_fqdn" {
  value = local.frontend_fqdn
}

output "live_fqdn" {
  value = local.live_fqdn
}

output "api_certificate_arn" {
  description = "Regional ACM cert ARN - use on the ALB HTTPS listener"
  value       = aws_acm_certificate_validation.api.certificate_arn
}

output "cloudfront_certificate_arn" {
  description = "us-east-1 ACM cert ARN - use on CloudFront distributions"
  value       = aws_acm_certificate_validation.cloudfront.certificate_arn
}
