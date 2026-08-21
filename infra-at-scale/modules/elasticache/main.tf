terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ElastiCache Serverless - no node-count/shard capacity planning; scales
# storage and compute (ECPUs) on demand within the ceilings below.
resource "aws_elasticache_serverless_cache" "this" {
  name                 = "${var.name_prefix}-redis"
  engine               = "redis"
  major_engine_version = var.major_engine_version
  description          = "Session/cache store for ${var.name_prefix}"

  subnet_ids         = var.data_subnet_ids
  security_group_ids = [var.redis_sg_id]
  kms_key_id         = var.kms_key_arn

  cache_usage_limits {
    data_storage {
      maximum = var.max_data_storage_gb
      unit    = "GB"
    }
    ecpu_per_second {
      maximum = var.max_ecpu_per_second
    }
  }

  daily_snapshot_time      = "04:00"
  snapshot_retention_limit = var.snapshot_retention_limit

  tags = merge(var.tags, { Name = "${var.name_prefix}-redis" })
}
