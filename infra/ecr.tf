# Container registry for the agent image. Referenced by ecr_repository_url
# in outputs.tf for docker push / Kubernetes manifests.

resource "aws_ecr_repository" "app" {
  name = "${local.cluster_name}-app"

  # Immutable tags force a unique tag (e.g. git SHA) per build instead
  # of silently overwriting "latest".
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only the most recent 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
