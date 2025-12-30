# S3 Backend Configuration for Dev Environment
# Use with: terraform init -backend-config=environments/dev/backend.tfvars

bucket         = "psyncopate-terraform-state"
key            = "rosa/dev/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-locks"
