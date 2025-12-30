# =============================================================================
# Environment Output
# =============================================================================

output "environment" {
  description = "Environment name"
  value       = var.environment
}

# =============================================================================
# Cluster Outputs
# =============================================================================

output "cluster_id" {
  description = "ROSA cluster ID"
  value       = rhcs_cluster_rosa_classic.cluster.id
}

output "cluster_name" {
  description = "ROSA cluster name"
  value       = rhcs_cluster_rosa_classic.cluster.name
}

output "api_url" {
  description = "OpenShift API URL"
  value       = rhcs_cluster_rosa_classic.cluster.api_url
}

output "console_url" {
  description = "OpenShift Console URL"
  value       = rhcs_cluster_rosa_classic.cluster.console_url
}

output "domain" {
  description = "Cluster base domain"
  value       = rhcs_cluster_rosa_classic.cluster.domain
}

output "apps_domain" {
  description = "Applications domain (for routes)"
  value       = "apps.${rhcs_cluster_rosa_classic.cluster.domain}"
}

output "infra_id" {
  description = "Cluster infrastructure ID"
  value       = rhcs_cluster_rosa_classic.cluster.id
}

# =============================================================================
# Network Outputs
# =============================================================================

output "machine_cidr" {
  description = "Machine CIDR"
  value       = var.machine_cidr
}

output "service_cidr" {
  description = "Service CIDR"
  value       = var.service_cidr
}

output "pod_cidr" {
  description = "Pod CIDR"
  value       = var.pod_cidr
}

# =============================================================================
# Authentication Outputs
# =============================================================================

output "admin_username" {
  description = "Cluster admin username"
  value       = var.create_admin_user ? "cluster-admin" : null
}

output "admin_password" {
  description = "Cluster admin password"
  value       = var.create_admin_user ? (var.admin_password != "" ? var.admin_password : try(random_password.admin[0].result, null)) : null
  sensitive   = true
}

output "oc_login_command" {
  description = "Command to login to the cluster"
  value       = var.create_admin_user ? "oc login ${rhcs_cluster_rosa_classic.cluster.api_url} --username=cluster-admin --password=<password>" : "oc login ${rhcs_cluster_rosa_classic.cluster.api_url}"
}

# =============================================================================
# Custom Domain Output
# =============================================================================

output "custom_domain" {
  description = "Custom domain for Confluent Platform"
  value       = var.custom_domain
}

# =============================================================================
# DNS Configuration Output
# =============================================================================

output "dns_setup_instructions" {
  description = "DNS setup instructions for custom domain"
  value       = var.custom_domain != "" ? <<-EOT
    To use custom domain ${var.custom_domain}:

    Create a wildcard CNAME record:
    *.${var.custom_domain} -> *.apps.${rhcs_cluster_rosa_classic.cluster.domain}

    Access URLs after DNS setup:
    - Control Center: https://controlcenter.${var.custom_domain}
    - Schema Registry: https://schemaregistry.${var.custom_domain}
    - Connect: https://connect.${var.custom_domain}
    - ksqlDB: https://ksqldb.${var.custom_domain}
    - REST Proxy: https://kafkarestproxy.${var.custom_domain}
  EOT : "No custom domain configured. Access services via OpenShift routes."
}
