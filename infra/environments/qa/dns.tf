# No Terraform-managed api.<domain> record: unlike the frontend's CloudFront distribution,
# the ALB doesn't exist until the AWS Load Balancer Controller creates it at Helm-deploy
# time - Terraform can't point a record at something that isn't provisioned yet. external-dns
# (a controller watching Ingress objects, IRSA-authorized below) creates and keeps that
# record in sync itself once the Ingress exists.

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
