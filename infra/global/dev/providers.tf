terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Multi-account: apply this once per AWS account (each account gets its own ECR repos -
# see README.md's account-topology section for why ECR isn't centralized in one account).
provider "aws" {
  region = var.aws_region

  dynamic "assume_role" {
    for_each = var.terraform_deploy_role_arn != null ? [1] : []
    content {
      role_arn     = var.terraform_deploy_role_arn
      session_name = "terraform-global"
    }
  }

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Scope     = "global"
    }
  }
}
