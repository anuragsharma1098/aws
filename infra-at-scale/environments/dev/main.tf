data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  backend_container_port = 8080
  admin_container_port   = 8081
}

# ---------------------------------------------------------------------------
# Encryption
# ---------------------------------------------------------------------------
module "kms" {
  source      = "../../modules/kms"
  name_prefix = local.name_prefix
  tags        = local.common_tags
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------
module "vpc" {
  source              = "../../modules/vpc"
  name_prefix         = local.name_prefix
  vpc_cidr            = var.vpc_cidr
  azs                 = var.azs
  public_subnet_cidrs = var.public_subnet_cidrs
  app_subnet_cidrs    = var.app_subnet_cidrs
  data_subnet_cidrs   = var.data_subnet_cidrs
  single_nat_gateway  = var.single_nat_gateway
  tags                = local.common_tags
}

module "security_groups" {
  source         = "../../modules/security-groups"
  name_prefix    = local.name_prefix
  vpc_id         = module.vpc.vpc_id
  container_port = local.backend_container_port
  tags           = local.common_tags
}

# ---------------------------------------------------------------------------
# DNS + certificates
# ---------------------------------------------------------------------------
module "dns" {
  source             = "../../modules/route53-acm"
  providers          = { aws = aws, aws.us_east_1 = aws.us_east_1 }
  domain_name        = var.domain_name
  create_hosted_zone = var.create_hosted_zone
  environment        = var.environment
  tags               = local.common_tags
}

# ---------------------------------------------------------------------------
# Edge security
# ---------------------------------------------------------------------------
module "waf" {
  source      = "../../modules/waf"
  providers   = { aws = aws, aws.us_east_1 = aws.us_east_1 }
  name_prefix = local.name_prefix
  tags        = local.common_tags
}

# ---------------------------------------------------------------------------
# Frontend static assets (S3 + CloudFront) and shared access-log bucket
# ---------------------------------------------------------------------------
module "frontend" {
  source                     = "../../modules/s3-cloudfront"
  name_prefix                = local.name_prefix
  frontend_fqdn              = module.dns.frontend_fqdn
  cloudfront_certificate_arn = module.dns.cloudfront_certificate_arn
  web_acl_arn                = module.waf.cloudfront_web_acl_arn
  kms_key_arn                = module.kms.key_arn
  tags                       = local.common_tags
}

# ---------------------------------------------------------------------------
# Application Load Balancer - backend + admin blue/green listeners
# ---------------------------------------------------------------------------
module "alb" {
  source            = "../../modules/alb"
  name_prefix       = local.name_prefix
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id
  certificate_arn   = module.dns.api_certificate_arn
  web_acl_arn       = module.waf.regional_web_acl_arn
  logs_bucket_name  = module.frontend.logs_bucket_name

