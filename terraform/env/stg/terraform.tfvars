# =============================================================================
# Staging Environment - ROSA Cluster Configuration
# =============================================================================

environment = "stg"

# Cluster name (must be lowercase, start with letter)
cluster_name = "cfk-stg"

# OpenShift version
openshift_version = "4.20.0"

# AWS region
aws_region = "us-east-1"

# =============================================================================
# Compute Configuration (production-like for staging)
# =============================================================================

compute_machine_type = "m5.xlarge"
compute_nodes        = 3
multi_az             = true

# =============================================================================
# Network Configuration
# =============================================================================

machine_cidr = "10.1.0.0/16"
service_cidr = "172.31.0.0/16"
pod_cidr     = "10.132.0.0/14"
host_prefix  = 23

# =============================================================================
# Custom Domain
# =============================================================================

custom_domain = "stg.confluent.psyncopate.io"

# =============================================================================
# Tags
# =============================================================================

tags = {
  Project     = "confluent-platform"
  ManagedBy   = "terraform"
  Environment = "staging"
  CostCenter  = "engineering"
}
