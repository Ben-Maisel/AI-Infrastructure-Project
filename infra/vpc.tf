# Network for EKS: 2 AZs, public+private subnets, one shared NAT Gateway.

locals {
  cluster_name = "ai-infra-project"
  azs          = ["${var.aws_region}a", "${var.aws_region}b"]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = local.azs
  public_subnets  = ["10.0.0.0/20", "10.0.16.0/20"]
  private_subnets = ["10.0.128.0/20", "10.0.144.0/20"]

  # Single shared NAT (not one per AZ) trades AZ resilience for cost.
  enable_nat_gateway = true
  single_nat_gateway = true

  # Tags EKS/Karpenter/the load balancer controller use for auto-discovery.
  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"              = "1"
    "karpenter.sh/discovery"                       = local.cluster_name
  }
}
