# infra

Terraform for the AWS side of a Kubernetes-based app: EKS (Managed node groups), an S3 +
CloudFront frontend, RDS Postgres, and everything the actual deploy path needs to reach
them - IRSA roles for in-cluster controllers, OIDC federation for Harness, ECR, and a CI
artifacts bucket. Three environments: **dev**, **qa**, **prd** - each its own **separate AWS
account**, not three environments sharing one account.

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the runtime architecture diagram, the CI/CD
pipeline diagram, and both walkthroughs.

## Account topology

Three AWS accounts, one per environment, with no dedicated shared/tooling account. That one
decision (no shared account) shapes several others:

- **ECR isn't centralized.** Each account has its own repos (`infra/global/{dev,qa,prd}`).
  The same built image is promoted forward by an explicit, pipeline-driven copy (Harness
  pulls the exact image by digest from the previous environment's ECR and pushes it into the
  next one's), never by granting compute (EKS nodes) standing cross-account pull rights. See
  the SDLC diagram in [`ARCHITECTURE.md`](ARCHITECTURE.md) for the full chain and the
  reasoning against centralizing ECR in a workload account.
- **CloudTrail is per-account**, not shared - each environment's `main.tf` creates its own
  trail, because a single trail can't span accounts without an AWS Organizations delegation
  this repo doesn't assume exists.
- **State is per-account too.** `bootstrap` and `global` both run once *per account* (three
  times total, not once), each producing its own state bucket/ECR/etc. within that account.
  There's no cross-account remote-state read anywhere in this repo.
- **Terraform authenticates via IAM role assumption.** Every root config's `provider "aws"`
  block supports an optional `terraform_deploy_role_arn` - set it if your workflow assumes a
  role into each target account; leave it `null` to just use whatever credentials/profile are
  already active for that account (e.g. `aws sso login --profile dev` before running
  anything in `environments/dev`).

If you're working through this for the first time, it's worth reading in order: bootstrap →
global → one environment, applying each with **that account's** credentials active before
moving to the next.

## Division of responsibility: Terraform vs. Helm/Harness

This repo provisions **infrastructure**, not the running application. It stops at:

- an EKS cluster, node group, and add-ons the app can schedule onto
- IAM roles the in-cluster controllers (AWS Load Balancer Controller, External Secrets
  Operator, external-dns) need, scoped via IRSA to their specific service accounts
- an OIDC-federated IAM role Harness assumes to push images and deploy - one per account
- ECR repos, RDS, Secrets Manager, S3, KMS, CloudTrail, the WAF Web ACL

It deliberately does **not** provision: the Kubernetes Deployment/Service/Ingress
(the Helm chart's job), the controllers themselves (installed via Helm, by Harness, using
the IRSA roles this repo creates), the CI/CD pipeline logic (Harness's job), or the
image-promotion pipeline steps (also Harness - this repo only grants the narrow cross-account
ECR pull permission that makes the copy step possible). If you're looking for where a
Deployment YAML or a Harness pipeline definition lives, it's not in this repo.

## Layout

```
infra/
├── Makefile             Thin wrapper around the terraform commands below (see "Makefile")
├── bootstrap/          One-time, per AWS ACCOUNT (not per environment - run with each
│                        account's credentials active). Creates the S3 bucket + DynamoDB
│                        table that config in that account uses as its remote state backend.
├── global/              Account-level resources, applied once per account:
│   ├── dev/                 ECR repos for the dev account
│   ├── qa/                  ECR repos for the qa account, with cross-account pull granted
│   │                         to dev's Harness role (promotion copy - see account topology)
│   └── prd/                 ECR repos for the prd account, pull granted to qa's Harness role
├── modules/             Reusable building blocks. Nothing in here is applied directly.
│   ├── vpc                 VPC, public/private subnets across 2+ AZs, IGW, NAT Gateway(s), EKS subnet tags
│   ├── security-groups     Per-tier security groups: ALB, app (vestigial on EKS), database
│   ├── kms                 Customer-managed key, one per environment (+ one for bootstrap, one for global)
│   ├── iam-boundary        Permissions boundary policy attached to every IAM role this repo creates
│   ├── ecr                 Container image repositories, with optional cross-account pull policy
│   ├── eks                 EKS cluster, its OIDC provider, the EBS CSI driver's IRSA role
│   ├── eks-node-group      Managed node group + its IAM role
│   ├── eks-addons          Core addons: vpc-cni, coredns, kube-proxy, aws-ebs-csi-driver
│   ├── eks-access          EKS access entries (the modern aws-auth ConfigMap replacement)
│   ├── irsa                Generic: an IAM role scoped to one Kubernetes service account
│   ├── harness-oidc        OIDC federation + IAM role for Harness's CI/CD delegate, per account
│   ├── ci-artifacts        S3 bucket for Harness CI test logs/reports
│   ├── rds                 Postgres instance + generated master credentials in Secrets Manager
│   ├── secrets-manager     Empty secret container for app-level secrets (API keys, etc.)
│   ├── s3-cloudfront       Private S3 bucket + CloudFront (OAC) for the static frontend
│   ├── s3-uploads          Private S3 bucket for user-uploaded media, lifecycle rules
│   ├── waf                 Regional WAFv2 Web ACL (managed rule groups + rate limit)
│   ├── cloudtrail           Per-account audit trail (used from each environment's main.tf)
│   ├── monitoring           CloudWatch alarms (RDS; ALB/ECS alarms toggle off on EKS) + an SNS topic
│   ├── route53-acm          Optional hosted zone + ACM cert, no-op until you own a domain
│   ├── alb                  Not wired into environments/* anymore (see note below) - kept for reference
│   ├── ecs-cluster          Not wired into environments/* anymore (see note below) - kept for reference
│   └── ecs-service          Not wired into environments/* anymore (see note below) - kept for reference
└── environments/
    ├── dev/              dev account. Small, cheap, disposable. Single NAT, single-AZ RDS, 2 nodes.
    │   └── dns.tf            The frontend's alias record - the one root-level resource that
    │                         isn't a module call, split out on purpose (see below)
    ├── qa/                qa account. Same shape as dev, closer to prd sizing for realistic testing.
    └── prd/               prd account. Multi-AZ NAT, Multi-AZ RDS, deletion protection,
                             longer backups, larger/more nodes.
```

**Why `alb`, `ecs-cluster`, and `ecs-service` are still here but unused:** this repo was
originally built assuming ECS Fargate as the compute layer, then pivoted to EKS once the
real deployment shape (GitHub + Harness CI/CD, Helm charts, EKS) was clear. Deleting working,
documented modules on a pivot is more destructive than leaving them - they're just no longer
referenced from any `environments/*/main.tf`. On EKS, the ALB is created dynamically by the
**AWS Load Balancer Controller** reacting to a Kubernetes `Ingress` (installed via Helm, using
the `irsa_lb_controller` role this repo creates), not by Terraform.

Every environment wires the same modules together the same way (`environments/*/main.tf` -
diff them if you want proof); only `terraform.tfvars` differs in sizing, redundancy, safety
settings, and (now) which AWS account it targets.

## Required manual inputs

These cannot be filled in for you - they're account-specific, cross-account, or too
large/volatile to hand-author confidently. Every environment's (and, where noted, `global`
account's) `terraform.tfvars` has a `REPLACE_WITH_*` placeholder for each:

1. **`lb_controller_policy_json`** *(per environment)* - the AWS Load Balancer Controller's
   IAM policy. Copy the current one from the `kubernetes-sigs/aws-load-balancer-controller`
   project's install docs (`docs/install/iam_policy.json`). It's long and AWS revises it
   alongside controller releases, so it's not embedded here.
2. **`harness_oidc_issuer_url`** *(per environment)* - from your Harness account's
   OIDC/identity provider settings.
3. **`harness_subject_claim`** *(per environment)* - scopes which Harness pipeline/account
   can assume that account's deploy role. Defaults to `"*"` (trusts any token the issuer
   signs) in dev/qa; **narrow this for prd** to your actual production pipeline's identity.
4. **`eks_public_access_cidrs`** *(prd only; dev/qa default to `0.0.0.0/0`)* - the CIDRs
   allowed to reach the EKS API server publicly. Set this to your office/VPN range or
   Harness's delegate egress IPs, not the whole internet.
5. **Account IDs, both directions** - `global/dev/terraform.tfvars`'
   `ecr_cross_account_pull_principals` needs qa's account ID; `global/qa`'s needs prd's.
   Going the other way, `environments/qa/terraform.tfvars`' `harness_ecr_pull_repository_arns`
   needs dev's account ID (to build dev's ECR ARNs); prd's needs qa's. All four AWS account
   IDs need to be known before any of these four files can be finished.
