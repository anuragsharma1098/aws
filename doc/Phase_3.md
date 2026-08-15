
# Phase 3 Notes: AWS + Terraform Integration Projects (Weeks 11–16)

Phase 3 is different from Phases 1 and 2 — it's not concept-first, it's project-first. You already know the individual pieces (EC2, VPC, S3, Terraform basics); now you're combining them into three real, portfolio-worthy builds. Each project introduces a few new concepts along the way, explained where they come up.

**Reminder from the roadmap:** every project here goes on GitHub with a proper README. Treat that as part of the deliverable, not an afterthought — instructions for writing one are at the end of these notes.

---

## Project 1 (Weeks 11–12): VPC From Scratch

**What you're building:** a VPC spanning two AZs, with public and private subnets, a NAT Gateway so private resources can reach the internet outbound, and a bastion host pattern so you can SSH into a private instance without exposing it directly.

### New concepts

**NAT Gateway vs. Internet Gateway** — you already know the IGW gives public subnets two-way internet access. A **NAT Gateway** sits in a *public* subnet and gives *private* subnet resources **outbound-only** internet access (e.g., to download OS updates) without letting anything from the internet initiate a connection inbound. This is the standard pattern for "my database server needs to fetch patches but should never be directly reachable from outside."

A NAT Gateway needs its own Elastic IP and, importantly, **costs money per hour it exists plus per GB processed** — this is the single most common "why is my AWS bill higher than expected" surprise for people learning VPCs. Destroy it when you're done experimenting.

**Bastion host (aka jump box)** — a small EC2 instance in a *public* subnet whose only job is to be an SSH entry point into your private subnet. You SSH into the bastion first, then from the bastion, SSH into the private instance. This means your actual application/database servers never need a public IP or an open SSH port to the internet at all.

```
Internet
   │
   ▼
Bastion Host (public subnet) ──SSH──▶ Private Instance (private subnet)
```

**Route tables, per subnet:**

- Public subnet's route table: local VPC traffic → local; everything else (`0.0.0.0/0`) → Internet Gateway
- Private subnet's route table: local VPC traffic → local; everything else → NAT Gateway

### Suggested file structure

```
project-1-vpc/
├── main.tf
├── variables.tf
├── outputs.tf
└── terraform.tfvars
```

### Full walkthrough — `main.tf`

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "project1-vpc" }
}

# --- Subnets ---
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-${count.index + 1}" }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 101}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = { Name = "private-subnet-${count.index + 1}" }
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "project1-igw" }
}

# --- NAT Gateway (needs an Elastic IP, lives in a public subnet) ---
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags = { Name = "project1-nat" }
}

# --- Route Tables ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "private-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# --- Security Groups ---
resource "aws_security_group" "bastion" {
  name   = "bastion-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "private_instance" {
  name   = "private-instance-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id] # only the bastion can reach it
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Instances ---
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public[0].id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.bastion.id]
  tags = { Name = "bastion-host" }
}

resource "aws_instance" "private" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private[0].id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.private_instance.id]
  tags = { Name = "private-instance" }
}
```

Notice `count` used for the subnets — this is how you provision multiple similar resources without copy-pasting a block four times. `count.index` gives you `0, 1, 2...` inside the loop.

### `variables.tf`

```hcl
variable "aws_region" {
  default = "us-east-1"
}
variable "key_name" {
  type = string
}
variable "my_ip" {
  description = "Your IP in CIDR notation"
  type        = string
}
```

### `outputs.tf`

```hcl
output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}
output "private_instance_ip" {
  value = aws_instance.private.private_ip
}
```

### Connecting through the bastion

```bash
# Copy your key to the bastion (or use SSH agent forwarding, cleaner long-term)
scp -i your-key.pem your-key.pem ec2-user@<bastion_public_ip>:~/

ssh -i your-key.pem ec2-user@<bastion_public_ip>
# from inside the bastion:
ssh -i your-key.pem ec2-user@<private_instance_ip>
```

**Better practice than copying your key to the bastion:** use `ssh -A` (agent forwarding) from your local machine so your private key never actually sits on the bastion. Worth looking up once this basic version works.

**Checkpoint:** you can SSH into the bastion, then SSH from the bastion into the private instance, and the private instance has no public IP or direct internet-facing security group rule at all. Run `terraform destroy` when done — the NAT Gateway is the one thing here you don't want idling.

---

## Project 2 (Weeks 13–14): Static Website Pipeline

**What you're building:** an S3 bucket serving a static site, fronted by CloudFront (a CDN) for speed and HTTPS, with an optional custom domain via Route53.

### New concepts

**CloudFront** — AWS's CDN. Instead of every visitor hitting your S3 bucket directly, CloudFront caches your content at edge locations worldwide (the ones from Phase 1, Week 1) so visitors get it from a location near them. It also gives you free HTTPS via a CloudFront domain, or a custom domain's cert via ACM.

**Origin Access Control (OAC)** — the modern way to let CloudFront read from a *private* S3 bucket while blocking direct public access to the bucket itself. This is a meaningfully better pattern than making the bucket public: visitors can only reach your content through CloudFront, not by guessing the S3 URL directly.

**Route53** — AWS's DNS service. A **hosted zone** is a container for DNS records for a domain you own. An **alias record** is Route53's special record type that lets you point a domain (like `www.yoursite.com`) directly at an AWS resource like a CloudFront distribution, without needing a separate IP address.

**ACM (AWS Certificate Manager)** — issues free TLS certificates for your domain, used to enable HTTPS on CloudFront with a custom domain. Only needed if you own a domain — skip this and use the CloudFront-provided domain if you don't.

### Two versions of this project

- **If you don't own a domain:** S3 + CloudFront with OAC, using the `*.cloudfront.net` domain CloudFront gives you for free. Fully sufficient for a portfolio piece.
- **If you own a domain:** add Route53 + ACM for a custom domain with HTTPS.

### Suggested file structure

```
project-2-static-site/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
└── site/
    └── index.html
