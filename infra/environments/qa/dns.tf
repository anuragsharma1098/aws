# Backend API endpoint - an alias record pointing api.<domain> at the ALB. This is what
# actually gives the backend a stable DNS name instead of the raw *.elb.amazonaws.com one.
# No-op (count = 0) until enable_dns = true and a real domain_name is set - see outputs.tf's
# api_endpoint for the ALB-DNS fallback used until then.

resource "aws_route53_record" "api" {
  count   = var.enable_dns ? 1 : 0
  zone_id = module.dns.zone_id
  name    = "${var.api_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

# Frontend endpoint - an alias record pointing www.<domain> (or whatever frontend_subdomain
# is) at CloudFront. Same no-op-until-enable_dns pattern as the API record above.

resource "aws_route53_record" "frontend" {
  count   = var.enable_dns ? 1 : 0
  zone_id = module.dns.zone_id
  name    = "${var.frontend_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.frontend.cloudfront_domain_name
    zone_id                = module.frontend.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}
