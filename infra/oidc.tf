# Establishes trust between AWS and GitHub Actions' identity tokens.
# Grants no permissions on its own -- see github_actions_role.tf and
# github_actions_plan_role.tf for what a trusted token can do.

data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # Certificates are ordered root-first; index 0 is the root CA.
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]
}
