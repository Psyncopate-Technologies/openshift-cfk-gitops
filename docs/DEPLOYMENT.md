# Deployment Guide

This guide walks through deploying Confluent Platform on OpenShift using the GitOps approach.

## Overview

The deployment process consists of 10 sequential steps, each managed by a GitHub Actions workflow.

## Deployment Steps

### Step 1: Deploy Infrastructure

**Workflow:** `01-deploy-infrastructure.yaml`

This creates all AWS infrastructure using Terraform:
- VPC with public/private subnets
- ROSA (Red Hat OpenShift on AWS) cluster
- ECR repositories for container images
- Route53 hosted zone
- AWS Secrets Manager secrets
- IAM roles for IRSA

```bash
# Run via GitHub Actions
# Navigate to Actions > 01-Deploy Infrastructure
# Select environment: dev
# Select action: plan (review first)
# Then run again with action: apply
```

**Duration:** ~45-60 minutes

**Post-deployment:**
1. Get the cluster admin password from Terraform outputs
2. Add it as `OPENSHIFT_ADMIN_PASSWORD` secret in GitHub

### Step 2: Configure Cluster

**Workflow:** `02-configure-cluster.yaml`

Applies OpenShift-specific configuration:
- Creates namespaces (confluent, confluent-operator)
- Applies Security Context Constraints
- Configures ECR pull secrets

**Duration:** ~5 minutes

### Step 3: Mirror Images

**Workflow:** `03-mirror-images.yaml`

Mirrors Confluent images from Docker Hub to ECR:
- cp-server (Kafka)
- cp-schema-registry
- cp-kafka-connect
- cp-ksqldb-server
- cp-control-center
- cp-kafka-rest
- confluent-init-container
- confluent-operator

**Duration:** ~15-20 minutes

### Step 4: Deploy External Secrets

**Workflow:** `04-deploy-external-secrets.yaml`

Installs External Secrets Operator and configures AWS Secrets Manager integration:
- Deploys ESO via Helm
- Creates IRSA-enabled ServiceAccount
- Configures SecretStore for AWS Secrets Manager
- Creates ExternalSecrets for Confluent credentials

**Duration:** ~5 minutes

### Step 5: Deploy ArgoCD

**Workflow:** `05-deploy-argocd.yaml`

Configures OpenShift GitOps (ArgoCD):
- Installs OpenShift GitOps Operator
- Configures ArgoCD instance
- Creates AppProject for Confluent
- Sets up Git repository credentials

**Duration:** ~10 minutes

**Post-deployment:**
- Access ArgoCD UI: Run `./scripts/get-argocd-password.sh`

### Step 6: Deploy CFK Operator

**Workflow:** `06-deploy-cfk-operator.yaml`

Installs Confluent for Kubernetes Operator:
- Deploys CFK via Helm
- Configures for OpenShift security model
- Grants SCC to operator ServiceAccount

**Duration:** ~5 minutes

### Step 7: Deploy cert-manager

**Workflow:** `07-deploy-cert-manager.yaml`

Installs cert-manager with Let's Encrypt:
- Deploys cert-manager via Helm
- Creates ClusterIssuer for Let's Encrypt
- Requests wildcard certificate

**Duration:** ~10 minutes

**Note:** Start with `staging` ACME server to avoid rate limits, then switch to `production` when ready.

### Step 8: Deploy Confluent Platform

**Workflow:** `08-deploy-confluent-platform.yaml`

Deploys all Confluent Platform components:
- KRaft Controller (3 replicas)
- Kafka (3 replicas)
- Schema Registry (2 replicas)
- Connect (2 replicas)
- ksqlDB (2 replicas)
- Control Center (1 replica)
- REST Proxy (2 replicas)

**Duration:** ~20-30 minutes

**Deployment order:**
1. KRaft Controller
2. Kafka (depends on KRaft)
3. Schema Registry (depends on Kafka)
4. Connect, ksqlDB, REST Proxy (depend on Kafka + SR)
5. Control Center (depends on all)

### Step 9: Deploy Routes

**Workflow:** `09-deploy-routes.yaml`

Creates OpenShift Routes for external access:
- Control Center
- Schema Registry
- Connect
- ksqlDB
- REST Proxy

**Duration:** ~2 minutes

### Step 10: Deploy Monitoring

**Workflow:** `10-deploy-monitoring.yaml`

Configures monitoring and alerting:
- Enables user workload monitoring
- Creates ServiceMonitors for all components
- Creates PrometheusRules for alerts

**Duration:** ~5 minutes

## Verification

After deployment, verify the cluster:

```bash
# Login to OpenShift
oc login <cluster-api-url> -u cluster-admin -p <password>

# Run validation script
./scripts/validate-cluster.sh

# Check all components are running
oc get kraftcontroller,kafka,schemaregistry,connect,ksqldb,controlcenter,kafkarestproxy -n confluent
```

## Accessing the Platform

### Control Center
```bash
# Get the route
oc get route controlcenter -n confluent -o jsonpath='{.spec.host}'
# Access: https://<route-host>
```

### ArgoCD
```bash
./scripts/get-argocd-password.sh
```

### OpenShift Console
```bash
# From Terraform outputs
terraform output cluster_console_url
```

## Updating the Deployment

### Via ArgoCD (Recommended)
1. Make changes to manifests in Git
2. Push to main branch
3. ArgoCD will automatically sync

### Manual Sync
```bash
argocd app sync confluent-platform-dev
```

## Rolling Back

### Via ArgoCD
1. Navigate to application in ArgoCD UI
2. Click "History and Rollback"
3. Select previous revision
4. Click "Rollback"

### Via kubectl
```bash
# Get revision history
oc rollout history deployment/kafka -n confluent

# Rollback to previous
oc rollout undo deployment/kafka -n confluent
```

## Scaling

### Horizontal Scaling
Edit the `replicas` field in the component manifests:

```yaml
spec:
  replicas: 5  # Increase Kafka brokers
```

### Vertical Scaling
Edit resource requests/limits:

```yaml
spec:
  podTemplate:
    resources:
      requests:
        cpu: "4"
        memory: 16Gi
      limits:
        cpu: "8"
        memory: 24Gi
```

## Next Steps

1. Configure authentication (SASL, RBAC)
2. Set up schema governance policies
3. Create topics and connectors
4. Configure backup and disaster recovery
5. Set up monitoring dashboards
