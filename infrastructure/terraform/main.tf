################################################################################
# OpenShift CFK GitOps - Main Terraform Configuration
################################################################################

# This is the main entry point for the Terraform configuration.
# It orchestrates all the modules and resources required to deploy
# a ROSA cluster with supporting AWS infrastructure for Confluent Platform.

################################################################################
# Local Variables
################################################################################

locals {
  # Common naming convention
  name_prefix = "${var.cluster_name}-${var.environment}"

  # ECR registry URL
  ecr_registry_url = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"

  # Common tags
  common_tags = merge(var.tags, {
    Project     = "openshift-cfk-gitops"
    Environment = var.environment
    Cluster     = var.cluster_name
  })
}

################################################################################
# Random Suffix for Unique Naming
################################################################################

resource "random_id" "suffix" {
  byte_length = 4
}
