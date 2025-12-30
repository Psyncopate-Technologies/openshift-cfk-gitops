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
  token = var.rhcs_token
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
# Account Roles (STS)
# =============================================================================

module "account_roles" {
  source  = "terraform-redhat/rosa-sts/aws//modules/account-iam-resources"
  version = "0.0.19"

  account_role_prefix = var.cluster_name
  openshift_version   = var.openshift_version
  tags                = var.tags
}

# =============================================================================
# Operator Roles
# =============================================================================

module "operator_roles" {
  source  = "terraform-redhat/rosa-sts/aws//modules/operator-roles"
  version = "0.0.19"

  cluster_id                  = rhcs_cluster_rosa_classic.cluster.id
  operator_role_prefix        = var.cluster_name
  account_role_prefix         = module.account_roles.account_role_prefix
  oidc_endpoint_url           = rhcs_cluster_rosa_classic.cluster.sts.oidc_endpoint_url
  tags                        = var.tags

  depends_on = [module.account_roles]
}

# =============================================================================
# OIDC Provider
# =============================================================================

module "oidc_provider" {
  source  = "terraform-redhat/rosa-sts/aws//modules/oidc-provider"
  version = "0.0.19"

  cluster_id = rhcs_cluster_rosa_classic.cluster.id
  tags       = var.tags
}

# =============================================================================
# ROSA Cluster
# =============================================================================

resource "rhcs_cluster_rosa_classic" "cluster" {
  name               = var.cluster_name
  cloud_region       = var.aws_region
  aws_account_id     = data.aws_caller_identity.current.account_id
  version            = "openshift-v${var.openshift_version}"

  # Compute configuration
  compute_machine_type = var.compute_machine_type
  replicas             = var.compute_nodes
  multi_az             = var.multi_az
  availability_zones   = var.multi_az ? slice(data.aws_availability_zones.available.names, 0, 3) : [data.aws_availability_zones.available.names[0]]

  # Network configuration
  machine_cidr = var.machine_cidr
  service_cidr = var.service_cidr
  pod_cidr     = var.pod_cidr
  host_prefix  = var.host_prefix

  # STS configuration
  sts = {
    role_arn         = module.account_roles.account_roles_arn["Installer"]
    support_role_arn = module.account_roles.account_roles_arn["Support"]
    instance_iam_roles = {
      master_role_arn = module.account_roles.account_roles_arn["ControlPlane"]
      worker_role_arn = module.account_roles.account_roles_arn["Worker"]
    }
    operator_role_prefix = var.cluster_name
  }

  properties = {
    rosa_creator_arn = data.aws_caller_identity.current.arn
  }

  # Wait for cluster to be ready
  wait_for_create_complete = true

  depends_on = [module.account_roles]

  lifecycle {
    precondition {
      condition     = can(regex("^[a-z][-a-z0-9]*[a-z0-9]$", var.cluster_name))
      error_message = "Cluster name must start with a letter, contain only lowercase letters, numbers, and hyphens."
    }
  }
}

# =============================================================================
# Cluster Admin User
# =============================================================================

resource "random_password" "admin" {
  count   = var.create_admin_user && var.admin_password == "" ? 1 : 0
  length  = 16
  special = true
}

resource "rhcs_cluster_rosa_classic_idp" "htpasswd" {
  count      = var.create_admin_user ? 1 : 0
  cluster    = rhcs_cluster_rosa_classic.cluster.id
  name       = "cluster-admin"
  type       = "htpasswd"

  htpasswd = {
    users = [{
      username = "cluster-admin"
      password = var.admin_password != "" ? var.admin_password : random_password.admin[0].result
    }]
  }
}

# Grant cluster-admin role
resource "null_resource" "grant_admin" {
  count = var.create_admin_user ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for IDP to be ready
      sleep 60

      # Login to cluster
      oc login "${rhcs_cluster_rosa_classic.cluster.api_url}" \
        --username=cluster-admin \
        --password="${var.admin_password != "" ? var.admin_password : random_password.admin[0].result}" \
        --insecure-skip-tls-verify=true || true

      # Grant cluster-admin role
      oc adm policy add-cluster-role-to-user cluster-admin cluster-admin || true
    EOT
  }

  depends_on = [
    rhcs_cluster_rosa_classic_idp.htpasswd,
    module.operator_roles,
    module.oidc_provider
  ]
}

# =============================================================================
# Wait for Cluster to be Ready
# =============================================================================

resource "time_sleep" "wait_for_cluster" {
  depends_on = [
    rhcs_cluster_rosa_classic.cluster,
    module.operator_roles,
    module.oidc_provider
  ]

  create_duration = "5m"
}
