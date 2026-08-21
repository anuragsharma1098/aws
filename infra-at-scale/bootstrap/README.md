# bootstrap

Creates the remote state backend (S3 bucket + DynamoDB lock table, both
KMS-encrypted) that every `environments/*` root module points at. Apply this
once per environment (ideally once per AWS account, before anything else):

```bash
terraform init
terraform apply -var="environment=dev"
terraform output
```

Copy the `state_bucket` / `lock_table` / `kms_key_arn` outputs into
`environments/dev/backend.hcl`, then `terraform init -backend-config=backend.hcl`
in that environment.

This module's own state is intentionally local (no backend block) — it is the
thing that creates the backend, so it can't depend on one existing yet. Keep
`bootstrap/terraform.tfstate` somewhere durable (a private, versioned bucket
outside this repo, or check it into a restricted-access state-of-state repo) —
losing it doesn't lose your infrastructure, but it does mean re-importing the
bucket/table by hand.