  services = {
    backend = {
      listener_port     = 443
      container_port    = local.backend_container_port
      health_check_path = "/healthz"
    }
    admin = {
      listener_port     = 8443
      container_port    = local.admin_container_port
      health_check_path = "/admin/healthz"
    }
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# ECS cluster
# ---------------------------------------------------------------------------
module "ecs_cluster" {
  source      = "../../modules/ecs-cluster"
  name_prefix = local.name_prefix
  tags        = local.common_tags
}

# ---------------------------------------------------------------------------
# Application secrets
# ---------------------------------------------------------------------------
module "secrets" {
  source      = "../../modules/secrets-manager"
  name_prefix = local.name_prefix
  kms_key_arn = module.kms.key_arn
  tags        = local.common_tags
}

# ---------------------------------------------------------------------------
# Data layer
# ---------------------------------------------------------------------------
module "rds" {
  source              = "../../modules/rds"
  name_prefix         = local.name_prefix
  data_subnet_ids     = module.vpc.data_subnet_ids
  rds_sg_id           = module.security_groups.rds_sg_id
  kms_key_arn         = module.kms.key_arn
  instance_class      = var.db_instance_class
  multi_az            = var.db_multi_az
  create_read_replica = var.db_create_read_replica
  allocated_storage   = var.db_allocated_storage
  deletion_protection = var.db_deletion_protection
  skip_final_snapshot = var.db_skip_final_snapshot
  tags                = local.common_tags
}

module "elasticache" {
  source              = "../../modules/elasticache"
  name_prefix         = local.name_prefix
  data_subnet_ids     = module.vpc.data_subnet_ids
  redis_sg_id         = module.security_groups.redis_sg_id
  kms_key_arn         = module.kms.key_arn
  max_data_storage_gb = var.redis_max_data_storage_gb
  max_ecpu_per_second = var.redis_max_ecpu_per_second
  tags                = local.common_tags
}

# ---------------------------------------------------------------------------
# IAM - one execution/task/CodeDeploy role set per service
# ---------------------------------------------------------------------------
module "iam_backend" {
  source       = "../../modules/iam-ecs"
  name_prefix  = "${local.name_prefix}-backend"
  secrets_arns = concat(values(module.secrets.secret_arns), [module.rds.db_credentials_secret_arn])
  kms_key_arn  = module.kms.key_arn
  tags         = local.common_tags
}

module "iam_admin" {
  source       = "../../modules/iam-ecs"
  name_prefix  = "${local.name_prefix}-admin"
  secrets_arns = concat(values(module.secrets.secret_arns), [module.rds.db_credentials_secret_arn])
  kms_key_arn  = module.kms.key_arn
  tags         = local.common_tags
}

# ---------------------------------------------------------------------------
# ECS services - blue/green via CodeDeploy
# ---------------------------------------------------------------------------
module "ecs_backend" {
  source                        = "../../modules/ecs-service-bluegreen"
  name_prefix                   = "${local.name_prefix}-backend"
  cluster_arn                   = module.ecs_cluster.cluster_arn
  cluster_name                  = module.ecs_cluster.cluster_name
  app_subnet_ids                = module.vpc.app_subnet_ids
  ecs_tasks_sg_id               = module.security_groups.ecs_tasks_sg_id
  execution_role_arn            = module.iam_backend.execution_role_arn
  task_role_arn                 = module.iam_backend.task_role_arn
  codedeploy_role_arn           = module.iam_backend.codedeploy_role_arn
  https_listener_arn            = module.alb.https_listener_arns["backend"]
  blue_target_group_name        = module.alb.blue_target_group_names["backend"]
  green_target_group_name       = module.alb.green_target_group_names["backend"]
  blue_target_group_arn         = module.alb.blue_target_group_arns["backend"]
  green_target_group_arn        = module.alb.green_target_group_arns["backend"]
  container_image               = var.container_image
  container_port                = local.backend_container_port
  cpu                           = var.backend_cpu
  memory                        = var.backend_memory
  desired_count                 = var.backend_desired_count
  min_capacity                  = var.backend_min_capacity
  max_capacity                  = var.backend_max_capacity
  deployment_config_name        = var.deployment_config_name
  termination_wait_time_minutes = var.termination_wait_time_minutes
  alarm_arns                    = module.monitoring.alarm_arns

  secrets = {
    DB_CREDENTIALS_JSON = module.rds.db_credentials_secret_arn
  }

  environment_variables = {
    ENVIRONMENT   = var.environment
    REDIS_HOST    = module.elasticache.endpoint_address
    REDIS_PORT    = tostring(module.elasticache.endpoint_port)
    DB_PROXY_HOST = module.rds.proxy_endpoint
  }

  tags = local.common_tags
}

module "ecs_admin" {
  source                        = "../../modules/ecs-service-bluegreen"
  name_prefix                   = "${local.name_prefix}-admin"
  cluster_arn                   = module.ecs_cluster.cluster_arn
  cluster_name                  = module.ecs_cluster.cluster_name
  app_subnet_ids                = module.vpc.app_subnet_ids
  ecs_tasks_sg_id               = module.security_groups.ecs_tasks_sg_id
  execution_role_arn            = module.iam_admin.execution_role_arn
  task_role_arn                 = module.iam_admin.task_role_arn
  codedeploy_role_arn           = module.iam_admin.codedeploy_role_arn
  https_listener_arn            = module.alb.https_listener_arns["admin"]
  blue_target_group_name        = module.alb.blue_target_group_names["admin"]
  green_target_group_name       = module.alb.green_target_group_names["admin"]
  blue_target_group_arn         = module.alb.blue_target_group_arns["admin"]
  green_target_group_arn        = module.alb.green_target_group_arns["admin"]
  container_image               = var.container_image
  container_port                = local.admin_container_port
  cpu                           = var.admin_cpu
  memory                        = var.admin_memory
  desired_count                 = var.admin_desired_count
  min_capacity                  = var.admin_min_capacity
  max_capacity                  = var.admin_max_capacity
  deployment_config_name        = var.deployment_config_name
  termination_wait_time_minutes = var.termination_wait_time_minutes

  secrets = {
    DB_CREDENTIALS_JSON = module.rds.db_credentials_secret_arn
  }

  environment_variables = {
    ENVIRONMENT   = var.environment
    DB_PROXY_HOST = module.rds.proxy_endpoint
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Observability - alarms feed backend's CodeDeploy auto-rollback.
# Not a dependency cycle despite the mutual reference: ecs_backend only
# consumes monitoring's alb_5xx/target_unhealthy alarm ARNs (which depend on
# the ALB module, not on ecs_backend), while monitoring's ecs_cpu/memory
# alarms (the ones that *do* depend on ecs_backend) aren't in that output.
# ---------------------------------------------------------------------------
module "monitoring" {
  source                       = "../../modules/monitoring"
  name_prefix                  = local.name_prefix
  kms_key_arn                  = module.kms.key_arn
  alarm_notification_email     = var.alarm_notification_email
  alb_arn_suffix               = module.alb.alb_arn_suffix
  blue_target_group_arn_suffix = module.alb.blue_target_group_arn_suffixes["backend"]
  ecs_cluster_name             = module.ecs_cluster.cluster_name
  ecs_service_name             = module.ecs_backend.service_name
  rds_instance_id              = module.rds.primary_identifier
  tags                         = local.common_tags
}

# ---------------------------------------------------------------------------
# Live streaming pipeline (optional - MediaLive bills hourly while running)
# ---------------------------------------------------------------------------
module "live_streaming" {
  count                      = var.enable_live_streaming ? 1 : 0
  source                     = "../../modules/live-streaming"
  providers                  = { aws = aws }
  name_prefix                = local.name_prefix
  kms_key_arn                = module.kms.key_arn
  cloudfront_certificate_arn = module.dns.cloudfront_certificate_arn
  live_fqdn                  = module.dns.live_fqdn
  web_acl_arn                = module.waf.cloudfront_web_acl_arn
  tags                       = local.common_tags
}

# ---------------------------------------------------------------------------
# CI/CD - GitHub Actions OIDC federated deploy role
# ---------------------------------------------------------------------------
module "github_oidc" {
  source            = "../../modules/iam-github-oidc"
  name_prefix       = local.name_prefix
  github_repository = var.github_repository
  allowed_ref       = var.github_allowed_ref
  ecs_cluster_arns  = [module.ecs_cluster.cluster_arn]
  codedeploy_application_arns = [
    "arn:aws:codedeploy:${var.aws_region}:${data.aws_caller_identity.current.account_id}:application:${module.ecs_backend.codedeploy_app_name}",
    "arn:aws:codedeploy:${var.aws_region}:${data.aws_caller_identity.current.account_id}:application:${module.ecs_admin.codedeploy_app_name}",
  ]
  tags = local.common_tags
}
