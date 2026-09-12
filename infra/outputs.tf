output "ecr_repository_url" {
  value       = aws_ecr_repository.app.repository_url
  description = "docker push/pull target for the agent image"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "karpenter_iam_role_arn" {
  value       = module.karpenter.iam_role_arn
  description = "Annotated onto the Karpenter controller's ServiceAccount so it can assume this role via IRSA"
}

output "karpenter_node_iam_role_name" {
  value       = module.karpenter.node_iam_role_name
  description = "Referenced by EC2NodeClass as spec.role"
}

output "karpenter_interruption_queue_name" {
  value = module.karpenter.queue_name
}
