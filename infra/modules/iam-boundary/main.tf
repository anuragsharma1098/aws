# A permissions boundary caps the MAXIMUM permissions a role can ever have, regardless of
# what its own policy grants - it's a ceiling, not a grant. Attach via `permissions_boundary`
# on any aws_iam_role this account creates (currently: the ECS task/execution roles in the
# ecs-service module). The boundary itself is deliberately broad ("allow everything except
# this deny list") rather than a narrow allow-list: app roles never get anywhere near it in
# normal operation, but it stops privilege escalation and IAM tampering if a role's own
# policy is ever misconfigured or a task is compromised.

data "aws_iam_policy_document" "boundary" {
  statement {
    sid       = "AllowMostActions"
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]
  }

  # Without this, a role that somehow gained iam:* could create a new admin user, attach
  # AdministratorAccess to itself, or strip its own boundary to escape it entirely.
  statement {
    sid    = "DenyIAMPrivilegeEscalation"
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:CreateAccessKey",
      "iam:CreateLoginProfile",
      "iam:UpdateLoginProfile",
      "iam:AttachUserPolicy",
      "iam:PutUserPolicy",
      "iam:AttachRolePolicy",
      "iam:PutRolePolicy",
      "iam:CreatePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:PutRolePermissionsBoundary",
      "iam:PutUserPermissionsBoundary",
      "iam:DeleteRolePermissionsBoundary",
      "iam:DeleteUserPermissionsBoundary",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "DenyOrgAndAccountControlPlane"
    effect    = "Deny"
    actions   = ["organizations:*", "account:*"]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = length(var.allowed_regions) > 0 ? [1] : []
    content {
      sid    = "DenyOutsideAllowedRegions"
      effect = "Deny"
      # Exempt IAM/STS and other inherently-global services from the region check.
      not_actions = [
        "iam:*", "sts:*", "cloudfront:*", "route53:*", "waf:*", "wafv2:*", "support:*", "organizations:*",
      ]
      resources = ["*"]
      condition {
        test     = "StringNotEquals"
        variable = "aws:RequestedRegion"
        values   = var.allowed_regions
      }
    }
  }
}

resource "aws_iam_policy" "boundary" {
  name        = "${var.name}-permissions-boundary"
  description = "Permissions boundary: caps the maximum permissions any role/user with this attached can reach, regardless of their own policy."
  policy      = data.aws_iam_policy_document.boundary.json

  tags = merge(var.tags, {
    Name = "${var.name}-permissions-boundary"
  })
}
