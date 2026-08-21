# Fill in with the outputs of `bootstrap` (terraform output) for this account.
bucket         = "CHANGE_ME-infra-at-scale-tfstate-staging-000000000000"
key            = "infra-at-scale/staging/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "CHANGE_ME-infra-at-scale-tflock-staging"
encrypt        = true
