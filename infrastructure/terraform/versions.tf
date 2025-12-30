terraform {
  required_version = ">= 1.5.0"

  required_providers {
    rhcs = {
      source  = "terraform-redhat/rhcs"
      version = "~> 1.5"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "openshift-cfk-gitops"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

provider "rhcs" {
  token = var.rhcs_token
}
