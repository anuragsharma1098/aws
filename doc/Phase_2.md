
# Phase 2 Notes: Terraform Fundamentals (Weeks 6–10)

Same approach as Phase 1: read a section, then actually type out and run the code — don't just read Terraform, run it. State files and the plan/apply cycle only really click once you've watched them work.

---

## Week 6: The Terraform Workflow, Providers, Resources, and State

### What is Terraform, and what problem does it solve?

In Week 2 of Phase 1, you launched an EC2 instance by clicking through the AWS Console. That works, but it's not repeatable, not version-controlled, and easy to forget the exact steps for next time.

**Infrastructure as Code (IaC)** means describing your infrastructure in files instead of clicking buttons. Terraform is a tool for this — you write HCL (HashiCorp Configuration Language) describing what you want to exist, and Terraform figures out how to make the real world match that description.

Terraform is **declarative**: you say *what* you want ("an EC2 instance of this type, with this security group"), not *how* to get there step by step. This is different from a script that runs a sequence of imperative commands.

### Providers

A **provider** is a plugin that lets Terraform talk to a specific platform's API — AWS, Azure, GCP, GitHub, Kubernetes, etc. You declare which providers you need and Terraform downloads them.

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
  region = "us-east-1"
}
```

The `~> 5.0` means "any 5.x version, but not 6.0" — this is version pinning, and it matters: an unpinned provider can silently upgrade and change behavior under you.

### Resources

A **resource** block is the core building block — it declares one piece of infrastructure you want to exist.

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0abcdef1234567890"
  instance_type = "t3.micro"
}
```

Structure: `resource "<provider_type>" "<local_name>"`. The local name (`web` here) is just how *you* refer to it within your Terraform code — it's not the actual AWS resource name/ID.

### The core workflow

Four commands you'll run constantly:

1. **`terraform init`** — downloads the providers and sets up the working directory. Run this once per project (and again if you add new providers/modules).
2. **`terraform plan`** — shows you what Terraform *would* do, without doing it. Always read this output before applying — it's your safety check.
3. **`terraform apply`** — actually creates/updates/destroys resources to match your config. Will show you the plan again and ask for confirmation (`yes`) unless you pass `-auto-approve`.
4. **`terraform destroy`** — tears down everything Terraform is managing in this config. Use this to avoid leaving billable resources running.

**Plan output symbols to know:**

- `+` — resource will be created
- `-` — resource will be destroyed
- `~` — resource will be modified in place
- `-/+` — resource will be destroyed and recreated (some changes can't be applied in place — e.g., changing an EC2 instance's AMI)

### The state file

When you run `terraform apply`, Terraform creates a file called `terraform.tfstate`. This is Terraform's record of what it created and the real-world IDs of those resources — it's how Terraform knows the difference between "this resource doesn't exist yet" and "this resource exists and matches config" and "this resource exists but has drifted from config."

**This file is critical — don't lose it, and don't hand-edit it.** More on this in Week 8.

---

## Week 7: Variables, Outputs, and Data Sources

Hardcoding values (like the AMI ID above) works for a quick test, but real configs need to be reusable and parameterized.

### Variables

```hcl
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
}
```

Ways to set a variable's value, in order of precedence (later overrides earlier):

1. Default value in the `variable` block
2. A `terraform.tfvars` file (auto-loaded)
3. A `*.auto.tfvars` file
4. `-var="instance_type=t3.small"` on the command line
5. `TF_VAR_instance_type` environment variable

**Types:** `string`, `number`, `bool`, `list(...)`, `map(...)`, `object({...})`. Terraform validates the type at plan time, which catches a lot of silly mistakes early.

### Outputs

```hcl
output "instance_public_ip" {
  description = "Public IP of the web server"
  value       = aws_instance.web.public_ip
}
```

Outputs are how you surface useful values after `apply` — e.g., printing the IP to SSH into, or passing a value from one module to another. Run `terraform output` any time to see them again without re-applying.

