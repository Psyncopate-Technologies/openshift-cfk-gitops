# S3 Backend Configuration for DR Environment
# Use with: terraform init -backend-config=env/dr/backend.tfvars

bucket       = "psyncopate-terraform-state"
key          = "rosa/dr/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true
