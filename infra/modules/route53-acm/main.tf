terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# No-op by default (var.enabled = false) until a real domain is bought. Once you have one,
# flip enabled = true and set domain_name in the environment's tfvars.
#
# NOTE: the ACM certificate here is regional (matches whatever provider/region this instance
# runs under - the ALB's cert needs to match the ALB's region). A certificate for CloudFront
# must exist in us-east-1 specifically: instantiate this module a second time with an
# aliased us-east-1 provider and existing_zone_id set to this instance's zone_id output, so
# the second instance validates against the same zone instead of creating/looking up another.

locals {
  create_zone = var.enabled && var.create_zone && var.existing_zone_id == null
  lookup_zone = var.enabled && !var.create_zone && var.existing_zone_id == null
}

resource "aws_route53_zone" "this" {
  count = local.create_zone ? 1 : 0
  name  = var.domain_name
  tags  = var.tags
}

data "aws_route53_zone" "existing" {
  count = local.lookup_zone ? 1 : 0
  name  = var.domain_name
}

locals {
  zone_id = var.enabled ? coalesce(var.existing_zone_id, local.create_zone ? aws_route53_zone.this[0].zone_id : try(data.aws_route53_zone.existing[0].zone_id, null)) : null
}

resource "aws_acm_certificate" "this" {
  count                     = var.enabled ? 1 : 0
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

resource "aws_route53_record" "validation" {
  for_each = var.enabled ? {
    for dvo in aws_acm_certificate.this[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id         = local.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  count                   = var.enabled ? 1 : 0
  certificate_arn         = aws_acm_certificate.this[0].arn
  validation_record_fqdns = [for r in aws_route53_record.validation : r.fqdn]
}
