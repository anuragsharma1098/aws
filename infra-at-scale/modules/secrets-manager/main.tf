terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_secretsmanager_secret" "this" {
  for_each   = var.secrets
  name       = "${var.name_prefix}/${each.key}"
  kms_key_id = var.kms_key_arn

  tags = merge(var.tags, { Name = "${var.name_prefix}/${each.key}" })
}

# Seeds each secret once at creation with placeholder values so `apply`
# doesn't fail on a missing version. Real values must be rotated in out of
# band (console/CLI/rotation Lambda) - Terraform will not overwrite them on
# subsequent applies because ignore_changes covers secret_string.
resource "aws_secretsmanager_secret_version" "this" {
  for_each      = var.secrets
  secret_id     = aws_secretsmanager_secret.this[each.key].id
  secret_string = jsonencode(each.value)

  lifecycle {
    ignore_changes = [secret_string]
  }
}
