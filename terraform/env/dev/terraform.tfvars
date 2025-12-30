# =============================================================================
# Development Environment - ROSA Cluster Configuration
# =============================================================================

environment = "dev"

# Cluster name (must be lowercase, start with letter)
cluster_name = "cfk-dev"

# OpenShift version
openshift_version = "4.20.0"

# AWS region
aws_region = "us-east-1"

# =============================================================================
# Compute Configuration (minimal for dev)
# =============================================================================

compute_machine_type = "m5.xlarge"
compute_nodes        = 2
multi_az             = false

# =============================================================================
# Network Configuration
# =============================================================================

machine_cidr = "10.0.0.0/16"
service_cidr = "172.30.0.0/16"
pod_cidr     = "10.128.0.0/14"
host_prefix  = 23

# =============================================================================
# Custom Domain
# =============================================================================

custom_domain = "dev.confluent.psyncopate.io"

# =============================================================================
# Tags
# =============================================================================

tags = {
  Project     = "confluent-platform"
  ManagedBy   = "terraform"
  Environment = "dev"
  CostCenter  = "engineering"
}
