# OpenShift CFK GitOps

Deploy Confluent Platform on Red Hat OpenShift (ROSA) using GitHub Actions workflows.

## Overview

This project deploys Confluent Platform 8.1.1 on a ROSA (Red Hat OpenShift Service on AWS) cluster using:

- **ROSA CLI or Terraform:** Automated cluster provisioning via GitHub Actions
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
| `DOCKERHUB_USERNAME` | Docker Hub username (for image pulls) |
| `DOCKERHUB_TOKEN` | Docker Hub access token ([Create token](https://hub.docker.com/settings/security)) |

> **Note:** Docker Hub credentials are required to avoid rate limits when pulling Confluent Platform images. Create a free Docker Hub account if you don't have one.

### Deployment Options

#### Cluster Provisioning

Choose one method to provision your ROSA cluster:

| Method | Workflow | Best For |
|--------|----------|----------|
| **CLI** | `01-provision-rosa` | Quick setup, simple use cases |
| **Terraform** | `01-provision-rosa-terraform` | Production, state management, IaC maturity |

**Terraform Benefits:**
- State tracking and drift detection
- Plan/review before apply
- Easier cleanup with `terraform destroy`
- Multi-environment support (dev, stg, prd, dr)
- Isolated state per environment

**Terraform Environments:**

| Environment | Cluster | Region | Custom Domain |
|-------------|---------|--------|---------------|
| dev | cfk-dev | us-east-1 | dev.confluent.psyncopate.io |
| stg | cfk-stg | us-east-1 | stg.confluent.psyncopate.io |
| prd | cfk-prd | us-east-1 | prd.confluent.psyncopate.io |
| dr | cfk-dr | us-west-2 | dr.confluent.psyncopate.io |

See [terraform/README.md](terraform/README.md) for Terraform-specific documentation.

#### Option A: Direct Deployment (Simple)

Run workflows in order via GitHub Actions:

1. **01-provision-rosa** (or **01-provision-rosa-terraform**) - Create ROSA cluster (~40 min)
2. **02-configure-cluster** - Configure namespaces and SCCs (~2 min)
3. **03-deploy-cfk-operator** - Install CFK Operator (~5 min)
4. **04-deploy-confluent-platform** - Deploy all components (~15 min)

#### Option B: GitOps with ArgoCD (Recommended for Production)

1. **01-provision-rosa** (or **01-provision-rosa-terraform**) - Create ROSA cluster (~40 min)
2. **02-configure-cluster** - Configure namespaces and SCCs (~2 min)
3. **05-install-argocd** - Install ArgoCD (~5 min)
4. **06-deploy-argocd-apps** - Deploy via ArgoCD (~10 min)

**ArgoCD Benefits:**
- Automatic sync when you push changes to git
- Self-healing (drift detection and correction)
- Visual dashboard for deployment status
- Rollback capabilities

## How ArgoCD Manages Components

When using ArgoCD (Option B), there are two ArgoCD Applications:

| Application | Source | What It Manages |
|-------------|--------|-----------------|
| `cfk-operator` | Confluent Helm repo | CFK Operator deployment |
| `confluent-platform` | This Git repo (`env/dev/confluent-platform/`) | Confluent Platform CRDs |

**Architecture:**

```
┌─────────────────────────────────────────────────────────────────┐
│                         ArgoCD                                   │
│  ┌─────────────────────┐    ┌─────────────────────────────┐    │
│  │  cfk-operator App   │    │  confluent-platform App     │    │
│  │  (Helm Chart)       │    │  (Git Repo)                 │    │
│  └──────────┬──────────┘    └──────────────┬──────────────┘    │
└─────────────┼───────────────────────────────┼──────────────────┘
              │                               │
              ▼                               ▼
┌─────────────────────────┐    ┌─────────────────────────────────┐
│ confluent-operator ns   │    │        confluent ns              │
│ ┌─────────────────────┐ │    │ ┌───────┐ ┌───────┐ ┌───────┐  │
│ │  CFK Operator Pod   │─┼────┼▶│ Kafka │ │ KRaft │ │  ...  │  │
│ │  (reconciles CRDs)  │ │    │ │ Pods  │ │ Pods  │ │       │  │
│ └─────────────────────┘ │    │ └───────┘ └───────┘ └───────┘  │
└─────────────────────────┘    └─────────────────────────────────┘
```

**Key Points:**
- ArgoCD manages the **CFK Operator** via Helm chart
- ArgoCD manages the **Confluent Platform CRDs** (Kafka, KRaftController, etc.) from this Git repo
- The **CFK Operator** reconciles CRDs into actual Pods, StatefulSets, and Services
- Changing `kafka.yaml` in Git → ArgoCD syncs → CFK Operator updates Kafka pods

**When done testing:**
- **99-deprovision-rosa** - Destroy cluster (stops charges!)

See [.github/workflows/README.md](.github/workflows/README.md) for detailed workflow documentation.

## Project Structure

```
openshift-cfk-gitops/
├── .github/workflows/              # GitHub Actions workflows
│   ├── 01-provision-rosa.yaml      # CLI-based provisioning
│   ├── 01-provision-rosa-terraform.yaml  # Terraform provisioning
│   ├── 02-configure-cluster.yaml
│   ├── 03-deploy-cfk-operator.yaml
│   ├── 04-deploy-confluent-platform.yaml
│   ├── 05-install-argocd.yaml
│   ├── 06-deploy-argocd-apps.yaml
│   ├── 99-deprovision-rosa.yaml
│   └── README.md
├── terraform/                      # Terraform configuration
│   ├── main.tf                     # ROSA cluster resources
│   ├── variables.tf                # Input variables
│   ├── outputs.tf                  # Output values
│   ├── versions.tf                 # Provider configuration
│   ├── README.md                   # Terraform docs
│   └── environments/               # Environment-specific configs
│       ├── dev/                    # Development
│       ├── stg/                    # Staging
│       ├── prd/                    # Production
│       └── dr/                     # Disaster Recovery
├── env/
│   └── dev/
│       ├── argocd/                 # ArgoCD Application manifests
│       ├── cluster-config/         # Namespace and SCC definitions
│       └── confluent-platform/     # Confluent Platform manifests
└── docs/                           # Documentation
```

## Cost Estimates

| Configuration | Hourly | Daily |
|--------------|--------|-------|
| Minimal (2x m5.xlarge, single AZ) | ~$0.65 | ~$15 |
| Dev (3x m5.xlarge, multi AZ) | ~$0.85 | ~$20 |

**Important:** Run the deprovision workflow when done testing to stop AWS charges!

## Custom Domain Setup

This project uses a custom domain `dev.confluent.psyncopate.io` for accessing Confluent Platform components. To set this up:

### DNS Configuration

Create a wildcard CNAME record pointing to your ROSA cluster's apps domain:

```
*.dev.confluent.psyncopate.io -> *.apps.<cluster-name>.<base-domain>
```

For example, if your ROSA cluster has the apps domain `apps.cfk-test.xxxx.p1.openshiftapps.com`:

```
*.dev.confluent.psyncopate.io CNAME *.apps.cfk-test.xxxx.p1.openshiftapps.com
```

### Access URLs

Once DNS is configured, access Confluent Platform at:

| Component | URL |
|-----------|-----|
| Control Center | https://controlcenter.dev.confluent.psyncopate.io |
| Schema Registry | https://schemaregistry.dev.confluent.psyncopate.io |
| Connect | https://connect.dev.confluent.psyncopate.io |
| ksqlDB | https://ksqldb.dev.confluent.psyncopate.io |
| REST Proxy | https://kafkarestproxy.dev.confluent.psyncopate.io |

ArgoCD (if using GitOps option) is accessed via the default OpenShift route:
- **ArgoCD:** `https://argocd-server-argocd.apps.<cluster-domain>`

### Multi-Environment Support

The domain pattern supports multiple environments:
- **Dev:** `*.dev.confluent.psyncopate.io`
- **Staging:** `*.staging.confluent.psyncopate.io` (create separate env folder)
- **Prod:** `*.prod.confluent.psyncopate.io` (create separate env folder)

## Documentation

- [Workflow Documentation](.github/workflows/README.md)
- [Prerequisites](docs/PREREQUISITES.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
- [Cost Optimization](docs/COST-OPTIMIZATION.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

## License

Apache License 2.0
