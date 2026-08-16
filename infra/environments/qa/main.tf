data "terraform_remote_state" "global" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "global/terraform.tfstate"
    region = var.aws_region
  }
}

locals {
  name_prefix  = "${var.project_name}-${var.environment}"
  cluster_name = "${local.name_prefix}-cluster"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

module "kms" {
  source = "../../modules/kms"

  name       = local.name_prefix
  aws_region = var.aws_region

  # Every service in this environment that reads/writes ciphertext with this key.
  # cloudfront/cloudwatch are here because they need Decrypt to serve frontend assets /
  # publish alarms to an encrypted SNS topic; eks is here for K8s Secrets envelope encryption.
  service_principals = [
    "s3.amazonaws.com",
    "secretsmanager.amazonaws.com",
    "rds.amazonaws.com",
    "sns.amazonaws.com",
    "cloudwatch.amazonaws.com",
    "cloudfront.amazonaws.com",
    "eks.amazonaws.com",
  ]
  enable_cloudwatch_logs = true
  enable_cloudtrail      = true

  tags = local.common_tags
}

module "iam_boundary" {
  source = "../../modules/iam-boundary"

  name            = local.name_prefix
  allowed_regions = [var.aws_region]
  tags            = local.common_tags
}

module "vpc" {
  source = "../../modules/vpc"

  name                 = local.name_prefix
  cidr_block           = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway
  eks_cluster_name     = local.cluster_name
  tags                 = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  name                     = local.cluster_name
  kubernetes_version       = var.kubernetes_version
  private_subnet_ids       = module.vpc.private_subnet_ids
  public_subnet_ids        = module.vpc.public_subnet_ids
  endpoint_public_access   = var.eks_endpoint_public_access
  public_access_cidrs      = var.eks_public_access_cidrs
  kms_key_arn              = module.kms.key_arn
  permissions_boundary_arn = module.iam_boundary.boundary_arn
  tags                     = local.common_tags
}

module "eks_node_group" {
  source = "../../modules/eks-node-group"

  cluster_name             = module.eks.cluster_name
  node_group_name          = "${local.name_prefix}-nodes"
  private_subnet_ids       = module.vpc.private_subnet_ids
  instance_types           = var.node_instance_types
  capacity_type            = var.node_capacity_type
  disk_size                = var.node_disk_size
  desired_size             = var.node_desired_size
  min_size                 = var.node_min_size
  max_size                 = var.node_max_size
  permissions_boundary_arn = module.iam_boundary.boundary_arn
  tags                     = local.common_tags
}

module "eks_addons" {
  source = "../../modules/eks-addons"

  cluster_name          = module.eks.cluster_name
  ebs_csi_irsa_role_arn = module.eks.ebs_csi_irsa_role_arn
  tags                  = local.common_tags

  depends_on = [module.eks_node_group]
}

module "security_groups" {
  source = "../../modules/security-groups"

  name_prefix                   = local.name_prefix
  vpc_id                        = module.vpc.vpc_id
  alb_ingress_cidrs             = var.alb_ingress_cidrs
  container_port                = var.container_port
  eks_cluster_security_group_id = module.eks.cluster_security_group_id
  tags                          = local.common_tags
}

module "dns" {
  source = "../../modules/route53-acm"

  enabled                   = var.enable_dns
  domain_name               = var.domain_name
  subject_alternative_names = var.enable_dns ? ["${var.api_subdomain}.${var.domain_name}"] : []
  tags                      = local.common_tags
}

# Separate instantiation, pinned to us-east-1, purely because CloudFront requires its ACM
# cert to live there - it validates against the same zone module.dns already created/found.
module "dns_cloudfront" {
  source = "../../modules/route53-acm"
  providers = {
    aws = aws.us_east_1
  }

  enabled          = var.enable_dns
  domain_name      = "${var.frontend_subdomain}.${var.domain_name}"
  existing_zone_id = module.dns.zone_id
  tags             = local.common_tags
}

# No alb_arn: on EKS the AWS Load Balancer Controller creates the ALB dynamically from an
# Ingress resource and associates this Web ACL itself via the
# alb.ingress.kubernetes.io/wafv2-acl-arn annotation (see module.waf's output below).
module "waf" {
  count  = var.enable_waf ? 1 : 0
  source = "../../modules/waf"

  name       = "${local.name_prefix}-waf"
  rate_limit = var.waf_rate_limit
  tags       = local.common_tags
}

# --- IRSA roles: scope AWS permissions to specific Kubernetes service accounts, not nodes ---

module "irsa_lb_controller" {
  source = "../../modules/irsa"

  name                     = "${local.name_prefix}-lb-controller"
  oidc_provider_arn        = module.eks.oidc_provider_arn
  oidc_provider_url        = module.eks.oidc_provider_url
  namespace                = var.lb_controller_namespace
  service_account_name     = var.lb_controller_service_account
  policy_json              = var.lb_controller_policy_json
  permissions_boundary_arn = module.iam_boundary.boundary_arn
  tags                     = local.common_tags
}

# external-dns needs an actual hosted zone to manage, so this whole role is a no-op
# alongside everything else that's dormant until enable_dns = true.
data "aws_iam_policy_document" "external_dns_permissions" {
  count = var.enable_dns ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = ["arn:aws:route53:::hostedzone/${module.dns.zone_id}"]
  }

  statement {
    effect    = "Allow"
    actions   = ["route53:ListHostedZones", "route53:ListResourceRecordSets", "route53:ListTagsForResource"]
    resources = ["*"]
  }
}

