terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Multi-account: this environment lives in its own AWS account. assume_role is optional -
# omit terraform_deploy_role_arn and Terraform just uses whatever credentials/profile are
# already active for that account (see README.md's account-topology section).
provider "aws" {
  region = var.aws_region

  dynamic "assume_role" {
    for_each = var.terraform_deploy_role_arn != null ? [1] : []
    content {
      role_arn     = var.terraform_deploy_role_arn
      session_name = "terraform-${var.environment}"
    }
  }

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# CloudFront's ACM certificate must be issued in us-east-1 regardless of var.aws_region -
# used only by the frontend's route53-acm instantiation in main.tf. Same account as the
# default provider above, just pinned to a different region.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  dynamic "assume_role" {
    for_each = var.terraform_deploy_role_arn != null ? [1] : []
    content {
      role_arn     = var.terraform_deploy_role_arn
      session_name = "terraform-${var.environment}-use1"
    }
  }

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
