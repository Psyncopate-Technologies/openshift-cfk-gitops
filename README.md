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
│  │                      ROSA Cluster                        │   │
│  │  ┌──────────────────────┐  ┌────────────────────────┐   │   │
│  │  │ confluent-operator   │  │     confluent ns       │   │   │
│  │  │ namespace            │  │  ┌──────┐ ┌──────┐    │   │   │
│  │  │ ┌──────────────────┐ │  │  │KRaft │ │Kafka │    │   │   │
│  │  │ │  CFK Operator    │─┼──┼─▶│Ctrl  │ │Broker│    │   │   │
│  │  │ │  (Control Plane) │ │  │  └──────┘ └──────┘    │   │   │
│  │  │ └──────────────────┘ │  │  ┌──────┐ ┌──────┐    │   │   │
│  │  └──────────────────────┘  │  │Schema│ │ksqlDB│    │   │   │
│  │                            │  │  Reg │ │      │    │   │   │
│  │                            │  └──────┘ └──────┘    │   │   │
│  │                            │  ┌──────┐ ┌──────┐    │   │   │
│  │                            │  │Connect│ │ C3  │    │   │   │
│  │                            │  └──────┘ └──────┘    │   │   │
│  │                            └────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

**Namespace Separation (Best Practice):**
- `confluent-operator` - CFK Operator (control plane)
- `confluent` - Confluent Platform components (data plane)

## Components

