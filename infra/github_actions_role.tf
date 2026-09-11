# The IAM role GitHub Actions actually assumes to run Terraform against
# this account. oidc.tf only established that AWS will *consider*
# GitHub's tokens -- this is where we say what a trusted token is
# allowed to DO, and for whom.
#
# Trust is scoped to this exact repo and the main branch only -- mirrors
# the branch protection rule that only allows main to change via a PR
# from dev: now, only a merge to main can trigger a real AWS change,
# not just a code change.

locals {
  github_repo = "Ben-Maisel/AI-Infrastructure-Project"
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
          "token.actions.githubusercontent.com:sub" = "repo:${local.github_repo}:ref:refs/heads/main"
        }
      }
    }]
  })
}

# Broad on purpose, for now: this role will need to manage EC2/VPC,
# EKS, IAM (to create Karpenter's own IRSA roles later), ECR, and S3 --
# and the full set of actions it needs isn't known yet since EKS,
# Karpenter, and the GPU NodePool haven't been built. A scoped-down
# custom policy would mean guessing at required actions prematurely.
# Documented here as a real, deliberate tradeoff to revisit once the
# full resource surface this role touches is actually known.
resource "aws_iam_role_policy_attachment" "github_actions_deploy_admin" {
  role       = aws_iam_role.github_actions_deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
