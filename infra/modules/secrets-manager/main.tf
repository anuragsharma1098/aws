# Creates an empty secret container - the actual value is set out-of-band (console, CLI,
# or CI/CD secret injection), never committed to tfvars or state-adjacent files. Terraform
# owns the secret's existence and access policy, not its content.

resource "aws_secretsmanager_secret" "this" {
  name                    = var.name
  description             = var.description
  recovery_window_in_days = var.recovery_window_in_days
  kms_key_id              = var.kms_key_arn

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_secretsmanager_secret_version" "placeholder" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = jsonencode({ placeholder = "set-me-via-console-or-cicd" })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
