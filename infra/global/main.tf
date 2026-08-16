# Account-level resources that are shared across dev/qa/prd and only ever applied once:
# a single ECR repo set (images are tagged, not duplicated, per environment) and the
# account's audit trail.

module "kms" {
  source = "../modules/kms"

  name               = "${var.project_name}-global"
  description        = "CMK for account-level resources (ECR, CloudTrail)"
  service_principals = ["ecr.amazonaws.com"]
  enable_cloudtrail  = true

  tags = {
    Project = var.project_name
    Scope   = "global"
  }
}

module "ecr" {
  source = "../modules/ecr"

  repository_names = var.ecr_repository_names
  kms_key_arn      = module.kms.key_arn

  tags = {
    Project = var.project_name
  }
}

module "cloudtrail" {
  source = "../modules/cloudtrail"

  trail_name      = "${var.project_name}-audit-trail"
  log_bucket_name = "${var.project_name}-cloudtrail-logs-${var.cloudtrail_log_bucket_suffix}"
  kms_key_arn     = module.kms.key_arn

  tags = {
    Project = var.project_name
  }
}