### Data Sources

A **data source** reads information about something that *already exists* — either outside Terraform entirely, or managed by a different Terraform config — without creating or managing it.

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
}
```

This is genuinely useful, not just an exercise — it means you never have to hardcode an AMI ID that goes stale. Common data source uses: latest AMI, existing VPC/subnet IDs, an existing IAM policy document.

**Resource vs. data source — the distinction that trips people up:** a `resource` block means "Terraform owns this, create/manage/destroy it." A `data` block means "just look this up, I don't want Terraform to touch it."

---

## Week 8: Terraform State, In Depth

This is the single most important concept to actually understand (not just memorize) in all of Terraform.

### Why state exists

Terraform needs a way to map "the `aws_instance.web` block in my config" to "the actual instance with ID `i-0123456789abcdef0` in AWS." That mapping — plus a cached copy of each resource's attributes — is what `terraform.tfstate` stores. Without it, every plan would require Terraform to somehow re-discover everything from scratch, which isn't generally possible (AWS doesn't know which resources "belong" to which Terraform config).

### Local vs. remote state

By default, state lives as a local file (`terraform.tfstate`) in your project directory. This is fine for solo learning, but breaks down fast for anything real:

- If you work from two machines, or with teammates, everyone needs the exact same state file, always in sync — a recipe for conflicts and corruption.
- The state file often contains sensitive data (e.g., a database password set as a resource attribute) — you don't want it casually sitting in a git repo.

**Remote state** solves this by storing the state file in a shared location — commonly an S3 bucket, with a DynamoDB table used for **state locking** (so two people can't run `apply` at the same time and corrupt the file).

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "project/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

You'll set this up for real in Phase 4, Week 20 — for now, just understand *why* it exists.

### Drift

**Drift** is when the real world no longer matches your Terraform state — e.g., someone manually changed a security group rule in the AWS Console. Running `terraform plan` after drift has occurred will show Terraform wanting to "fix" it back to match your config, which can be surprising if you don't know drift happened. This is exactly why teams try to avoid making manual changes to Terraform-managed infrastructure.

### Useful state commands

- `terraform state list` — see everything Terraform is currently tracking
- `terraform state show <resource>` — see the current attributes of one resource
- `terraform state mv` — rename/move a resource in state without destroying and recreating it (e.g., after refactoring your code)
- `terraform import` — bring an existing, manually-created resource under Terraform's management

### The golden rule

**Never hand-edit `terraform.tfstate`.** If it gets out of sync, use `terraform state` subcommands or `terraform import` — editing the JSON directly is how people end up with orphaned resources or a completely broken state file.

---

## Week 9: Modules

### What is a module?

Every Terraform config is technically a module — the directory you run `terraform apply` in is called the **root module**. A **child module** is a reusable, self-contained bundle of Terraform config that you call from elsewhere, the same way a function lets you reuse code instead of copy-pasting it.

### Using a public module

The [Terraform Registry](https://registry.terraform.io) hosts thousands of community and official modules. Example — using the popular `terraform-aws-modules/vpc/aws` module instead of writing VPC config from scratch:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
}
```

Always pin the `version` — modules can introduce breaking changes between versions just like providers.

### Writing your own module

A typical module's file layout:

```
modules/ec2-instance/
├── main.tf        # the resource(s)
├── variables.tf   # inputs the module accepts
└── outputs.tf     # values the module exposes to whoever calls it
```

Example `modules/ec2-instance/main.tf`:

```hcl
resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type
  tags = {
    Name = var.instance_name
  }
}
```

`modules/ec2-instance/variables.tf`:

```hcl
variable "ami_id" {
  type = string
}
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
variable "instance_name" {
  type = string
}
```

`modules/ec2-instance/outputs.tf`:

```hcl
output "instance_id" {
  value = aws_instance.this.id
}
```

Calling it from your root module:

