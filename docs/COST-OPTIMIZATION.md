# Cost Optimization Guide

This guide provides strategies for optimizing costs when running Confluent Platform on ROSA.

## Base Cost Breakdown

### Minimal Configuration (Single AZ)

| Resource | Hourly | Daily |
|----------|--------|-------|
| ROSA cluster fee | ~$0.171 | ~$4.10 |
| 2x m5.xlarge (4 vCPU, 16GB each) | ~$0.48 | ~$11.50 |
| EBS volumes (~100GB) | ~$0.01 | ~$0.30 |
| **Total** | **~$0.65** | **~$15-16** |

### Development Configuration (Multi-AZ)

| Resource | Hourly | Daily |
|----------|--------|-------|
| ROSA cluster fee | ~$0.171 | ~$4.10 |
| 3x m5.xlarge | ~$0.72 | ~$17.30 |
| NAT Gateways (multi-AZ) | ~$0.05 | ~$1.20 |
| EBS volumes | ~$0.02 | ~$0.50 |
| **Total** | **~$0.85** | **~$20-23** |

## Cost Reduction Strategies

### 1. Use Minimal Configuration

For testing and development, use the minimal configuration:
- 2 worker nodes (single AZ)
- m5.xlarge instance type
- No multi-AZ (saves NAT Gateway costs)

```
Workflow inputs:
- compute_nodes: 2
- instance_type: m5.xlarge
- multi_az: false
```

### 2. Destroy When Not In Use

**Most important cost saver!**

Run `99-deprovision-rosa` workflow when done testing. A cluster running 24/7 costs ~$450-600/month. Running only during business hours (8 hours/day, weekdays) reduces cost to ~$100-150/month.

### 3. Right-Size Confluent Components

For development/testing, reduce replicas in `environments/dev/platform-dockerhub/`:

```yaml
# Reduce Kafka brokers
spec:
  replicas: 1  # Instead of 3

# Reduce KRaft controllers
spec:
  replicas: 1  # Instead of 3
```

**Note:** Single replica configurations are not suitable for production.

### 4. Reduce Resource Requests

Lower resource requests for dev environments:

```yaml
spec:
  podTemplate:
    resources:
      requests:
        cpu: "500m"
        memory: 2Gi
      limits:
        cpu: "1"
        memory: 4Gi
```

### 5. Use Smaller Instance Types

For minimal testing with reduced components:

```
instance_type: m5.large  # 2 vCPU, 8GB (~$0.096/hour)
```

**Note:** May not be sufficient for full Confluent Platform deployment.

## Example Testing Sessions

### Quick Test (~$3-4)
```
Morning:  Run 01-provision-rosa
          Run 02, 03, 04 workflows
          Test for 4 hours
Evening:  Run 99-deprovision-rosa

Cost: ~4 hours × $0.65/hour = ~$2.60 + provisioning time
```

### Full Day Development (~$8-10)
```
9 AM:     Run 01-provision-rosa (~40 min)
10 AM:    Run 02, 03, 04 workflows
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

## Cost Monitoring

### AWS Cost Explorer

1. Navigate to AWS Cost Explorer
2. Filter by service: EC2, ROSA
3. Group by tag or resource

### Budget Alerts

Set up AWS Budgets to alert on spending:

1. Go to AWS Budgets
2. Create budget with daily/monthly threshold
3. Set alert at 80% of budget

## Comparison: ROSA vs Other Options

| Option | Monthly Cost | Notes |
|--------|-------------|-------|
| ROSA (minimal, 8hr/day) | ~$100-150 | Best for intermittent use |
| ROSA (24/7 minimal) | ~$450-500 | Simple management |
| Self-managed OpenShift | ~$300-400 | More operational overhead |
| EKS + CFK | ~$250-350 | No OpenShift features |

## Summary

| Strategy | Savings |
|----------|---------|
| Destroy when not in use | Up to 70% |
| Single AZ (dev only) | ~$30-50/month |
| Smaller instances | ~20-30% |
| Reduced replicas | Minimal (compute bound) |

**Key takeaway:** The single most effective cost optimization is destroying the cluster when not actively testing. A cluster left running over a weekend costs ~$30-40 unnecessarily.
