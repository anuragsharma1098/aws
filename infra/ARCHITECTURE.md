# Architecture

Two diagrams, two different questions. **[`architecture-diagram.svg`](architecture-diagram.svg)**
shows the runtime: what's live in AWS at any moment and how a request moves through it.
**[`sdlc-diagram.svg`](sdlc-diagram.svg)** shows how a commit gets there in the first place —
the CI/CD pipeline that builds, tests, and deploys it. Terraform (this repo) only provisions
what the first diagram depicts; the second diagram's pipeline itself lives in Harness, not
here — see [`infra/README.md`](README.md)'s "Division of responsibility" section.

One environment's worth of `infra/environments/{dev,qa,prd}` is shown — all three wire the
same modules together; only sizing, redundancy, safety settings, and (see below) the AWS
account differ per `terraform.tfvars`. **dev, qa, and prd are three separate AWS accounts**,
not three environments sharing one — see [`infra/README.md`](README.md)'s "Account topology"
section. Account-level pieces (ECR, CloudTrail) are per-account too: `infra/global/{dev,qa,prd}`
each apply once, in their own account, producing their own ECR repos - there's no single
shared registry.

## Runtime architecture

![AWS architecture diagram: a client resolves DNS via Route 53, reaches the frontend through CloudFront and S3, and the backend API through WAF and an Application Load Balancer into EKS worker nodes running in private subnets across two AZs, which read RDS Postgres, and pull images from ECR through a NAT Gateway. In-cluster Helm-installed controllers (AWS Load Balancer Controller, External Secrets, external-dns), all IRSA-authorized, manage the ALB, sync Secrets Manager, and write DNS records respectively. Everything is encrypted with a per-environment KMS key and monitored via CloudWatch, SNS, CloudTrail, and an IAM permissions boundary.](architecture-diagram.svg)

Client traffic enters through two independent public paths (CloudFront for static assets,
WAF→ALB for the API) into a VPC with public and private subnets split across two
Availability Zones. Compute is EKS: worker nodes run the app's pods, and three Helm-installed
controllers — not Terraform — manage the pieces that used to be static resources under the
old ECS design (see the note in `infra/README.md`'s layout section on why the unused `alb`/
`ecs-*` modules are still in the repo).

### Request flow

1. **DNS lookup** — the client resolves `api.<domain>` / `www.<domain>` against Route 53.
   No-op today: `enable_dns` defaults to `false` in every environment, so this step (and the
   ACM certificates that depend on it) doesn't exist until a real domain is configured.
2. **Frontend (`HTTPS · frontend`)** — the client hits CloudFront directly, which serves
   static assets from the `S3 · frontend` bucket via Origin Access Control. The bucket has no
   public access of its own; CloudFront is the only reader.
3. **API (`HTTPS · api`)** — the client hits the ALB through WAF, which evaluates AWS managed
   rule groups and a per-IP rate limit before anything reaches the load balancer. The ALB
   itself isn't a Terraform resource here — the **AWS Load Balancer Controller** (Helm-
   installed, IRSA-authorized) creates and owns it from a Kubernetes `Ingress`.
4. **ALB → EKS** — the ALB forwards to whichever pod is healthy, on either AZ's worker node.
   Nodes run in private subnets with no public IP; outbound internet access (image pulls,
   CloudWatch Logs) goes through a NAT Gateway, not a direct route.
5. **EKS → RDS** — pods query the RDS Postgres primary over the security-group-scoped
   `:5432` path, entirely inside the VPC (no NAT hop) — via the cluster's own managed
   security group, not a dedicated "app tier" SG. `prd` adds a Multi-AZ standby; dev/qa don't.
6. **EKS → ECR / CloudWatch Logs** — two NAT-routed calls: the node pulling the container
   image, and log shipping to CloudWatch.
