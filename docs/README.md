# Documentation

This directory contains comprehensive documentation for deploying Confluent Platform on Red Hat OpenShift (ROSA) using GitOps practices.

## Quick Navigation

| Document | Description |
|----------|-------------|
| [PREREQUISITES.md](PREREQUISITES.md) | Required accounts, credentials, and setup steps |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Step-by-step deployment using GitHub Actions workflows |
| [EXISTING-CLUSTER-SETUP.md](EXISTING-CLUSTER-SETUP.md) | Manual deployment to an existing ROSA cluster |
| [MINIMAL-ROSA-GUIDE.md](MINIMAL-ROSA-GUIDE.md) | Cost-effective ROSA setup for testing |
| [COST-OPTIMIZATION.md](COST-OPTIMIZATION.md) | Strategies to minimize AWS costs |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Common issues and solutions |
| [ROSA-OC-CHEATSHEET.md](ROSA-OC-CHEATSHEET.md) | ROSA and OpenShift CLI command reference |

## Related Documentation

| Document | Description |
|----------|-------------|
| [Main README](../README.md) | Project overview and architecture |
| [Terraform README](../terraform/README.md) | Infrastructure as Code with Terraform |
| [Workflows README](../.github/workflows/README.md) | GitHub Actions workflow details |

## Getting Started Path

### New to this project?

1. **[PREREQUISITES.md](PREREQUISITES.md)** - Set up your accounts and credentials
2. **[Main README](../README.md)** - Understand the architecture
3. **[DEPLOYMENT.md](DEPLOYMENT.md)** - Deploy using GitHub Actions

### Want to minimize costs?

1. **[MINIMAL-ROSA-GUIDE.md](MINIMAL-ROSA-GUIDE.md)** - Cost breakdown and minimal setup
2. **[COST-OPTIMIZATION.md](COST-OPTIMIZATION.md)** - Cost reduction strategies

### Already have a ROSA cluster?

1. **[EXISTING-CLUSTER-SETUP.md](EXISTING-CLUSTER-SETUP.md)** - Deploy to existing cluster

### Need help?

1. **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues
2. **[ROSA-OC-CHEATSHEET.md](ROSA-OC-CHEATSHEET.md)** - CLI commands

## Deployment Options

### Option 1: Automated via GitHub Actions (Recommended)

Uses GitHub Actions workflows to provision and configure everything:
- **01-provision-rosa** - Create ROSA cluster via Terraform
- **02-configure-cluster** - Configure namespaces and security
- **03-install-argocd** - Install ArgoCD for GitOps
- **04-deploy-cfk-operator** - Deploy CFK Operator
- **05-deploy-confluent-platform** - Deploy Confluent Platform

See [DEPLOYMENT.md](DEPLOYMENT.md) for details.

### Option 2: Manual Deployment

For deploying to an existing OpenShift cluster without GitHub Actions:
- Install CFK Operator via Helm
- Apply Confluent Platform manifests manually

See [EXISTING-CLUSTER-SETUP.md](EXISTING-CLUSTER-SETUP.md) for details.

## Architecture Overview

```
ROSA Cluster
├── confluent-operator namespace
│   └── CFK Operator (manages Confluent resources)
└── confluent namespace
    ├── KRaft Controller (3 replicas)
    ├── Kafka (3 brokers)
    ├── Schema Registry
    ├── Kafka Connect
    ├── ksqlDB
    ├── Control Center
    └── REST Proxy
```

## Key Technologies

| Technology | Version | Purpose |
|------------|---------|---------|
| ROSA | 4.20.0 | Managed OpenShift on AWS |
| CFK | 3.1.1 | Confluent for Kubernetes operator |
| Confluent Platform | 8.1.1 | Kafka and ecosystem |
| ArgoCD | Latest | GitOps continuous deployment |
| Terraform | 1.11+ | Infrastructure as Code |

## Cost Estimates

| Configuration | Daily Cost | Monthly Cost |
|--------------|------------|--------------|
| Minimal (2 nodes, single AZ) | ~$15 | ~$450 |
| Development (3 nodes, multi-AZ) | ~$20 | ~$600 |
| Production (3 nodes, larger instances) | ~$36 | ~$1,080 |

**Important:** Always destroy your cluster when not in use to avoid unnecessary charges!
