# =============================================================================
# Environment Configuration
# =============================================================================

variable "environment" {
  description = "Environment name (dev, stg, prd, dr)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "stg", "prd", "dr"], var.environment)
    error_message = "Environment must be one of: dev, stg, prd, dr"
  }
}

# =============================================================================
# ROSA Cluster Variables
# =============================================================================

variable "cluster_name" {
  description = "Name of the ROSA cluster"
  type        = string
  default     = "cfk-test"
}

variable "openshift_version" {
  description = "OpenShift version for the ROSA cluster"
  type        = string
  default     = "4.20.0"
}

variable "aws_region" {
  description = "AWS region for the ROSA cluster"
  type        = string
  default     = "us-east-1"
}

# =============================================================================
# Compute Configuration
# =============================================================================

variable "compute_machine_type" {
  description = "EC2 instance type for compute nodes"
  type        = string
  default     = "m5.xlarge"
}

variable "compute_nodes" {
  description = "Number of compute nodes"
  type        = number
  default     = 2
}

variable "multi_az" {
  description = "Deploy cluster across multiple availability zones"
  type        = bool
  default     = false
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "machine_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "service_cidr" {
  description = "CIDR block for Kubernetes services"
  type        = string
  default     = "172.30.0.0/16"
}

variable "pod_cidr" {
  description = "CIDR block for pods"
  type        = string
  default     = "10.128.0.0/14"
}

variable "host_prefix" {
  description = "Host prefix for pod CIDR allocation"
  type        = number
  default     = 23
}

# =============================================================================
# Authentication
# =============================================================================

# RHCS service-account credentials — sole supported auth method.
# Create at https://console.redhat.com/iam/service-accounts.
# Red Hat deprecated offline tokens (their session times out after
# ~30 days of inactivity and refresh fails with `invalid_grant:
# Offline user session not found`), so this repo only authenticates
# via the OAuth2 client_credentials grant. The rhcs provider mints
# and refreshes the bearer token internally given these two values.
variable "rhcs_client_id" {
  description = "Red Hat Cloud Services service-account client ID (required)"
  type        = string
  sensitive   = true
}

variable "rhcs_client_secret" {
  description = "Red Hat Cloud Services service-account client secret (required)"
  type        = string
  sensitive   = true
}

variable "create_admin_user" {
  description = "Create cluster-admin user"
  type        = bool
  default     = true
}

variable "admin_password" {
  description = "Password for cluster-admin user (leave empty to auto-generate)"
  type        = string
  default     = "72WrS-SWWjy-RNZeD-ZYyIB"
  sensitive   = true
}

# =============================================================================
# Custom Domain
# =============================================================================

variable "custom_domain" {
  description = "Custom domain for Confluent Platform access (e.g., dev.confluent.psyncopate.io)"
  type        = string
  default     = ""
}

# =============================================================================
# Tags
# =============================================================================

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "confluent-platform"
    ManagedBy   = "terraform"
    Environment = "dev"
  }
}
