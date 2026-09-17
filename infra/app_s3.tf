# Backs agent/tools.py's write_file tool in the cluster (S3, instead of
# local disk). Same hand-rolled IRSA pattern as ebs_csi.tf: an IAM role
# trusting the cluster's OIDC provider, scoped via condition to one
# specific Kubernetes ServiceAccount so nothing else in the cluster can
# assume it.

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "app_tool_output" {
  # Bucket names are globally unique across all of AWS, not just this
  # account -- account ID suffix makes collision practically impossible
  # without needing a random suffix.
  bucket = "${local.cluster_name}-tool-output-${data.aws_caller_identity.current.account_id}"
}

# Agent-written files are working output, not records worth keeping
# indefinitely -- bounds storage cost from unbounded accumulation.
resource "aws_s3_bucket_lifecycle_configuration" "app_tool_output" {
  bucket = aws_s3_bucket.app_tool_output.id

  rule {
    id     = "expire-after-30-days"
    status = "Enabled"
    filter {}
    expiration {
      days = 30
    }
  }
}

resource "aws_iam_role" "app" {
  name = "${local.cluster_name}-app"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${module.eks.oidc_provider}:aud" = "sts.amazonaws.com"
          "${module.eks.oidc_provider}:sub" = "system:serviceaccount:default:app"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "app_s3" {
  name = "s3-tool-output"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject"]
        Resource = "${aws_s3_bucket.app_tool_output.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.app_tool_output.arn
      }
    ]
  })
}
