# Karpenter's IAM plumbing: a role for its controller pod (IRSA) and a
# role for the EC2 nodes it will launch. The controller's attached
# policy (module-managed, see its policy.tf) is already tag-scoped, not
# admin-wide. Helm install + NodePools come in later files.

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.0"

  cluster_name = module.eks.cluster_name

  # v1 permission set -- the module also supports an older, pre-v1 policy.
  enable_v1_permissions = true

  # IRSA, to match how the cluster is already configured -- not the
  # newer Pod Identity mechanism, to keep one consistent trust model.
  enable_pod_identity    = false
  enable_irsa            = true
  irsa_oidc_provider_arn = module.eks.oidc_provider_arn
}
