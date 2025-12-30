# OpenShift CFK GitOps

GitOps-based deployment of Confluent Platform on Red Hat OpenShift (ROSA) using Terraform and ArgoCD.

## Overview

This project deploys a production-ready Confluent Platform 8.0.1 on a ROSA (Red Hat OpenShift Service on AWS) cluster using:

- **Infrastructure as Code:** Terraform for AWS and ROSA resources
- **GitOps:** OpenShift GitOps (ArgoCD) for application deployment
- **Secrets Management:** External Secrets Operator with AWS Secrets Manager
- **TLS:** cert-manager with Let's Encrypt
- **Monitoring:** OpenShift built-in Prometheus

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Account                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                        VPC                                │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │   │
│  │  │   AZ-1      │  │   AZ-2      │  │   AZ-3      │      │   │
│  │  │  ┌───────┐  │  │  ┌───────┐  │  │  ┌───────┐  │      │   │
│  │  │  │ Node  │  │  │  │ Node  │  │  │  │ Node  │  │      │   │
│  │  │  │ Kafka │  │  │  │ Kafka │  │  │  │ Kafka │  │      │   │
│  │  │  │ KRaft │  │  │  │ KRaft │  │  │  │ KRaft │  │      │   │
│  │  │  └───────┘  │  │  └───────┘  │  │  └───────┘  │      │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │   ECR    │  │ Route53  │  │ Secrets  │  │   IAM    │       │
│  │          │  │          │  │ Manager  │  │  (IRSA)  │       │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

## Components

| Component | Version | Description |
|-----------|---------|-------------|
| OpenShift | 4.14.x | Container platform |
| Confluent Platform | 8.0.1 | Event streaming platform |
| CFK Operator | 2.10.0 | Kubernetes operator |
| cert-manager | 1.14.2 | Certificate management |
| External Secrets | Latest | Secrets synchronization |

## Quick Start

### Prerequisites

1. AWS account with appropriate permissions
2. Red Hat account with ROSA enabled
3. Domain name for TLS certificates
4. GitHub repository with Actions enabled

See [docs/PREREQUISITES.md](docs/PREREQUISITES.md) for detailed requirements.

### Configuration

1. Fork this repository
2. Update `infrastructure/terraform/environments/*.tfvars` with your values
3. Configure GitHub secrets (see below)
4. Run deployment workflows in order

### GitHub Secrets Required

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |
| `RHCS_TOKEN` | Red Hat Cloud Services token |
| `ARGOCD_SSH_PRIVATE_KEY` | SSH key for Git access |
| `ACME_EMAIL` | Email for Let's Encrypt |

### Deployment

Run workflows in order via GitHub Actions:

1. `01-deploy-infrastructure.yaml` - Create ROSA cluster (~45 min)
2. `02-configure-cluster.yaml` - Configure OpenShift
3. `03-mirror-images.yaml` - Mirror images to ECR
4. `04-deploy-external-secrets.yaml` - Deploy ESO
5. `05-deploy-argocd.yaml` - Configure ArgoCD
6. `06-deploy-cfk-operator.yaml` - Install CFK
7. `07-deploy-cert-manager.yaml` - Setup TLS
8. `08-deploy-confluent-platform.yaml` - Deploy Confluent
9. `09-deploy-routes.yaml` - Create Routes
10. `10-deploy-monitoring.yaml` - Enable monitoring

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for detailed instructions.

## Project Structure

```
openshift-cfk-gitops/
├── .github/workflows/      # GitHub Actions workflows
├── infrastructure/
│   └── terraform/          # Terraform configurations
│       └── environments/   # Environment-specific variables
├── argocd/                 # ArgoCD applications
│   └── dev/               # Dev environment apps
├── environments/
│   ├── dev/               # Dev manifests
│   │   ├── platform/      # Confluent Platform CRs
│   │   ├── routes/        # OpenShift Routes
│   │   ├── external-secrets/
│   │   ├── cert-manager/
│   │   ├── cluster-config/
│   │   └── monitoring/
│   ├── staging/
│   └── prod/
├── scripts/               # Utility scripts
└── docs/                  # Documentation
```

## Estimated Costs

| Environment | Monthly Cost |
|-------------|-------------|
| Development | ~$300-500 |
| Staging | ~$500-700 |
| Production | ~$800-1200 |

See [docs/COST-OPTIMIZATION.md](docs/COST-OPTIMIZATION.md) for cost reduction strategies.

## Accessing the Platform

After deployment:

```bash
# Get ArgoCD credentials
./scripts/get-argocd-password.sh

# Validate deployment
./scripts/validate-cluster.sh

# Get Control Center URL
oc get route controlcenter -n confluent -o jsonpath='{.spec.host}'
```

## Documentation

- [Prerequisites](docs/PREREQUISITES.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
- [Cost Optimization](docs/COST-OPTIMIZATION.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

## Cleanup

To destroy all resources, run workflows in reverse order:

1. `91-destroy-confluent-platform.yaml`
2. ... (intermediate destroy workflows)
3. `99-destroy-infrastructure.yaml`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes
4. Submit a pull request

## License

Apache License 2.0
