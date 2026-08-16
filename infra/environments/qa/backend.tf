# Partial backend config - see backend.hcl for the account-specific values.
# Init with: terraform init -backend-config=backend.hcl

terraform {
  backend "s3" {
    key     = "qa/terraform.tfstate"
    encrypt = true
  }
}
