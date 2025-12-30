# Development Environment Configuration

environment  = "dev"
cluster_name = "cfk-dev"
aws_region   = "us-east-1"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# ROSA Cluster Configuration
openshift_version    = "4.14.12"
compute_machine_type = "m5.2xlarge"
compute_replicas     = 3
multi_az             = true

# Confluent Machine Pool (disabled for dev to save costs)
enable_confluent_machine_pool = false
confluent_machine_type        = "m5.2xlarge"
confluent_replicas            = 3

# Cost savings for dev
use_spot_instances = false  # Set to true for additional savings

# Domain Configuration
domain_name           = "example.com"  # Replace with your domain
create_route53_zone   = true

# Confluent Versions
confluent_platform_version = "8.0.1"
cfk_operator_version       = "2.10.0"

# Secrets
create_sample_secrets = true

# Tags
tags = {
  Team        = "platform"
  CostCenter  = "engineering"
  Environment = "development"
}
