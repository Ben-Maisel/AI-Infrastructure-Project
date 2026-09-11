# Container registry for the agent image. CI will build and push here;
# the Kubernetes Deployment manifests will reference this repo's URL.

resource "aws_ecr_repository" "app" {
  name = "${local.cluster_name}-app"

  # Each tag can only ever be pushed once -- forces every build to use a
  # genuinely unique tag (e.g. the git SHA) instead of silently
  # overwriting something like "latest", which is better for traceability
  # and rollback. This is a real constraint on the future CI build/push
  # stage, not just a Terraform setting -- worth remembering when that
  # stage gets built.
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
