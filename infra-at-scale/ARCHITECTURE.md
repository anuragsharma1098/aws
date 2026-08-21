# Architecture

Maps every component in the target diagram to the Terraform module that provisions
it, and describes the request path end to end.

![AWS architecture diagram for infra-at-scale: visitors resolve DNS via Route 53 and reach the frontend through WAF and CloudFront to S3, or the API through WAF and an Application Load Balancer into ECS Fargate backend and admin services running as blue/green pairs in private subnets, which read/write RDS Postgres via RDS Proxy and cache in ElastiCache Redis. A venue encoder pushes RTP into MediaLive, which writes HLS to S3 and is served by a second CloudFront distribution to viewers. GitHub Actions authenticates via OIDC and drives CodeDeploy to shift ALB traffic between blue and green target groups, with CloudWatch alarms feeding automatic rollback.](architecture-diagram.svg)

The same map, read as prose module-by-module, is in
[`docs/02-module-connections.md`](docs/02-module-connections.md); each user
type's request walked step by step is in
[`docs/03-user-flow.md`](docs/03-user-flow.md).

## Component → module reference

| Diagram component | Terraform module |
| --- | --- |
| Route 53 DNS | `modules/route53-acm` |
| CloudFront CDN (frontend) | `modules/s3-cloudfront` |
| WAF Edge Security | `modules/waf` (scope `CLOUDFRONT` + scope `REGIONAL`) |
| Application Load Balancer | `modules/alb` |
| ECS Service (Containers) + Auto Scaling | `modules/ecs-service-bluegreen` |
| Backend Services / Admin Services (private subnets) | `modules/ecs-service-bluegreen` (×2 instantiations, one per service group) |
| NAT Gateway | `modules/vpc` |
| Amazon RDS Multi-AZ (Primary) | `modules/rds` |
| RDS Proxy | `modules/rds` |
| RDS Read Replica | `modules/rds` |
| ElastiCache Serverless Redis | `modules/elasticache` |
| Live streaming: RTP-push ingest, MediaLive, S3 HLS, CloudFront | `modules/live-streaming` |
| CloudWatch metrics/logs/alarms | `modules/monitoring` |
| ALB access logs → S3 | `modules/monitoring` (bucket) + `modules/alb` (log config) |
| AWS WAF Protection | `modules/waf` |
| AWS Secrets Manager | `modules/secrets-manager` (+ `modules/rds` for DB creds) |
| Security Groups | `modules/security-groups` |
| AWS Certificate Manager | `modules/route53-acm` |
| KMS encryption | `modules/kms` |
| GitHub Actions → AWS (CI/CD auth) | `modules/iam-github-oidc` |

## Request flow

1. **DNS** — client resolves `app.<domain>` (API) and `www.<domain>` (frontend)
   against the Route 53 hosted zone created/looked up in `modules/route53-acm`.
2. **Frontend** — `www.<domain>` → CloudFront → S3 (Origin Access Control; the
   bucket has no public access of its own).
3. **API** — `app.<domain>` → CloudFront-fronted or direct-to-ALB path → **WAFv2
   (REGIONAL)** evaluates AWS managed rule groups + a per-IP rate limit → **ALB**
   in the public subnets.
4. **ALB → ECS** — the ALB's HTTPS listener forwards to the *active* (blue or
   green) target group's healthy tasks, running as Fargate tasks in private
   "Application Layer" subnets across 2 AZs. The second target group sits idle,
   ready to receive the next blue/green cutover.
5. **ECS → NAT → internet** — tasks have no public IP; ECR image pulls and any
   third-party API calls route out through the NAT Gateway in the public subnet.
6. **ECS → RDS Proxy → RDS** — application tasks connect to **RDS Proxy**, not
   the database directly, which multiplexes connections onto the Multi-AZ primary
   (writes) and the read replica (reads, via the reader endpoint) — all inside the
   private "Data Layer" subnets, security-group-scoped to the ECS tasks' SG only.
7. **ECS → ElastiCache** — session/cache reads and writes go to the ElastiCache
   Serverless Redis endpoint, same private data-layer subnets, same SG scoping.
8. **Live streaming pipeline** — a venue encoder pushes RTP to a MediaLive input
   (the diagram's "SRT Ingest" label — see `modules/live-streaming/README.md` for
   why this ships as RTP push instead); the MediaLive channel transcodes to HLS
   and writes segments to a dedicated S3 bucket; a second CloudFront distribution
   serves those HLS segments to viewers. This pipeline is intentionally decoupled
   from the request-path VPC — MediaLive talks to S3 over AWS's network, not
   through the app VPC.
9. **Observability** — Container Insights + ALB target-group health + RDS
   CPU/storage/replica-lag alarms all publish to one CloudWatch → SNS topic per
   environment. CodeDeploy deployment failure also triggers automatic rollback
   via the same alarm.

## Blue/green deployment mechanics

`modules/ecs-service-bluegreen` provisions:

- **Two ALB target groups** (`blue`, `green`) — Terraform creates both; CodeDeploy
  owns which one is "production" and which is "staging" at any given moment via
  the ALB listener's forward action, which CodeDeploy rewrites during a
  deployment.
- **One ECS service** with `deployment_controller.type = "CODE_DEPLOY"` — Terraform
  sets the *initial* task set on the blue target group; every subsequent
  deployment is driven by CodeDeploy (via CI/CD calling `create-deployment`), not
  by re-running `terraform apply` with a new `image` value. Changing the pinned
  image in Terraform would just define what the *next* CodeDeploy deployment
  starts from — actual traffic cutover always goes through CodeDeploy so rollback
  works.
- **One CodeDeploy application + deployment group** (`aws_codedeploy_app`,
  `aws_codedeploy_deployment_group`, `compute_platform = "ECS"`), with a
  deployment config that varies by environment:
  - `dev` / `qa`: `CodeDeployDefault.ECSAllAtOnce` — fast feedback, no bake time.
  - `staging` / `prod`: `CodeDeployDefault.ECSLinear10PercentEvery1Minutes` (prod
    additionally requires manual approval upstream in the CI/CD pipeline, and
    auto-rollback is enabled on `DEPLOYMENT_FAILURE` and the CloudWatch alarm
    from `modules/monitoring`).
- **Automatic rollback** — `auto_rollback_configuration` triggers on deployment
  failure and on the target group's 5xx/unhealthy-host alarm, so a bad green
  deployment reverts the listener back to blue without human intervention.

## Account topology (recommended)

Each of `dev`, `qa`, `staging`, `prod` should be its own AWS account under AWS
Organizations, with its own Terraform state (already true here — see
`environments/*/backend.hcl`) and its own `modules/iam-github-oidc` role, so a
compromised CI credential or misconfigured pipeline step in one environment has
no path into another. Running all four out of one account is possible (just
point every `backend.hcl` at the same bucket with different keys, and give every
environment's resources a `-<env>` suffix, which every module in this repo
already does) but loses that blast-radius isolation — treat it as a
learning/demo shortcut, not the target state.
