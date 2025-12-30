# S3 Backend Configuration for Dev Environment
# Use with: terraform init -backend-config=env/dev/backend.tfvars

bucket       = "psyncopate-terraform-state"
key          = "rosa/dev/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true
