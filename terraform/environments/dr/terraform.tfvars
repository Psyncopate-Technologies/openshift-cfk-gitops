# =============================================================================
# Disaster Recovery Environment - ROSA Cluster Configuration
# =============================================================================

environment = "dr"

# Cluster name (must be lowercase, start with letter)
cluster_name = "cfk-dr"

# OpenShift version (match production)
openshift_version = "4.14.0"

# AWS region (different region from production for DR)
aws_region = "us-west-2"

# =============================================================================
# Compute Configuration (match production capacity)
# =============================================================================

compute_machine_type = "m5.2xlarge"
compute_nodes        = 3
multi_az             = true

# =============================================================================
# Network Configuration (non-overlapping with production)
# =============================================================================

machine_cidr = "10.3.0.0/16"
service_cidr = "172.33.0.0/16"
pod_cidr     = "10.140.0.0/14"
host_prefix  = 23

# =============================================================================
# Custom Domain
# =============================================================================

custom_domain = "dr.confluent.psyncopate.io"

# =============================================================================
# Tags
# =============================================================================

tags = {
  Project     = "confluent-platform"
  ManagedBy   = "terraform"
  Environment = "disaster-recovery"
  CostCenter  = "operations"
  Criticality = "high"
  PairedWith  = "cfk-prd"
}
