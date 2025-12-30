# Staging Environment Configuration

environment  = "staging"
cluster_name = "cfk-staging"
aws_region   = "us-east-1"

# VPC Configuration
vpc_cidr             = "10.1.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
private_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
public_subnet_cidrs  = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]

# ROSA Cluster Configuration
openshift_version    = "4.14.12"
compute_machine_type = "m5.2xlarge"
compute_replicas     = 3
multi_az             = true

# Confluent Machine Pool (enabled for staging)
enable_confluent_machine_pool = true
confluent_machine_type        = "m5.2xlarge"
confluent_replicas            = 3

# No spot instances for staging (needs stability)
use_spot_instances = false

# Domain Configuration
domain_name           = "example.com"  # Replace with your domain
create_route53_zone   = false
existing_route53_zone_id = ""  # Set if using existing zone

# Confluent Versions
confluent_platform_version = "8.0.1"
cfk_operator_version       = "2.10.0"

# Secrets
create_sample_secrets = true

# Tags
tags = {
  Team        = "platform"
  CostCenter  = "engineering"
  Environment = "staging"
}
