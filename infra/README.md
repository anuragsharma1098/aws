# infra

Terraform for a containerized web app (S3 + CloudFront frontend, ECS Fargate backend behind
an ALB, RDS Postgres) across three environments: **dev**, **qa**, **prd**.

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the full diagram and request-flow walkthrough.

## Layout

```
infra/
├── Makefile             Thin wrapper around the terraform commands below (see "Makefile")
├── bootstrap/          One-time, per-AWS-account. Creates the S3 bucket + DynamoDB table
│                        that every other config uses as its remote state backend.
├── global/              Applied once per account. Resources shared across all environments:
│                        the ECR repositories and the account's CloudTrail audit trail.
├── modules/             Reusable building blocks. Nothing in here is applied directly.
│   ├── vpc                 VPC, public/private subnets across 2+ AZs, IGW, NAT Gateway(s)
│   ├── security-groups     Per-tier security groups: ALB, app, database
│   ├── kms                 Customer-managed key, one per environment (+ one for bootstrap, one for global)
│   ├── iam-boundary        Permissions boundary policy attached to every IAM role this repo creates
│   ├── ecr                 Container image repositories (used from infra/global)
│   ├── alb                 Application Load Balancer, target group, HTTP/HTTPS listeners
│   ├── ecs-cluster         Fargate ECS cluster
│   ├── ecs-service         Task definition, service, task/execution IAM roles, autoscaling
│   ├── rds                 Postgres instance + generated master credentials in Secrets Manager
│   ├── secrets-manager     Empty secret container for app-level secrets (API keys, etc.)
│   ├── s3-cloudfront       Private S3 bucket + CloudFront (OAC) for the static frontend
│   ├── s3-uploads          Private S3 bucket for user-uploaded media, lifecycle rules
│   ├── waf                 Regional WAFv2 Web ACL (managed rule groups + rate limit) on the ALB
│   ├── cloudtrail           Account-level audit trail (used from infra/global)
│   ├── monitoring           CloudWatch alarms (ALB, ECS, RDS) + an SNS topic
│   └── route53-acm          Optional hosted zone + ACM cert, no-op until you own a domain
└── environments/
    ├── dev/              Small, cheap, disposable. Single NAT, single-AZ RDS.
    │   └── dns.tf            The api./www. alias records - the root-level resources that
    │                         aren't module calls, split out on purpose (see below)
    ├── qa/                Same shape as dev, closer to prd sizing for realistic testing.
    └── prd/               Multi-AZ NAT, Multi-AZ RDS, deletion protection, longer backups.
```

Every environment wires the same modules together the same way (`environments/*/main.tf` -
diff them if you want proof); only `terraform.tfvars` differs in sizing, redundancy, and
safety settings. `dns.tf` is the one exception to "everything is a module call" - it's two
`aws_route53_record` alias records (API → ALB, frontend → CloudFront), kept as a standalone
root file (rather than folded into `main.tf` or the `route53-acm` module) because each
composes outputs from two other modules and stands alone as its own concern, the same way a
hand-rolled enterprise repo would split root-level `dns.tf` from `main.tf`.

## What's deliberately not here yet

