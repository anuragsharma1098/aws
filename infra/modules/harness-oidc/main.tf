# Federates Harness's OIDC identity with AWS, the same pattern GitHub Actions OIDC uses:
# Harness's delegate presents a short-lived token instead of a long-lived AWS access key
# ever being pasted into Harness's secret store.

data "tls_certificate" "harness" {
  url = var.oidc_issuer_url
}

resource "aws_iam_openid_connect_provider" "harness" {
  client_id_list  = [var.audience]
  thumbprint_list = [data.tls_certificate.harness.certificates[0].sha1_fingerprint]
  url             = var.oidc_issuer_url

  tags = var.tags
}

locals {
  oidc_provider_host = replace(var.oidc_issuer_url, "https://", "")
}

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.harness.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:aud"
      values   = [var.audience]
    }

    condition {
      test     = "StringLike"
      variable = "${local.oidc_provider_host}:sub"
      values   = [var.subject_claim]
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = var.name
  assume_role_policy   = data.aws_iam_policy_document.assume.json
  permissions_boundary = var.permissions_boundary_arn
  tags                 = var.tags
}

data "aws_iam_policy_document" "permissions" {
  # ecr:GetAuthorizationToken doesn't support resource-level scoping - it's account-wide by
  # design (it hands back a token, not access to a specific repo).
  statement {
    sid       = "ECRAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "ECRPushPullOwnRepos"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = var.ecr_push_repository_arns
  }

  # Promotion: pull (read-only) from the previous environment's ECR to copy the exact,
  # already-validated image in by digest - dev has nothing before it, so this is empty
  # there; qa pulls from dev's repos, prd pulls from qa's. Never grants push cross-account,
  # and never grants this to compute (node roles) - only to this pipeline role, for the
  # explicit copy step.
  dynamic "statement" {
    for_each = length(var.ecr_pull_repository_arns) > 0 ? [1] : []
    content {
      sid    = "ECRPullFromPreviousEnv"
      effect = "Allow"
      actions = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
      ]
      resources = var.ecr_pull_repository_arns
    }
  }

  statement {
    sid       = "CIArtifactsWrite"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
    resources = [var.ci_artifacts_bucket_arn, "${var.ci_artifacts_bucket_arn}/*"]
  }

  # Fetches cluster connection info (endpoint, CA cert) so Harness's delegate can build a
  # kubeconfig. This does NOT grant kubectl/helm permissions inside the cluster - that comes
  # from an EKS access entry (modules/eks-access) for this role's ARN.
  statement {
    sid       = "EKSDescribe"
    effect    = "Allow"
    actions   = ["eks:DescribeCluster", "eks:ListClusters"]
    resources = [var.eks_cluster_arn]
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.name}-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.permissions.json
}
