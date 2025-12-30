# =============================================================================
# Production Environment - ROSA Cluster Configuration
# =============================================================================

environment = "prd"

# Cluster name (must be lowercase, start with letter)
cluster_name = "cfk-prd"

# OpenShift version
openshift_version = "4.20.0"

# AWS region (primary production region)
aws_region = "us-east-1"

# =============================================================================
# Compute Configuration (production-grade)
# =============================================================================

compute_machine_type = "m5.2xlarge"
compute_nodes        = 3
multi_az             = true

# =============================================================================
# Network Configuration
# =============================================================================

machine_cidr = "10.2.0.0/16"
service_cidr = "172.32.0.0/16"
pod_cidr     = "10.136.0.0/14"
host_prefix  = 23

# =============================================================================
# Custom Domain
# =============================================================================

custom_domain = "prd.confluent.psyncopate.io"

# =============================================================================
# Tags
# =============================================================================

tags = {
  Project     = "confluent-platform"
  ManagedBy   = "terraform"
  Environment = "production"
  CostCenter  = "operations"
  Criticality = "high"
}
