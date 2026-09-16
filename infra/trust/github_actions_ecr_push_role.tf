# Narrow role for CI to build and push app's image to ECR -- separate
# from the admin-wide deploy role, since this only ever needs to push
# to one specific repository, never touch AWS infrastructure itself.
# Trusted for the plain ref-shaped claim a push-to-main job produces
# when it doesn't reference a GitHub Environment (same shape already
# verified for the plan role) -- image builds run on every push, no
# approval gate, since pushing an image has no effect until a
# separate, still-gated deploy actually uses it.

data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket = "ai-infra-project-tfstate-786830914740"
    key    = "infra/terraform.tfstate"
    region = "us-east-2"
  }
}

resource "aws_iam_role" "github_actions_ecr_push" {
  name = "${local.cluster_name}-github-actions-ecr-push"

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

resource "aws_iam_role_policy" "github_actions_ecr_push" {
  name = "ecr-push"
  role = aws_iam_role.github_actions_ecr_push.id

  # Matches AWS's own documented minimum push policy --
  # GetAuthorizationToken can't be scoped to a single repo (the token
  # it returns is account-wide), everything else can.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:CompleteLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:InitiateLayerUpload",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:BatchGetImage",
        ]
        Resource = data.terraform_remote_state.infra.outputs.ecr_repository_arn
      },
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
    ]
  })
}