| Component | Version | Replicas | Namespace |
|-----------|---------|----------|-----------|
| CFK Operator | 3.1.1 | 1 | confluent-operator |
| KRaft Controller | 8.1.1 | 3 | confluent |
| Kafka | 8.1.1 | 3 | confluent |
| Schema Registry | 8.1.1 | 1 | confluent |
| Connect | 8.1.1 | 1 | confluent |
| ksqlDB | 8.1.1 | 1 | confluent |
| Control Center | Next-Gen 2.3.1 | 1 | confluent |
| REST Proxy | 8.1.1 | 1 | confluent |

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
| `RHCS_CLIENT_ID` | RHCS service-account client ID ([Create service account](https://console.redhat.com/iam/service-accounts)) |
| `RHCS_CLIENT_SECRET` | RHCS service-account client secret (shown once at creation time) |
| `OPENSHIFT_ADMIN_PASSWORD` | Cluster admin password (created by workflow 01) |
| `DOCKER_HUB_USERNAME` | Docker Hub username (for image pulls) |
| `DOCKER_HUB_TOKEN` | Docker Hub access token ([Create token](https://hub.docker.com/settings/security)) |
| `ARGOCD_SSH_PRIVATE_KEY` | SSH private key for ArgoCD to access this repo (see below) |

> **Note:** Docker Hub credentials are required to avoid rate limits when pulling Confluent Platform images. Create a free Docker Hub account if you don't have one.

### Setting Up SSH Deploy Key for ArgoCD

ArgoCD requires SSH credentials to access this private repository. Follow these steps:

1. **Generate an SSH key pair:**
   ```bash
   ssh-keygen -t ed25519 -C "argocd-deploy-key" -f argocd-deploy-key -N ""
   ```

2. **Add public key as Deploy Key:**
   - Go to this repository → Settings → Deploy keys
   - Click "Add deploy key"
   - Title: `ArgoCD Deploy Key`
   - Key: Contents of `argocd-deploy-key.pub`
   - Leave "Allow write access" unchecked

3. **Add private key as GitHub Secret:**
   - Go to this repository → Settings → Secrets → Actions
   - Click "New repository secret"
   - Name: `ARGOCD_SSH_PRIVATE_KEY`
   - Value: Entire contents of `argocd-deploy-key` (including BEGIN/END lines)

4. **Delete local key files:**
   ```bash
   rm argocd-deploy-key argocd-deploy-key.pub
   ```

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

#### GitOps Deployment (Recommended)

Run workflows in order via GitHub Actions:

1. **01-provision-rosa** - Create ROSA cluster (~40 min)
2. **02-configure-cluster** - Configure namespaces and SCCs (~2 min)
3. **03-install-argocd** - Install ArgoCD and configure SSH credentials (~5 min)
4. **04-deploy-cfk-operator** - Deploy CFK Operator via ArgoCD (~5 min)
5. **05-deploy-confluent-platform** - Deploy all components via ArgoCD (~15 min)

**ArgoCD Benefits:**
- Automatic sync when you push changes to git
- Self-healing (drift detection and correction)
- Visual dashboard for deployment status
- Rollback capabilities

## How ArgoCD Manages Components

There are two ArgoCD Applications:

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
│   ├── 01-provision-rosa.yaml      # Terraform-based provisioning
│   ├── 02-configure-cluster.yaml   # Namespace, SCC, secrets setup
│   ├── 03-install-argocd.yaml      # Install ArgoCD + SSH credentials
│   ├── 04-deploy-cfk-operator.yaml # Deploy CFK via ArgoCD
│   ├── 05-deploy-confluent-platform.yaml  # Deploy CP via ArgoCD
│   ├── 99-deprovision-rosa.yaml    # Destroy cluster
│   └── README.md
├── terraform/                      # Terraform configuration
│   ├── main.tf                     # ROSA cluster resources
│   ├── variables.tf                # Input variables
│   ├── outputs.tf                  # Output values
│   ├── versions.tf                 # Provider configuration
│   ├── README.md                   # Terraform docs
│   └── env/                        # Environment-specific configs
│       ├── dev/                    # Development
│       ├── stg/                    # Staging
│       ├── prd/                    # Production
│       └── dr/                     # Disaster Recovery
├── env/
│   └── dev/
│       ├── argocd/                 # ArgoCD Application manifests
│       │   ├── appproject.yaml     # ArgoCD AppProject
│       │   ├── cfk-operator-app.yaml      # CFK Operator Application
│       │   └── confluent-platform-app.yaml # CP Application (SSH repo)
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

## TLS Configuration

All Confluent Platform components use TLS for secure communication with **auto-generated certificates**.

### How It Works

1. **CA Certificate** (`ca-pair-sslcerts`) - A self-signed CA is created by workflow 02-configure-cluster
2. **Auto-Generated Certificates** - CFK automatically generates and manages certificates for all components using the CA
3. **Automatic Trust** - CFK handles certificate trust between components automatically

**Configuration:**
```yaml
tls:
  autoGeneratedCerts: true
```

All components use this setting, which tells CFK to:
- Generate server certificates signed by the CA in `ca-pair-sslcerts`
- Automatically configure truststores for inter-component communication
- Handle certificate rotation and renewal

### SNI Configuration for Control Center

The next-gen Control Center uses Jetty 12, which requires SNI (Server Name Indication) validation. Since auto-generated certificates don't include SANs for custom external domains, Control Center is configured to disable SNI host checking:

```yaml
configOverrides:
  server:
    - confluent.controlcenter.rest.sni.host.check.enabled=false
```

This allows external access via the custom domain while maintaining TLS encryption.

### External Access

External access is provided via OpenShift Routes with TLS passthrough:
- Routes terminate at the Confluent component pods
- TLS is end-to-end encrypted
- Custom domain: `*.{env}.confluent.psyncopate.io`

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

- [Documentation Index](docs/README.md) - Overview of all documentation
- [Workflow Documentation](.github/workflows/README.md) - GitHub Actions workflows
- [Terraform Documentation](terraform/README.md) - Infrastructure as Code
- [Prerequisites](docs/PREREQUISITES.md) - Required accounts and setup
- [Deployment Guide](docs/DEPLOYMENT.md) - Step-by-step deployment
- [Existing Cluster Setup](docs/EXISTING-CLUSTER-SETUP.md) - Deploy to existing cluster
- [Cost Optimization](docs/COST-OPTIMIZATION.md) - Cost management strategies
- [Minimal ROSA Guide](docs/MINIMAL-ROSA-GUIDE.md) - Cost-effective testing setup
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [ROSA & OC Cheatsheet](docs/ROSA-OC-CHEATSHEET.md) - CLI command reference

## License

Apache License 2.0
