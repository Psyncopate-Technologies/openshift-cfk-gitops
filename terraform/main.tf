# =============================================================================
# Provider Configuration
# =============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

provider "rhcs" {
  client_id     = var.rhcs_client_id
  client_secret = var.rhcs_client_secret
}

# =============================================================================
# Data Sources
# =============================================================================

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# =============================================================================
# ROSA Classic Cluster (with integrated account roles, operator roles, OIDC)
# =============================================================================

module "rosa_cluster" {
  source  = "terraform-redhat/rosa-classic/rhcs"
  version = "1.7.1"

  # Cluster configuration
  cluster_name      = var.cluster_name
  openshift_version = var.openshift_version

  # Automatically create IAM resources
  create_account_roles  = true
  create_operator_roles = true
  create_oidc           = true

  # Account role configuration
  account_role_prefix = var.cluster_name

  # Compute configuration
  compute_machine_type   = var.compute_machine_type
  replicas               = var.compute_nodes
  multi_az               = var.multi_az
  aws_availability_zones = var.multi_az ? slice(data.aws_availability_zones.available.names, 0, 3) : [data.aws_availability_zones.available.names[0]]

  # Network configuration
  machine_cidr = var.machine_cidr
  service_cidr = var.service_cidr
  pod_cidr     = var.pod_cidr
  host_prefix  = var.host_prefix

  # Admin user
  create_admin_user          = var.create_admin_user
  admin_credentials_username = var.create_admin_user ? "cluster-admin" : null
  admin_credentials_password = var.create_admin_user ? var.admin_password : null

  # Tags
  tags = var.tags
}
