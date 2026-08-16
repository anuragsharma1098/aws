resource "random_password" "master" {
  length  = 32
  special = true
  # RDS master passwords reject '/', '@', '"' and space.
  override_special = "!#$%^&*()-_=+[]{}<>:?"
}

resource "aws_db_subnet_group" "this" {
  name       = var.identifier
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.identifier}-subnet-group"
  })
}

resource "aws_db_instance" "this" {
  identifier     = var.identifier
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_name  = var.db_name
  username = var.username
  password = random_password.master.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false

  multi_az                   = var.multi_az
  backup_retention_period    = var.backup_retention_period
  backup_window              = "03:00-04:00"
  maintenance_window         = "mon:04:30-mon:05:30"
  deletion_protection        = var.deletion_protection
  skip_final_snapshot        = var.skip_final_snapshot
  final_snapshot_identifier  = var.skip_final_snapshot ? null : "${var.identifier}-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  copy_tags_to_snapshot      = true
  auto_minor_version_upgrade = true

  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_kms_key_id = var.performance_insights_enabled ? var.kms_key_arn : null

  tags = merge(var.tags, {
    Name = var.identifier
  })

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }
}

# Credentials are stored in Secrets Manager, never in tfvars or state-adjacent plaintext files.
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.identifier}-db-credentials"
  description             = "Master credentials for RDS instance ${var.identifier}"
  recovery_window_in_days = 7
  kms_key_id              = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.identifier}-db-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.username
    password = random_password.master.result
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = var.db_name
    engine   = var.engine
  })
}
