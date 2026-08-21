terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# S3 - HLS segment/manifest output from MediaLive
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "hls" {
  bucket = "${var.name_prefix}-hls"

  tags = merge(var.tags, { Name = "${var.name_prefix}-hls" })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "hls" {
  bucket = aws_s3_bucket.hls.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "hls" {
  bucket                  = aws_s3_bucket.hls.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Access logging into the shared SSE-S3 logs bucket - no KMS grant needed
# since the target (unlike this bucket itself) isn't SSE-KMS encrypted.
resource "aws_s3_bucket_logging" "hls" {
  bucket        = aws_s3_bucket.hls.id
  target_bucket = var.logs_bucket_name
  target_prefix = "s3-hls/"
}

# Segments/manifests are transient - expire aggressively so a forgotten
# channel doesn't accumulate storage cost indefinitely.
resource "aws_s3_bucket_lifecycle_configuration" "hls" {
  bucket = aws_s3_bucket.hls.id
  rule {
    id     = "expire-segments"
    status = "Enabled"
    filter {}
    expiration {
      days = 3
    }
  }
}

resource "aws_cloudfront_origin_access_control" "hls" {
  name                              = "${var.name_prefix}-hls-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ---------------------------------------------------------------------------
# IAM role - MediaLive channel writes to the HLS bucket, logs to CloudWatch
# ---------------------------------------------------------------------------
resource "aws_iam_role" "medialive" {
  name = "${var.name_prefix}-medialive"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "medialive.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "medialive" {
  name = "${var.name_prefix}-medialive"
  role = aws_iam_role.medialive.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket", "s3:DeleteObject"]
        Resource = [aws_s3_bucket.hls.arn, "${aws_s3_bucket.hls.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey*"]
        Resource = [var.kms_key_arn]
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
        Resource = "arn:aws:logs:*:*:log-group:/infra-at-scale/${var.name_prefix}/medialive*"
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# MediaLive input - RTP push. The encoder pushes its stream to the endpoint
# MediaLive assigns this input (visible on `aws_medialive_input.ingest`'s
# `destinations` attribute after apply, or in the console); only source IPs
# in input_cidr_allowlist are permitted to push.
#
# See README.md in this directory: literal SRT ingest (the diagram's label)
# isn't provisionable via Terraform on the pinned `hashicorp/aws` provider
# version - confirmed by inspecting its resource schema - RTP_PUSH is the
# nearest well-supported equivalent.
# ---------------------------------------------------------------------------
resource "aws_medialive_input_security_group" "ingest" {
  dynamic "whitelist_rules" {
    for_each = var.input_cidr_allowlist
    content {
      cidr = whitelist_rules.value
    }
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-input-sg" })
}

resource "aws_medialive_input" "ingest" {
  name                  = "${var.name_prefix}-rtp-input"
  type                  = "RTP_PUSH"
  input_security_groups = [aws_medialive_input_security_group.ingest.id]

  destinations {
    stream_name = var.stream_name
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-rtp-input" })
}

# ---------------------------------------------------------------------------
# MediaLive channel - single H.264/AAC rendition to HLS on S3.
# PLACEHOLDER encode ladder: production ABR needs multiple video_description
# entries (e.g. 1080p/720p/480p) each with its own output in output_group,
# tuned to your source's real resolution/frame rate/bitrate budget.
# ---------------------------------------------------------------------------
resource "aws_medialive_channel" "this" {
  name          = "${var.name_prefix}-channel"
  channel_class = var.channel_class
  role_arn      = aws_iam_role.medialive.arn

  input_specification {
    codec            = "AVC"
    input_resolution = "HD"
    maximum_bitrate  = "MAX_20_MBPS"
  }

  input_attachments {
    input_id              = aws_medialive_input.ingest.id
    input_attachment_name = "primary"
  }

  destinations {
    id = "hls-destination"

    settings {
      url = "s3ssl://${aws_s3_bucket.hls.bucket}/live/"
    }
  }

  encoder_settings {
    timecode_config {
      source = "SYSTEMCLOCK"
    }

    video_descriptions {
      name   = "video_720p"
      width  = 1280
      height = 720

      codec_settings {
        h264_settings {
          bitrate               = 3000000
          rate_control_mode     = "CBR"
          framerate_control     = "SPECIFIED"
          framerate_numerator   = 30
          framerate_denominator = 1
          gop_size              = 60
          gop_size_units        = "FRAMES"
          profile               = "HIGH"
          level                 = "H264_LEVEL_AUTO"
        }
      }
    }

    audio_descriptions {
      name                = "audio_stereo"
      audio_selector_name = "default"

      codec_settings {
        aac_settings {
          bitrate     = 128000
          sample_rate = 48000
          coding_mode = "CODING_MODE_2_0"
        }
      }
    }

    output_groups {
      name = "hls-output-group"

      output_group_settings {
        hls_group_settings {
          destination {
            destination_ref_id = "hls-destination"
          }

          segment_length      = var.hls_segment_length_seconds
          codec_specification = "RFC_4281"
          directory_structure = "SINGLE_DIRECTORY"
          index_n_segments    = 10
          mode                = "LIVE"
        }
      }

      outputs {
        output_name             = "720p"
        video_description_name  = "video_720p"
        audio_description_names = ["audio_stereo"]

        output_settings {
          hls_output_settings {
            name_modifier = "_720p"

            hls_settings {
              standard_hls_settings {
                m3u8_settings {
                  audio_frames_per_pes = 4
                }
              }
            }
          }
        }
      }
    }
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-channel" })
}

# ---------------------------------------------------------------------------
# CloudFront distribution - HLS playback
# ---------------------------------------------------------------------------
resource "aws_cloudfront_distribution" "hls" {
  enabled         = true
  is_ipv6_enabled = true
  price_class     = var.price_class
  aliases         = [var.live_fqdn]
  web_acl_id      = var.web_acl_arn
  comment         = "${var.name_prefix} live HLS playback"

  origin {
    domain_name              = aws_s3_bucket.hls.bucket_regional_domain_name
    origin_id                = "s3-hls"
    origin_access_control_id = aws_cloudfront_origin_access_control.hls.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-hls"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # Short TTL suits a live manifest/segment cadence better than the default
    # "CachingOptimized" policy tuned for static assets.
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CloudFront-managed "CachingDisabled"; swap for a custom policy tuned to hls_segment_length_seconds in production
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.cloudfront_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  logging_config {
    bucket          = var.logs_bucket_domain_name
    prefix          = "cloudfront-live/"
    include_cookies = false
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-hls-cf" })
}

resource "aws_s3_bucket_policy" "hls" {
  bucket = aws_s3_bucket.hls.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontRead"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.hls.arn}/*"
        Condition = {
          StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.hls.arn }
        }
      },
      {
        Sid       = "AllowMediaLiveWrite"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.medialive.arn }
        Action    = ["s3:PutObject", "s3:GetObject", "s3:ListBucket", "s3:DeleteObject"]
        Resource  = [aws_s3_bucket.hls.arn, "${aws_s3_bucket.hls.arn}/*"]
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.hls.arn, "${aws_s3_bucket.hls.arn}/*"]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "medialive" {
  name              = "/infra-at-scale/${var.name_prefix}/medialive"
  retention_in_days = var.log_retention_days
}
