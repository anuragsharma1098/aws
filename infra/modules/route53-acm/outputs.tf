output "zone_id" {
  description = "Route 53 hosted zone ID (null if disabled)"
  value       = local.zone_id
}

output "name_servers" {
  description = "Name servers for the created zone (empty if disabled or zone wasn't created here)"
  value       = local.create_zone ? aws_route53_zone.this[0].name_servers : []
}

output "certificate_arn" {
  description = "Validated ACM certificate ARN (null if disabled)"
  value       = var.enabled ? aws_acm_certificate_validation.this[0].certificate_arn : null
}