module "irsa_external_dns" {
  count  = var.enable_dns ? 1 : 0
  source = "../../modules/irsa"

  name                     = "${local.name_prefix}-external-dns"
  oidc_provider_arn        = module.eks.oidc_provider_arn
  oidc_provider_url        = module.eks.oidc_provider_url
  namespace                = var.external_dns_namespace
  service_account_name     = var.external_dns_service_account
  policy_json              = data.aws_iam_policy_document.external_dns_permissions[0].json
  permissions_boundary_arn = module.iam_boundary.boundary_arn
  tags                     = local.common_tags
}

data "aws_iam_policy_document" "external_secrets_permissions" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [module.rds.secret_arn, module.app_secrets.secret_arn]
  }
}

module "irsa_external_secrets" {
  source = "../../modules/irsa"

  name                     = "${local.name_prefix}-external-secrets"
  oidc_provider_arn        = module.eks.oidc_provider_arn
  oidc_provider_url        = module.eks.oidc_provider_url
  namespace                = var.external_secrets_namespace
  service_account_name     = var.external_secrets_service_account
  policy_json              = data.aws_iam_policy_document.external_secrets_permissions.json
  permissions_boundary_arn = module.iam_boundary.boundary_arn
  tags                     = local.common_tags
}

module "rds" {
  source = "../../modules/rds"

  identifier              = "${local.name_prefix}-db"
  private_subnet_ids      = module.vpc.private_subnet_ids
  security_group_id       = module.security_groups.db_sg_id
  db_name                 = var.db_name
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  max_allocated_storage   = var.db_max_allocated_storage
  multi_az                = var.db_multi_az
  backup_retention_period = var.db_backup_retention_period
  deletion_protection     = var.db_deletion_protection
  skip_final_snapshot     = var.db_skip_final_snapshot
  kms_key_arn             = module.kms.key_arn
  tags                    = local.common_tags
}

module "app_secrets" {
  source = "../../modules/secrets-manager"

  name        = "${local.name_prefix}-app-secrets"
  description = "Application secrets for ${var.environment}"
  kms_key_arn = module.kms.key_arn
  tags        = local.common_tags
}

module "frontend" {
  source = "../../modules/s3-cloudfront"

  bucket_name     = var.frontend_bucket_name
  kms_key_arn     = module.kms.key_arn
  certificate_arn = module.dns_cloudfront.certificate_arn
  aliases         = var.enable_dns ? ["${var.frontend_subdomain}.${var.domain_name}"] : []
  tags            = local.common_tags
}

module "uploads" {
  source = "../../modules/s3-uploads"

  bucket_name          = var.uploads_bucket_name
  cors_allowed_origins = var.uploads_cors_origins
  kms_key_arn          = module.kms.key_arn
  tags                 = local.common_tags
}

module "ci_artifacts" {
  source = "../../modules/ci-artifacts"

  bucket_name = var.ci_artifacts_bucket_name
  kms_key_arn = module.kms.key_arn
  tags        = local.common_tags
}

module "harness_oidc" {
  source = "../../modules/harness-oidc"

  name                     = "${local.name_prefix}-harness"
  oidc_issuer_url          = var.harness_oidc_issuer_url
  audience                 = var.harness_audience
  subject_claim            = var.harness_subject_claim
  ecr_push_repository_arns = values(data.terraform_remote_state.global.outputs.ecr_repository_arns)
  ecr_pull_repository_arns = var.harness_ecr_pull_repository_arns
  ci_artifacts_bucket_arn  = module.ci_artifacts.bucket_arn
  eks_cluster_arn          = module.eks.cluster_arn
  permissions_boundary_arn = module.iam_boundary.boundary_arn
  tags                     = local.common_tags
}

module "eks_access" {
  source = "../../modules/eks-access"

  cluster_name = module.eks.cluster_name

  access_entries = {
    harness = {
      principal_arn = module.harness_oidc.role_arn
      policy_arns   = var.harness_eks_access_policy_arns
      namespaces    = var.harness_eks_namespaces
    }
  }
}

module "monitoring" {
  source = "../../modules/monitoring"

  name              = local.name_prefix
  alarm_email       = var.alarm_email
  enable_alb_alarms = false # the ALB isn't Terraform-managed on the EKS path
  enable_ecs_alarms = false # compute is EKS, not ECS
  rds_instance_id   = module.rds.db_instance_id
  kms_key_arn       = module.kms.key_arn
  tags              = local.common_tags
}

# Per-account audit trail - every AWS account needs its own, since a single trail can't span
# separate accounts without an AWS Organizations delegation this repo doesn't assume exists.
module "cloudtrail" {
  source = "../../modules/cloudtrail"

  trail_name      = "${local.name_prefix}-audit-trail"
  log_bucket_name = "${local.name_prefix}-cloudtrail-logs-${var.cloudtrail_log_bucket_suffix}"
  kms_key_arn     = module.kms.key_arn
  tags            = local.common_tags
}
