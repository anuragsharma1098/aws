# Fill these in with the outputs from `terraform apply` in infra/bootstrap, then run:
#   terraform init -backend-config=backend.hcl
bucket         = "REPLACE_WITH_state_bucket_name"
region         = "us-east-1"
dynamodb_table = "REPLACE_WITH_lock_table_name"
