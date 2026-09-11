# Read-only role for `terraform plan` on pull requests -- separate
# from github_actions_deploy since a pull_request-shaped token isn't
# scoped to any specific PR, and anyone can open one on this public repo.

resource "aws_iam_role" "github_actions_plan" {
  name = "${local.cluster_name}-github-actions-plan"

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
          "token.actions.githubusercontent.com:sub" = "repo:${local.github_repo_claim}:pull_request"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_plan_readonly" {
  role       = aws_iam_role.github_actions_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
