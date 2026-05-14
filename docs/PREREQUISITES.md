# Prerequisites

This document outlines the prerequisites for deploying the OpenShift CFK GitOps project.

## Required Accounts

### Red Hat Account
1. Create an account at [cloud.redhat.com](https://cloud.redhat.com)
2. Enable ROSA (Red Hat OpenShift Service on AWS)
3. Create a service account for RHCS API access (offline tokens are
   deprecated and not supported by this repo):
   - Navigate to [Service Accounts](https://console.redhat.com/iam/service-accounts)
   - Create a new service account
   - Copy the **Client ID** → save as `RHCS_CLIENT_ID` GitHub secret
   - Copy the **Client Secret** → save as `RHCS_CLIENT_SECRET` GitHub secret

### AWS Account
Required permissions:
- EC2 (for ROSA worker nodes)
- IAM (create roles and policies for ROSA)
- VPC management (created by ROSA)
- EBS (for persistent volumes)

The ROSA CLI will create the necessary IAM roles and VPC resources automatically.

## GitHub Repository Setup

### Secrets Configuration

Navigate to Settings > Secrets and variables > Actions and add:

| Secret | Description | Required |
|--------|-------------|----------|
| `AWS_ACCESS_KEY_ID` | AWS access key | Yes |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | Yes |
| `RHCS_CLIENT_ID` | RHCS service-account client ID | Yes |
| `RHCS_CLIENT_SECRET` | RHCS service-account client secret | Yes |
| `OPENSHIFT_ADMIN_PASSWORD` | Generated after cluster creation | After workflow 01 |

### Getting the Secrets

#### AWS Credentials
1. Go to AWS IAM Console
2. Create a user with programmatic access
3. Attach policy: `AdministratorAccess` (or create a custom ROSA policy)
4. Save the Access Key ID and Secret Access Key

#### RHCS Service-Account Credentials
1. Go to https://console.redhat.com/iam/service-accounts
2. Click "Create service account", give it a name
3. Copy the **Client ID** and **Client Secret** values
4. Add as `RHCS_CLIENT_ID` and `RHCS_CLIENT_SECRET` GitHub secrets

The `rhcs` Terraform provider (>= 1.6) and recent ROSA CLI versions
both authenticate via these directly — no manual token minting needed.

#### OpenShift Admin Password
1. Run workflow **01-provision-rosa**
2. Check the workflow logs for the `rosa create admin` output
3. Copy the password and add it as `OPENSHIFT_ADMIN_PASSWORD` secret

## ROSA Prerequisites

Before creating a ROSA cluster, the workflows will automatically:

1. Verify AWS quotas (`rosa verify quota`)
2. Verify AWS permissions (`rosa verify permissions`)
3. Create account roles if needed (`rosa create account-roles`)

### Manual Verification (Optional)

If you want to verify prerequisites locally:

```bash
# Install ROSA CLI
brew install rosa-cli  # macOS
# or download from https://github.com/openshift/rosa/releases

# Login to ROSA (service-account credentials)
rosa login --client-id="$RHCS_CLIENT_ID" --client-secret="$RHCS_CLIENT_SECRET"

# Verify AWS credentials
rosa verify quota

# Verify permissions
rosa verify permissions
```

## Local Tools (Optional)

These tools are only needed if you want to interact with the cluster manually:

- [OpenShift CLI (oc)](https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html)
- [Helm 3](https://helm.sh/docs/intro/install/) (for CFK operator management)

## Cost Estimation

### Minimal Configuration (~$15-20/day)
- ROSA cluster fee: ~$0.171/hour
- 2x m5.xlarge instances: ~$0.48/hour
- Single AZ (no multi-AZ NAT costs)

### Development Configuration (~$20-25/day)
- ROSA cluster fee: ~$0.171/hour
- 3x m5.xlarge instances: ~$0.72/hour
- Multi-AZ deployment

**Important:** Always run the deprovision workflow when done testing to stop charges!
