output "primary_endpoint" {
  value = aws_db_instance.primary.address
}

output "primary_identifier" {
  value = aws_db_instance.primary.identifier
}

output "read_replica_endpoint" {
  value = var.create_read_replica ? aws_db_instance.read_replica[0].address : null
}

output "proxy_endpoint" {
  description = "Application connection string should point here, not at the instance directly"
  value       = var.enable_proxy ? aws_db_proxy.this[0].endpoint : null
}

output "db_credentials_secret_arn" {
  value = aws_secretsmanager_secret.db_credentials.arn
}
