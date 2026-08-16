
# Phase 5 Notes: Certification + Polish (Weeks 21–26)

**Important update before you start:** the original roadmap referenced "Terraform Associate" generically. As of these notes, the exam has moved to a new version — **004**, testing Terraform 1.12 — which replaced the older 003 version. If you're studying for this exam now, make sure any course or practice questions you use are labeled 004, not 003; several of the newer objectives (custom conditions, ephemeral values) didn't exist on the old version. Always double check the current version and objectives on HashiCorp's own certification page before you sit the exam, since these details can shift again.

**Format, as of this writing:** ~60 minutes, delivered online with a live proctor, closed-book, multiple-choice/true-false/multi-select, roughly $70 (plus tax), pass/fail shown immediately with a detailed objective-level report following shortly after. No published passing score or exact question count. Valid for two years once earned.

---

## Week 21: Core Workflow, Configuration Language, and Data Handling

This is a review-and-deepen week — you know this material from Phase 2, but the exam expects sharper precision than "I can write a working config."

### Core workflow, revisited with exam-level detail

You know `init` / `plan` / `apply` / `destroy`. A few details worth nailing down precisely:

- **`terraform fmt`** — rewrites files into canonical formatting. `terraform fmt -check` (used in your Phase 4 CI pipeline) exits non-zero if formatting is off, without changing files — useful for CI, since you want the pipeline to *fail* on bad formatting, not silently fix it.
- **`terraform validate`** — checks syntax and internal consistency, but does **not** check against real cloud state or credentials. You can run `validate` with no AWS credentials configured at all.
- **`-refresh-only` planning** — `terraform plan -refresh-only` shows you drift (differences between real infrastructure and state) *without* proposing any config changes. Useful for auditing before deciding whether to accept drift into state or fix it in code.
- **`-target`** — lets you `apply` against a single resource instead of the whole config. The exam wants you to know this exists **and** that it's considered risky for routine use, because it can leave your state and config out of sync with each other if used casually instead of as a deliberate, occasional escape hatch.
- **Verbose logging** — set `TF_LOG=DEBUG` (or `TRACE`, `INFO`, `WARN`, `ERROR`) as an environment variable for troubleshooting provider or plugin issues.

### Resources vs. data sources vs. arguments vs. attributes

You know the resource/data distinction from Phase 2. Two more precise terms the exam likes:

- **Argument** — a value *you* set in a block (e.g., `instance_type = "t3.micro"`)
- **Attribute** — a value *exposed by* a resource after creation, which you can reference elsewhere (e.g., `aws_instance.web.id`). Some attributes are also arguments (you can set `instance_type`, and also read it back); others are purely computed, like `id` or `arn`, which you never set directly.

### Complex types and variable validation

You've used `string`, `number`, `bool`. The exam expects comfort with:

```hcl
variable "allowed_ports" {
  type = list(number)
}

variable "tags" {
  type = map(string)
}

variable "instance_config" {
  type = object({
    instance_type = string
    ami_id        = string
  })
}
```

**Variable validation** — a block that rejects bad input before `plan` even runs:

```hcl
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}
```

This is genuinely useful beyond the exam — it turns "someone typos an environment name and gets a confusing downstream error" into a clear, immediate failure.

### Sensitive outputs

```hcl
output "db_password" {
  value     = aws_db_instance.main.password
  sensitive = true
}
```

Marking an output `sensitive` hides its value from CLI output (`plan`/`apply` logs show `(sensitive value)` instead) — but it's still stored in the state file in plain form. This distinction — hidden from *logs* vs. hidden from *state* — is exactly the gap that ephemeral values and write-only arguments (Week 22) solve.

### Checkpoint

Add validation rules to at least three variables across your existing projects, and mark at least one output `sensitive`. Run `terraform plan -refresh-only` against one of your Phase 3 projects to see what drift detection output actually looks like, even if nothing has drifted.

---

## Week 22: Safe Lifecycle Changes and Custom Conditions

This week covers the newest and most exam-specific material — these are the objectives added in the 004 version, so don't assume older study guides cover them well.

### `depends_on` vs. inferred dependencies

Terraform normally figures out resource ordering automatically, just from the references between blocks (if `aws_instance.web` references `aws_security_group.web_sg.id`, Terraform knows to create the security group first). You only need explicit `depends_on` when there's an ordering requirement that *isn't* visible through any reference — e.g., an IAM policy that must exist before a Lambda function runs, even though the Lambda config doesn't directly reference the policy resource.

```hcl
resource "aws_lambda_function" "example" {
  # ...
  depends_on = [aws_iam_role_policy.lambda_logging]
}
```

Use it sparingly — reach for `depends_on` only when Terraform genuinely can't infer the order any other way, not as a default habit.

### `lifecycle { create_before_destroy = true }`

By default, when a change forces replacement (like the `-/+` symbol you learned in Phase 2), Terraform destroys the old resource, *then* creates the new one — meaning a gap where the resource doesn't exist at all.

