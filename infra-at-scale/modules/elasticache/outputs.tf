output "endpoint_address" {
  value = aws_elasticache_serverless_cache.this.endpoint[0].address
}

output "endpoint_port" {
  value = aws_elasticache_serverless_cache.this.endpoint[0].port
}

output "reader_endpoint_address" {
  value = aws_elasticache_serverless_cache.this.reader_endpoint[0].address
}
