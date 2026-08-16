# Architecture

One environment's worth of `infra/environments/{dev,qa,prd}` — all three wire the same
modules together (see [`infra/README.md`](README.md)); only sizing, redundancy, and safety
settings differ per `terraform.tfvars`. Account-level pieces (ECR, CloudTrail) live once in
`infra/global` and are shared across all three.

![AWS architecture diagram: a client resolves DNS via Route 53, reaches the frontend through CloudFront and S3, and the backend API through WAF and an Application Load Balancer into ECS Fargate tasks running in private subnets across two AZs, which read RDS Postgres, Secrets Manager, and ECR through a NAT Gateway, all encrypted with a per-environment KMS key and monitored via CloudWatch, SNS, CloudTrail, and an IAM permissions boundary.](architecture-diagram.svg)

Client traffic enters through two independent public paths (CloudFront for static assets,
WAF→ALB for the API) into a VPC with public and private subnets split across two
Availability Zones; everything AWS-managed and security-relevant — KMS, Secrets Manager,
IAM boundary, CloudTrail — sits outside the VPC boundary since none of it is a network
resource.

## Request flow

1. **DNS lookup** — the client resolves `api.<domain>` / `www.<domain>` against Route 53.
   No-op today: `enable_dns` defaults to `false` in every environment, so this step (and the
   ACM certificates that depend on it) doesn't exist until a real domain is configured.
2. **Frontend (`HTTPS · frontend`)** — the client hits CloudFront directly, which serves
   static assets from the `S3 · frontend` bucket via Origin Access Control. The bucket has no
   public access of its own; CloudFront is the only reader.
3. **API (`HTTPS · api`)** — the client hits the ALB through WAF, which evaluates AWS managed
   rule groups and a per-IP rate limit before anything reaches the load balancer.
4. **ALB → ECS** — the ALB forwards to whichever ECS Fargate task is healthy, in either AZ.
   Tasks run in private subnets with no public IP; outbound internet access (image pulls,
   Secrets Manager/API calls) goes through a NAT Gateway, not a direct route.
5. **ECS → RDS** — tasks query the RDS Postgres primary over the security-group-scoped
   `:5432` path, entirely inside the VPC (no NAT hop). `prd` adds a Multi-AZ standby; dev/qa
   don't.
6. **ECS → Secrets Manager / ECR / CloudWatch Logs** — three more NAT-routed calls: reading
   DB and app credentials, pulling the container image, and writing application logs.
7. **CloudWatch → SNS** — ALB 5xx rate, ECS CPU/memory, and RDS CPU/storage alarms publish to
   an SNS topic, which emails `alarm_email` if one is set.

## Security controls (not part of the request path)

- **KMS** — one customer-managed key per environment encrypts RDS storage, both Secrets
  Manager secrets, both S3 buckets, ECR images, CloudWatch Logs, and the SNS topic. Always
  on, not a toggle.
- **IAM permissions boundary** — attached to both the ECS execution role and task role; caps
  what either role could ever do even if its own policy is later widened.
- **CloudTrail** — a single account-wide, multi-region trail (`infra/global`) records every
  API call across every service in this diagram, independent of which environment made it.

## Component → module reference

| Diagram component | Terraform module |
| --- | --- |
| VPC, subnets, IGW, NAT Gateway | `modules/vpc` |
| Security groups (ALB / app / db tiers) | `modules/security-groups` |
| Route 53 zone + ACM certs | `modules/route53-acm` (×2 per env — see the "DNS endpoints" section of [`infra/README.md`](README.md)) |
| CloudFront, ALB, WAF | `modules/s3-cloudfront`, `modules/alb`, `modules/waf` |
| ECS cluster, ECS service/tasks | `modules/ecs-cluster`, `modules/ecs-service` |
| RDS Postgres + its credentials secret | `modules/rds` |
| App secrets | `modules/secrets-manager` |
| S3 frontend / uploads buckets | `modules/s3-cloudfront`, `modules/s3-uploads` |
| KMS key | `modules/kms` |
| IAM permissions boundary | `modules/iam-boundary` |
| CloudWatch alarms + SNS | `modules/monitoring` |
| ECR, CloudTrail (account-level) | `modules/ecr`, `modules/cloudtrail` (via `infra/global`) |

Regenerating the diagram: it's a hand-authored, self-contained SVG (`architecture-diagram.svg`)
with no build step — edit the file directly, or ask for changes and hand over what should
change.
