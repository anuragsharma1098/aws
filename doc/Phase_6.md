
# Phase 6 Notes: Job Prep (Weeks 27–28+)

This phase is different in kind from everything before it — there's no new technical skill to build. The work now is translation and positioning: turning six phases of real, demonstrable work into something that gets you interviews, and then performing well once you're in the room. Budget more than two weeks if you need to — job searches rarely run on a fixed schedule, and that's normal, not a sign you did something wrong earlier.

---

## Week 27: Resume and LinkedIn

### Resume structure for an entry-level cloud/DevOps role

A resume at this stage should lead with **projects and skills**, not a thin work history that may have nothing to do with cloud engineering. Suggested order:

1. **Header** — name, email, LinkedIn, GitHub link (make sure your GitHub is genuinely presentable — pinned repos should be your Phase 3 projects, not random old coursework)
2. **Skills** — a compact line or two: `AWS (EC2, VPC, S3, RDS, IAM, CloudFront), Terraform, Docker, GitHub Actions, Git`
3. **Projects** — the centerpiece. 3–4 bullet points per project, framed as outcomes, not a tool list
4. **Work experience** — even if unrelated to tech, keep it (it shows reliability, communication, teamwork — real signals for entry-level hiring) but keep it brief
5. **Certifications** — your Terraform Associate badge (or "in progress" if you're still working toward it) goes here or right under Skills

### Turning your projects into resume bullets

The biggest mistake people make at this stage is describing what a tool *does* instead of what *they* did with it. Compare:

> Weak: "Used Terraform and AWS to build infrastructure."

> Strong: "Designed and deployed a highly-available two-tier AWS architecture using Terraform — Application Load Balancer, Auto Scaling Group, and RDS across two Availability Zones — with security groups scoped per tier and remote state managed via S3 with DynamoDB locking."

Notice the strong version names specific services, specific decisions (multi-AZ, per-tier security groups), and reads like something you'd actually be asked to explain in an interview — because you can.

**A bullet-writing template you can apply to each Phase 3 project:**

```
[Action verb] a [what it is] using [tools], including [1-2 specific technical
decisions], resulting in [outcome or capability].
```

Applied to Project 1 (VPC from scratch):

> "Built a segmented AWS VPC using Terraform with public/private subnets across two AZs, a NAT Gateway for outbound-only private access, and a bastion host pattern for secure SSH — eliminating direct internet exposure for internal instances."

Applied to Project 2 (static site pipeline):

> "Deployed a static website through S3 and CloudFront using Terraform, with Origin Access Control restricting direct bucket access — reducing attack surface versus a public S3 bucket while serving content over HTTPS from edge locations."

### ATS keywords, briefly

Many entry-level applications pass through an Applicant Tracking System before a human sees them. This doesn't mean gaming it — it means making sure the specific service names and tools from the job posting (if you actually have that experience) appear somewhere in your resume in plain text, not just as a screenshot or an image. If a posting says "Terraform, AWS, CI/CD" and you have all three, use those exact words somewhere, not just synonyms.

### LinkedIn

- **Headline:** not just "Job Seeker" — something like "Cloud/DevOps Engineer | AWS · Terraform · Docker | Building infrastructure as code" tells people what you actually do at a glance.
- **About section:** 2–3 sentences on your background and what you've built, plus a line inviting people to check your GitHub.
- **Post your projects individually**, each with a short writeup (what it does, one interesting technical decision, a link to the repo). This is free visibility, and it's also genuinely good interview prep — writing a plain-English explanation of your own project is a smaller version of what you'll do out loud in an interview.
- **Add your certification badge** as soon as you have it (or add "Studying for HashiCorp Terraform Associate" if you're still working toward it — momentum is a legitimate thing to signal).

### Checkpoint

Resume rewritten with the bullet template above applied to all three Phase 3 projects. LinkedIn headline and About section updated, and at least one project posted with a writeup.

---

## Week 27–28: Job Search Strategy

### Titles to target

At this stage, aim explicitly for entry-level titles — the exact wording varies by company, but look for:

- Junior/Associate Cloud Engineer
- Junior/Associate DevOps Engineer
- Cloud Support Engineer (a genuinely good foot-in-the-door role — AWS itself hires heavily for this)
- Platform Engineer I / SRE I (less common at true entry level, but worth checking)

**Titles to be cautious about applying to right now:** anything with "Senior," "Staff," "Lead," or a bare "DevOps Engineer" posting explicitly asking for 3+ years experience. Applying occasionally is fine — some postings are more flexible than the title suggests — but don't spend most of your energy there yet.

### Where to actually look

- **LinkedIn Jobs** — filter by "Entry level" experience and use exact phrase search (`"terraform" "aws"`) rather than broad keywords
- **Company career pages directly** — for companies you specifically want to work for; often has postings before/instead of appearing on aggregators
- **Niche boards** — remote-specific boards, and cloud/DevOps-focused job boards tend to have less noise than general aggregators
- **Referrals** — genuinely the highest-yield channel at any level. A short, specific message to someone in your network (even a weak connection) asking about their team, not just "can you refer me," tends to land better than a cold ask

### Networking without it feeling transactional

- Comment thoughtfully on posts from people in cloud/DevOps roles — real engagement, not "great post!"
- Attend a local AWS or DevOps meetup if one exists near you, or an online community (many are free) — you don't need to network *at* people, just show up consistently
- If you reach out to someone for advice, ask a specific question ("how did you structure your first DevOps resume" is answerable in one message; "can you help me get a job" isn't)

### Tracking applications

Keep a simple spreadsheet: company, role, date applied, status, notes from any conversation. This sounds unnecessary until you've applied to 40 roles and can't remember which ones you already followed up with.

---

## Week 28+: Interview Preparation

Expect two distinct interview types at this level, often in the same process: **behavioral** and **technical**.

### Behavioral interviews — the STAR method

Most behavioral questions ("tell me about a time you solved a difficult problem") are answered well with **STAR**: Situation, Task, Action, Result. Your Phase 3 projects are genuine source material here, even without professional experience:

> **Situation:** "I was building a two-tier AWS architecture as a portfolio project and needed the database to be reachable by app servers but never directly from the internet."
> **Task:** "I needed to design security group rules that enforced this without manual IP management."
> **Action:** "I chained security groups — the database's security group only allowed inbound traffic from the app tier's security group ID, not any CIDR range — so the rule stayed correct even as instances scaled up or down."
> **Result:** "The database had zero direct internet exposure, and the pattern is one I'd apply to any multi-tier design going forward."

Prepare 3–4 of these in advance, pulling from different projects, so you're not improvising under pressure.

### Technical interviews — what to expect at entry level

- **Concept questions** — this is where Phases 1–5 pay off directly. Be ready to explain, out loud, in your own words (not recited definitions):
  - Security group vs. NACL, and why both exist
  - What Terraform state is for, and why remote state with locking matters for teams
  - Public vs. private subnet, and what actually makes a subnet "public"
  - Why you'd use `create_before_destroy`
  - The difference between a resource and a data source
  - Idempotency — why running `terraform apply` twice in a row with no config changes should do nothing
- **Small practical exercises** — writing a short Terraform snippet on the spot, or debugging a broken config with an obvious error. Practice this by intentionally breaking one of your own projects (wrong security group reference, missing variable) and fixing it against the clock.
- **Architecture whiteboard questions** — "design a highly available web app on AWS" is a very likely prompt, and it's almost exactly your Project 3. Practice sketching it (ALB → ASG → RDS, subnets, security groups) and narrating your choices out loud, including trade-offs ("I'd put RDS in a private subnet since it never needs direct internet access").

### The question they're actually asking

Across both interview types, what's being evaluated at entry level isn't "do you already know everything a senior engineer knows" — it's "can you reason clearly about trade-offs, and will you be pleasant and effective to work with while you keep learning." Explaining *why* you made a decision (even a simple one, like why RDS lives in a private subnet) demonstrates more than reciting the correct terminology would.

### Take-home assignments

Some companies give a small take-home Terraform task instead of (or alongside) a live technical interview. General advice:

- Follow the instructions exactly — don't over-engineer beyond what's asked, which can read as not listening as much as it reads as ambition
- Include a README, same as your portfolio projects — this is often what's actually being evaluated as much as the code itself
- If a time limit is suggested, respect it, and note in your submission if you had to make time trade-offs (this is honest and shows judgment)

### Salary conversations, briefly

- Research typical entry-level cloud/DevOps compensation in your specific region/market before any conversation happens — ranges vary enormously by location and company size
- If asked for a number early, it's fine to redirect once ("I'd like to learn more about the role first, but can you share the budgeted range for this position?") — this isn't evasive, it's standard
- At entry level, total compensation (benefits, learning budget, remote flexibility) is often as relevant a factor as base salary alone — decide what actually matters to you before you're mid-negotiation and have to decide on the spot

### Handling rejection

You will get far more rejections (including silence) than offers at this stage — this is close to universal, not a signal specific to you. A few things that help:

- Ask for feedback when you're rejected after an actual interview (not always given, but worth asking) — even one useful data point compounds over many applications
- Keep applying at a steady pace rather than pausing entirely after each rejection — momentum matters more than any single application
- Revisit your tracker periodically: if you're getting interviews but not offers, that's a technical/behavioral-interview problem to solve; if you're not getting interviews at all, that's a resume/targeting problem to solve — they call for different fixes

---

## Self-check before considering this phase "done"

You should be able to:

- [ ] Explain any of your three Phase 3 projects out loud, in under two minutes, to someone non-technical and to someone technical (two different explanations, same project)
- [ ] Answer each of the technical concept questions listed above without notes
- [ ] Point to a specific resume bullet for each project that names a real technical decision, not just a tool
- [ ] Have a tracker with at least a handful of applications logged and a rough sense of where in the funnel (applied / interviewing / rejected) things are landing

---

This is also a natural point to say: the roadmap ends here, but the learning doesn't. Once you're interviewing or working, the next real skill-builder is whatever your team's actual stack and problems are — that's genuinely a better teacher than any further solo project. If you want, I'm glad to help with a specific resume rewrite, a mock interview on any of these questions, or working through a real job posting to see how your current profile matches up.
