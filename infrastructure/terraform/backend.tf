terraform {
  backend "s3" {
    bucket         = "openshift-cfk-gitops-tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "openshift-cfk-gitops-tflock"
    # key is set dynamically via -backend-config in CI/CD
  }
}
