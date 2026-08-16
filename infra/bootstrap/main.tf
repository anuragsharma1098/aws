# Chicken-and-egg fix: this config has no remote backend of its own (state stays local,
# a single local .tfstate committed nowhere - see infra/bootstrap/README below). Run it
# once per AWS account before anything under infra/global or infra/environments/*.

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  state_bucket_name = "${var.project_name}-terraform-state-${var.state_bucket_suffix}"
  lock_table_name   = "${var.project_name}-terraform-locks"
}

resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket_name

  tags = {
    Name      = local.state_bucket_name
    Project   = var.project_name
    ManagedBy = "Terraform"
    Purpose   = "terraform-remote-state"
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

module "kms" {
  source = "../modules/kms"

  name               = "${var.project_name}-terraform-state"
  description        = "CMK for the Terraform remote state bucket"
  service_principals = ["s3.amazonaws.com"]

  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
    Purpose   = "terraform-remote-state"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = module.kms.key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "locks" {
  name         = local.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = local.lock_table_name
    Project   = var.project_name
    ManagedBy = "Terraform"
    Purpose   = "terraform-state-locking"
  }
}
