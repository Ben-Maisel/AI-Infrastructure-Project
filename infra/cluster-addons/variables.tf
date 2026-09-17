variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-2"
}

variable "app_image_tag" {
  description = "Git SHA tag of the app image in ECR (CI always builds one per push to main; no default since a stale/wrong tag should fail loudly, not silently succeed)"
  type        = string
}
