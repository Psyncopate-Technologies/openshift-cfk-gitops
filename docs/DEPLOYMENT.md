# Deployment Guide

This guide walks through deploying Confluent Platform on OpenShift using GitHub Actions workflows.

## Overview

The deployment consists of 4 sequential workflows, plus a cleanup workflow.

## Deployment Steps

### Step 1: Provision ROSA Cluster

**Workflow:** `01-provision-rosa.yaml`

Creates a new ROSA cluster using the ROSA CLI.

**Inputs:**
- `cluster_name`: Name for the cluster (default: `cfk-test`)
- `environment`: Configuration profile (minimal, dev, staging, prod)
- `compute_nodes`: Number of worker nodes (default: 2)
- `instance_type`: EC2 instance type (default: m5.xlarge)
- `multi_az`: Multi-AZ deployment (default: false)

**Duration:** ~35-45 minutes

**Post-deployment:**
1. Check the workflow logs for the `rosa create admin` output
2. Copy the admin password
3. Add it as `OPENSHIFT_ADMIN_PASSWORD` secret in GitHub

### Step 2: Configure Cluster

**Workflow:** `02-configure-cluster.yaml`

Configures the cluster for Confluent Platform:
- Creates `confluent` namespace
- Creates `confluent-operator` namespace
- Applies `confluent-scc` SecurityContextConstraints
- Grants SCCs to service accounts

**Inputs:**
- `cluster_name`: ROSA cluster name
- `environment`: Environment to configure

**Duration:** ~2 minutes

### Step 3: Deploy CFK Operator

**Workflow:** `03-deploy-cfk-operator.yaml`

Installs Confluent for Kubernetes Operator via Helm:
- Deploys CFK from Confluent Helm repository
- Configures for OpenShift security model
- Grants SCC to operator ServiceAccount

**Inputs:**
- `cluster_name`: ROSA cluster name
- `cfk_version`: Helm chart version (default: 0.921.20)

**Duration:** ~5 minutes

### Step 4: Deploy Confluent Platform

**Workflow:** `04-deploy-confluent-platform.yaml`

Deploys all Confluent Platform components:
- KRaft Controller (3 replicas)
- Kafka (3 replicas)
- Schema Registry (1 replica)
- Connect (1 replica)
- ksqlDB (1 replica)
- Control Center (1 replica)
- REST Proxy (1 replica)

**Inputs:**
- `cluster_name`: ROSA cluster name

**Duration:** ~15-20 minutes

**Deployment order:**
1. KRaft Controller starts first
2. Kafka brokers connect to KRaft
3. Schema Registry, Connect, ksqlDB, REST Proxy start
4. Control Center starts last (depends on all components)

## Cleanup

### Deprovision ROSA Cluster

**Workflow:** `99-deprovision-rosa.yaml`

Destroys the ROSA cluster and cleans up AWS resources:
- Deletes the ROSA cluster
- Removes operator roles
- Deletes OIDC provider
- Cleans up orphaned CloudFormation stacks

**Inputs:**
- `cluster_name`: Cluster to delete
- `confirm_cluster_name`: Type cluster name again to confirm (safety check)

**Duration:** ~15-20 minutes

**Important:** Run this workflow when done testing to stop AWS charges!

## Verification

After deployment, verify the cluster status in the workflow summary or manually:

```bash
# Login to OpenShift
oc login <cluster-api-url> -u cluster-admin -p <password>

# Check all components are running
oc get kraftcontroller,kafka,schemaregistry,connect,ksqldb,controlcenter,kafkarestproxy -n confluent

# Check pods
oc get pods -n confluent

# Check routes
oc get routes -n confluent
```

## Accessing the Platform

Access URLs are provided in the workflow summary after deployment:

| Component | URL Pattern |
|-----------|-------------|
| Control Center | `https://controlcenter.<apps-domain>` |
| Schema Registry | `https://schemaregistry.<apps-domain>` |
| Connect | `https://connect.<apps-domain>` |
| ksqlDB | `https://ksqldb.<apps-domain>` |
| REST Proxy | `https://kafkarestproxy.<apps-domain>` |

The `<apps-domain>` is shown in the workflow output (e.g., `apps.cfk-test.abcd.p1.openshiftapps.com`).

## Scaling

### Horizontal Scaling
Edit the component manifests in `environments/dev/platform-dockerhub/`:

```yaml
spec:
  replicas: 5  # Increase Kafka brokers
```

Then re-run workflow 04 to apply changes.

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
