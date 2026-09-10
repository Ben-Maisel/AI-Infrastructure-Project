# The network EKS lives in. Two AZs (EKS's minimum), one public subnet
# per AZ (for the internet-facing load balancer) and one private subnet
# per AZ (for the actual worker nodes/pods). A single NAT Gateway lets
# the private subnets reach the internet outbound without being
# reachable from it -- the one resource here with a real hourly cost.

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

  # One shared NAT Gateway (not one per AZ) to keep the always-on cost
  # to a single ~$0.045/hr resource rather than doubling it.
  enable_nat_gateway = true
  single_nat_gateway = true

  # Auto-discovery tags EKS, the load balancer controller, and Karpenter
  # all rely on to find the right subnets without being told explicitly.
  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"              = "1"
    "karpenter.sh/discovery"                        = local.cluster_name
  }
}
