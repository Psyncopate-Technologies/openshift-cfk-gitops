# Minimal Cost ROSA Cluster Guide

This guide helps you create a cost-effective ROSA cluster for testing Confluent Platform.

## Cost Summary

| Configuration | Hourly | Daily | Monthly |
|--------------|--------|-------|---------|
| **Minimal (recommended)** | ~$0.65 | ~$15 | ~$450 |
| Standard 3-node | ~$0.85 | ~$20 | ~$600 |
| Production | ~$1.50 | ~$36 | ~$1,080 |

### Minimal Configuration Breakdown
| Resource | Hourly Cost |
|----------|-------------|
| ROSA cluster fee | $0.171 |
| 2x m5.xlarge (spot) | $0.26 (60% of on-demand) |
| NAT Gateway | $0.045 |
| EBS Storage (~100GB) | $0.01 |
| **Total** | **~$0.50-0.65/hr** |

## Quick Start

### Prerequisites

1. **AWS Account** with billing enabled
2. **Red Hat Account** at [cloud.redhat.com](https://cloud.redhat.com)
3. **ROSA enabled** on your AWS account

### Install Required Tools (macOS)

```bash
# AWS CLI
brew install awscli
aws configure  # Enter your AWS credentials

# ROSA CLI
brew install rosa-cli

# OpenShift CLI
brew install openshift-cli

# Helm
brew install helm
```

### Enable ROSA on AWS (One-time)

```bash
# Login to ROSA
# Get token from: https://cloud.redhat.com/openshift/token/rosa
rosa login --token=<your-token>

# Enable ROSA on AWS account
rosa verify quota
rosa verify permissions

# Create account roles (one-time)
rosa create account-roles --mode auto --yes
```

### Create Cluster

```bash
# Option 1: Use the script (recommended)
./scripts/create-minimal-rosa.sh cfk-test

# Option 2: Manual command
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

**Creation takes 30-45 minutes.**

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

This outputs login credentials. Save them!

### Login and Deploy Confluent

```bash
# Login with the credentials from above
oc login https://api.<cluster>.openshiftapps.com:6443 \
    --username=cluster-admin \
    --password=<password>

# Deploy Confluent Platform
./scripts/deploy-to-existing-cluster.sh
```

## IMPORTANT: Destroy When Done

**Don't forget to destroy the cluster to stop charges!**

```bash
# Option 1: Use the script
./scripts/destroy-rosa.sh cfk-test

# Option 2: Manual
rosa delete cluster --cluster=cfk-test --yes
rosa delete operator-roles -c cfk-test --mode auto --yes
rosa delete oidc-provider -c cfk-test --mode auto --yes
```

## Cost Optimization Tips

### 1. Use Spot Instances (saves ~40%)
The minimal config uses spot instances by default. Your cluster may be interrupted but saves significant cost.

### 2. Single Availability Zone
Using single AZ eliminates multiple NAT gateways (~$35/month savings).

### 3. Smaller Instance Types
| Type | vCPU | RAM | On-Demand | Spot |
|------|------|-----|-----------|------|
| m5.large | 2 | 8GB | $0.096/hr | $0.04/hr |
| m5.xlarge | 4 | 16GB | $0.192/hr | $0.08/hr |
| m5.2xlarge | 8 | 32GB | $0.384/hr | $0.15/hr |

**Note:** m5.xlarge is minimum recommended for Kafka.

### 4. Destroy When Not in Use
```bash
# Morning: Create
./scripts/create-minimal-rosa.sh cfk-test

# Evening: Destroy
./scripts/destroy-rosa.sh cfk-test
```

8-hour workday: ~$5-6/day instead of ~$15-20/day

### 5. Use AWS Free Tier (new accounts)
New AWS accounts get some free tier benefits that can offset costs.

## Testing Schedule Example

| Activity | Duration | Cost |
|----------|----------|------|
| Create cluster | 45 min | $0.50 |
| Deploy Confluent | 15 min | $0.15 |
| Testing | 4 hours | $2.60 |
| Destroy cluster | 15 min | $0.15 |
| **Total** | ~5.5 hours | **~$3.50** |

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

# Clean up manually if needed
aws cloudformation delete-stack --stack-name rosa-cfk-test-...
```

## Reference

- [ROSA Pricing](https://aws.amazon.com/rosa/pricing/)
- [ROSA Documentation](https://docs.openshift.com/rosa/)
- [EC2 Spot Pricing](https://aws.amazon.com/ec2/spot/pricing/)
