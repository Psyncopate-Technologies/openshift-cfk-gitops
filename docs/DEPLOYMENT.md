# Deployment Guide

This guide walks through deploying Confluent Platform on OpenShift using GitHub Actions workflows with ArgoCD for GitOps.

## Overview

The deployment consists of 7 sequential workflows, plus a cleanup workflow. All workflows use ArgoCD for GitOps-based continuous deployment.

## Prerequisites

Before starting, ensure you have:

1. **GitHub Secrets configured** (see [PREREQUISITES.md](PREREQUISITES.md)):
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `RHCS_TOKEN`
   - `OPENSHIFT_ADMIN_PASSWORD`
   - `DOCKER_HUB_USERNAME`
   - `DOCKER_HUB_TOKEN`
   - `ARGOCD_SSH_PRIVATE_KEY`

2. **Red Hat terms accepted** at https://console.redhat.com/openshift

## Deployment Steps

### Step 1: Provision ROSA Cluster

**Workflow:** `01-provision-rosa.yaml`

Creates a ROSA cluster using Terraform for Infrastructure as Code.

**Inputs:**
- `environment`: Target environment (dev, stg, prd, dr)
- `action`: Terraform action (plan, apply, destroy)

**Environment Configurations:**

| Environment | Cluster | Region | Nodes | Instance | Multi-AZ |
|-------------|---------|--------|-------|----------|----------|
| dev | cfk-dev | us-east-1 | 2 | m5.xlarge | No |
| stg | cfk-stg | us-east-1 | 3 | m5.xlarge | Yes |
| prd | cfk-prd | us-east-1 | 3 | m5.2xlarge | Yes |
| dr | cfk-dr | us-west-2 | 3 | m5.2xlarge | Yes |

**Duration:** ~35-45 minutes

**Post-deployment:**
1. Note the cluster API URL from workflow output
2. Update DNS for custom domain (see DNS Setup below)

### Step 2: Configure Cluster

**Workflow:** `02-configure-cluster.yaml`

Configures the cluster for Confluent Platform:
- Creates `confluent` namespace (data plane)
- Creates `confluent-operator` namespace (control plane)
- Applies `confluent-scc` SecurityContextConstraints
- Creates Docker Hub pull secret
- Generates CA certificate for TLS (`ca-pair-sslcerts`)
- Grants SCCs to service accounts

**Inputs:**
- `cluster_name`: ROSA cluster name (cfk-dev, cfk-stg, cfk-prd, cfk-dr)

**Duration:** ~2 minutes

### Step 3: Install ArgoCD

**Workflow:** `03-install-argocd.yaml`

Installs OpenShift GitOps (ArgoCD) operator:
- Installs Red Hat OpenShift GitOps Operator
- Configures SSH credentials for private repository access
- Grants ArgoCD cluster-admin permissions
- Creates ArgoCD AppProject

**Inputs:**
- `cluster_name`: ROSA cluster name

**Duration:** ~5 minutes

**Access ArgoCD:**
```bash
# Get ArgoCD URL
oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}'

# Get admin password
oc get secret openshift-gitops-cluster -n openshift-gitops \
  -o jsonpath='{.data.admin\.password}' | base64 -d
```

### Step 4: Deploy CFK Operator

**Workflow:** `04-deploy-cfk-operator.yaml`

Deploys Confluent for Kubernetes Operator via ArgoCD:
- Creates ArgoCD Application for CFK Operator
- Deploys CFK 3.1.1 from Confluent Helm repository
- Installs to `confluent-operator` namespace
- Manages resources in `confluent` namespace

**Inputs:**
- `cluster_name`: ROSA cluster name

**Duration:** ~5 minutes

### Step 5: Deploy Confluent Platform

**Workflow:** `05-deploy-confluent-platform.yaml`

Deploys all Confluent Platform components via ArgoCD:
- Creates ArgoCD Application for Confluent Platform
- Syncs manifests from `env/dev/confluent-platform/` directory
- Components deployed in order by CFK Operator

**Components Deployed:**

| Component | Replicas | Description |
|-----------|----------|-------------|
| KRaft Controller | 3 | Metadata management (replaces ZooKeeper) |
| Kafka | 3 | Message brokers |
| Schema Registry | 1 | Schema management |
| Connect | 1 | Kafka Connect workers |
| ksqlDB | 1 | Stream processing |
| Control Center | 1 | Management UI |
| REST Proxy | 1 | HTTP interface to Kafka |

**Inputs:**
- `cluster_name`: ROSA cluster name

