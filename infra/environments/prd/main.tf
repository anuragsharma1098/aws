data "terraform_remote_state" "global" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "global/terraform.tfstate"
    region = var.aws_region
  }
}

locals {
  name_prefix   = "${var.project_name}-${var.environment}"
  backend_image = "${data.terraform_remote_state.global.outputs.ecr_repository_urls["backend-app"]}:${var.backend_image_tag}"

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
  # publish alarms to an encrypted SNS topic, not because they own any encrypted data.
  service_principals = [
    "s3.amazonaws.com",
    "secretsmanager.amazonaws.com",
    "rds.amazonaws.com",
    "sns.amazonaws.com",
    "cloudwatch.amazonaws.com",
    "cloudfront.amazonaws.com",
  ]
  enable_cloudwatch_logs = true

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
  tags                 = local.common_tags
}

module "security_groups" {
  source = "../../modules/security-groups"

  name_prefix       = local.name_prefix
  vpc_id            = module.vpc.vpc_id
  alb_ingress_cidrs = var.alb_ingress_cidrs
  container_port    = var.container_port
  tags              = local.common_tags
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

module "alb" {
  source = "../../modules/alb"

  name                = "${local.name_prefix}-alb"
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  security_group_id   = module.security_groups.alb_sg_id
  certificate_arn     = module.dns.certificate_arn
  target_port         = var.container_port
  health_check_path   = var.health_check_path
  deletion_protection = var.alb_deletion_protection
  tags                = local.common_tags
}

module "waf" {
  count  = var.enable_waf ? 1 : 0
  source = "../../modules/waf"

  name       = "${local.name_prefix}-waf"
  alb_arn    = module.alb.alb_arn
  rate_limit = var.waf_rate_limit
  tags       = local.common_tags
}

module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  name                = "${local.name_prefix}-cluster"
  enable_fargate_spot = var.environment != "prd"
  tags                = local.common_tags
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

module "ecs_service" {
  source = "../../modules/ecs-service"

  name                     = "${local.name_prefix}-backend"
  cluster_arn              = module.ecs_cluster.cluster_arn
  private_subnet_ids       = module.vpc.private_subnet_ids
  security_group_id        = module.security_groups.app_sg_id
  target_group_arn         = module.alb.target_group_arn
  container_image          = local.backend_image
  container_port           = var.container_port
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  desired_count            = var.ecs_desired_count
  min_capacity             = var.ecs_min_capacity
  max_capacity             = var.ecs_max_capacity
  kms_key_arn              = module.kms.key_arn
  permissions_boundary_arn = module.iam_boundary.boundary_arn

  environment_variables = {
    ENVIRONMENT = var.environment
  }

  secrets = {
    DB_CREDENTIALS = module.rds.secret_arn
    APP_SECRETS    = module.app_secrets.secret_arn
  }

  tags = local.common_tags
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

module "monitoring" {
  source = "../../modules/monitoring"

  name                    = local.name_prefix
  alarm_email             = var.alarm_email
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
  ecs_cluster_name        = module.ecs_cluster.cluster_name
  ecs_service_name        = module.ecs_service.service_name
  rds_instance_id         = module.rds.db_instance_id
  kms_key_arn             = module.kms.key_arn
  tags                    = local.common_tags
}
