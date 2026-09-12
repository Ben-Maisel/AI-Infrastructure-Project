terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Same state bucket as infra/, different key -- separate state file.
  backend "s3" {
    bucket       = "ai-infra-project-tfstate-786830914740"
    key          = "infra/trust/terraform.tfstate"
    region       = "us-east-2"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "ai-infra-project"
      ManagedBy = "terraform"
    }
  }
}
