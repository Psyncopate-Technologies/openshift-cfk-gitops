# GitHub Actions Workflows

This directory contains the GitHub Actions workflows for deploying and managing Confluent Platform on ROSA using GitOps (ArgoCD).

**Important:** All workflows are **manual dispatch only** - they will NOT auto-execute on push or pull request.

## Workflow Overview

| # | Workflow | Description | Duration |
|---|----------|-------------|----------|
| 01 | [01-provision-rosa.yaml](01-provision-rosa.yaml) | Provision ROSA cluster via Terraform | ~40 min |
| 02 | [02-configure-cluster.yaml](02-configure-cluster.yaml) | Configure namespaces, SCCs, secrets | ~2 min |
| 03 | [03-install-argocd.yaml](03-install-argocd.yaml) | Install OpenShift GitOps (ArgoCD) | ~5 min |
| 04 | [04-deploy-cfk-operator.yaml](04-deploy-cfk-operator.yaml) | Deploy CFK Operator via ArgoCD | ~5 min |
| 05 | [05-deploy-confluent-platform.yaml](05-deploy-confluent-platform.yaml) | Deploy Confluent Platform via ArgoCD | ~15 min |
| 06 | [06-install-flink-infra.yaml](06-install-flink-infra.yaml) | Install Flink infra (cert-manager, Flink Operator, CMF, mTLS) | ~10 min |
| 07 | [07-deploy-flink-gitops.yaml](07-deploy-flink-gitops.yaml) | Deploy Flink environments and applications via ArgoCD | ~5 min |
| 99 | [99-deprovision-rosa.yaml](99-deprovision-rosa.yaml) | Delete ROSA cluster and cleanup | ~15 min |

## Quick Start

Run these workflows in order:

```
01-Provision ROSA             → Create ROSA cluster (Terraform)
02-Configure Cluster          → Setup namespaces, SCCs, secrets
03-Install ArgoCD             → Install OpenShift GitOps operator
04-Deploy CFK Operator        → Deploy CFK 3.1.1 via ArgoCD
05-Deploy Confluent Platform  → Deploy CP 8.1.x via ArgoCD
06-Install Flink Infra        → Install cert-manager, Flink Operator, CMF, mTLS
07-Deploy Flink (GitOps)      → Deploy Flink environments and applications
```

**When done testing:**
```
99-Deprovision ROSA      → Delete cluster (stops charges!)
```

## Cluster Options

All workflows support these ROSA clusters:

| Cluster | Environment | Domain |
|---------|-------------|--------|
| cfk-dev | Development | dev.confluent.psyncopate.io |
| cfk-stg | Staging | stg.confluent.psyncopate.io |
| cfk-prd | Production | prd.confluent.psyncopate.io |
| cfk-dr | Disaster Recovery | dr.confluent.psyncopate.io |

## Required GitHub Secrets

Configure these secrets in your GitHub repository (Settings > Secrets > Actions):

