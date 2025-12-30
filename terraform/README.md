# Terraform ROSA Provisioning

Deploy ROSA (Red Hat OpenShift Service on AWS) clusters using Terraform for proper Infrastructure as Code management.

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.0.0
3. **ROSA CLI** (optional, for verification)
4. **Red Hat Cloud Services Token** from [cloud.redhat.com](https://cloud.redhat.com/openshift/token/rosa)

## Quick Start

```bash
# Initialize Terraform
cd terraform
terraform init

# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Set sensitive variables
export TF_VAR_rhcs_token="your-rhcs-token"
export TF_VAR_admin_password="your-secure-password"  # Optional

# Plan the deployment
terraform plan

# Apply
terraform apply
```

## Configuration

### Required Variables

| Variable | Description |
|----------|-------------|
| `rhcs_token` | Red Hat Cloud Services API token |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `cluster_name` | `cfk-test` | ROSA cluster name |
| `aws_region` | `us-east-1` | AWS region |
| `compute_machine_type` | `m5.xlarge` | EC2 instance type |
| `compute_nodes` | `2` | Number of worker nodes |
| `multi_az` | `false` | Multi-AZ deployment |
| `openshift_version` | `4.14.0` | OpenShift version |

## Outputs

After successful deployment:

```bash
# View all outputs
terraform output

# Get specific values
terraform output api_url
terraform output console_url
terraform output admin_password  # Sensitive, use -json flag
```

## State Management

### Local State (Default)
State is stored locally in `terraform.tfstate`. Do not commit this file.

### Remote State (Recommended for Teams)
Uncomment and configure the S3 backend in `versions.tf`:

```hcl
backend "s3" {
  bucket         = "your-terraform-state-bucket"
  key            = "rosa/cfk-test/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-locks"
}
```

## Cleanup

```bash
# Destroy all resources
terraform destroy
```

## Integration with GitHub Actions

This Terraform configuration can be run via the `01-provision-rosa-terraform.yaml` workflow which:
1. Initializes Terraform with remote state
2. Plans and applies changes
3. Stores outputs as artifacts

## Next Steps

After cluster provisioning:

1. Run **02-configure-cluster** workflow
2. Run **03-deploy-cfk-operator** workflow
3. Run **04-deploy-confluent-platform** workflow

Or use ArgoCD:
1. Run **05-install-argocd** workflow
2. Run **06-deploy-argocd-apps** workflow
