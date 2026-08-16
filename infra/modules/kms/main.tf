# One customer-managed key per environment (or per global scope), shared across the
# services that need it. Real key-material control, audit trail, and rotation instead of
# AWS-managed default keys - the tradeoff against a key per data class is simplicity and
# cost (~$1/mo/key); split further if a compliance requirement ever demands it.

data "aws_caller_identity" "current" {}

locals {
  description = coalesce(var.description, "Customer-managed key for ${var.name}")
}

data "aws_iam_policy_document" "this" {
  # Every custom key policy needs this, or IAM policies in the account stop being able to
  # grant kms:* on the key at all - this is what AWS's own default key policy does too.
  statement {
    sid    = "EnableIAMUserPermissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = length(var.service_principals) > 0 ? [1] : []
    content {
      sid    = "AllowServicePrincipalUsage"
      effect = "Allow"
      principals {
        type        = "Service"
        identifiers = var.service_principals
      }
      actions = [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
      ]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = length(var.service_principals) > 0 ? [1] : []
    content {
      sid    = "AllowServicePrincipalGrants"
      effect = "Allow"
      principals {
        type        = "Service"
        identifiers = var.service_principals
      }
      actions   = ["kms:CreateGrant"]
      resources = ["*"]
      condition {
        test     = "Bool"
        variable = "kms:GrantIsForAWSResource"
        values   = ["true"]
      }
    }
  }

  # CloudWatch Logs' principal is region-scoped and requires an encryption-context condition -
  # it doesn't fit the generic service_principals shape above.
  dynamic "statement" {
    for_each = var.enable_cloudwatch_logs ? [1] : []
    content {
      sid    = "AllowCloudWatchLogs"
      effect = "Allow"
      principals {
        type        = "Service"
        identifiers = ["logs.${var.aws_region}.amazonaws.com"]
      }
      actions = [
        "kms:Encrypt*",
        "kms:Decrypt*",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:Describe*",
      ]
      resources = ["*"]
      condition {
        test     = "ArnLike"
        variable = "kms:EncryptionContext:aws:logs:arn"
        values   = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:*"]
      }
    }
  }

  # CloudTrail also needs its own encryption-context condition, scoped to trails in this account.
  dynamic "statement" {
    for_each = var.enable_cloudtrail ? [1] : []
    content {
      sid    = "AllowCloudTrailEncrypt"
      effect = "Allow"
      principals {
        type        = "Service"
        identifiers = ["cloudtrail.amazonaws.com"]
      }
      actions   = ["kms:GenerateDataKey*"]
      resources = ["*"]
      condition {
        test     = "StringLike"
        variable = "kms:EncryptionContext:aws:cloudtrail:arn"
        values   = ["arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"]
      }
    }
  }

  dynamic "statement" {
    for_each = var.enable_cloudtrail ? [1] : []
    content {
      sid    = "AllowCloudTrailDescribe"
      effect = "Allow"
      principals {
        type        = "Service"
        identifiers = ["cloudtrail.amazonaws.com"]
      }
      actions   = ["kms:DescribeKey"]
      resources = ["*"]
    }
  }
}

resource "aws_kms_key" "this" {
  description             = local.description
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation
  policy                  = data.aws_iam_policy_document.this.json

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.name}"
  target_key_id = aws_kms_key.this.key_id
}
