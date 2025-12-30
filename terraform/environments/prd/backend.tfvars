# S3 Backend Configuration for Production Environment
# Use with: terraform init -backend-config=environments/prd/backend.tfvars

bucket         = "psyncopate-terraform-state"
key            = "rosa/prd/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-locks"
