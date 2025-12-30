# Prerequisites

This document outlines the prerequisites for deploying the OpenShift CFK GitOps project.

## Required Accounts

### Red Hat Account
1. Create an account at [cloud.redhat.com](https://cloud.redhat.com)
2. Enable ROSA (Red Hat OpenShift Service on AWS)
3. Generate an offline token for RHCS API access:
   - Navigate to [Red Hat API tokens](https://cloud.redhat.com/openshift/token/rosa)
   - Click "Load token" or "Generate token"
   - Save the token as `RHCS_TOKEN` GitHub secret

### AWS Account
Required permissions:
- VPC management (create/delete VPCs, subnets, NAT gateways)
- EC2 (for ROSA worker nodes)
- IAM (create roles and policies)
- Route53 (manage hosted zones)
- ECR (create repositories, push/pull images)
- Secrets Manager (create/read secrets)
- S3 (for Terraform state)
- DynamoDB (for Terraform state locking)

### Domain Configuration
You need a domain name for TLS certificates:
- Either register a new domain in Route53
- Or delegate a subdomain to a new Route53 hosted zone

## Local Tools (for manual operations)

### Required
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [Terraform >= 1.5.0](https://developer.hashicorp.com/terraform/downloads)
- [OpenShift CLI (oc)](https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html)
- [Helm 3](https://helm.sh/docs/intro/install/)
- [Docker](https://docs.docker.com/get-docker/)

### Optional
- [kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/)
- [ArgoCD CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/)
- [jq](https://stedolan.github.io/jq/download/)

## GitHub Repository Setup

### Secrets Configuration

Navigate to Settings > Secrets and variables > Actions and add:

| Secret | Description | Required |
|--------|-------------|----------|
| `AWS_ACCESS_KEY_ID` | AWS access key | Yes |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | Yes |
| `RHCS_TOKEN` | Red Hat Cloud Services token | Yes |
| `OPENSHIFT_ADMIN_PASSWORD` | Generated after cluster creation | After step 1 |
| `ARGOCD_SSH_PRIVATE_KEY` | SSH key for Git access | Yes |
| `ACME_EMAIL` | Email for Let's Encrypt | Yes |
| `DOCKER_HUB_USERNAME` | Docker Hub username | Optional |
| `DOCKER_HUB_TOKEN` | Docker Hub access token | Optional |
| `DATADOG_API_KEY` | DataDog API key | Optional |

### Environment Configuration

Create environments in Settings > Environments:

1. **dev**
   - No protection rules (for rapid iteration)

2. **staging**
   - Required reviewers: 1
   - Deployment branches: `main`

3. **prod**
   - Required reviewers: 2
   - Wait timer: 5 minutes
   - Deployment branches: `main`

## Terraform State Backend

Create S3 bucket and DynamoDB table for Terraform state:

```bash
# Create S3 bucket
aws s3 mb s3://openshift-cfk-gitops-tfstate --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket openshift-cfk-gitops-tfstate \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name openshift-cfk-gitops-tflock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

## ROSA Prerequisites

Before creating a ROSA cluster, verify your AWS account:

```bash
# Install ROSA CLI
brew install rosa-cli  # macOS
# or download from https://github.com/openshift/rosa/releases

# Login to ROSA
rosa login --token="$RHCS_TOKEN"

# Verify AWS credentials
rosa verify quota

# Verify permissions
rosa verify permissions

# Initialize account roles (one-time setup)
rosa create account-roles --mode auto
```

## Network Requirements

Ensure the following network access:

### Outbound Access Required
- Red Hat APIs (`api.openshift.com`)
- Quay.io (container images)
- Docker Hub (if not using ECR exclusively)
- Let's Encrypt ACME servers
- AWS APIs

### Firewall Rules (if applicable)
| Source | Destination | Ports | Purpose |
|--------|-------------|-------|---------|
| Cluster | Internet | 443 | API access |
| Cluster | Route53 | 53 | DNS resolution |
| Clients | Cluster | 443 | HTTPS access |
| Clients | Cluster | 9092-9094 | Kafka (if external) |

## Cost Estimation

### Development Environment (~$500/month)
- ROSA cluster fee: ~$125
- 3x m5.2xlarge instances: ~$350
- NAT Gateway: ~$35
- Other (ECR, Secrets Manager, Route53): ~$10

### Cost Optimization Options
1. Use spot instances for worker nodes (saves ~40%)
2. Reduce instance sizes for dev
3. Schedule cluster shutdown during off-hours
4. Use reserved instances for long-term deployments