```hcl
module "web_server" {
  source        = "./modules/ec2-instance"
  ami_id        = data.aws_ami.amazon_linux.id
  instance_name = "web-server-1"
}
```

**Why bother?** If you need three near-identical EC2 instances with slightly different names, a module means writing the resource logic once and calling it three times with different inputs — instead of copy-pasting the same `resource` block three times and having to keep them all in sync by hand.

---

## Week 10: Review — Rebuild the Phase 1 Lab in Terraform

Time to redo the EC2 lab from Phase 1 Week 2 (launch an instance, SSH in, serve a web page) — except this time entirely as code, with nothing clicked in the Console.

### Suggested file layout for this project

```
ec2-lab/
├── main.tf
├── variables.tf
├── outputs.tf
└── terraform.tfvars
```

### `main.tf`

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

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow SSH and HTTP"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

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

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    yum install -y httpd
    systemctl start httpd
    echo "Hello from Terraform-managed EC2" > /var/www/html/index.html
  EOF

  tags = {
    Name = "terraform-web-lab"
  }
}
```

Notice `user_data` — this replaces the manual SSH-in-and-install-httpd steps from Phase 1 with a boot-time script. The instance configures itself.

### `variables.tf`

```hcl
variable "aws_region" {
  default = "us-east-1"
}
variable "instance_type" {
  default = "t3.micro"
}
variable "key_name" {
  description = "Name of an existing EC2 key pair"
  type        = string
}
variable "my_ip" {
  description = "Your IP in CIDR notation, e.g. 1.2.3.4/32"
  type        = string
}
```

### `outputs.tf`

```hcl
output "instance_public_ip" {
  value = aws_instance.web.public_ip
}
```

### `terraform.tfvars`

```hcl
key_name = "your-key-pair-name"
my_ip    = "1.2.3.4/32"
```

### Running it

```bash
terraform init
terraform fmt      # auto-formats your files consistently
terraform validate # catches syntax errors before you plan
terraform plan
terraform apply
```

Once applied, `terraform output instance_public_ip` gives you the IP — open it in a browser and you should see your message, with zero manual console clicks involved.

**Don't forget:** `terraform destroy` when you're done, same as Phase 1.

---

## Glossary — quick reference

| Term                 | One-line definition                                                           |
| -------------------- | ----------------------------------------------------------------------------- |
| HCL                  | HashiCorp Configuration Language — the syntax Terraform files are written in |
| Provider             | A plugin connecting Terraform to a platform's API (AWS, Azure, etc.)          |
| Resource             | A block declaring one piece of infrastructure Terraform should manage         |
| Data source          | A block that reads existing info without managing it                          |
| State file           | Terraform's record mapping config to real-world resource IDs                  |
| Remote backend       | Shared, external location for state (e.g., S3 + DynamoDB lock)                |
| Drift                | When real infrastructure no longer matches Terraform state/config             |
| Module               | A reusable, self-contained bundle of Terraform config                         |
| Root module          | The top-level directory you run`terraform apply` from                       |
| `terraform plan`   | Preview of changes, without applying them                                     |
| `terraform apply`  | Actually creates/updates/destroys resources                                   |
| `terraform import` | Brings an existing resource under Terraform management                        |

### Self-check before moving to Phase 3

You should be able to, without looking anything up:

- [ ] Explain what the state file is for, in your own words
- [ ] Explain why remote state + locking matters for teams
- [ ] Write a `variable` block with a type and default, and reference it in a resource
- [ ] Explain the difference between a `resource` block and a `data` block
- [ ] Use a public module from the Terraform Registry, with a pinned version
- [ ] Write, from a blank file, a Terraform config that provisions an EC2 instance + security group and outputs its public IP

If the state and drift sections still feel fuzzy, spend extra time there specifically — Phase 3's projects introduce remote state and multiple resources interacting, and shaky state understanding is where most beginner Terraform frustration comes from.