```hcl
resource "aws_launch_template" "app" {
  name_prefix = "app-"
  # ...
  lifecycle {
    create_before_destroy = true
  }
}
```

This flips the order: create the replacement first, then destroy the old one, once the new one exists. Critical for anything where a downtime gap is unacceptable — think of your Project 3 launch template or a load balancer's supporting resources.

### Custom conditions: preconditions and postconditions

New syntax that lets you assert expectations directly in your config, and fail loudly (at plan or apply time) if they're violated — rather than discovering a bad assumption later as a confusing runtime error.

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  lifecycle {
    precondition {
      condition     = data.aws_ami.amazon_linux.architecture == "x86_64"
      error_message = "The selected AMI must be x86_64."
    }
    postcondition {
      condition     = self.public_ip != ""
      error_message = "Instance did not receive a public IP as expected."
    }
  }
}
```

**Precondition** — checked before the resource is created/modified (e.g., validating something about a data source's result). **Postcondition** — checked after, against the resource's own resulting attributes (`self` refers to the resource itself).

### Ephemeral values and write-only arguments

This directly solves the gap flagged in Week 21: a `sensitive` output still ends up in the state file. Write-only arguments and ephemeral values are designed to **never be persisted to state at all**.

```hcl
resource "example_resource" "api" {
  api_key = var.api_key # write-only argument — accepted as input, never stored in state
}

