output "ecr_repository_url" {
  value       = aws_ecr_repository.app.repository_url
  description = "docker push/pull target for the agent image"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
