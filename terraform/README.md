# Terraform ROSA Provisioning

Deploy ROSA (Red Hat OpenShift Service on AWS) clusters using Terraform for proper Infrastructure as Code management with multi-environment support.

## Multi-Environment Architecture

```
terraform/
├── main.tf                    # ROSA cluster resources
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── versions.tf                # Provider and backend config
└── env/
    ├── dev/
    │   ├── terraform.tfvars   # Dev cluster config
    │   └── backend.tfvars     # Dev state backend
    ├── stg/
    │   ├── terraform.tfvars   # Staging cluster config
    │   └── backend.tfvars     # Staging state backend
    ├── prd/
    │   ├── terraform.tfvars   # Production cluster config
    │   └── backend.tfvars     # Production state backend
    └── dr/
        ├── terraform.tfvars   # DR cluster config
        └── backend.tfvars     # DR state backend
```

## Environment Configuration

| Environment | Cluster | Region | Nodes | Instance | Multi-AZ | Domain |
|-------------|---------|--------|-------|----------|----------|--------|
| **dev** | cfk-dev | us-east-1 | 2 | m5.xlarge | No | dev.confluent.psyncopate.io |
| **stg** | cfk-stg | us-east-1 | 3 | m5.xlarge | Yes | stg.confluent.psyncopate.io |
| **prd** | cfk-prd | us-east-1 | 3 | m5.2xlarge | Yes | prd.confluent.psyncopate.io |
| **dr** | cfk-dr | us-west-2 | 3 | m5.2xlarge | Yes | dr.confluent.psyncopate.io |

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.11.0
3. **Red Hat Cloud Services Token** from [cloud.redhat.com](https://cloud.redhat.com/openshift/token/rosa)
4. **S3 Bucket** for Terraform state (create before first use)

### GitHub Secrets Required

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |
| `RHCS_CLIENT_ID` | RHCS service-account client ID |
| `RHCS_CLIENT_SECRET` | RHCS service-account client secret |
| `OPENSHIFT_ADMIN_PASSWORD` | Cluster admin password (see requirements below) |

### Admin Password Requirements

The `OPENSHIFT_ADMIN_PASSWORD` must meet these requirements:
- At least **14 characters** long
- Contains **uppercase** letters (A-Z)
- Contains **lowercase** letters (a-z)
- Contains **numbers or symbols** (0-9, !@#$%^&*)
- **ASCII characters only**

Example: `MyClusterAdmin123!`

### Create State Backend

```bash
# Create S3 bucket for state
aws s3 mb s3://psyncopate-terraform-state --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket psyncopate-terraform-state \
  --versioning-configuration Status=Enabled
```

> **Note:** State locking uses S3's native locking feature (`use_lockfile = true`), so no DynamoDB table is required.

## Quick Start

### Via GitHub Actions (Recommended)

1. Go to **Actions** → **01-Provision ROSA (Terraform)**
2. Select environment: `dev`, `stg`, `prd`, or `dr`
3. Select action: `plan` (preview) or `apply` (create)
4. Run the workflow

### Via CLI

```bash
cd terraform

# Set sensitive variables (RHCS service-account credentials from
# https://console.redhat.com/iam/service-accounts)
export TF_VAR_rhcs_client_id="your-rhcs-client-id"
export TF_VAR_rhcs_client_secret="your-rhcs-client-secret"
export TF_VAR_admin_password="your-secure-password"

# Initialize for dev environment
terraform init -backend-config=env/dev/backend.tfvars

# Plan
terraform plan -var-file=env/dev/terraform.tfvars

# Apply
terraform apply -var-file=env/dev/terraform.tfvars
```

### Switching Environments

```bash
# Re-initialize for a different environment
terraform init -backend-config=env/prd/backend.tfvars -reconfigure

# Plan production
terraform plan -var-file=env/prd/terraform.tfvars
```

## Environment Variables

Each environment has its own `terraform.tfvars` with pre-configured values:

| Variable | dev | stg | prd | dr |
|----------|-----|-----|-----|-----|
| cluster_name | cfk-dev | cfk-stg | cfk-prd | cfk-dr |
| aws_region | us-east-1 | us-east-1 | us-east-1 | us-west-2 |
| compute_nodes | 2 | 3 | 3 | 3 |
| compute_machine_type | m5.xlarge | m5.xlarge | m5.2xlarge | m5.2xlarge |
| multi_az | false | true | true | true |
| custom_domain | dev.confluent... | stg.confluent... | prd.confluent... | dr.confluent... |

## Outputs

After successful deployment:

```bash
# View all outputs
terraform output

# Get specific values
terraform output api_url
terraform output dns_setup_instructions
terraform output -json > cluster-config.json
```

## State Management

Each environment has isolated state:
- **dev**: `rosa/dev/terraform.tfstate`
- **stg**: `rosa/stg/terraform.tfstate`
- **prd**: `rosa/prd/terraform.tfstate`
- **dr**: `rosa/dr/terraform.tfstate`

Benefits:
- Environments can be managed independently
- No risk of accidentally modifying wrong environment
- Clear separation of concerns

## Cleanup

```bash
# Destroy specific environment
terraform init -backend-config=env/dev/backend.tfvars -reconfigure
terraform destroy -var-file=env/dev/terraform.tfvars
```

Or via GitHub Actions with action: `destroy`

## Network CIDR Allocation

Non-overlapping CIDRs for potential VPC peering:

| Environment | Machine CIDR | Service CIDR | Pod CIDR |
|-------------|--------------|--------------|----------|
| dev | 10.0.0.0/16 | 172.30.0.0/16 | 10.128.0.0/14 |
| stg | 10.1.0.0/16 | 172.31.0.0/16 | 10.132.0.0/14 |
| prd | 10.2.0.0/16 | 172.32.0.0/16 | 10.136.0.0/14 |
| dr | 10.3.0.0/16 | 172.33.0.0/16 | 10.140.0.0/14 |

## Next Steps

After cluster provisioning:

1. Run **02-configure-cluster** workflow
2. Run **03-deploy-cfk-operator** workflow
3. Run **04-deploy-confluent-platform** workflow

Or use ArgoCD:
1. Run **05-install-argocd** workflow
2. Run **06-deploy-argocd-apps** workflow