**Duration:** ~15-20 minutes

**Deployment order (handled by CFK):**
1. KRaft Controller starts first
2. Kafka brokers connect to KRaft
3. Schema Registry, Connect, ksqlDB, REST Proxy start
4. Control Center starts last (depends on all components)

### Step 6: Install Flink Infrastructure (Optional)

**Workflow:** `06-install-flink-infra.yaml`

Installs all infrastructure required for Apache Flink.

**Installs:**
- cert-manager (required by Flink Kubernetes Operator)
- Flink Kubernetes Operator (watches the `flink` namespace)
- Confluent Manager for Apache Flink (CMF)
- Mutual TLS (mTLS) between CFK and CMF

**Security Model:**
- Reuses the cluster CA (`ca-pair-sslcerts`) created in Step 2
- Generates CMF server certificates and CFK client certificates
- Configures CMF to require mTLS
- No OpenShift Route is created (internal service only)

**CMF Endpoint:**
https://cmf-service.confluent.svc.cluster.local:80

**Duration:** ~10 minutes

### Step 7: Deploy Flink via GitOps (Optional)

**Workflow:** `07-deploy-flink-gitops.yaml`

Deploys Apache Flink resources using ArgoCD.

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

**Duration:** ~5 minutes

## DNS Setup

After cluster provisioning, create a wildcard CNAME record for your custom domain:

```
*.dev.confluent.psyncopate.io → *.apps.cfk-dev.<cluster-domain>
```

The exact cluster domain is shown in the workflow 01 output.

## Accessing the Platform

### Via Custom Domain (after DNS configured)

| Component | URL |
|-----------|-----|
| Control Center | `https://controlcenter.dev.confluent.psyncopate.io` |
| Schema Registry | `https://schemaregistry.dev.confluent.psyncopate.io` |
| Connect | `https://connect.dev.confluent.psyncopate.io` |
| ksqlDB | `https://ksqldb.dev.confluent.psyncopate.io` |
| REST Proxy | `https://kafkarestproxy.dev.confluent.psyncopate.io` |

### Via OpenShift Routes

```bash
# Get all routes
oc get routes -n confluent

# Get specific route URL
oc get route controlcenter -n confluent -o jsonpath='{.spec.host}'
```

## Cleanup

### Deprovision ROSA Cluster

**Workflow:** `99-deprovision-rosa.yaml`

Destroys the ROSA cluster and cleans up AWS resources using Terraform destroy.

**Inputs:**
- `cluster_name`: Cluster to delete
- `confirm_cluster_name`: Type cluster name again to confirm (safety check)

**Duration:** ~15-20 minutes

**Important:** Run this workflow when done testing to stop AWS charges!

## Verification

After deployment, verify the cluster status:

```bash
# Login to OpenShift
oc login <cluster-api-url> -u cluster-admin -p <password>

# Check all Confluent components
oc get kraftcontroller,kafka,schemaregistry,connect,ksqldb,controlcenter,kafkarestproxy -n confluent

# Check pods are running
oc get pods -n confluent

# Check ArgoCD applications
oc get applications -n openshift-gitops

# Verify Flink
oc get cmfrestclass -n confluent
oc get flinkenvironment -n confluent
oc get flinkapplication -n confluent
oc get pods -n flink

# Flink Security Model
- **CFK ↔ CMF:** Mutual TLS (mTLS)
- **Kafka / Clients:** OAuth (SASL/OAUTHBEARER)

# Check routes
oc get routes -n confluent
```

## GitOps Benefits

Using ArgoCD provides:
- **Auto-sync:** Changes pushed to git are automatically deployed
- **Self-heal:** Drift from desired state is automatically corrected
- **Prune:** Removed resources are automatically deleted
- **Rollback:** Easy rollback to previous versions
- **Audit trail:** All changes tracked in git history

## Scaling

### Horizontal Scaling

Edit the component manifests in `env/dev/confluent-platform/`:

```yaml
spec:
  replicas: 5  # Increase Kafka brokers
```

Push to git - ArgoCD will automatically sync the changes.

### Vertical Scaling

Edit resource requests/limits in the component manifests:

```yaml
spec:
  podTemplate:
    resources:
      requests:
        cpu: "2"
        memory: 8Gi
      limits:
        cpu: "4"
        memory: 12Gi
```

## Next Steps

After deployment:
1. Access Control Center to verify all components
2. Create topics for your applications
3. Configure connectors if needed
4. Set up monitoring dashboards

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues and solutions.
