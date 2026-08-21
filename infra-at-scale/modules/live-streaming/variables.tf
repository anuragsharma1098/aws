variable "name_prefix" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "cloudfront_certificate_arn" {
  description = "us-east-1 ACM cert ARN covering live_fqdn (from modules/route53-acm)"
  type        = string
}

variable "live_fqdn" {
  type = string
}

variable "web_acl_arn" {
  description = "CLOUDFRONT-scope WAFv2 web ACL ARN"
  type        = string
}

variable "logs_bucket_domain_name" {
  description = "Shared access-log bucket's bucket_domain_name (from modules/s3-cloudfront) - the live CloudFront distribution logs here under a distinct prefix, same as the frontend distribution"
  type        = string
}

variable "logs_bucket_name" {
  description = "Same shared access-log bucket, by name rather than domain name - S3 server access logging (unlike CloudFront's logging_config) targets a bucket name, not a domain name"
  type        = string
}

# --- Encoder-side connection details -----------------------------------
# PLACEHOLDER: the venue encoder pushes RTP into MediaLive at the endpoint
# AWS assigns this input after creation (visible on aws_medialive_input's
# `destinations` computed output, or in the console) - restrict who can push
# to it with input_cidr_allowlist, the encoder's real public egress CIDR.
#
# The architecture diagram's "SRT Ingest" label is aspirational for this
# module: neither aws_medialive_input nor an SRT-capable MediaConnect
# resource exists yet in the pinned hashicorp/aws provider version (verified
# against its schema - see README.md in this directory) - RTP_PUSH is the
# nearest well-supported equivalent. Revisit once the provider adds SRT
# support, or configure SRT out-of-band via the AWS CLI/console and `terraform
# import` the result if you need SRT specifically before then.
variable "input_cidr_allowlist" {
  description = "PLACEHOLDER - CIDRs allowed to push RTP into this MediaLive input; replace with the encoder's real public egress CIDR"
  type        = list(string)
  default     = ["203.0.113.0/24"] # PLACEHOLDER (TEST-NET-3, RFC 5737)
}

variable "stream_name" {
  description = "Stream/application name segment of the RTP push destination MediaLive assigns this input"
  type        = string
  default     = "primary"
}

variable "channel_class" {
  description = "SINGLE_PIPELINE for dev/qa (cheaper), STANDARD for staging/prod (dual-pipeline HA)"
  type        = string
  default     = "SINGLE_PIPELINE"
}

variable "price_class" {
  type    = string
  default = "PriceClass_100"
}

variable "hls_segment_length_seconds" {
  type    = number
  default = 6
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
