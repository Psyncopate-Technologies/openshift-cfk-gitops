# GitHub Actions Workflows

This directory contains the GitHub Actions workflows for deploying and managing Confluent Platform on ROSA.

## Quick Start (Minimal Cost Setup)

For a cost-effective test cluster (~$15-20/day), run these workflows in order:

1. **00-provision-rosa.yaml** - Create ROSA cluster (~35-45 min)
2. **02-configure-cluster.yaml** - Configure namespaces and SCCs
3. **06-deploy-cfk-operator.yaml** - Install CFK Operator
4. **08-deploy-confluent-platform.yaml** - Deploy Confluent Platform

**When done testing, run:**
- **100-deprovision-rosa.yaml** - Destroy cluster (stops charges!)

## Workflow Execution Order

### Provision & Deploy (Sequential)

| # | Workflow | Description | Duration |
|---|----------|-------------|----------|
| 00 | **provision-rosa** | Create ROSA cluster | ~40 min |
| 02 | **configure-cluster** | Namespaces, SCCs | ~2 min |
| 06 | **deploy-cfk-operator** | CFK Operator via Helm | ~5 min |
| 08 | **deploy-confluent-platform** | All CP components | ~15 min |

### Destroy (When Done)

| # | Workflow | Description |
|---|----------|-------------|
| 100 | **deprovision-rosa** | Delete ROSA cluster and cleanup |

## Required GitHub Secrets

Configure these secrets in your GitHub repository (Settings > Secrets > Actions):

| Secret | Description | How to Get |
|--------|-------------|------------|
| `AWS_ACCESS_KEY_ID` | AWS access key | AWS IAM Console |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | AWS IAM Console |
| `RHCS_TOKEN` | Red Hat Cloud Services token | [Get Token](https://cloud.redhat.com/openshift/token/rosa) |
| `OPENSHIFT_ADMIN_PASSWORD` | Cluster admin password | Created by workflow 00 |

### Getting the Secrets

#### AWS Credentials
1. Go to AWS IAM Console
2. Create a user with programmatic access
3. Attach policies: `AdministratorAccess` (or create custom policy)
4. Save the Access Key ID and Secret Access Key

#### RHCS Token
1. Go to https://cloud.redhat.com/openshift/token/rosa
2. Click "Load token" or "Generate token"
3. Copy the token value

#### OpenShift Admin Password
1. Run workflow **00-provision-rosa**
2. Check the workflow logs for the `rosa create admin` output
3. Copy the password and add it as `OPENSHIFT_ADMIN_PASSWORD` secret

## Workflow Details

### 00-provision-rosa.yaml
Creates a new ROSA cluster using the ROSA CLI.

**Inputs:**
- `cluster_name`: Name for the cluster (default: `cfk-test`)
- `environment`: Configuration profile (minimal, dev, staging, prod)
- `compute_nodes`: Number of worker nodes (default: 2)
- `instance_type`: EC2 instance type (default: m5.xlarge)
- `multi_az`: Multi-AZ deployment (default: false)

**Cost Estimates:**
| Config | Hourly | Daily |
|--------|--------|-------|
| minimal (2x m5.xlarge, single AZ) | ~$0.65 | ~$15 |
| dev (3x m5.xlarge, multi AZ) | ~$0.85 | ~$20 |

### 02-configure-cluster.yaml
Configures the cluster for Confluent Platform.

**Creates:**
- `confluent` namespace
- `confluent-operator` namespace
- `confluent-scc` SecurityContextConstraints
- Grants SCCs to service accounts

### 06-deploy-cfk-operator.yaml
Installs Confluent for Kubernetes operator via Helm.

**Inputs:**
- `cluster_name`: ROSA cluster name
- `cfk_version`: Helm chart version (default: 0.921.20)

### 08-deploy-confluent-platform.yaml
Deploys all Confluent Platform components.

**Components deployed:**
- KRaft Controller (3 replicas)
- Kafka (3 replicas)
- Schema Registry (1 replica)
- Connect (1 replica)
- ksqlDB (1 replica)
- Control Center (1 replica)
- REST Proxy (1 replica)

### 100-deprovision-rosa.yaml
Destroys the ROSA cluster and cleans up AWS resources.

**Inputs:**
- `cluster_name`: Cluster to delete
- `confirm_cluster_name`: Type cluster name again to confirm

**⚠️ IMPORTANT:** Run this when done testing to stop AWS charges!

## Cost Management

### Minimize Costs
1. Use `minimal` environment (2 nodes, single AZ)
2. Destroy cluster when not in use
3. Test during business hours only

### Example Testing Session
```
Morning:  Run 00-provision-rosa (~$0.50)
          Run 02, 06, 08 workflows
          Test for 4 hours (~$2.60)
Evening:  Run 100-deprovision-rosa

Total: ~$3-4 for a day of testing
```

## Troubleshooting

### "Cluster not found" error
- Check cluster name matches across workflows
- Verify cluster is in "ready" state: `rosa describe cluster -c <name>`

### OpenShift login fails
- Verify `OPENSHIFT_ADMIN_PASSWORD` secret is set
- Check cluster is accessible (not still provisioning)

### CFK Operator fails to install
- Ensure cluster configuration (workflow 02) completed successfully
- Check SCCs are applied: `oc get scc confluent-scc`

### Components stuck in "Provisioning"
- Check operator logs: `oc logs -n confluent-operator -l app=confluent-operator`
- Verify node resources: `oc describe nodes`
- Check events: `oc get events -n confluent --sort-by='.lastTimestamp'`
