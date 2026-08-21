output "regional_web_acl_arn" {
  description = "Associate with the ALB (aws_wafv2_web_acl_association)"
  value       = aws_wafv2_web_acl.regional.arn
}

output "cloudfront_web_acl_arn" {
  description = "Pass to CloudFront distributions' web_acl_id"
  value       = aws_wafv2_web_acl.cloudfront.arn
}
