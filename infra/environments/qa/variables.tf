variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name, used to derive resource names"
  type        = string
  default     = "myapp"
}

variable "environment" {
  description = "Environment name: dev, qa, or prd"
  type        = string
}

variable "state_bucket" {
  description = "Name of this account's Terraform state bucket (from infra/bootstrap), used to read this account's infra/global outputs"
  type        = string
}

variable "terraform_deploy_role_arn" {
  description = "IAM role ARN to assume in this environment's AWS account before applying, if using cross-account role assumption (multi-account setups) instead of a pre-scoped credential/profile. Null uses whatever credentials are already active."
  type        = string
  default     = null
}

# --- Networking ---

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use a single shared NAT Gateway instead of one per AZ"
  type        = bool
  default     = true
}

variable "alb_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the ALB the Load Balancer Controller creates, on 443. Passed to the Helm chart's Ingress via a security-group annotation, not consumed by Terraform directly."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# --- DNS / TLS (optional - off until a real domain exists) ---

variable "enable_dns" {
  description = "Create a Route 53 hosted zone + ACM certificate for this environment"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Domain name for this environment, e.g. dev.myapp.com. Required if enable_dns = true."
  type        = string
  default     = ""
}

variable "api_subdomain" {
  description = "Subdomain the backend API is served on, e.g. \"api\" -> api.<domain_name>. Only used when enable_dns = true."
  type        = string
  default     = "api"
}

variable "frontend_subdomain" {
  description = "Subdomain the frontend is served on, e.g. \"www\" -> www.<domain_name>. Only used when enable_dns = true."
  type        = string
  default     = "www"
}

# --- Backend (informational - the Helm chart/Harness pipeline own the actual deploy) ---

variable "container_port" {
  description = "Port the backend container listens on. Used by the vestigial app_sg rule (see modules/security-groups) and exposed as an output for the Helm chart's Service/Ingress values."
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Health check path for the Helm chart's Ingress/target group annotations. Not consumed by any Terraform resource directly."
  type        = string
  default     = "/health"
}

# --- EKS ---

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version"
  type        = string
  default     = "1.31"
}

variable "eks_endpoint_public_access" {
  description = "Allow the EKS API server to be reached from outside the VPC (kubectl/helm from a laptop, or a Harness delegate running outside AWS)"
  type        = bool
  default     = true
}

variable "eks_public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint, if enabled"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  description = "EC2 instance types for the default managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT for the default node group"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_disk_size" {
  description = "Root EBS volume size (GB) per node"
  type        = number
  default     = 20
}

variable "node_desired_size" {
  description = "Desired node count"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum node count"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum node count"
  type        = number
  default     = 4
}

# --- IRSA: AWS Load Balancer Controller ---

variable "lb_controller_namespace" {
  description = "Kubernetes namespace the AWS Load Balancer Controller runs in"
  type        = string
  default     = "kube-system"
}

variable "lb_controller_service_account" {
  description = "Service account name the AWS Load Balancer Controller's Helm chart creates - must match the chart's serviceAccount.name value"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "lb_controller_policy_json" {
  description = <<-EOT
    IAM policy JSON for the AWS Load Balancer Controller. This is NOT filled in for you -
    copy the current official policy from the aws-load-balancer-controller project's install
    docs (kubernetes-sigs/aws-load-balancer-controller on GitHub, docs/install/iam_policy.json)
    into terraform.tfvars. It's long and AWS revises it with new controller versions, so
    hand-authoring or guessing at it here would go stale and quietly under- or
    over-permission the controller.
  EOT
  type        = string
}

# --- IRSA: external-dns ---

variable "external_dns_namespace" {
  description = "Kubernetes namespace external-dns runs in"
  type        = string
  default     = "external-dns"
}

variable "external_dns_service_account" {
  description = "Service account name external-dns's Helm chart creates - must match the chart's serviceAccount.name value"
  type        = string
  default     = "external-dns"
}

# --- IRSA: External Secrets Operator ---

variable "external_secrets_namespace" {
  description = "Kubernetes namespace the External Secrets Operator runs in"
  type        = string
  default     = "external-secrets"
}

variable "external_secrets_service_account" {
  description = "Service account name External Secrets' Helm chart creates - must match the chart's serviceAccount.name value"
  type        = string
  default     = "external-secrets"
}

# --- Harness CI/CD ---

variable "harness_oidc_issuer_url" {
  description = "Harness's OIDC issuer URL for your account (from Harness's OIDC/identity provider settings) - account-specific, not guessable"
  type        = string
}

variable "harness_audience" {
  description = "Expected 'aud' claim Harness presents - confirm against Harness's OIDC docs for your account"
  type        = string
  default     = "sts.amazonaws.com"
}

variable "harness_subject_claim" {
  description = "Expected 'sub' claim, scoping which Harness account/pipeline can assume the deploy role. \"*\" trusts any token this issuer signs - narrow this before using anything but a throwaway environment."
  type        = string
  default     = "*"
}

variable "harness_eks_access_policy_arns" {
  description = "EKS access policy ARNs granted to the Harness deploy role, scoped to this environment's namespace (see main.tf). AmazonEKSEditPolicy lets it create/update/delete workloads but not touch RBAC itself."
  type        = list(string)
  default     = ["arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"]
}

variable "harness_eks_namespaces" {
  description = "Kubernetes namespaces the Harness deploy role's EKS access is scoped to"
  type        = list(string)
  default     = ["default"]
}

variable "ci_artifacts_bucket_name" {
  description = "Globally-unique S3 bucket name for Harness CI test logs/reports"
  type        = string
}

variable "harness_ecr_pull_repository_arns" {
  description = "The PREVIOUS environment's ECR repository ARNs (from that account's `infra/global` outputs) - pull-only, so this environment's Harness role can copy an already-validated image in by digest during promotion. Empty for dev (nothing precedes it in the chain); qa sets this to dev's repo ARNs, prd sets this to qa's."
  type        = list(string)
  default     = []
}

# --- CloudTrail (per-account: every account needs its own audit trail) ---

variable "cloudtrail_log_bucket_suffix" {
  description = "Suffix to make the CloudTrail log bucket name globally unique, e.g. this account's AWS account ID"
  type        = string
}

# --- Database (RDS Postgres) ---

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "appdb"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Storage autoscaling ceiling in GB"
  type        = number
  default     = 50
}

variable "db_multi_az" {
  description = "Enable Multi-AZ standby"
  type        = bool
  default     = false
}

variable "db_backup_retention_period" {
  description = "Automated backup retention in days"
  type        = number
  default     = 3
}

variable "db_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot on destroy"
  type        = bool
  default     = true
}

# --- Storage ---

variable "frontend_bucket_name" {
  description = "Globally-unique S3 bucket name for built frontend assets"
  type        = string
}

variable "uploads_bucket_name" {
  description = "Globally-unique S3 bucket name for user uploads"
  type        = string
}

variable "uploads_cors_origins" {
  description = "Origins allowed to upload directly to the uploads bucket"
  type        = list(string)
  default     = []
}

# --- Security & monitoring ---

variable "enable_waf" {
  description = "Create a WAF Web ACL. Association with the ALB happens via the Helm chart's Ingress annotation (alb.ingress.kubernetes.io/wafv2-acl-arn), not Terraform."
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "Max requests per 5-minute window from a single IP"
  type        = number
  default     = 2000
}

variable "alarm_email" {
  description = "Email to notify on CloudWatch alarms. Null skips the subscription."
  type        = string
  default     = null
}
