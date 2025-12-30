# OpenShift CFK GitOps

Deploy Confluent Platform on Red Hat OpenShift (ROSA) using GitHub Actions workflows.

## Overview

This project deploys Confluent Platform 8.1.1 on a ROSA (Red Hat OpenShift Service on AWS) cluster using:

- **ROSA CLI:** Automated cluster provisioning via GitHub Actions
- **CFK Operator:** Confluent for Kubernetes 3.1.1
- **KRaft Mode:** No ZooKeeper dependency
- **Docker Hub:** Direct image pulls (no ECR mirroring required)
- **ArgoCD (Optional):** GitOps-based continuous deployment

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Account                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    ROSA Cluster                          │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │              confluent namespace                 │    │   │
│  │  │  ┌───────────┐ ┌───────────┐ ┌───────────┐     │    │   │
│  │  │  │  KRaft    │ │   Kafka   │ │  Schema   │     │    │   │
│  │  │  │Controller │ │  Brokers  │ │ Registry  │     │    │   │
│  │  │  └───────────┘ └───────────┘ └───────────┘     │    │   │
│  │  │  ┌───────────┐ ┌───────────┐ ┌───────────┐     │    │   │
│  │  │  │  Connect  │ │  ksqlDB   │ │  Control  │     │    │   │
│  │  │  │           │ │           │ │  Center   │     │    │   │
│  │  │  └───────────┘ └───────────┘ └───────────┘     │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Components

| Component | Version | Replicas |
|-----------|---------|----------|
| KRaft Controller | 8.1.1 | 3 |
| Kafka | 8.1.1 | 3 |
| Schema Registry | 8.1.1 | 1 |
| Connect | 8.1.1 | 1 |
| ksqlDB | 8.1.1 | 1 |
| Control Center | 8.1.1 | 1 |
| REST Proxy | 8.1.1 | 1 |

## Quick Start

### Prerequisites

1. AWS account with appropriate permissions
2. Red Hat account with ROSA enabled
3. GitHub repository with Actions enabled

### GitHub Secrets Required

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |
| `RHCS_TOKEN` | Red Hat Cloud Services token ([Get token](https://cloud.redhat.com/openshift/token/rosa)) |
| `OPENSHIFT_ADMIN_PASSWORD` | Cluster admin password (created by workflow 01) |

### Deployment Options

#### Option A: Direct Deployment (Simple)

Run workflows in order via GitHub Actions:

1. **01-provision-rosa** - Create ROSA cluster (~40 min)
2. **02-configure-cluster** - Configure namespaces and SCCs (~2 min)
3. **03-deploy-cfk-operator** - Install CFK Operator (~5 min)
4. **04-deploy-confluent-platform** - Deploy all components (~15 min)

#### Option B: GitOps with ArgoCD (Recommended for Production)

1. **01-provision-rosa** - Create ROSA cluster (~40 min)
2. **02-configure-cluster** - Configure namespaces and SCCs (~2 min)
3. **05-install-argocd** - Install ArgoCD (~5 min)
4. **06-deploy-argocd-apps** - Deploy via ArgoCD (~10 min)

**ArgoCD Benefits:**
- Automatic sync when you push changes to git
- Self-healing (drift detection and correction)
- Visual dashboard for deployment status
- Rollback capabilities

**When done testing:**
- **99-deprovision-rosa** - Destroy cluster (stops charges!)

See [.github/workflows/README.md](.github/workflows/README.md) for detailed workflow documentation.

## Project Structure

```
openshift-cfk-gitops/
├── .github/workflows/          # GitHub Actions workflows
│   ├── 01-provision-rosa.yaml
│   ├── 02-configure-cluster.yaml
│   ├── 03-deploy-cfk-operator.yaml
│   ├── 04-deploy-confluent-platform.yaml
│   ├── 05-install-argocd.yaml
│   ├── 06-deploy-argocd-apps.yaml
│   ├── 99-deprovision-rosa.yaml
│   └── README.md
├── environments/
│   └── dev/
│       ├── argocd/            # ArgoCD Application manifests
│       ├── cluster-config/     # Namespace and SCC definitions
│       └── platform-dockerhub/ # Confluent Platform manifests
└── docs/                       # Documentation
```

## Cost Estimates

| Configuration | Hourly | Daily |
|--------------|--------|-------|
| Minimal (2x m5.xlarge, single AZ) | ~$0.65 | ~$15 |
| Dev (3x m5.xlarge, multi AZ) | ~$0.85 | ~$20 |

**Important:** Run the deprovision workflow when done testing to stop AWS charges!

## Accessing the Platform

After deployment, access URLs are provided in the workflow summary:

- **ArgoCD:** `https://argocd-server.<apps-domain>` (if using GitOps)
- **Control Center:** `https://controlcenter.<apps-domain>`
- **Schema Registry:** `https://schemaregistry.<apps-domain>`
- **Connect:** `https://connect.<apps-domain>`
- **ksqlDB:** `https://ksqldb.<apps-domain>`
- **REST Proxy:** `https://kafkarestproxy.<apps-domain>`

## Documentation

- [Workflow Documentation](.github/workflows/README.md)
- [Prerequisites](docs/PREREQUISITES.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
- [Cost Optimization](docs/COST-OPTIMIZATION.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

## License

Apache License 2.0
