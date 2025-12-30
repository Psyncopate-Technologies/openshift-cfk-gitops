################################################################################
# Cluster Outputs
################################################################################

output "cluster_id" {
  description = "ROSA cluster ID"
  value       = rhcs_cluster_rosa_classic.rosa.id
}

output "cluster_name" {
  description = "ROSA cluster name"
  value       = rhcs_cluster_rosa_classic.rosa.name
}

output "cluster_api_url" {
  description = "OpenShift API server URL"
  value       = rhcs_cluster_rosa_classic.rosa.api_url
}

output "cluster_console_url" {
  description = "OpenShift console URL"
  value       = rhcs_cluster_rosa_classic.rosa.console_url
}

output "cluster_domain" {
  description = "OpenShift cluster domain"
  value       = rhcs_cluster_rosa_classic.rosa.domain
}

output "cluster_version" {
  description = "OpenShift version"
  value       = rhcs_cluster_rosa_classic.rosa.current_version
}

################################################################################
# OIDC Outputs (for IRSA)
################################################################################

output "oidc_endpoint_url" {
  description = "OIDC endpoint URL for IRSA"
  value       = rhcs_cluster_rosa_classic.rosa.sts.oidc_endpoint_url
}

output "oidc_config_id" {
  description = "OIDC configuration ID"
  value       = rhcs_rosa_oidc_config.oidc_config.id
}

################################################################################
# IAM Role Outputs
################################################################################

output "external_secrets_role_arn" {
  description = "IAM role ARN for External Secrets Operator"
  value       = aws_iam_role.external_secrets.arn
}

output "cert_manager_role_arn" {
  description = "IAM role ARN for cert-manager"
  value       = aws_iam_role.cert_manager.arn
}

output "ecr_pull_role_arn" {
  description = "IAM role ARN for ECR pull access"
  value       = aws_iam_role.ecr_pull.arn
}

################################################################################
# ECR Outputs
################################################################################

output "ecr_registry_url" {
  description = "ECR registry URL"
  value       = local.ecr_registry_url
}

output "ecr_repository_urls" {
  description = "Map of ECR repository URLs"
  value = {
    for name, repo in aws_ecr_repository.confluent : name => repo.repository_url
  }
}

################################################################################
# VPC Outputs
################################################################################

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

################################################################################
# Route53 Outputs
################################################################################

output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = local.route53_zone_id
}

output "route53_domain" {
  description = "Route53 domain name"
  value       = var.domain_name
}

################################################################################
# Secrets Manager Outputs
################################################################################

output "secrets_manager_arns" {
  description = "ARNs of created Secrets Manager secrets"
  value = var.create_sample_secrets ? {
    credentials = aws_secretsmanager_secret.confluent_credentials[0].arn
    tls         = aws_secretsmanager_secret.confluent_tls[0].arn
    license     = aws_secretsmanager_secret.confluent_license[0].arn
    jaas        = aws_secretsmanager_secret.confluent_jaas[0].arn
  } : {}
}

################################################################################
# Cluster Admin Credentials
################################################################################

output "cluster_admin_username" {
  description = "Cluster admin username"
  value       = rhcs_cluster_rosa_classic_cluster_admin_user.cluster_admin.username
}

output "cluster_admin_password" {
  description = "Cluster admin password"
  value       = rhcs_cluster_rosa_classic_cluster_admin_user.cluster_admin.password
  sensitive   = true
}

################################################################################
# Configuration for Kubernetes Manifests
################################################################################

output "manifest_config" {
  description = "Configuration values for Kubernetes manifests"
  value = {
    environment               = var.environment
    cluster_name              = var.cluster_name
    aws_region                = var.aws_region
    domain_name               = var.domain_name
    ecr_registry_url          = local.ecr_registry_url
    external_secrets_role_arn = aws_iam_role.external_secrets.arn
    cert_manager_role_arn     = aws_iam_role.cert_manager.arn
    route53_zone_id           = local.route53_zone_id
    confluent_platform_version = var.confluent_platform_version
    cfk_operator_version      = var.cfk_operator_version
  }
}
