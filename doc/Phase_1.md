
# Phase 1 Notes: AWS Fundamentals (Weeks 1–5)

These notes cover everything in Phase 1 of your roadmap. Read a section, then actually do the hands-on bit before moving to the next — reading about EC2 and launching an EC2 instance teach you very different things.

---

## Week 1: Cloud Computing Basics & AWS Global Infrastructure

### What is cloud computing, really?

Before cloud computing, if you wanted to run a website or application, you bought physical servers, put them in a data center, and managed everything yourself — power, cooling, hardware failures, all of it.

Cloud computing means renting compute, storage, and networking from a provider (AWS, Azure, GCP) instead of owning it. You pay for what you use, and the provider handles the physical infrastructure.

**Three service models** (you'll see these terms everywhere):

- **IaaS (Infrastructure as a Service)** — you rent raw building blocks: virtual machines, storage, networks. You still manage the OS and everything above it. EC2 is IaaS.
- **PaaS (Platform as a Service)** — the provider manages the OS and runtime too; you just deploy code. AWS Elastic Beanstalk is PaaS.
- **SaaS (Software as a Service)** — fully finished software you just use. Gmail, Salesforce.

Terraform mostly operates at the IaaS/PaaS level — you're describing infrastructure, not writing application code.

### AWS Global Infrastructure

This is one of the most-tested fundamentals concepts, and it matters for real architecture decisions too.

- **Region** — a physical geographic area (e.g., `us-east-1` = North Virginia, `eu-west-2` = London). Each region is fully independent — resources in one region don't automatically exist in another.
- **Availability Zone (AZ)** — one or more discrete data centers within a region, each with independent power, cooling, and networking. A region typically has 3+ AZs (e.g., `us-east-1a`, `us-east-1b`, `us-east-1c`).
- **Why AZs matter:** if you put all your servers in one AZ and that data center has an outage, you're down. Spreading resources across multiple AZs is the core idea behind "high availability."
- **Edge Locations** — smaller sites used by CloudFront (AWS's CDN) to cache content closer to users. Far more numerous than regions/AZs.

**Mental model:** Region → contains → multiple AZs → each AZ contains → data center(s). Your VPC lives in one region but spans multiple AZs.

### IAM (Identity and Access Management) Basics

IAM controls *who* can do *what* in your AWS account. Get this wrong and you either lock yourself out or leave your account wide open — so it's worth understanding properly, not just memorizing.

- **Root user** — created when you make your AWS account. Has unrestricted access to everything, including billing. **Never use this day-to-day.** Lock it down with MFA and set it aside.
- **IAM Users** — individual identities (a person, or a service) with their own credentials.
- **IAM Groups** — a way to attach permissions to multiple users at once (e.g., a "Developers" group).
- **IAM Roles** — a set of permissions that can be *assumed* temporarily, rather than tied permanently to one user. Used heavily for:
  - EC2 instances that need to talk to other AWS services (S3, DynamoDB, etc.) without hardcoding credentials
  - Cross-account access
  - Federated login (e.g., logging in via your company's SSO)
- **IAM Policies** — JSON documents that define permissions. Structure is roughly:
  ```json
  {
    "Effect": "Allow",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::my-bucket/*"
  }
  ```

  Attached to users, groups, or roles.

**Best practices (these come up constantly in interviews):**

1. Never use the root account for daily work — create an IAM user (or better, use IAM Identity Center) for yourself.
2. Enable MFA, especially on root.
3. Follow **least privilege** — grant only the permissions actually needed, nothing broader "just in case."
4. Prefer roles over long-lived access keys wherever possible (e.g., EC2 instance roles instead of storing AWS keys on the instance).

---

## Week 2: EC2 (Elastic Compute Cloud)

EC2 is AWS's virtual server product — this is what most people picture when they think "cloud computing."

### Core concepts

- **Instance** — a virtual server. You choose an OS, size, and configuration.
- **AMI (Amazon Machine Image)** — a template that defines the OS and pre-installed software an instance boots from. AWS provides official AMIs (Amazon Linux, Ubuntu, Windows Server); you can also build your own.
- **Instance types** — define the hardware profile (CPU, memory, network performance). Named like `t3.micro`, `m5.large`. The letter indicates the family (t=burstable/general purpose, m=general purpose, c=compute-optimized, r=memory-optimized), the number is generation, and the size (micro/small/large/xlarge...) scales resources.
- **Key pairs** — SSH key pairs used to securely log into Linux instances (or decrypt the admin password on Windows). AWS stores the public key; you keep the private key (`.pem` file) — if you lose it, there's no "forgot password" recovery.

### Security Groups

A security group is a **virtual firewall** attached to an instance (or network interface). Critical things to know:

- Security groups are **stateful** — if you allow inbound traffic on a port, the response traffic is automatically allowed out, no separate outbound rule needed.
- Rules are **allow-only** — you can't write a "deny" rule in a security group (that's what Network ACLs are for, see Week 3).
- A common beginner mistake: opening port 22 (SSH) to `0.0.0.0/0` (the whole internet). Fine for a quick lab, never fine for anything real — scope it to your own IP.

### EBS (Elastic Block Store)

EBS volumes are the virtual "hard drives" attached to EC2 instances. They persist independently of the instance (you can detach and reattach them). Contrast this with **instance store**, which is physically tied to the underlying hardware and is wiped if the instance stops.

### Elastic IPs

A regular EC2 public IP changes if you stop and start the instance. An **Elastic IP** is a static public IP you can allocate and attach to an instance, so the address stays the same. Note: AWS charges you if you allocate one but *don't* attach it to a running instance — a classic "gotcha" that costs people a few dollars before they notice.

### Hands-on walkthrough (do this before moving on)

1. Launch an EC2 instance (Amazon Linux 2023, `t3.micro` — free tier eligible)
2. Create a new key pair, download the `.pem` file
3. Create a security group allowing SSH (port 22) from your IP only, and HTTP (port 80) from anywhere
4. SSH in: `ssh -i your-key.pem ec2-user@<public-ip>`
5. Install a web server and confirm you can reach it from a browser:
   ```bash
   sudo yum install -y httpd
   sudo systemctl start httpd
   echo "Hello from EC2" | sudo tee /var/www/html/index.html
   ```
6. **Terminate the instance when done** so it doesn't run up charges.

---

## Week 3: S3 and VPC Basics

### S3 (Simple Storage Service)

S3 is object storage — think of it as a massive, durable key-value store for files, not a filesystem.

- **Bucket** — a container for objects. Bucket names are globally unique across *all* AWS accounts, not just yours.
- **Object** — a file plus metadata, identified by a key (essentially its path/name within the bucket).
- **Storage classes** — trade cost against retrieval speed/frequency:
  - **S3 Standard** — frequently accessed data, higher cost
  - **S3 Standard-IA (Infrequent Access)** — cheaper storage, retrieval fee
  - **S3 Glacier / Glacier Deep Archive** — very cheap, but retrieval can take minutes to hours — built for backups/archives, not active data
- **Permissions** — this is where beginners get tripped up. Three overlapping mechanisms:
  - **Bucket policies** — JSON policy attached to the bucket itself (similar structure to IAM policies)
  - **IAM policies** — attached to users/roles, controlling what they can do to S3
  - **Block Public Access settings** — an account/bucket-level safety switch that overrides other permissions to prevent accidental public exposure. (A huge number of real-world data leaks trace back to someone disabling this without understanding why it existed.)
- **Static website hosting** — S3 can serve a bucket's contents directly as a website (useful for the Phase 3 project). Note this requires the bucket to be public, or fronted by CloudFront with Origin Access Control — a static site with sensitive info should never be a public bucket without thinking that through.

### VPC (Virtual Private Cloud) Basics

A VPC is your own private, isolated network within AWS. Everything else (EC2, RDS, etc.) lives inside one.

- **CIDR block** — the IP address range for your VPC, e.g., `10.0.0.0/16` (that `/16` gives you ~65,000 addresses). You'll carve this into smaller ranges for subnets.
- **Subnet** — a subdivision of your VPC's CIDR range, tied to a single AZ. E.g., `10.0.1.0/24` in `us-east-1a`.
  - **Public subnet** — has a route to an Internet Gateway, so resources in it can be reached from (and reach) the internet.
  - **Private subnet** — no direct internet route; used for databases, internal services.
- **Internet Gateway (IGW)** — attached to the VPC, lets public subnets communicate with the internet.
- **Route table** — determines where traffic from a subnet is allowed to go. A subnet is "public" specifically *because* its route table has a route to the IGW — nothing more magical than that.
- **NACLs (Network ACLs)** — firewall rules at the *subnet* level, unlike security groups which are at the *instance* level. Unlike security groups, NACLs are **stateless** (you need explicit inbound AND outbound rules) and *can* have explicit deny rules.

**Security Group vs NACL — a common interview question:**

|            | Security Group      | NACL                                           |
| ---------- | ------------------- | ---------------------------------------------- |
| Level      | Instance (ENI)      | Subnet                                         |
| State      | Stateful            | Stateless                                      |
| Rules      | Allow only          | Allow and Deny                                 |
| Evaluation | All rules evaluated | Rules evaluated in order (lowest number first) |

---

## Week 4: RDS, Load Balancers, and Auto Scaling

You don't need to build with these yet — that happens in Phase 3. This week is about understanding what they are and why they exist.

### RDS (Relational Database Service)

RDS is a *managed* relational database — AWS handles patching, backups, and failover, so you don't run a database server yourself. Supports MySQL, PostgreSQL, MariaDB, SQL Server, Oracle, and Aurora (AWS's own MySQL/Postgres-compatible engine).

- **Multi-AZ deployment** — RDS maintains a synchronous standby replica in a different AZ. If the primary fails, RDS automatically fails over to the standby. This is for *availability*, not performance.
- **Read replicas** — asynchronous copies used to offload read traffic (e.g., reporting queries) from the primary. This is for *scaling reads*, not automatic failover (though a read replica can be manually promoted).

### Elastic Load Balancing (ELB)

Distributes incoming traffic across multiple targets (EC2 instances, containers, IPs). Three types:

- **Application Load Balancer (ALB)** — operates at Layer 7 (HTTP/HTTPS). Can route based on URL path or hostname. This is what you'll use most often for web apps.
- **Network Load Balancer (NLB)** — operates at Layer 4 (TCP/UDP). Used for extreme performance/low latency needs.
- **Classic Load Balancer (CLB)** — the legacy option; you'll rarely choose this for new work.

A **target group** defines the set of instances/IPs the load balancer sends traffic to, plus health check settings — the load balancer stops sending traffic to any target that fails its health check.

### Auto Scaling Groups (ASG)

An ASG automatically adds or removes EC2 instances based on demand, using a **launch template** (which defines what a new instance should look like — AMI, instance type, security groups, etc.).

- **Scaling policies** — rules for when to scale, e.g., "add an instance if average CPU > 70%."
- **Min/Max/Desired capacity** — the ASG will never go below Min or above Max, and tries to keep the count at Desired.
- Combine ASG + ALB and you get a classic resilient web tier: the load balancer spreads traffic, and the ASG keeps the right number of healthy instances behind it.

---

## Week 5: Review & Consolidation

### Quick recap — how these pieces fit together

A typical simple web app architecture, using everything from this phase:

```
Internet
   │
   ▼
Internet Gateway
   │
   ▼
Application Load Balancer (public subnet, spans multiple AZs)
   │
   ▼
Auto Scaling Group of EC2 instances (public or private subnet)
   │
   ▼
RDS database (private subnet, Multi-AZ)
```

This is essentially the architecture you'll build in Phase 3, Project 3 — so if this diagram makes sense to you, you're ready to move to Terraform.

### Glossary — quick reference

| Term           | One-line definition                                           |
| -------------- | ------------------------------------------------------------- |
| Region         | A geographic area containing multiple AZs                     |
| AZ             | An isolated data center (or cluster of them) within a region  |
| IAM Role       | Temporary, assumable permissions — no long-lived credentials |
| AMI            | A template an EC2 instance boots from                         |
| Security Group | Stateful, instance-level, allow-only firewall                 |
| NACL           | Stateless, subnet-level firewall, allow + deny                |
| VPC            | Your private network in AWS                                   |
| CIDR           | The IP address range notation (e.g.,`/16`, `/24`)         |
| IGW            | Gives a VPC's public subnets internet access                  |
| S3             | Object storage (not a filesystem)                             |
| RDS            | Managed relational database                                   |
| Multi-AZ (RDS) | Synchronous standby for failover — availability              |
| Read replica   | Asynchronous copy for read scaling — performance             |
| ALB            | Layer 7 load balancer, routes HTTP/HTTPS traffic              |
| ASG            | Automatically scales EC2 instance count based on demand       |

### Self-check before moving to Phase 2

You should be able to, without looking anything up:

- [ ] Explain the difference between a region and an AZ, and why AZs matter for availability
- [ ] Explain why you shouldn't use the root account day-to-day
- [ ] Launch an EC2 instance, SSH into it, and serve a basic web page
- [ ] Explain the difference between a security group and a NACL
- [ ] Explain the difference between a public and private subnet
- [ ] Explain why Multi-AZ and read replicas solve different problems

If any of these feel shaky, spend extra time there before starting Terraform — Phase 2 assumes you understand what you're provisioning, not just the syntax to provision it.
