output "ecr_repository_url" {
  value       = aws_ecr_repository.app.repository_url
  description = "docker push/pull target for the agent image"
}

output "ecr_repository_arn" {
  value       = aws_ecr_repository.app.arn
  description = "Read by infra/trust/ to scope the CI image-push role to this one repo"
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

output "eks_cluster_ca" {
  value       = module.eks.cluster_certificate_authority_data
  description = "Read by infra/cluster-addons/ to configure the helm/kubectl providers"
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

output "app_tool_output_bucket" {
  value       = aws_s3_bucket.app_tool_output.bucket
  description = "Read by cluster-addons/ to set AGENT_TOOL_OUTPUT_S3_BUCKET on the app Deployment"
}

output "app_iam_role_arn" {
  value       = aws_iam_role.app.arn
  description = "Annotated onto the app ServiceAccount so it can assume this role via IRSA"
}
