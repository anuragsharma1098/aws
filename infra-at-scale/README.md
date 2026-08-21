# infra-at-scale

Enterprise-grade Terraform for a production AWS platform built to serve 1M+ users:
edge (Route 53 + CloudFront + WAF), an ECS Fargate application tier behind an ALB
with **blue/green deployments via AWS CodeDeploy**, a private data layer (RDS
Multi-AZ + RDS Proxy + read replica, ElastiCache Serverless Redis), a live-streaming
ingest/delivery pipeline (RTP push → MediaLive → S3 HLS → CloudFront — see
[`modules/live-streaming/README.md`](modules/live-streaming/README.md) for why RTP,
not the diagram's SRT), and full observability (CloudWatch + SNS). Four independent
environments — **dev, qa, staging, prod** — share the same module set and diverge
only in `terraform.tfvars`.

This tree is a standalone design built directly from the target architecture
diagram. It does not reuse or extend `infra/` — treat the two as unrelated.

## Layout

```
infra-at-scale/
├── bootstrap/              # one-time: S3 state bucket + DynamoDB lock table (apply first, per account)
├── modules/                # reusable building blocks, one concern each
│   ├── vpc/                # VPC, public/private/data subnets, IGW, NAT
│   ├── security-groups/    # least-privilege SGs, tier-to-tier only
│   ├── kms/                # customer-managed key, one per environment
│   ├── route53-acm/        # hosted zone lookup + ACM certs (regional + us-east-1)
│   ├── waf/                # WAFv2 web ACLs (CLOUDFRONT + REGIONAL scopes)
│   ├── s3-cloudfront/      # frontend S3 bucket + CloudFront (OAC), ALB log bucket
│   ├── alb/                # ALB, HTTPS listener, blue/green target group pair
│   ├── ecs-cluster/        # Fargate ECS cluster + Container Insights
│   ├── iam-ecs/            # task execution role, task role, CodeDeploy service role
│   ├── ecs-service-bluegreen/ # task def, ECS service (CODE_DEPLOY controller), CodeDeploy app/group, autoscaling
│   ├── rds/                # Postgres Multi-AZ primary, read replica, RDS Proxy
│   ├── elasticache/        # ElastiCache Serverless (Redis)
│   ├── secrets-manager/    # DB credentials + app secrets
│   ├── monitoring/         # CloudWatch alarms, dashboard, SNS topic
│   ├── live-streaming/     # RTP-push ingest → MediaLive → S3 (HLS) → CloudFront
│   └── iam-github-oidc/    # GitHub Actions OIDC federated deploy role (no long-lived keys)
├── environments/
│   ├── dev/  qa/  staging/  prod/   # root modules; each wires every module above
├── ci-cd/github-actions/   # example blue/green pipeline (terraform + ECS/CodeDeploy deploy)
├── docs/                   # flow docs: git→deploy, module wiring, end-user request flow
└── Makefile
```

## Flow documentation

[`docs/`](docs/) walks three things end to end, in order: how a commit gets
from `git push` to running in production
([`docs/01-git-to-deployment-flow.md`](docs/01-git-to-deployment-flow.md)),
how the 16 modules above wire into each other
([`docs/02-module-connections.md`](docs/02-module-connections.md)), and what
a real user experiences hitting the frontend, the API, the admin service, a
live stream, and a mid-deployment request
([`docs/03-user-flow.md`](docs/03-user-flow.md)). `ARCHITECTURE.md` below is
the component-by-component reference table; `docs/` is the narrative walk
through it. [`architecture-diagram.svg`](architecture-diagram.svg) is the
single-picture version of all three — every module mapped to its AWS
resources, colored by category, with every user type's entry point marked.

## Design principles

1. **Isolation first** — app tier and data tier live in private subnets with no
   public IP; only the ALB and NAT Gateways sit in public subnets. Only the ALB is
   reachable from the internet on the data path (behind WAF); RDS/ElastiCache accept
   traffic only from the ECS tasks' security group.
2. **Blue/green, not rolling** — every environment's ECS service deploys through
   AWS CodeDeploy (`deployment_controller.type = "CODE_DEPLOY"`), never
   `ECS`-native rolling updates. A new task set is stood up alongside the old one
   behind a second ("green") target group, validated, and the ALB listener is
   flipped — with automatic rollback on CloudWatch alarm. `dev`/`qa` shift traffic
   `ALL_AT_ONCE`; `staging` and `prod` shift `LINEAR`/`CANARY` with a bake window
   (see each environment's `terraform.tfvars`).
3. **Failure resilient** — Multi-AZ subnets everywhere; `prod`/`staging` run a
   Multi-AZ RDS primary + a cross-AZ read replica behind RDS Proxy; ECS services
   run a minimum of 2 tasks across 2 AZs with target-tracking autoscaling.
4. **Scalable on demand** — ECS service autoscaling on CPU/memory/request-count,
   RDS Proxy to absorb connection storms, ElastiCache Serverless to avoid manual
   node-count capacity planning, CloudFront to absorb static/HLS read traffic at
   the edge.
5. **Secure by design** — WAF in front of both CloudFront and the ALB, a
   customer-managed KMS key encrypts every data store, Secrets Manager holds every
   credential (no secrets in `terraform.tfvars` or task definitions), IAM roles are
   scoped per-task (no shared "app role"), and CI/CD authenticates via GitHub OIDC
   federation instead of static AWS access keys.
6. **Observable** — Container Insights, ALB access logs to S3, CloudWatch alarms
   on the ALB/ECS/RDS/CodeDeploy deployment health, all wired to a single SNS topic
   per environment (email/Slack-webhook subscriber, added out of band).

## Placeholders you must replace before `apply`

Every placeholder is a Terraform variable with an obviously-fake default so `plan`
never silently uses a real value. Grep for `CHANGE_ME` across `environments/*/terraform.tfvars`
before applying any environment:

| Placeholder | Where | Real value comes from |
| --- | --- | --- |
| `domain_name` | every `terraform.tfvars` | your registered Route 53 domain |
| `container_image` | every `terraform.tfvars` | your CI pipeline's ECR image URI (`<account>.dkr.ecr.<region>.amazonaws.com/app:<tag-or-digest>`) |
| `github_repository` | `iam-github-oidc` inputs | `"your-org/your-repo"` |
| `alarm_notification_email` | every `terraform.tfvars` | on-call distribution list |
| DB master credentials | never in tfvars | generated by `modules/rds` into Secrets Manager on first apply — nothing to fill in |

## Bootstrapping a new environment

```bash
# 1. One-time per AWS account: create the remote state backend
cd bootstrap
terraform init && terraform apply -var="environment=dev"

# 2. Point the environment's backend.hcl at the bucket/table bootstrap just created,
#    then fill in terraform.tfvars (replace every CHANGE_ME)
cd ../environments/dev
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

Repeat step 2 for `qa`, `staging`, `prod` — each is a fully independent Terraform
state and, in a real multi-account setup, a separate AWS account (see
`ARCHITECTURE.md`).

## Blue/green deploy flow (CI/CD, not Terraform)

Terraform provisions the CodeDeploy application/deployment group and the ECS
service's *initial* task set; it does not perform deployments on every code push
— that's `ci-cd/github-actions/ecs-blue-green-deploy.yml`'s job, using
`aws deploy create-deployment` against the resources Terraform created. See that
workflow file for the exact AppSpec / task-definition-registration sequence.
