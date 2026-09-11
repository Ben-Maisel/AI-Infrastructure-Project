# IAM role GitHub Actions assumes to run Terraform. Trust is scoped to
# this exact repo and the main branch only.

locals {
  # GitHub's sub claim embeds numeric owner/repo IDs, not just names:
  # repo:OWNER@OWNER_ID/REPO@REPO_ID:... Verified against a real token.
  github_repo_claim = "Ben-Maisel@146761912/AI-Infrastructure-Project@1363459857"
}

resource "aws_iam_role" "github_actions_deploy" {
  name = "${local.cluster_name}-github-actions-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github_actions.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${local.github_repo_claim}:ref:refs/heads/main"
        }
      }
    }]
  })
}

# Broad on purpose for now -- scope down once EKS/Karpenter are built
# and the real set of required actions is known.
resource "aws_iam_role_policy_attachment" "github_actions_deploy_admin" {
  role       = aws_iam_role.github_actions_deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