6. **`terraform_deploy_role_arn`** *(every root config, if you assume a role into each
   account rather than switching credentials/profile - see "Account topology")*.

Also globally-unique S3 bucket names (`frontend_bucket_name`, `uploads_bucket_name`,
`ci_artifacts_bucket_name`) and `state_bucket` - same as everywhere else in this repo.

## Prerequisites

- Terraform >= 1.6
- Three AWS accounts (dev/qa/prd) and a way to get credentials active for each in turn -
  `aws configure`/SSO profiles, or role assumption via `terraform_deploy_role_arn`
- An S3 bucket name is globally unique across *all* AWS accounts - every `REPLACE_WITH_*`
  placeholder in this repo needs a real, unique value before you can apply (an AWS account ID
  is a reasonable, always-unique suffix).

## First-time setup (once per AWS account - so three times total)

Repeat all three steps below with **dev's** credentials active, then again with **qa's**,
then **prd's**. Nothing here is "run once for the whole org."

1. **Bootstrap remote state.** This is the only config that doesn't use a remote backend -
   it creates the S3 bucket and DynamoDB table everything else in *that account* needs, so it
   can't depend on them existing yet.

   ```bash
   cd infra/bootstrap
   terraform init
   terraform apply -var="state_bucket_suffix=<this-account-id>"
   terraform output   # note state_bucket_name and lock_table_name
   ```

