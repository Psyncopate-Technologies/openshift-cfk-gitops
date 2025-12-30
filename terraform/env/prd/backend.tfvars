# S3 Backend Configuration for Production Environment
# Use with: terraform init -backend-config=env/prd/backend.tfvars

bucket       = "psyncopate-terraform-state"
key          = "rosa/prd/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true
