################################################################################
# ROSA Cluster
################################################################################

resource "rhcs_cluster_rosa_classic" "rosa" {
  name               = var.cluster_name
  cloud_region       = var.aws_region
  aws_account_id     = data.aws_caller_identity.current.account_id
  availability_zones = var.availability_zones

  # Compute configuration
  replicas             = var.compute_replicas
  compute_machine_type = var.compute_machine_type
  multi_az             = var.multi_az

  # VPC configuration
  aws_subnet_ids = concat(
    aws_subnet.private[*].id,
    aws_subnet.public[*].id
  )
  machine_cidr = var.vpc_cidr

  # OpenShift version
  version = var.openshift_version

  # Enable STS for IRSA
  sts = local.sts

  # Private cluster configuration (optional)
  aws_private_link = false
  private          = false

  # Proxy configuration (optional, for private clusters)
  # proxy = {
  #   http_proxy  = "http://proxy.example.com:3128"
  #   https_proxy = "http://proxy.example.com:3128"
  #   no_proxy    = ".cluster.local,.svc,localhost,127.0.0.1"
  # }

  # Wait for cluster to be ready
  wait_for_create_complete = true

  # Properties
  properties = {
    rosa_creator_arn = data.aws_caller_identity.current.arn
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = length(var.availability_zones) >= 1
      error_message = "At least one availability zone must be specified."
    }
  }

  depends_on = [
    aws_subnet.private,
    aws_subnet.public,
    module.rosa_account_roles
  ]
}

locals {
  sts = {
    role_arn         = module.rosa_account_roles.account_role_arns.Installer
    support_role_arn = module.rosa_account_roles.account_role_arns.Support
    instance_iam_roles = {
      master_role_arn = module.rosa_account_roles.account_role_arns.ControlPlane
      worker_role_arn = module.rosa_account_roles.account_role_arns.Worker
    }
    operator_role_prefix = var.cluster_name
    oidc_config_id       = rhcs_rosa_oidc_config.oidc_config.id
  }
}

################################################################################
# OIDC Configuration
################################################################################

resource "rhcs_rosa_oidc_config" "oidc_config" {
  managed = true
}

resource "rhcs_rosa_oidc_config_input" "oidc_input" {
  region = var.aws_region
}

################################################################################
# Cluster Admin User
################################################################################

resource "rhcs_cluster_rosa_classic_cluster_admin_user" "cluster_admin" {
  cluster_id = rhcs_cluster_rosa_classic.rosa.id
  username   = "cluster-admin"
}

################################################################################
# Machine Pool for Confluent Workloads (Optional)
################################################################################

resource "rhcs_machine_pool" "confluent" {
  count = var.enable_confluent_machine_pool ? 1 : 0

  cluster      = rhcs_cluster_rosa_classic.rosa.id
  name         = "confluent"
  machine_type = var.confluent_machine_type
  replicas     = var.confluent_replicas

  # Use spot instances for cost savings
  aws_node_pool = var.use_spot_instances ? {
    instance_type  = var.confluent_machine_type
    spot_max_price = null # Use on-demand price as max
  } : null

  labels = {
    "node-role.kubernetes.io/confluent" = ""
  }

  taints = [
    {
      key           = "confluent"
      value         = "true"
      schedule_type = "NoSchedule"
    }
  ]

  auto_scaling = {
    enabled  = false
    min      = var.confluent_replicas
    max      = var.confluent_replicas
  }
}

################################################################################
# Cluster Wait (ensures cluster is fully ready)
################################################################################

resource "null_resource" "wait_for_cluster" {
  depends_on = [rhcs_cluster_rosa_classic.rosa]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for ROSA cluster to be fully ready..."
      sleep 60
    EOT
  }
}
