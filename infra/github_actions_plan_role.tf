# Narrowly-scoped role for `terraform plan` on pull requests. Read-only
# on purpose -- plan only needs to read current AWS state to compute a
# diff, never to create/modify/delete anything.
#
# Deliberately a SEPARATE role from github_actions_deploy (not a
# broadened trust policy on that one): the pull_request-shaped OIDC
# token isn't scoped to any specific branch or PR number, and this is
# a public repo -- anyone can open a PR. That token shape should never
# be able to assume anything more powerful than read-only. Trust
# policy here matches exactly that shape, which is what the original
# single-role attempt got wrong: its trust policy only allowed the
# push-to-main shape, so `plan` failed on every PR with "Not
# authorized to perform sts:AssumeRoleWithWebIdentity."
#
# Also got the sub format itself wrong on the first two attempts --
# assumed "repo:OWNER/REPO:pull_request", but the real claim (decoded
# from an actual issued token, not guessed) embeds numeric owner/repo
# IDs: "repo:OWNER@OWNER_ID/REPO@REPO_ID:pull_request". Fixed via
# local.github_repo_claim in github_actions_role.tf.

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
