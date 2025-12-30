################################################################################
# General Variables
################################################################################

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the ROSA cluster"
  type        = string
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "rhcs_token" {
  description = "Red Hat Cloud Services API token"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

################################################################################
# VPC Variables
################################################################################

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

################################################################################
# ROSA Cluster Variables
################################################################################

variable "openshift_version" {
  description = "OpenShift version to deploy"
  type        = string
  default     = "4.14.12"
}

variable "compute_machine_type" {
  description = "EC2 instance type for compute nodes"
  type        = string
  default     = "m5.2xlarge"
}

variable "compute_replicas" {
  description = "Number of compute replicas"
  type        = number
  default     = 3
}

variable "confluent_machine_type" {
  description = "EC2 instance type for Confluent workload nodes"
  type        = string
  default     = "m5.2xlarge"
}

variable "confluent_replicas" {
  description = "Number of Confluent workload node replicas"
  type        = number
  default     = 3
}

variable "enable_confluent_machine_pool" {
  description = "Enable dedicated machine pool for Confluent workloads"
  type        = bool
  default     = false
}

variable "use_spot_instances" {
  description = "Use spot instances for cost savings (dev/staging only)"
  type        = bool
  default     = false
}

variable "multi_az" {
  description = "Deploy across multiple availability zones"
  type        = bool
  default     = true
}

################################################################################
# Domain and DNS Variables
################################################################################

variable "domain_name" {
  description = "Domain name for the cluster (e.g., example.com)"
  type        = string
}

variable "create_route53_zone" {
  description = "Create a new Route53 hosted zone"
  type        = bool
  default     = true
}

variable "existing_route53_zone_id" {
  description = "Existing Route53 zone ID (if create_route53_zone is false)"
  type        = string
  default     = ""
}

################################################################################
# ECR Variables
################################################################################

variable "confluent_platform_version" {
  description = "Confluent Platform version"
  type        = string
  default     = "8.0.1"
}

variable "cfk_operator_version" {
  description = "Confluent for Kubernetes operator version"
  type        = string
  default     = "2.10.0"
}

################################################################################
# Secrets Manager Variables
################################################################################

variable "create_sample_secrets" {
  description = "Create sample secrets in AWS Secrets Manager"
  type        = bool
  default     = true
}