variable "api_key" {
  type      = string
  ephemeral = true
}
```

The exact syntax varies by provider (not every resource supports write-only arguments yet — it depends on the provider implementing support), but the concept is what matters for the exam: this is the mechanism for handling genuinely sensitive input (API keys, short-lived tokens) with minimum exposure, going further than just marking something `sensitive`.

### Checkpoint

Add `create_before_destroy` to one resource in one of your Phase 3 projects where a replacement gap would actually matter (the launch template is a good candidate), and add one precondition or postcondition somewhere reasonable. You don't need a real ephemeral-value use case to understand the concept — just be able to explain clearly, out loud, what problem it solves and why `sensitive = true` alone doesn't solve it.

---

## Week 23: State, Backends, Drift, and Modules — Exam Depth

You built real remote state and modules in Phases 2–4. This week is about the specific vocabulary and edge cases the exam tests.

### `moved` and `removed` blocks

When you refactor Terraform code — renaming a resource, or moving it into a module — without these blocks, Terraform sees "old name gone, new name appeared" and plans to **destroy the old resource and create a new one**, even though nothing about the actual infrastructure needs to change.

```hcl
moved {
  from = aws_instance.web
  to   = aws_instance.app_server
}
```

This tells Terraform "this is the same resource under a new name," so it updates the state mapping instead of destroying/recreating. The `removed` block is the equivalent for cleanly dropping a resource from management without an accidental destroy:

```hcl
removed {
  from = aws_instance.old_bastion

  lifecycle {
    destroy = false # remove from Terraform's management, but leave the real resource alone
  }
}
```

### Import, in the modern syntax

You know `terraform import <resource_address> <id>` from Phase 2 as a CLI command. Newer Terraform also supports declaring imports directly in config:

```hcl
import {
  to = aws_instance.web
  id = "i-0123456789abcdef0"
}
```

Advantage over the CLI command: this is reviewable in a pull request like any other config change, rather than being a one-off command someone ran locally and didn't document.

### Drift, precisely defined

**Drift** = the real infrastructure no longer matches what's recorded in state (usually because of a manual change outside Terraform). Note the distinction from a **plan showing changes** — a plan showing changes because *you edited the config* is expected and intentional; drift specifically means the mismatch came from something *outside* your Terraform workflow.

### Modules — authoring and versioning, precisely

You've written modules since Phase 2. The exam wants clean articulation of:

- **Root module** — where you run `terraform apply`
- **Child module** — called via a `module` block
- **Module sources** — local path (`./modules/x`), Terraform Registry (`hashicorp/vpc/aws`), a Git repository, or an HTTP URL
- **Version constraints** on registry/Git-sourced modules (`version = "~> 5.0"`) — same pinning discipline as providers, and for the same reason: an unpinned module can introduce breaking changes silently
- Modules **cannot** access variables from their caller except through explicit input variables passed in — there's no implicit access to the root module's state or variables, which is exactly what makes a module portable and reusable in the first place

### Checkpoint

Rename one resource in an existing project and use a `moved` block to preserve its state, instead of letting Terraform destroy/recreate it — run `plan` before and after adding the `moved` block and compare the difference in output. That side-by-side comparison is worth more than reading about it.

---

## Week 24: HCP Terraform, Governance, and Exam Practice

The last new-content week — this is the collaboration/governance layer, worth understanding conceptually even if you don't have a paid HCP Terraform account to click through yourself.

### Workspaces and projects (HCP Terraform, not CLI workspaces)

**Important distinction:** this is a *different* concept from the `terraform workspace` CLI command you learned in Phase 4 — same word, different layer. In HCP Terraform (formerly Terraform Cloud), a **workspace** is a full unit of Terraform state, variables, and run history for one configuration/environment — closer in spirit to "a whole project" than to the lightweight CLI workspaces from Phase 4. A **project** is a grouping of workspaces, used to organize environments/teams at scale and to apply governance at a broader scope than a single workspace.

### Collaboration modes

- **VCS-driven runs** — HCP Terraform watches a connected GitHub/GitLab repo and triggers plans automatically on PRs, applies on merge — a hosted, more full-featured version of what you hand-built with GitHub Actions in Phase 4.
- **CLI-driven runs** — you trigger runs from your local `terraform` CLI, but state and execution happen in HCP Terraform.
- **API-driven runs** — for custom integrations.
- **Variable sets** — shared variables (e.g., common tags, a shared API endpoint) reusable across multiple workspaces, instead of redefining them per workspace.
- **Run tasks** — hooks into external tools (e.g., a security scanner) that can pass/fail a run before it's allowed to proceed.

### Governance basics

- **Policy sets** (Sentinel, or OPA via third-party integration) — policy-as-code, enforced automatically before a run is allowed to apply. E.g., "no security group may allow inbound 0.0.0.0/0 on port 22" enforced organization-wide, not just as a habit individual engineers remember.
- **Workspace health / drift signals** — HCP Terraform can periodically check for drift automatically and surface it, rather than you needing to remember to run `-refresh-only` yourself.

### Exam practice

- Do the official 004 sample questions from HashiCorp's own certification learning path — these are the most reliable indicator of actual question style and difficulty.
- Keep a short log of anything you got wrong or were unsure about, and go back to that specific objective rather than re-studying everything evenly.

### Checkpoint

You can explain, without notes: the difference between an HCP Terraform workspace and a CLI workspace (same word, different concept — this trips people up on the exam specifically), what a policy set enforces and when, and what a variable set solves that per-workspace variables don't.

---

## Week 25: Exam Day

### Before

- Run the proctoring platform's system/network check on the exact device and network you'll test on, a day or two ahead — not the same day.
- Confirm your certification portal profile name matches your government ID exactly.
- Clear your desk and test space — expect a room scan as part of check-in.

### Logistics to know going in

- Roughly 60 minutes, online-proctored, closed-book — no notes, no second monitor, no extra devices on the desk.
- You'll get an immediate pass/fail; a detailed, objective-level breakdown typically follows within a day or two, which is useful for knowing exactly what to review if you don't pass the first time.
- If you don't pass, there's a mandatory waiting period before retaking, and a cap on attempts within a 12-month window — check current numbers when you register, since retake policies are exactly the kind of detail that gets revised.

### During

- Read each question fully before answering — multi-select questions in particular can be worded so that skimming costs you a wrong answer.
- If a question is genuinely unclear, answer with your best guess and keep moving — there's no benefit to burning disproportionate time on one question when the exam is timed as a whole.

### After

Regardless of outcome: add the credential (or your close attempt) to your study log for Week 26 — if you passed, the digital badge goes on LinkedIn and GitHub; if not, you already have the objective-level report telling you exactly where to focus for a retake, so it's a short detour, not a restart.

---

## Week 26: Portfolio Polish

This is the roadmap's original Week 26 goal — go back through everything you've built across Phases 3 and 4 and make it interview-ready, now informed by everything Weeks 21–24 taught you about how Terraform is *supposed* to be used.

### A polish checklist for each project

- [ ] Does the README follow the structure from Phase 3's notes (summary, architecture, requirements, what it deploys, known simplifications)?
- [ ] Is there an actual architecture diagram, even a simple one (draw.io or Excalidraw, both free)?
- [ ] Are variables validated where it makes sense (Week 21)?
- [ ] Does anything that forces resource replacement unnecessarily risk downtime — would `create_before_destroy` help anywhere (Week 22)?
- [ ] Is state remote, with locking (Phase 4, Week 20) — and is that clearly stated in the README?
- [ ] Does `.gitignore` correctly exclude state/secrets while `.terraform.lock.hcl` is committed (Phase 4, Week 17)?
- [ ] Is there a working CI check on PRs (Phase 4, Week 19)?
- [ ] Does the "known simplifications" section honestly call out anything you'd do differently in real production (e.g., the hardcoded dev DB password from Phase 3)?

### Updating your resume and LinkedIn

- Each project becomes a resume bullet describing the *problem and outcome*, not just the tool list: "Built a highly-available two-tier AWS architecture with Terraform, including auto-scaling, load balancing, and a remote state backend with CI-driven plan checks" reads very differently from "used Terraform and AWS."
- Post the certification badge and a short writeup of one project on LinkedIn — this is free, and specifically the kind of visibility a lot of learners skip.

You're now at the end of the technical build-up — Phase 6 is entirely about turning this portfolio and credential into an actual job.
