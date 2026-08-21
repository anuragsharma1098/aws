# Fill in with the outputs of `bootstrap` (terraform output) for this account.
bucket         = "CHANGE_ME-infra-at-scale-tfstate-dev-000000000000"
key            = "infra-at-scale/dev/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "CHANGE_ME-infra-at-scale-tflock-dev"
encrypt        = true
