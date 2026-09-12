# Read-only role for `terraform plan` on pull requests -- separate
# from github_actions_deploy since a pull_request-shaped token isn't
# scoped to any specific PR, and anyone can open one on this public repo.
#
# Also trusted for the plain ref-shaped claim a workflow_dispatch job
# gets when it doesn't reference a GitHub Environment (verified against
# a real token) -- used by destroy.yml's ungated preview job. Widening
# *this* read-only role for that, instead of github_actions_role.tf's
# admin role, keeps the powerful role's trust surface untouched: it
# stays reachable only via the environment-gated shape.
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
          "token.actions.githubusercontent.com:sub" = [
            "repo:${local.github_repo_claim}:pull_request",
            "repo:${local.github_repo_claim}:ref:refs/heads/main",
          ]
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_plan_readonly" {
  role       = aws_iam_role.github_actions_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
