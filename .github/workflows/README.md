# GitHub Actions Workflows

This directory contains the GitHub Actions workflows for deploying and managing the OpenShift CFK GitOps infrastructure.

## Workflow Execution Order

### Deployment (Sequential)

Execute workflows in the following order:

1. **01-deploy-infrastructure.yaml** - Terraform apply for ROSA cluster and AWS resources
2. **02-configure-cluster.yaml** - Post-install cluster configuration (namespaces, SCCs)
3. **03-mirror-images.yaml** - Mirror Confluent images to ECR
4. **04-deploy-external-secrets.yaml** - External Secrets Operator with AWS SM backend
5. **05-deploy-argocd.yaml** - Configure OpenShift GitOps Operator
6. **06-deploy-cfk-operator.yaml** - Confluent for Kubernetes Operator
7. **07-deploy-cert-manager.yaml** - cert-manager with Let's Encrypt
8. **08-deploy-confluent-platform.yaml** - Deploy Confluent Platform components
9. **09-deploy-routes.yaml** - OpenShift Routes for external access
10. **10-deploy-monitoring.yaml** - ServiceMonitors and PrometheusRules

### Destruction (Reverse Order)

Execute workflows in the following order:

1. **91-destroy-confluent-platform.yaml** - Delete Confluent Platform components
2. **92-destroy-cfk-operator.yaml** - Uninstall CFK Operator
3. **93-destroy-monitoring.yaml** - Remove monitoring resources
4. **94-destroy-routes.yaml** - Delete OpenShift Routes
5. **95-destroy-cert-manager.yaml** - Uninstall cert-manager
6. **96-destroy-argocd.yaml** - Remove ArgoCD configuration
7. **97-destroy-external-secrets.yaml** - Uninstall External Secrets Operator
8. **98-destroy-cluster-config.yaml** - Remove cluster configuration
9. **99-destroy-infrastructure.yaml** - Terraform destroy for ROSA and AWS resources

## Required Secrets

Configure the following secrets in your GitHub repository:

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS access key for Terraform and AWS CLI |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key for Terraform and AWS CLI |
| `RHCS_TOKEN` | Red Hat Cloud Services API token |
| `OPENSHIFT_ADMIN_PASSWORD` | OpenShift cluster admin password |
| `ARGOCD_SSH_PRIVATE_KEY` | SSH private key for ArgoCD Git repo access |
| `ACME_EMAIL` | Email for Let's Encrypt certificate registration |
| `DOCKER_HUB_USERNAME` | (Optional) Docker Hub username for rate limits |
| `DOCKER_HUB_TOKEN` | (Optional) Docker Hub token for rate limits |
| `DATADOG_API_KEY` | (Optional) DataDog API key for monitoring |

## Environment Protection Rules

For production environments, configure environment protection rules in GitHub:

1. Go to Settings > Environments
2. Create environments: `dev`, `staging`, `prod`
3. For `staging` and `prod`, enable:
   - Required reviewers
   - Wait timer (optional)
   - Deployment branches (e.g., `main` only)

## Workflow Inputs

Most workflows accept the following inputs:

- **environment**: Target environment (`dev`, `staging`, `prod`)
- **confirm**: Confirmation string for destructive operations

## Artifacts

Workflows produce the following artifacts:

- `terraform-outputs-{environment}`: Terraform output values (JSON)
- `tfplan-{environment}-{run_id}`: Terraform plan files

Artifacts are used to pass configuration between workflows. The Terraform outputs artifact is particularly important as it contains:

- Cluster API URL
- ECR registry URL
- IAM role ARNs for IRSA
- Route53 zone ID
- Domain name

## Troubleshooting

### Workflow fails to download artifacts

Artifacts expire after 90 days. Re-run the infrastructure workflow if outputs are missing.

### OpenShift login fails

Ensure `OPENSHIFT_ADMIN_PASSWORD` secret is correct and the cluster is accessible.

### Terraform state lock

If Terraform reports a state lock, check for running workflows or manually release the lock in DynamoDB.

### Image pull errors

Verify ECR credentials and ensure images have been mirrored (workflow 03).
