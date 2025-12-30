# Minimal Cost ROSA Cluster for Testing
# Estimated cost: ~$15-20/day (~$0.60-0.85/hour)
#
# Cost breakdown:
#   - ROSA cluster fee: $0.171/hr = ~$4.10/day
#   - 2x m5.xlarge (4 vCPU, 16GB): $0.192/hr each = ~$9.20/day
#   - Single NAT Gateway: $0.045/hr + data = ~$1.50/day
#   - EBS storage: ~$0.50/day
#   Total: ~$15-20/day
#
# To minimize costs:
#   1. Deploy in morning, destroy in evening
#   2. Use spot instances (saves ~40% on compute)
#   3. Destroy when not in use: terraform destroy

environment  = "minimal"
cluster_name = "cfk-minimal"
aws_region   = "us-east-1"

# VPC Configuration - Single AZ to reduce NAT costs
vpc_cidr             = "10.10.0.0/16"
availability_zones   = ["us-east-1a"]  # Single AZ
private_subnet_cidrs = ["10.10.1.0/24"]
public_subnet_cidrs  = ["10.10.101.0/24"]

# ROSA Cluster - Minimal viable config
openshift_version    = "4.14.12"
compute_machine_type = "m5.xlarge"  # 4 vCPU, 16GB - minimum for Kafka
compute_replicas     = 2            # Minimum for HA
multi_az             = false        # Single AZ saves NAT costs

# No dedicated Confluent machine pool (use shared workers)
enable_confluent_machine_pool = false

# SPOT INSTANCES - Saves ~40% on compute!
use_spot_instances = true

# Domain - Use a subdomain you control
domain_name         = "example.com"  # CHANGE THIS
create_route53_zone = true

# Confluent Versions
confluent_platform_version = "7.7.1"
cfk_operator_version       = "2.10.0"

# Create placeholder secrets
create_sample_secrets = false  # Skip to reduce Secrets Manager costs

# Tags
tags = {
  Purpose     = "testing"
  Environment = "minimal"
  CostCenter  = "development"
}