```

### Full walkthrough (no custom domain version) — `main.tf`

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- S3 bucket (private — CloudFront reaches it via OAC) ---
resource "aws_s3_bucket" "site" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.site.id
  key          = "index.html"
  source       = "site/index.html"
  content_type = "text/html"
  etag         = filemd5("site/index.html")
}

# --- CloudFront Origin Access Control ---
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "site-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# --- CloudFront distribution ---
resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-site-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    allowed_methods       = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-site-origin"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# --- Bucket policy allowing only this CloudFront distribution to read ---
resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.site.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.site.arn
        }
      }
    }]
  })
}
```

### `variables.tf`

```hcl
variable "aws_region" {
  default = "us-east-1"
}
variable "bucket_name" {
  description = "Must be globally unique"
  type        = string
}
```

### `outputs.tf`

```hcl
output "cloudfront_domain" {
  value = aws_cloudfront_distribution.site.domain_name
}
```

After `terraform apply`, visit the `cloudfront_domain` output in a browser (CloudFront distributions take a few minutes to fully deploy the first time — this is normal).

**Checkpoint:** your site loads over HTTPS from the CloudFront URL, and if you try to access the S3 bucket URL directly, it's denied. Note CloudFront distributions are one of the few resources with a slow `destroy` (10-15 minutes) — don't panic if `terraform destroy` seems to hang here.

---

## Project 3 (Weeks 15–16): Two-Tier App — ALB + Auto Scaling + RDS

**What you're building:** the architecture diagram from the end of your Phase 1 notes, actually built: an Application Load Balancer, an Auto Scaling Group of EC2 instances behind it, and an RDS database behind that — with security groups chained so only the right tier can talk to the next.

### New concepts

**Security group chaining** — instead of opening a port to an IP range, you reference *another security group* as the source. E.g., the RDS security group allows inbound traffic on port 3306/5432 *only from the EC2 security group*, not from any IP at all. This is the pattern real production setups use.

**Launch template** — the blueprint an Auto Scaling Group uses when it creates a new instance (AMI, instance type, security group, user data script). You learned the concept in Phase 1, Week 4 — now you're writing it in Terraform.

**Target group + listener** — the ALB's **listener** defines what port/protocol it accepts traffic on (e.g., port 80). It forwards matching traffic to a **target group**, which is the set of instances (managed automatically by the ASG) plus a health check definition.

**Environment separation with `.tfvars`** — rather than hardcoding "dev" vs "prod" values, you keep separate variable files (`dev.tfvars`, `prod.tfvars`) and select one at apply time:

```bash
terraform apply -var-file="dev.tfvars"
```

(Terraform *workspaces* are another way to do this — worth knowing they exist, but separate `.tfvars` files are simpler to reason about as a beginner and are what most teams actually use for this kind of separation.)

### Suggested file structure

```
project-3-two-tier-app/
├── main.tf
├── variables.tf
├── outputs.tf
├── dev.tfvars
└── prod.tfvars
```

### Full walkthrough — `main.tf`

*(Assumes you have a VPC with public and private subnets — reuse the pattern from Project 1, or reference an existing VPC via data sources. Shown here inline for clarity.)*

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "${var.environment}-vpc" }
}

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 101}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Security Groups, chained tier to tier ---
resource "aws_security_group" "alb" {
  name   = "${var.environment}-alb-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app" {
  name   = "${var.environment}-app-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id] # only the ALB can reach app instances
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  name   = "${var.environment}-db-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id] # only app instances can reach the DB
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Launch Template ---
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.environment}-app-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum install -y httpd
    systemctl start httpd
    echo "Hello from ${var.environment}" > /var/www/html/index.html
  EOF
  )
}

