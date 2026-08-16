# Partial backend config on purpose - account-specific values (bucket/table names) live in
# backend.hcl, not here, so this file stays identical across accounts/forks.
# Init with: terraform init -backend-config=backend.hcl

terraform {
  backend "s3" {
    key     = "global/terraform.tfstate"
    encrypt = true
  }
}