This covers the core request path end to end but skips pieces that only make sense once
there's a real product decision behind them - add them the same way as everything else
(new module + a stanza in each environment's `main.tf`) when the need shows up:

- **Cognito** - only needed once there's real user auth/identity, not before.
- **SES** - only needed once the app sends transactional email.
- **ElastiCache (Redis)** - only needed once there's an actual caching/session-store need.
- **CI/CD (GitHub Actions + OIDC)** - deploys are manual (`terraform apply`, `docker push`)
  until a pipeline is worth building.
- **A Terraform Enterprise remote backend** - a real enterprise repo (the one this was
  compared against) uses a TFE/Terraform Cloud `backend "remote"` with per-environment
  `*_tfe_backend.config` + shared `*.auto.tfvars` files (we did adopt its `Makefile`, see
  below). This repo intentionally keeps the S3+DynamoDB backend and a directory-per-environment
  layout instead: each environment already gets fully isolated state and tfvars by virtue of
  its own folder, so a shared `config/` directory with auto-loaded `*.auto.tfvars` per
  environment would be solving a problem this layout doesn't have. Worth revisiting if this
  ever moves onto Terraform Cloud/Enterprise for its policy-as-code (Sentinel/OPA) and
  run-approval features - the backend swap is contained to each environment's `backend.tf`.

## Prerequisites

- Terraform >= 1.6
- An AWS account and credentials (`aws configure` or environment variables)
- An S3 bucket name is globally unique across *all* AWS accounts - every `REPLACE_WITH_*`
  placeholder in this repo needs a real, unique value before you can apply (your AWS account
  ID is a reasonable, always-unique suffix).

## First-time setup (once per AWS account)

1. **Bootstrap remote state.** This is the only config that doesn't use a remote backend -
   it creates the S3 bucket and DynamoDB table everything else needs, so it can't depend on
   them existing yet.

   ```bash
   cd infra/bootstrap
   terraform init
   terraform apply -var="state_bucket_suffix=<your-aws-account-id>"
   terraform output   # note state_bucket_name and lock_table_name
   ```

2. **Fill in backend.hcl everywhere.** Every other config (`global/`, `environments/*/`)
   has a `backend.hcl` with `REPLACE_WITH_state_bucket_name` / `REPLACE_WITH_lock_table_name`
   placeholders - fill them in with the outputs from step 1.

3. **Apply global resources** (ECR repos + CloudTrail, shared by every environment):

   ```bash
   cd infra/global
   # edit terraform.tfvars: set cloudtrail_log_bucket_suffix
   terraform init -backend-config=backend.hcl
   terraform apply
   ```

## Makefile

`infra/Makefile` wraps the commands below - it doesn't do anything you couldn't type by
hand, it just saves re-typing `-backend-config=backend.hcl` and `cd`-ing around. Requires
GNU Make; not bundled with Git Bash by default on Windows (`choco install make`,
`scoop install make`, or run it from WSL - `make` is standard on Linux/macOS).

```bash
make help                   # list every target
make plan ENV=dev           # terraform plan in environments/dev
make apply ENV=qa           # terraform apply in environments/qa
make destroy ENV=dev        # terraform destroy, with a typed confirmation prompt
make bootstrap-apply        # apply infra/bootstrap
make global-apply           # apply infra/global
make fmt                    # terraform fmt -recursive across all of infra/
make validate-all           # init -backend=false + validate on every root config
```

`ENV` defaults to `dev` if omitted. `destroy` refuses to run unless you type the environment
name back at the prompt - there's no `--auto-approve` anywhere in the Makefile on purpose.

## Working in an environment

```bash
cd infra/environments/dev   # or qa / prd
# edit terraform.tfvars: fill in state_bucket and the *_REPLACE_WITH_SUFFIX bucket names
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

Promotion flow is dev → qa → prd: make and validate a change in dev first, run the same
change through qa, then apply to prd. Each environment has fully isolated state, its own
VPC/CIDR range, and its own resources - nothing but the ECR images and the AMI/module code
itself is shared.

### Deploying a new backend image

Images are pushed to the shared ECR repos in `infra/global`, then referenced by tag from
each environment:

```bash
docker build -t <ecr-repo-url>:<tag> .
docker push <ecr-repo-url>:<tag>
# then in the environment's terraform.tfvars:
backend_image_tag = "<tag>"
terraform apply
```

`ecs-service`'s task definition ignores drift on `task_definition`/`desired_count` in state
(see the module's `lifecycle` block) so a CI/CD pipeline can update the running task via
`aws ecs update-service` without fighting Terraform on the next `plan`.

## DNS endpoints (backend API + frontend)

`environments/*/dns.tf` creates the two `aws_route53_record` alias records that give each
public-facing piece a stable, Terraform-managed DNS name instead of a raw AWS-generated one:

- **Backend** - `api.<domain_name>` → the ALB. `api_subdomain` (default `"api"`) controls
  the subdomain. The ALB's ACM cert (`module.dns` in `main.tf`) picks up this name in its SAN
  list automatically.
- **Frontend** - `www.<domain_name>` → CloudFront. `frontend_subdomain` (default `"www"`)
  controls the subdomain.

Both are a no-op (`count = 0`) until `enable_dns = true` and a real `domain_name` is set in
that environment's `terraform.tfvars` - `terraform output api_endpoint` / `frontend_endpoint`
fall back to the raw ALB DNS name / CloudFront domain until then, so both are always
reachable regardless of whether a custom domain exists yet.

**Why the frontend needs a second ACM certificate, not the one the ALB uses:** ACM
certificates for CloudFront must be issued in **us-east-1** specifically, independent of
`var.aws_region`. `main.tf` instantiates `route53-acm` a second time as `dns_cloudfront`,
using an aliased `aws.us_east_1` provider (declared in `providers.tf`) and the *same* zone
the first instantiation created (via `existing_zone_id = module.dns.zone_id`) rather than
creating or looking up a second zone. If `var.aws_region` is ever changed away from
`us-east-1`, the ALB's cert and the CloudFront cert correctly stay in different regions -
that's the whole reason this is two module calls instead of one shared certificate.

## Security & tagging conventions

- **No credentials in tfvars.** RDS master credentials are generated (`random_password`) and
  stored in Secrets Manager by the `rds` module itself; the `secrets-manager` module creates
  an empty container for app secrets you populate out-of-band (console, CLI, or CI/CD), never
  in a committed file.
- **Least-privilege IAM + a permissions boundary.** Every ECS service gets its own execution
  role (image pull, log write, secret read - only for the secrets it's given) and its own
  task role (empty by default; add permissions as the app actually needs AWS API access).
  Both roles also carry the `iam-boundary` module's policy as their `permissions_boundary` -
  a ceiling on the maximum permissions either role could ever reach, even if its own policy
  is later widened by mistake or a task is compromised. The boundary itself denies IAM
  privilege-escalation actions (creating users/access keys, attaching policies, touching
  permissions boundaries themselves) and, when `allowed_regions` is set, anything outside
  those regions.
- **Network isolation.** Only the ALB's security group is reachable from the internet. The
  app tier only accepts traffic from the ALB; the database only accepts traffic from the app
  tier. ECS tasks and RDS both live in private subnets with no public IP.
- **Encryption at rest via customer-managed KMS, everywhere.** Each environment gets its own
  CMK (`modules/kms`, instantiated once in each environment's `main.tf`, plus one for
  `bootstrap`'s state bucket and one for `global`'s ECR/CloudTrail) - RDS storage, both
  Secrets Manager secrets, the frontend/uploads S3 buckets, the ECS log group, the SNS alarm
  topic, ECR images, and the CloudTrail log bucket all encrypt with it instead of an
  AWS-managed default key. The key's policy (see `modules/kms/main.tf`) grants exactly the
  service principals that need it - CloudWatch Logs and CloudTrail each need a non-standard,
  encryption-context-scoped statement, which is why they're separate `enable_cloudwatch_logs`
  / `enable_cloudtrail` toggles rather than plain entries in `service_principals`.
- **Encryption in transit** via TLS termination at the ALB/CloudFront once a certificate is
  attached (see the DNS section above).
- **Tagging.** Every module accepts a `tags` map; each environment's `main.tf` merges in
  `Project` and `Environment` as `local.common_tags`. Extend that local, not individual
  resources, to add an org-wide tag (e.g. `CostCenter`) everywhere at once.

## Cost notes

- `single_nat_gateway = true` (dev/qa default) runs one NAT Gateway instead of one per AZ -
  meaningfully cheaper, at the cost of AZ-level resilience for outbound traffic. prd sets it
  `false`.
- `enable_fargate_spot` is on for every non-`prd` environment's ECS cluster automatically
  (`environment != "prd"` in `main.tf`) - Fargate Spot is cheaper but tasks can be interrupted,
  fine for dev/qa.
- WAF, NAT Gateways, and Multi-AZ RDS are the line items most likely to surprise you on the
  bill - `terraform plan` before applying, and remember `terraform destroy` in an environment
  you're not using tears all of this back down.
- Each customer-managed KMS key is ~$1/month plus negligible per-request cost (S3/RDS/etc.
  use `bucket_key_enabled`/caching where available to keep request volume down) - five keys
  total (bootstrap, global, dev, qa, prd) is a rounding error next to NAT Gateways or RDS, but
  it's not exactly zero either.
