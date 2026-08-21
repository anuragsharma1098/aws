# ci-cd/github-actions

Example pipelines, inert until copied into `.github/workflows/` at the repo
root (GitHub only executes workflows from that exact path).

| File | Purpose |
| --- | --- |
| `terraform-plan-apply.yml` | `terraform plan` on every PR touching `infra-at-scale/**`; `terraform apply` per environment on merge to `main`, gated by a GitHub Environment approval rule for `prod`. |
| `ecs-blue-green-deploy.yml` | Builds the app image once, then calls `_deploy-env.yml` sequentially for dev → qa → staging → prod, promoting the exact same image **digest** at every step. |
| `_deploy-env.yml` | Reusable workflow: registers a new ECS task definition revision and starts the actual CodeDeploy blue/green deployment for one environment. |

Both workflows authenticate via each environment's `modules/iam-github-oidc`
role (GitHub OIDC federation) — set `AWS_ROLE_ARN_DEV` / `_QA` / `_STAGING` /
`_PROD` as repo or GitHub Environment secrets, populated from each
environment's `github_actions_role_arn` Terraform output. No AWS access keys
are ever stored in GitHub.

**Manual approval for prod**: create a GitHub Environment named `prod` under
repo Settings → Environments, add required reviewers, and both workflows'
`environment: prod` job will pause for approval before running — this is
enforced by GitHub, not by Terraform (Terraform only narrows *which*
repo/ref may assume the prod deploy role in the first place).
