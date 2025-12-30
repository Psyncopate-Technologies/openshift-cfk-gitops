# S3 Backend Configuration for Staging Environment
# Use with: terraform init -backend-config=environments/stg/backend.tfvars

bucket         = "psyncopate-terraform-state"
key            = "rosa/stg/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-locks"
