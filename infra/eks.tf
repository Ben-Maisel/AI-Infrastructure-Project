# EKS cluster + an always-on "system" node group for CoreDNS and the
# Karpenter controller. App/Ollama/Chroma workloads run on
# Karpenter-provisioned nodes instead (see infra/karpenter.tf, next).

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = "1.31"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  # Lets a Kubernetes service account assume an IAM role directly --
  # Karpenter's controller needs this to call the EC2 API.
  enable_irsa = true

  # IAM auth alone doesn't grant Kubernetes RBAC access -- separate
  # systems. Without this, whoever's identity runs `terraform apply`
  # (the CI deploy role) can authenticate to the API server but is
  # authorized to do nothing inside the cluster, which is why the
  # Helm install failed.
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    system = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 2
      desired_size   = 1
    }
  }

  # Karpenter discovers which security group to put its nodes in via this tag.
  node_security_group_tags = {
    "karpenter.sh/discovery" = local.cluster_name
  }

  # Read-only kubectl access for local debugging/demos -- matches the
  # same philosophy as the AWS IAM side: personal credentials observe,
  # CI creates and modifies.
  access_entries = {
    ben = {
      principal_arn = "arn:aws:iam::786830914740:user/Ben"
      policy_associations = {
        view = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
}