7. **CloudWatch → SNS** — RDS CPU/storage alarms publish to an SNS topic, which emails
   `alarm_email` if one is set. (ALB/pod-level alarms aren't Terraform-managed on this path —
   see `modules/monitoring`'s `enable_alb_alarms`/`enable_ecs_alarms` toggles, both off here.)

### In-cluster controllers (Helm-installed, not Terraform)

Three controllers do the work that Terraform-managed resources did under the old ECS design.
Terraform's job stops at the IRSA role each one assumes — installing and configuring the
controller itself is Harness's job (see the SDLC diagram below):

- **AWS Load Balancer Controller** — watches `Ingress` objects and creates/manages the ALB,
  target groups, and (via the `alb.ingress.kubernetes.io/wafv2-acl-arn` annotation) the WAF
  association.
- **External Secrets Operator** — syncs the `rds` and `secrets-manager` modules' Secrets
  Manager entries into native Kubernetes `Secret` objects the app's pods mount normally.
- **external-dns** — watches `Ingress`/`Service` objects and writes the `api.<domain>` Route
  53 record once `enable_dns = true` — the mechanism the old design used a direct Terraform
  `aws_route53_record` for, before the ALB stopped being something Terraform could point a
  record at.

### Security controls (not part of the request path)

- **KMS** — one customer-managed key per environment encrypts RDS storage, both Secrets
  Manager secrets, both S3 buckets, ECR images, CloudWatch Logs, the SNS topic, and EKS's
  own Kubernetes Secrets envelope encryption. Always on, not a toggle.
- **IAM permissions boundary** — attached to every IAM role this repo creates (node roles,
  every IRSA role, the Harness deploy role); caps what any of them could ever do even if
  their own policy is later widened.
- **IRSA, not node-wide IAM** — each controller's AWS permissions are scoped to its exact
  Kubernetes service account via OIDC, not inherited from the node's own instance role that
  every pod on that node could otherwise reach.
- **CloudTrail** — every AWS account (dev/qa/prd) has its own multi-region trail
  (`environments/*/main.tf`, not `infra/global`), recording every API call in that account.
  There's no organization-level trail spanning all three - each is independent.

### Component → module reference

| Diagram component | Terraform module |
| --- | --- |
| VPC, subnets, IGW, NAT Gateway | `modules/vpc` |
| Security groups (ALB / db tiers) | `modules/security-groups` |
| Route 53 zone + ACM certs | `modules/route53-acm` (×2 per env — see the "DNS endpoints" section of [`infra/README.md`](README.md)) |
| CloudFront, WAF | `modules/s3-cloudfront`, `modules/waf` |
| EKS cluster, node group, addons | `modules/eks`, `modules/eks-node-group`, `modules/eks-addons` |
| AWS LB Controller / External Secrets / external-dns IRSA roles | `modules/irsa` (×3 instantiations) |
| RDS Postgres + its credentials secret | `modules/rds` |
| App secrets | `modules/secrets-manager` |
| S3 frontend / uploads buckets | `modules/s3-cloudfront`, `modules/s3-uploads` |
| KMS key | `modules/kms` |
| IAM permissions boundary | `modules/iam-boundary` |
| CloudWatch alarms + SNS | `modules/monitoring` |
| ECR (per-account) | `modules/ecr` (via `infra/global/{dev,qa,prd}`) |
| CloudTrail (per-account) | `modules/cloudtrail` (via each environment's own `main.tf`) |

## SDLC / CI-CD pipeline

![CI/CD pipeline diagram across three separate AWS accounts, one per environment: a developer pushes to GitHub, which triggers Harness CI to check out and test the code, exporting test logs/reports to dev's S3 bucket, then build and push a container image to dev account's ECR using an OIDC-federated role. On tests passing, Harness CD deploys to dev's EKS cluster directly. To promote to qa and then prd, Harness pulls the exact image by digest from the previous environment's ECR and pushes it into the next environment's own ECR - a narrow, pipeline-only cross-account permission, never granted to cluster compute - before deploying there, with prd gated behind manual approval. Every environment's EKS cluster pulls only from its own account's ECR at runtime.](sdlc-diagram.svg)

This is the part Terraform doesn't own — Harness's pipeline definitions live in Harness, not
this repo. What this repo provides is everything the pipeline needs to authenticate and act,
**once per AWS account**: the `harness-oidc` role (OIDC-federated, no long-lived AWS keys in
Harness), that account's own ECR repos, a CI-artifacts bucket, and an EKS access entry scoping
exactly what the deploy role can touch in that account's cluster.

### Pipeline flow

1. **Push** — a developer pushes to GitHub, which webhook-triggers Harness CI.
2. **Test** — Harness CI checks out the code and runs tests, exporting logs/reports to dev's
   `ci-artifacts` S3 bucket (`modules/ci-artifacts`) — CI runs once, so its own output lands
   in the same account as the build.
3. **Build & push** — on success, Harness CI builds the image and pushes it to **dev's own**
   ECR (`infra/global/dev`), authenticating as dev's `harness-oidc` role —
   `ecr:GetAuthorizationToken` plus push permissions scoped to dev's repo ARNs, nothing
   broader.
4. **Deploy: dev** — Harness CD deploys the Helm chart straight to dev's EKS cluster via
   `helm upgrade --install`, using dev's own Harness role + EKS access entry
   (`AmazonEKSEditPolicy`, scoped to `harness_eks_namespaces`). No cross-account activity yet.
5. **Promote to qa** — Harness pulls the exact, already-tested image **by digest** (not just
   tag — a tag can move, a digest can't) from dev's ECR and pushes it into qa's own ECR. This
   is the one and only cross-account permission anywhere in this pipeline: qa's Harness role
   has narrow, pull-only access to dev's repos (`harness_ecr_pull_repository_arns`), granted
   by dev's ECR repository policy (`ecr_cross_account_pull_principals`). It is never granted
   to compute — qa's EKS nodes have no path into dev's account at all.
6. **Deploy: qa** — same local deploy mechanism as dev, now against qa's own freshly-copied
   image and qa's own cluster.
7. **Promote to prd, then deploy** — same copy-then-deploy mechanism again (qa's ECR → prd's
   ECR → prd's cluster), gated on manual approval in the Harness pipeline — enforced on the
   Terraform side too, by narrowing prd's `harness_subject_claim` to the specific production
   pipeline identity, not `"*"`.

**Why copy the image instead of letting each cluster pull cross-account:** the alternative
(one centralized ECR, with qa's and prd's EKS nodes granted standing pull rights into it) was
considered and rejected for this account layout. Without a dedicated shared/tooling account,
centralizing ECR in one of the three *workload* accounts (e.g. dev) would make prod's pods
runtime-dependent on dev's account being available, uncompromised, and trustworthy at
image-pull time — exactly the kind of blast-radius connection separate accounts exist to
avoid. Copying the image keeps every environment's compute fully self-contained: nothing an
EKS cluster does ever crosses an account boundary, only Harness's own pipeline role does, and
only for the narrow, audited act of promotion.

**Why three separate Harness roles instead of one:** each environment's `main.tf`
instantiates `harness-oidc` and `eks-access` independently, in that environment's own
account. A credential compromise or misconfigured pipeline step in dev's deploy role has no
path to qa or prd — it's a different IAM role, in a different AWS account, trusting a
different (or more tightly scoped) subject claim, with access entries into a completely
different cluster.

Regenerating either diagram: both are hand-authored, self-contained SVGs with no build step —
edit the file directly, or ask for changes and hand over what should change.
