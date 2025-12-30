# Cost Optimization Guide

This guide provides strategies for optimizing costs when running Confluent Platform on ROSA.

## Base Cost Breakdown

### Standard 3-Node Cluster (On-Demand)

| Resource | Monthly Cost |
|----------|-------------|
| ROSA cluster fee | ~$125 |
| 3x m5.2xlarge (8 vCPU, 32GB) | ~$350 |
| NAT Gateway | ~$35 |
| ECR storage | ~$5 |
| Route53 | ~$1 |
| Secrets Manager | ~$5 |
| **Total** | **~$520/month** |

## Cost Reduction Strategies

### 1. Use Spot Instances (~40% savings)

Enable spot instances in Terraform:

```hcl
# environments/dev.tfvars
use_spot_instances = true
```

**Savings:** ~$140/month on compute

**Considerations:**
- Only for dev/staging environments
- Spot instances may be interrupted
- Configure pod disruption budgets

### 2. Right-Size Instances

#### Development Environment
Use smaller instances for dev:

```hcl
# environments/dev.tfvars
compute_machine_type = "m5.xlarge"  # 4 vCPU, 16GB
compute_replicas     = 2            # Reduce to 2 nodes
```

**Savings:** ~$200/month

#### Confluent Component Sizing
Reduce resource requests for dev:

```yaml
# environments/dev/platform/kafka.yaml
spec:
  podTemplate:
    resources:
      requests:
        cpu: "1"
        memory: 4Gi
      limits:
        cpu: "2"
        memory: 6Gi
```

### 3. Single NAT Gateway

For dev environments, use a single NAT Gateway:

```hcl
# variables.tf
multi_az = false  # Single NAT Gateway
```

**Savings:** ~$70/month (if using 3 NAT gateways)

### 4. Reserved Instances

For production workloads, consider:
- 1-year reserved: ~30% savings
- 3-year reserved: ~60% savings

Calculate break-even:
- 1-year RI pays off after ~5 months
- 3-year RI pays off after ~14 months

### 5. Scheduled Scaling

For non-production environments, scale down during off-hours:

```bash
# Scale down script (run via cron or scheduled workflow)
#!/bin/bash
# Scale Confluent components to 0
oc scale kafka kafka -n confluent --replicas=0
oc scale kraftcontroller kraftcontroller -n confluent --replicas=0
oc scale schemaregistry schemaregistry -n confluent --replicas=0
# ... etc
```

**Savings:** Up to 66% if running 8 hours/day

### 6. Delete Unused Environments

Implement automatic cleanup:

```yaml
# .github/workflows/scheduled-cleanup.yaml
name: Scheduled Cleanup
on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday
jobs:
  check-and-cleanup:
    # Check for stale dev environments
    # Delete if no activity in 7 days
```

## Cost Monitoring

### Enable AWS Cost Explorer

1. Navigate to AWS Cost Explorer
2. Create cost allocation tags:
   - `Project: openshift-cfk-gitops`
   - `Environment: dev/staging/prod`

### Set Up Budget Alerts

```hcl
# Add to Terraform
resource "aws_budgets_budget" "monthly" {
  name         = "openshift-cfk-${var.environment}"
  budget_type  = "COST"
  limit_amount = "600"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator = "GREATER_THAN"
    threshold           = 80
    threshold_type      = "PERCENTAGE"
    notification_type   = "FORECASTED"
    subscriber_email_addresses = ["team@example.com"]
  }
}
```

## Environment-Specific Configurations

### Development (~$200-300/month)
```hcl
# environments/dev.tfvars
compute_machine_type = "m5.xlarge"
compute_replicas     = 2
use_spot_instances   = true
multi_az             = false
enable_confluent_machine_pool = false
```

### Staging (~$400-500/month)
```hcl
# environments/staging.tfvars
compute_machine_type = "m5.2xlarge"
compute_replicas     = 3
use_spot_instances   = false
multi_az             = true
enable_confluent_machine_pool = false
```

### Production (~$800-1000/month)
```hcl
# environments/prod.tfvars
compute_machine_type = "m5.4xlarge"
compute_replicas     = 3
use_spot_instances   = false
multi_az             = true
enable_confluent_machine_pool = true
```

## Cleanup Checklist

When destroying an environment, ensure all resources are cleaned:

1. [ ] Confluent Platform components
2. [ ] PersistentVolumeClaims (EBS volumes)
3. [ ] Load Balancers (from Routes/Services)
4. [ ] ECR images (if not shared)
5. [ ] Secrets Manager secrets
6. [ ] Route53 records
7. [ ] ROSA cluster
8. [ ] VPC and networking
9. [ ] Terraform state files

## Summary

| Strategy | Dev Savings | Prod Applicability |
|----------|-------------|-------------------|
| Spot instances | ~$140/month | No |
| Smaller instances | ~$200/month | Limited |
| Single NAT | ~$70/month | No |
| Reserved instances | - | ~$200/month |
| Scheduled scaling | ~$300/month | No |

**Total potential dev savings: ~$300-400/month (60-70%)**
