terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend is partially configured here; the rest (bucket/key/region/dynamodb_table)
  # comes from -backend-config=backend/<env>.tfbackend at `terraform init` time,
  # so the same code deploys dev, uat and prod into separate state files.
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-rust-serverless-oltp"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
