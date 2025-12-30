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
  value       = module.rosa_cluster.cluster_id
}

output "cluster_name" {
  description = "ROSA cluster name"
  value       = var.cluster_name
}

output "api_url" {
  description = "OpenShift API URL"
  value       = module.rosa_cluster.api_url
}

output "console_url" {
  description = "OpenShift Console URL"
  value       = module.rosa_cluster.console_url
}

output "domain" {
  description = "Cluster base domain"
  value       = module.rosa_cluster.domain
}

output "apps_domain" {
  description = "Applications domain (for routes)"
  value       = "apps.${module.rosa_cluster.domain}"
}

output "infra_id" {
  description = "Cluster infrastructure ID"
  value       = module.rosa_cluster.infra_id
}

output "cluster_state" {
  description = "Cluster state"
  value       = module.rosa_cluster.state
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
  value       = module.rosa_cluster.cluster_admin_username
  sensitive   = true
}

output "admin_password" {
  description = "Cluster admin password"
  value       = module.rosa_cluster.cluster_admin_password
  sensitive   = true
}

output "oc_login_command" {
  description = "Command to login to the cluster"
  value       = "oc login ${module.rosa_cluster.api_url} --username=${module.rosa_cluster.cluster_admin_username} --password=<password>"
  sensitive   = true
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
  value = var.custom_domain != "" ? join("\n", [
    "To use custom domain ${var.custom_domain}:",
    "",
    "Create a wildcard CNAME record:",
    "*.${var.custom_domain} -> *.apps.${module.rosa_cluster.domain}",
    "",
    "Access URLs after DNS setup:",
    "- Control Center: https://controlcenter.${var.custom_domain}",
    "- Schema Registry: https://schemaregistry.${var.custom_domain}",
    "- Connect: https://connect.${var.custom_domain}",
    "- ksqlDB: https://ksqldb.${var.custom_domain}",
    "- REST Proxy: https://kafkarestproxy.${var.custom_domain}"
  ]) : "No custom domain configured. Access services via OpenShift routes."
}
