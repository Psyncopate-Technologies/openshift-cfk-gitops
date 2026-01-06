# Minimal Cost ROSA Cluster Guide

This guide helps you create a cost-effective ROSA cluster for testing Confluent Platform.

## Cost Summary

| Configuration | Hourly | Daily | Monthly |
|--------------|--------|-------|---------|
| **Minimal (recommended for testing)** | ~$0.65 | ~$15 | ~$450 |
| Standard 3-node | ~$0.85 | ~$20 | ~$600 |
| Production | ~$1.50 | ~$36 | ~$1,080 |

### Minimal Configuration Breakdown

| Resource | Hourly Cost |
|----------|-------------|
| ROSA cluster fee | $0.171 |
| 2x m5.xlarge (on-demand) | $0.384 |
| NAT Gateway | $0.045 |
| EBS Storage (~100GB) | $0.01 |
| **Total** | **~$0.60-0.65/hr** |

## Quick Start (GitHub Actions)

The recommended approach is to use the GitHub Actions workflows:

### Prerequisites

1. **GitHub Secrets configured** (see [PREREQUISITES.md](PREREQUISITES.md)):
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `RHCS_TOKEN`
   - `OPENSHIFT_ADMIN_PASSWORD`

2. **Red Hat terms accepted** at https://console.redhat.com/openshift

### Create Cluster

1. Go to **Actions** → **01-Provision ROSA (Terraform)**
2. Select environment: **dev** (minimal configuration)
3. Select action: **apply**
4. Run the workflow

**Creation takes 35-45 minutes.**

### Deploy Confluent Platform

After cluster provisioning, run workflows in order:
1. **02-Configure Cluster**
2. **03-Install ArgoCD**
3. **04-Deploy CFK Operator**
4. **05-Deploy Confluent Platform**

### Destroy Cluster (Important!)

When done testing, run **99-Deprovision ROSA** to stop charges!

## Manual CLI Approach

For manual cluster creation without GitHub Actions:

### Prerequisites

```bash
# Install tools (macOS)
brew install awscli rosa-cli openshift-cli helm

# Configure AWS
aws configure

# Login to ROSA
# Get token from: https://console.redhat.com/openshift/token/rosa
rosa login --token=<your-token>

# Verify prerequisites
rosa verify quota
rosa verify permissions

# Create account roles (one-time)
rosa create account-roles --mode auto --yes
```

### Create Cluster

```bash
rosa create cluster \
    --cluster-name=cfk-test \
    --region=us-east-1 \
    --compute-nodes=2 \
    --compute-machine-type=m5.xlarge \
    --multi-az=false \
    --sts \
    --mode=auto \
    --yes
```

### Monitor Progress

```bash
# Watch installation logs
rosa logs install --cluster=cfk-test --watch

# Check status
rosa describe cluster --cluster=cfk-test
```

### Create Admin User

```bash
rosa create admin --cluster=cfk-test
```

Save the credentials output!

### Login and Deploy

```bash
# Login with the credentials from above
oc login https://api.<cluster>.openshiftapps.com:6443 \
    --username=cluster-admin \
    --password=<password>

# Follow manual deployment steps in EXISTING-CLUSTER-SETUP.md
```

## IMPORTANT: Destroy When Done

**Don't forget to destroy the cluster to stop charges!**

### Via GitHub Actions

Run **99-Deprovision ROSA** workflow.

### Via CLI

```bash
rosa delete cluster --cluster=cfk-test --yes --watch
rosa delete operator-roles -c cfk-test --mode auto --yes
rosa delete oidc-provider -c cfk-test --mode auto --yes
```

## Cost Optimization Tips

### 1. Single Availability Zone

The dev environment uses single AZ, eliminating multiple NAT gateways (~$35/month savings).

### 2. Minimal Instance Types

| Type | vCPU | RAM | On-Demand |
|------|------|-----|-----------|
| m5.large | 2 | 8GB | $0.096/hr |
| m5.xlarge | 4 | 16GB | $0.192/hr |
| m5.2xlarge | 8 | 32GB | $0.384/hr |

**Note:** m5.xlarge is minimum recommended for Kafka.

### 3. Destroy When Not in Use

```
Morning: Create cluster via workflow 01
         Deploy Confluent via workflows 02-05
         Test for 4-8 hours
Evening: Destroy via workflow 99

Cost: ~$5-8/day instead of ~$15-20/day
```

### 4. Use Dev Environment

The dev environment in this project is optimized for minimal cost:
- 2 worker nodes (not 3)
- Single AZ (not multi-AZ)
- m5.xlarge instances

## Testing Schedule Examples

### Quick Test (~$3-4)

| Activity | Duration | Cost |
|----------|----------|------|
| Create cluster | 45 min | $0.50 |
| Deploy Confluent | 15 min | $0.15 |
| Testing | 4 hours | $2.60 |
| Destroy cluster | 15 min | $0.15 |
| **Total** | ~5.5 hours | **~$3.50** |

### Full Day Development (~$8-10)

```
9 AM:     Run 01-provision-rosa (~40 min)
10 AM:    Run 02, 03, 04, 05 workflows
          Develop and test all day
6 PM:     Run 99-deprovision-rosa

Cost: ~8 hours × $0.65/hour + provisioning = ~$8
```

### Weekly Sprint (~$40-50)

```
Monday:   Provision cluster in morning
Mon-Fri:  Use during business hours (destroy each evening)
Friday:   Final deprovision

Cost: 5 days × ~$8/day = ~$40
```

## Troubleshooting

### "Quota exceeded"

```bash
rosa verify quota --region=us-east-1
```

Request quota increase in AWS console for EC2 instances.

### "Permission denied"

```bash
rosa verify permissions
```

Ensure your AWS user has required permissions.

### "Legal terms not accepted"

Visit https://console.redhat.com/openshift and accept terms.

### Cluster stuck in "Installing"

```bash
rosa logs install --cluster=cfk-test --watch
```

Check for errors. Common issues:
- VPC/subnet conflicts
- IAM role issues
- Quota limits

### Can't delete cluster

```bash
# Force delete
rosa delete cluster --cluster=cfk-test --yes --watch

# Clean up operator roles
rosa delete operator-roles -c cfk-test --mode auto --yes
rosa delete oidc-provider -c cfk-test --mode auto --yes
```

## Reference

- [ROSA Pricing](https://aws.amazon.com/rosa/pricing/)
- [ROSA Documentation](https://docs.openshift.com/rosa/)
- [EC2 Instance Types](https://aws.amazon.com/ec2/instance-types/)
- [ROSA CLI Cheatsheet](ROSA-OC-CHEATSHEET.md)
