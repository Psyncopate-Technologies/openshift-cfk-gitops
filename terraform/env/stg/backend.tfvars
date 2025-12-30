# S3 Backend Configuration for Staging Environment
# Use with: terraform init -backend-config=env/stg/backend.tfvars

bucket       = "psyncopate-terraform-state"
key          = "rosa/stg/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true