| Secret | Description | How to Get |
|--------|-------------|------------|
| `AWS_ACCESS_KEY_ID` | AWS access key | AWS IAM Console |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | AWS IAM Console |
| `RHCS_TOKEN` | Red Hat Cloud Services token | [Get Token](https://cloud.redhat.com/openshift/token/rosa) |
| `OPENSHIFT_ADMIN_PASSWORD` | Cluster admin password | Created by workflow 01 |
| `DOCKER_HUB_USERNAME` | Docker Hub username | For pulling images |
| `DOCKER_HUB_TOKEN` | Docker Hub access token | Docker Hub settings |
| `ARGOCD_SSH_PRIVATE_KEY` | SSH private key for ArgoCD | See setup below |

### Setting Up SSH Deploy Key for ArgoCD

ArgoCD uses SSH to access this private repository. Setup steps:

1. **Generate SSH key pair:**
   ```bash
   ssh-keygen -t ed25519 -C "argocd-deploy-key" -f argocd-deploy-key -N ""
   ```

2. **Add public key as Deploy Key:**
   - Repository → Settings → Deploy keys → Add deploy key
   - Title: `ArgoCD Deploy Key`
   - Key: Contents of `argocd-deploy-key.pub`

3. **Add private key as GitHub Secret:**
   - Repository → Settings → Secrets → Actions → New secret
   - Name: `ARGOCD_SSH_PRIVATE_KEY`
   - Value: Contents of `argocd-deploy-key`

4. **Delete local keys:** `rm argocd-deploy-key argocd-deploy-key.pub`

## Namespace Architecture

Following Confluent best practices, this deployment uses separate namespaces:

| Namespace | Purpose | Contents |
|-----------|---------|----------|
| `confluent-operator` | Control Plane | CFK Operator pod |
| `confluent` | Data Plane | Kafka, KRaft, Schema Registry, Connect, ksqlDB, Control Center, REST Proxy |
| `flink` | Compute | Apache Flink JobManager / TaskManager pods |

**Benefits:**
- Security isolation with different RBAC policies
- Independent lifecycle management for operator upgrades
- Reduced blast radius if workload issues occur
- Better compliance and auditing

## Workflow Details

### 01-provision-rosa.yaml

Provisions a ROSA cluster using Terraform.

**Inputs:**
- `environment`: Target environment (dev, stg, prd, dr)
- `action`: Terraform action (plan, apply, destroy)

**Features:**
- Infrastructure as Code with Terraform
- Environment-specific configurations in `terraform/env/`
- OpenShift 4.20.0

### 02-configure-cluster.yaml

Configures the cluster for Confluent Platform.

**Creates:**
- `confluent` and `confluent-operator` namespaces
- `confluent-scc` SecurityContextConstraints
- Docker Hub pull secret (for image pulls)
- CA certificate secrets for TLS
- Grants SCCs to service accounts

**TLS Configuration:**
- Generates a self-signed CA certificate (`ca-pair-sslcerts`) used by CFK for auto-generated certificates
- All components use `autoGeneratedCerts: true` - CFK manages certificate generation and trust automatically
- Control Center includes `confluent.controlcenter.rest.sni.host.check.enabled=false` to allow external access via custom domain

### 03-install-argocd.yaml

Installs OpenShift GitOps (ArgoCD) operator and configures repository access.

**Features:**
- Installs via OpenShift GitOps Operator (Red Hat supported)
- Configures SSH credentials for private repository access
- Grants ArgoCD cluster-admin permissions
- Creates custom domain route for ArgoCD

**SSH Repository Access:**
- Uses `ARGOCD_SSH_PRIVATE_KEY` secret
- Creates Kubernetes secret labeled `argocd.argoproj.io/secret-type=repository`
- Repo URL: `git@github.com:Psyncopate-Technologies/openshift-cfk-gitops.git`

**Access:**
- URL: `https://argocd.<custom-domain>`
- Username: `admin`
- Password: `oc get secret openshift-gitops-cluster -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d`

### 04-deploy-cfk-operator.yaml

Deploys Confluent for Kubernetes (CFK) operator via ArgoCD.

**Features:**
- CFK 3.1.1 (Helm chart 0.1351.59)
- Deployed to `confluent-operator` namespace (best practice: separate control plane)
- Manages resources in `confluent` namespace
- GitOps managed with auto-sync and self-heal

### 05-deploy-confluent-platform.yaml

Deploys all Confluent Platform components via ArgoCD.

**Components:**
- KRaft Controller (3 replicas)
- Kafka (3 brokers)
- Schema Registry
- Kafka Connect
- ksqlDB
- Control Center
- REST Proxy

**Access URLs (after DNS configured):**
- Control Center: `https://controlcenter.<custom-domain>`
- Schema Registry: `https://schemaregistry.<custom-domain>`
- Connect: `https://connect.<custom-domain>`
- ksqlDB: `https://ksqldb.<custom-domain>`
- REST Proxy: `https://kafkarestproxy.<custom-domain>`

## Apache Flink Workflows

Apache Flink is deployed using **Confluent Platform for Apache Flink** and managed through **CFK and GitOps**.

### 06-install-flink-infra.yaml

Installs all Flink infrastructure components.

**Installs:**
- cert-manager (required by Flink Kubernetes Operator)
- Flink Kubernetes Operator (watches `flink` namespace)
- Confluent Manager for Apache Flink (CMF)
- mTLS configuration between CFK and CMF

**Security:**
- Reuses the cluster CA (`ca-pair-sslcerts`) created in workflow 02
- Generates CMF server certificates and CFK client certificates
- Configures CMF to require mTLS
- No OpenShift Route is created (internal service only)

CMF endpoint:
https://cmf-service.confluent.svc.cluster.local:80

### 07-deploy-flink-gitops.yaml

Deploys Flink resources using ArgoCD.

**Deploys:**
- `CMFRestClass`
- `FlinkEnvironment`
- `FlinkApplication`

**GitOps Source:**
env/<env>/flink/

**Behavior:**
- Flink CRs are created in the `confluent` namespace
- Flink JobManager and TaskManager pods run in the `flink` namespace
- CFK reconciles Flink state via CMF

### Flink Security Model

- **CFK ↔ CMF:** Mutual TLS (mTLS)
- **Kafka / Clients:** OAuth (SASL/OAUTHBEARER)

OAuth configuration applies to Kafka and client-facing components.
It does **not** replace mTLS between CFK and CMF.

If Flink jobs access Kafka using OAuth, Flink pods must be configured
with OAuth client properties and trust the IdP certificate chain.

### 99-deprovision-rosa.yaml

Destroys the ROSA cluster and cleans up AWS resources.

**Inputs:**
- `cluster_name`: Cluster to delete
- `confirm_cluster_name`: Type cluster name again to confirm

**Warning:** Run this when done testing to stop AWS charges!

## DNS Setup

After cluster provisioning, create a wildcard CNAME record:

```
*.dev.confluent.psyncopate.io → *.apps.cfk-dev.<cluster-domain>
```

The exact target domain is shown in the workflow summary after running 01-provision-rosa.

## GitOps Benefits

Using ArgoCD provides:
- **Auto-sync:** Changes pushed to git are automatically deployed
- **Self-heal:** Drift from desired state is automatically corrected
- **Prune:** Removed resources are automatically deleted
- **Audit trail:** All changes tracked in git history

## Cost Management

### Minimize Costs
1. Use `dev` environment (smaller nodes)
2. Destroy cluster when not in use
3. Test during business hours only

### Example Testing Session
```
Morning:  Run 01-provision-rosa (~40 min)
          Run 02, 03, 04, 05 workflows
          Test for 4 hours
Evening:  Run 99-deprovision-rosa

Total: ~$15-20 for a day of testing
```

## Troubleshooting

### "Cluster not found" error
- Check cluster name matches across workflows
- Verify cluster is in "ready" state: `rosa describe cluster -c <name>`

### OpenShift login fails
- Verify `OPENSHIFT_ADMIN_PASSWORD` secret is set
- Check cluster is accessible (not still provisioning)

### ArgoCD application stuck
- Check ArgoCD UI for sync errors
- View application events: `oc get events -n openshift-gitops`

### CFK Operator not syncing
- Verify helm chart version exists
- Check ArgoCD application logs

### Components stuck in "Provisioning"
- Check operator logs: `oc logs -n confluent-operator -l app=confluent-operator`
- Verify node resources: `oc describe nodes`
- Check events: `oc get events -n confluent --sort-by='.lastTimestamp'`

### Image pull errors (ErrImagePull)
- Verify Docker Hub secret exists: `oc get secret dockerhub-secret -n confluent`
- Check secret is correctly configured: `oc get secret dockerhub-secret -n confluent -o yaml`
- Ensure `DOCKER_HUB_USERNAME` and `DOCKER_HUB_TOKEN` GitHub secrets are set
- Re-run workflow 02-configure-cluster to recreate the secret

### TLS certificate errors
- Verify CA certificate secret exists:
  ```bash
  oc get secret ca-pair-sslcerts -n confluent
  ```
- Check CA certificate content: `oc get secret ca-pair-sslcerts -n confluent -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout`
- If components show "PKIX path building failed" errors, re-run workflow 02-configure-cluster to regenerate the CA certificate
- CFK auto-generates component certificates and truststores from the CA - no manual certificate management needed

### SNI / Invalid SNI errors on Control Center
- Control Center uses Jetty 12 which requires SNI validation
- Ensure `confluent.controlcenter.rest.sni.host.check.enabled=false` is in Control Center configOverrides
- This is already configured in `env/dev/confluent-platform/controlcenter.yaml`

### Flink application not starting
- Verify CMF is running: `oc -n confluent get pods | grep cmf`
- Verify CMFRestClass status: `oc -n confluent get cmfrestclass`
- Verify FlinkEnvironment exists: `oc -n confluent get flinkenvironment`
- Ensure service account exists: `oc -n flink get sa flink`
- Check CFK operator logs: `oc logs -n confluent-operator -l app=confluent-operator`