2. **Fill in backend.hcl everywhere for this account.** `global/<env>/` and
   `environments/<env>/` each have a `backend.hcl` with `REPLACE_WITH_state_bucket_name` /
   `REPLACE_WITH_lock_table_name` placeholders - fill them in with this account's outputs
   from step 1.

3. **Apply this account's global resources** (ECR repos):

   ```bash
   cd infra/global/dev   # or qa / prd - matches whichever account's credentials are active
   # edit terraform.tfvars: set ecr_cross_account_pull_principals (see "Required manual inputs")
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
make bootstrap-apply        # apply infra/bootstrap (run once per account, with that account's credentials)
make global-apply           # apply infra/global (see note below)
make fmt                    # terraform fmt -recursive across all of infra/
make validate-all           # init -backend=false + validate on every root config
```

`ENV` defaults to `dev` if omitted. `destroy` refuses to run unless you type the environment
name back at the prompt - there's no `--auto-approve` anywhere in the Makefile on purpose.
Note: `global-apply` currently targets `infra/global` directly - since `global` is now split
into `global/dev`, `global/qa`, `global/prd`, run `terraform apply` by hand in the right
subdirectory (matching whichever account's credentials are active) until the Makefile target
is updated to take an `ENV` the same way `plan`/`apply` do.

## Working in an environment

```bash
cd infra/environments/dev   # or qa / prd - with that account's credentials active
# edit terraform.tfvars: fill in state_bucket, the *_REPLACE_WITH_SUFFIX bucket names,
# and the "Required manual inputs" above
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

Promotion flow is dev → qa → prd: make and validate a change in dev first, run the same
change through qa, then apply to prd. Each environment has fully isolated state, its own AWS
account, VPC/CIDR range, and EKS cluster - nothing is shared between them except the module
code itself and the narrow cross-account ECR pull permission used for image promotion.

### What happens after `terraform apply`

Terraform's job ends at a running, empty EKS cluster. From there:

1. `aws eks update-kubeconfig --name <output.eks_cluster_name>` to get `kubectl`/`helm`
   access (or let Harness's delegate do this using `harness_role_arn` + the EKS access entry
   this repo already granted it).
2. Install the AWS Load Balancer Controller, External Secrets Operator, and (once
   `enable_dns = true`) external-dns via Helm, annotating each chart's service account with
   the matching `*_irsa_role_arn` output.
3. Harness CI builds and pushes the image to dev's ECR only (URL in
   `terraform output ecr_repository_urls`, from dev's `infra/global`), using dev's
   `harness_role_arn`.
4. Harness CD deploys directly to dev's EKS cluster. To promote to qa, then prd, Harness
   pulls the exact image by digest from the previous environment's ECR and pushes it into the
   next one's own ECR (using that environment's `harness_role_arn`, which has narrow
   pull-only access to the previous environment's repos - `ecr_pull_repository_arns`), then
   deploys there. See the SDLC diagram in [`ARCHITECTURE.md`](ARCHITECTURE.md) for the full
   diagram.
5. Each deploy references the WAF Web ACL ARN (`terraform output waf_web_acl_arn`, for the
   Ingress's `alb.ingress.kubernetes.io/wafv2-acl-arn` annotation) and the Secrets Manager
   ARNs (`db_secret_arn`, `app_secrets_arn`) for External Secrets to sync - both from that
   environment's own account.

## DNS endpoints (frontend + backend)

- **Frontend** - `environments/*/dns.tf` creates a Terraform-managed `aws_route53_record`
  alias pointing `www.<domain_name>` (or whatever `frontend_subdomain` is) at CloudFront.
  This works because CloudFront is Terraform-managed and exists at apply time.
- **Backend** - there's no equivalent Terraform record. The ALB doesn't exist until the AWS
  Load Balancer Controller creates it from a Helm-deployed `Ingress`, so Terraform can't
  point a record at it yet. **external-dns** (installed via Helm, IRSA-authorized by
  `irsa_external_dns`) watches the `Ingress` and creates/updates `api.<domain_name>` itself
  once it exists.

Both paths are no-ops until `enable_dns = true` and a real `domain_name` is set -
`terraform output frontend_endpoint` falls back to the raw CloudFront domain until then; the
API has no Terraform-known URL before a domain exists (check `kubectl get ingress` for the
controller-assigned ALB hostname in the meantime).

**Why the frontend needs a second ACM certificate, not the same one anything else uses:** ACM
certificates for CloudFront must be issued in **us-east-1** specifically, independent of
`var.aws_region`. `main.tf` instantiates `route53-acm` a second time as `dns_cloudfront`,
using an aliased `aws.us_east_1` provider (declared in `providers.tf`) and the *same* zone
the first instantiation created (via `existing_zone_id = module.dns.zone_id`) rather than
creating or looking up a second zone.

## Security & tagging conventions

- **No credentials in tfvars.** RDS master credentials are generated (`random_password`) and
  stored in Secrets Manager by the `rds` module itself; the `secrets-manager` module creates
  an empty container for app secrets you populate out-of-band (console, CLI, or CI/CD), never
  in a committed file. Harness never gets a long-lived AWS access key either - `harness-oidc`
  federates its identity the same way GitHub Actions OIDC does, separately per account.
- **IRSA, not node-wide IAM.** Every controller that needs AWS permissions (Load Balancer
  Controller, External Secrets, external-dns, the EBS CSI driver) gets its own IAM role
  scoped to its exact Kubernetes service account via OIDC (`modules/irsa`) - not the node's
  own instance role, which every pod on that node could otherwise reach.
- **Image promotion never grants compute cross-account access.** The only cross-account IAM
  trust anywhere in this repo is ECR pull, granted narrowly to the *next* environment's
  Harness role (never push, never to a node/IRSA role) - see "Account topology" above. Prod's
  EKS nodes never have standing access into a lower environment's account.
- **A permissions boundary on every role this repo creates** - node roles, IRSA roles, and
  the Harness deploy role all carry the `iam-boundary` module's policy as their
  `permissions_boundary`, capping their maximum reachable permissions regardless of what
  their own policy grants. It denies IAM privilege-escalation actions (creating
  users/access keys, attaching policies, touching permissions boundaries themselves) and,
  when `allowed_regions` is set, anything outside those regions.
- **Network isolation.** Only the ALB (created by the Load Balancer Controller in public
  subnets) is reachable from the internet. Pods reach RDS via the EKS cluster's own managed
  security group; RDS itself lives in private subnets with no public IP.
- **Encryption at rest via customer-managed KMS, everywhere.** Each environment gets its own
  CMK (`modules/kms`, plus one for `bootstrap`'s state bucket and one for each account's
  `global` ECR) - RDS storage, both Secrets Manager secrets, the frontend/uploads/CI-artifacts
  S3 buckets, EKS's Kubernetes Secrets envelope encryption, the SNS alarm topic, ECR images,
  and that account's CloudTrail log bucket all encrypt with it instead of an AWS-managed
  default key.
- **Encryption in transit** via TLS termination at the ALB/CloudFront once a certificate is
  attached (see the DNS section above).
- **EKS access entries, not a hand-edited aws-auth ConfigMap.** Every principal that needs
  `kubectl`/`helm` access - currently just that account's Harness deploy role, scoped to
  `harness_eks_namespaces` - gets an explicit `aws_eks_access_entry` (`modules/eks-access`).
- **CloudTrail per account.** Every account gets its own audit trail (`environments/*/main.tf`)
  - there's no organization-level trail this repo assumes exists.
- **Tagging.** Every module accepts a `tags` map; each environment's `main.tf` merges in
  `Project` and `Environment` as `local.common_tags`. Extend that local, not individual
  resources, to add an org-wide tag (e.g. `CostCenter`) everywhere at once.

## Cost notes

- **The EKS control plane itself is a flat ~$73/month per cluster**, regardless of usage -
  one cluster per environment/account (dev/qa/prd) means ~$219/month before a single pod
  runs. This is the line item most different from the old ECS Fargate shape, where dev/qa
  cost near-zero when idle.
- Three AWS accounts also means **three of everything else with a flat/minimum cost**: three
  NAT Gateway setups, three sets of KMS keys (~$1/mo each), three CloudTrail trails, three
  RDS instances. There's no economy-of-scale from a shared account here - budget for it as
  three genuinely separate small deployments, not one deployment split three ways.
- `single_nat_gateway = true` (dev/qa default) runs one NAT Gateway instead of one per AZ -
  meaningfully cheaper, at the cost of AZ-level resilience for outbound traffic. prd sets it
  `false`.
- Node groups are `ON_DEMAND` by default everywhere (`node_capacity_type`) - switch dev/qa to
  `SPOT` if occasional interruption is acceptable there, for real savings on top of the
  control-plane cost above.
- WAF, NAT Gateways, and Multi-AZ RDS are the other line items most likely to surprise you on
  the bill - `terraform plan` before applying, and remember `terraform destroy` in an
  environment you're not using tears all of this back down (the EKS control plane cost stops
  the moment the cluster is gone).
