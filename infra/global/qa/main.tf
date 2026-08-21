# Account-level resources: applied once per AWS account (dev/qa/prd each apply their own
# copy - see README.md's account-topology section). Just ECR here; CloudTrail moved to each
# environment's own main.tf since every account needs its own audit trail, not a shared one.

module "kms" {
  source = "../../modules/kms"

  name               = "${var.project_name}-global"
  description        = "CMK for account-level resources (ECR)"
  service_principals = ["ecr.amazonaws.com"]

  tags = {
    Project = var.project_name
    Scope   = "global"
  }
}

module "ecr" {
  source = "../../modules/ecr"

  repository_names              = var.ecr_repository_names
  kms_key_arn                   = module.kms.key_arn
  cross_account_pull_principals = var.ecr_cross_account_pull_principals

  tags = {
    Project = var.project_name
  }
}
