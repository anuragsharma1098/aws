
# AWS + Terraform Roadmap — Zero to Job-Ready

**Starting point:** Complete beginner
**Goal:** Land a cloud/DevOps job
**Pace:** 2–4 hrs/week
**Estimated timeline:** ~28 weeks (~7 months)

This is deliberately slow and steady. At this pace, consistency matters more than intensity — missing one week won't hurt you, but skipping months will. Treat each phase as a gate: don't move on until you can do the "checkpoint" task without looking anything up.

---

## Phase 1: AWS Fundamentals (Weeks 1–5)

**Goal:** Understand core AWS services and how the cloud actually works, before touching Terraform.

- Week 1: What is cloud computing, regions/AZs, IAM basics (users, roles, policies)
- Week 2: EC2 (instances, security groups, key pairs) — launch and SSH into one manually
- Week 3: S3 (buckets, permissions, static hosting) + VPC basics (subnets, route tables, internet gateway)
- Week 4: RDS basics, Load Balancers, Auto Scaling Groups (conceptual — don't need to master these yet)
- Week 5: Review + hands-on lab week

**Resources:**

- AWS Skill Builder (free) — "AWS Cloud Practitioner Essentials"
- freeCodeCamp's AWS Certified Cloud Practitioner course (YouTube, free)

**Checkpoint:** Manually launch an EC2 instance, put it in a security group that allows SSH + HTTP, and host a static "Hello World" page on it — without a tutorial open.

**Milestone cert (optional but recommended):** AWS Certified Cloud Practitioner — cheap, fast, and it forces you to actually retain the fundamentals instead of skimming them.

---

## Phase 2: Terraform Fundamentals (Weeks 6–10)

**Goal:** Understand Terraform's core workflow and HCL syntax independent of AWS complexity.

- Week 6: Terraform workflow (init/plan/apply/destroy), providers, resources, state files
- Week 7: Variables, outputs, data sources
- Week 8: Terraform state — what it is, why remote state matters, state locking
- Week 9: Modules — using a public module, then writing your own simple one
- Week 10: Review + rebuild Phase 1's EC2 lab, but entirely in Terraform this time

**Resources:**

- HashiCorp's own "Terraform - Getting Started" tutorials (developer.hashicorp.com)
- "Terraform Up & Running" by Yevgeniy Brikman (widely considered the best book on this — worth the cost if you can afford it)

**Checkpoint:** Write a Terraform config from a blank file that provisions an EC2 instance, a security group, and an S3 bucket — no copy-pasting from old tutorials.

---

## Phase 3: AWS + Terraform Integration Projects (Weeks 11–16)

**Goal:** Build real, portfolio-worthy infrastructure — this is where the two skills actually merge.

- Week 11–12: **Project 1 — VPC from scratch.** Public/private subnets, NAT gateway, route tables, an EC2 instance in the private subnet reachable only via a bastion host.
- Week 13–14: **Project 2 — Static website pipeline.** S3 + CloudFront + Route53 (if you own a domain) or just S3 static hosting, all in Terraform.
- Week 15–16: **Project 3 — Simple 2-tier app.** EC2 (or ECS if you're feeling ambitious) behind an Application Load Balancer, talking to an RDS database, all provisioned via Terraform with variables for environment (dev/prod).

**Every project goes on GitHub.** Write a proper README for each: what it does, an architecture diagram (even a rough one), and how to run it. This is what recruiters and interviewers actually look at.

**Checkpoint:** You have 3 repos on GitHub, each with working Terraform code and a README a stranger could follow.

---

## Phase 4: The Rest of the DevOps Toolchain (Weeks 17–20)

**Goal:** Terraform + AWS alone won't get you hired — employers expect the surrounding toolchain too.

- Week 17: Git/GitHub properly (branches, PRs, .gitignore for Terraform — you've been doing basics already, now go deeper)
- Week 18: Docker fundamentals (images, containers, Dockerfile) — containerize a small app
- Week 19: CI/CD basics — set up a GitHub Actions workflow that runs `terraform plan` on every PR
- Week 20: Terraform workspaces + remote state backend (S3 + DynamoDB for locking) — go back and retrofit this into your Phase 3 projects

**Checkpoint:** One of your Phase 3 projects now has remote state and a GitHub Actions pipeline that validates Terraform changes automatically.

---

## Phase 5: Certification + Polish (Weeks 21–26)

**Goal:** Get a credential that gets you past resume filters, and make your portfolio interview-ready.

- Weeks 21–24: Study for **HashiCorp Certified: Terraform Associate** — this is the most directly relevant cert for what you've built
- Week 25: Take the exam
- Week 26: Go back through all your GitHub projects — clean up code, improve READMEs, add architecture diagrams (draw.io or Excalidraw, free)

**Optional stretch:** AWS Certified Solutions Architect – Associate is the most job-recognized AWS cert, but it's a bigger lift. If you have energy left, it's worth it; if not, Terraform Associate + solid projects is a legitimate path on its own.

---

## Phase 6: Job Prep (Weeks 27–28+)

- Rewrite your resume with your 3 projects as concrete bullet points (what you built, what tools, what problem it solved — not just "learned Terraform")
- Post projects on LinkedIn with a short writeup — this is free visibility and a lot of people skip it
- Start applying to junior DevOps / Cloud Engineer / Platform Engineer roles — target "junior" or "associate" titles explicitly, not senior/mid
- Practice explaining your projects out loud — interviewers care more about *why* you made architecture decisions than the exact Terraform syntax

---

## Ground rules for the whole plan

1. **Don't skip to Terraform before basic AWS makes sense.** Terraform without understanding what it's provisioning is just memorizing HCL syntax — it won't survive an interview question.
2. **Always destroy your AWS resources when you're done for the day** (`terraform destroy`). At this pace it's easy to forget something running and get a surprise bill. Set a billing alarm in AWS Budgets in Week 1 as a safety net.
3. **Every project must go on GitHub, no exceptions.** A portfolio of 3 real projects beats a certificate with nothing to show for it.
4. **If a week's checkpoint doesn't work without looking things up, repeat the week.** Slow and solid beats fast and shaky at this pace.

Good luck — and come back anytime you get stuck on a specific step, want a deeper dive into any phase, or want a project idea beyond what's listed here.
