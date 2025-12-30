################################################################################
# Route53 Hosted Zone
################################################################################

resource "aws_route53_zone" "main" {
  count = var.create_route53_zone ? 1 : 0

  name    = var.domain_name
  comment = "Hosted zone for ${var.cluster_name} OpenShift cluster"

  tags = merge(var.tags, {
    Name = var.domain_name
  })
}

data "aws_route53_zone" "existing" {
  count = var.create_route53_zone ? 0 : 1

  zone_id = var.existing_route53_zone_id
}

locals {
  route53_zone_id   = var.create_route53_zone ? aws_route53_zone.main[0].zone_id : data.aws_route53_zone.existing[0].zone_id
  route53_zone_name = var.create_route53_zone ? aws_route53_zone.main[0].name : data.aws_route53_zone.existing[0].name
}

################################################################################
# Wildcard DNS Record for OpenShift Apps
################################################################################

# Note: This record points to the OpenShift ingress load balancer
# The actual ingress endpoint is created by OpenShift after cluster deployment
# You may need to update this after the cluster is created

# resource "aws_route53_record" "apps_wildcard" {
#   zone_id = local.route53_zone_id
#   name    = "*.apps.${var.environment}.${var.domain_name}"
#   type    = "CNAME"
#   ttl     = 300
#   records = [rhcs_cluster_rosa_classic.rosa.infra_id] # This needs to be updated with actual ingress
# }

################################################################################
# Output Zone Information
################################################################################

output "route53_zone_id_internal" {
  description = "Route53 zone ID (internal use)"
  value       = local.route53_zone_id
}

output "route53_nameservers" {
  description = "Route53 nameservers (for domain delegation)"
  value       = var.create_route53_zone ? aws_route53_zone.main[0].name_servers : []
}
