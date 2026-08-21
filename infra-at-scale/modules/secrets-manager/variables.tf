variable "name_prefix" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "secrets" {
  description = <<-EOT
    map(secret short-name -> map of key/value pairs to seed it with).
    Placeholder default seeds one example app-secrets entry with obviously
    fake values - CHANGE_ME entries must be overwritten out-of-band (AWS
    console/CLI, or a secrets-rotation pipeline), never left in tfvars.
  EOT
  type        = map(map(string))
  default = {
    app-secrets = {
      jwt_signing_key     = "CHANGE_ME"
      third_party_api_key = "CHANGE_ME"
    }
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
