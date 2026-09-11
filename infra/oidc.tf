# Establishes trust between AWS and GitHub Actions' identity tokens.
# This alone grants no permissions -- it just tells AWS "tokens signed
# by GitHub's OIDC issuer are legitimate, I'll consider them." What
# those tokens are actually allowed to DO is a separate IAM role
# (next file), not defined here.

# Fetches GitHub's live certificate chain at plan/apply time, so the
# thumbprint below is always derived from the real current chain
data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]
}
