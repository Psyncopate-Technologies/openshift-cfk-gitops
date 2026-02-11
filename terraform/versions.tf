terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    rhcs = {
      source  = "terraform-redhat/rhcs"
      version = "1.7.1"
    }
  }

  # S3 backend for state management (configured per environment)
  # Initialize with: terraform init -backend-config=env/<env>/backend.tfvars
  backend "s3" {
    # Values provided via -backend-config flag
  }
}