# --- Auto Scaling Group ---
resource "aws_autoscaling_group" "app" {
  desired_capacity    = var.asg_desired
  min_size            = var.asg_min
  max_size            = var.asg_max
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.app.arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-app-instance"
    propagate_at_launch = true
  }
}

# --- Load Balancer ---
resource "aws_lb" "app" {
  name               = "${var.environment}-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "app" {
  name     = "${var.environment}-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# --- RDS ---
resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_db_instance" "main" {
  identifier             = "${var.environment}-db"
  engine                 = "postgres"
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  db_name                = "appdb"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  skip_final_snapshot    = true # fine for a learning project, never do this in real prod
}
```

### `variables.tf`

```hcl
variable "aws_region" {
  default = "us-east-1"
}
variable "environment" {
  type = string
}
variable "instance_type" {
  default = "t3.micro"
}
variable "asg_min" {
  default = 1
}
variable "asg_max" {
  default = 3
}
variable "asg_desired" {
  default = 2
}
variable "db_instance_class" {
  default = "db.t3.micro"
}
variable "db_username" {
  type = string
}
variable "db_password" {
  type      = string
  sensitive = true
}
```

### `dev.tfvars`

```hcl
environment  = "dev"
asg_min      = 1
asg_max      = 2
asg_desired  = 1
db_username  = "appuser"
db_password  = "changeme-use-a-real-secret-manager-later"
```

**Note on `db_password` here:** hardcoding a password in a `.tfvars` file is acceptable for this learning project, but flag it in your README as a known simplification — real projects use AWS Secrets Manager or SSM Parameter Store instead, and you should NOT commit `.tfvars` files containing real secrets to a public GitHub repo. Add `*.tfvars` to `.gitignore` for this project, and provide an example file instead (`terraform.tfvars.example`) showing the expected format without real values.

### Running it per environment

```bash
terraform init
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

### `outputs.tf`

```hcl
output "alb_dns_name" {
  value = aws_lb.app.dns_name
}
```

Visit the `alb_dns_name` output in a browser — traffic flows through the ALB, to whichever ASG instance responds, and the app is ready to talk to the RDS database on the private subnet (even though this particular demo app doesn't query it yet — that's a natural extension if you want to push the project further).

**Checkpoint:** you can hit the ALB's DNS name and get a response, `terraform state list` shows the ASG, target group, RDS instance, and all three security groups, and refreshing the ALB URL several times occasionally shows the request landing on different instances (open the "Monitoring" tab or check EC2 instance IDs served via a small tweak to the `user_data` script if you want to visibly confirm load balancing).

---

## Writing the README for each project

This matters as much as the code — it's often the first thing anyone (recruiter, interviewer, hiring manager) actually reads.

A good README includes:

1. **One-paragraph summary** — what does this deploy, and why
2. **Architecture** — even a simple diagram (draw.io, Excalidraw, or plain text like the bastion diagram earlier in these notes) showing how the pieces connect
3. **What you'd need to run it** — AWS account, Terraform version, any variables the reader needs to supply
4. **What it deploys** — a short list of the actual AWS resources
5. **Known simplifications** — e.g., "database password is in tfvars for simplicity — a real deployment would use Secrets Manager." This signals you understand the gap between "learning project" and "production," which is exactly what interviewers want to hear.

---

## Glossary — quick reference

| Term                        | One-line definition                                               |
| --------------------------- | ----------------------------------------------------------------- |
| NAT Gateway                 | Gives private subnets outbound-only internet access               |
| Bastion host                | A public-subnet jump box used to reach private instances via SSH  |
| CloudFront                  | AWS's CDN — caches content at edge locations, adds HTTPS         |
| OAC                         | Lets CloudFront read a private S3 bucket without making it public |
| Route53                     | AWS's DNS service                                                 |
| ACM                         | Issues free TLS certificates for custom domains                   |
| Security group chaining     | Referencing another SG as a traffic source instead of an IP range |
| Launch template             | The blueprint an ASG uses to create new instances                 |
| Target group                | The set of instances an ALB sends traffic to, plus health checks  |
| Listener                    | Defines what port/protocol an ALB accepts traffic on              |
| `.tfvars` per environment | A simple pattern for separating dev/prod config values            |

### Self-check before moving to Phase 4

You should be able to, without looking anything up:

- [ ] Explain why a NAT Gateway is needed even though private instances already have a route table
- [ ] Explain the bastion host pattern and why it's more secure than giving every instance a public IP
- [ ] Explain what OAC does and why a public S3 bucket is the weaker alternative
- [ ] Draw (even roughly) the ALB → ASG → RDS architecture and explain what each security group allows
- [ ] Explain why you'd use separate `.tfvars` files instead of hardcoding "dev" values into `main.tf`
- [ ] Have all three projects live on GitHub, each with a README following the structure above

If Project 3's security group chaining is still fuzzy, that's worth resolving now — Phase 4 adds CI/CD on top of this same architecture, and a shaky mental model of how the tiers connect makes debugging pipeline issues much harder later.
