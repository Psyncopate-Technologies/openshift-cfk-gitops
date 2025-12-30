################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

################################################################################
# ROSA Account Roles
################################################################################

# Account-wide IAM roles required for ROSA
module "rosa_account_roles" {
  source  = "terraform-redhat/rosa-sts/aws//modules/account-iam-resources"
  version = "0.0.15"

  account_role_prefix = var.cluster_name
  openshift_version   = var.openshift_version
  tags                = var.tags
}

################################################################################
# ROSA Operator Roles
################################################################################

module "rosa_operator_roles" {
  source  = "terraform-redhat/rosa-sts/aws//modules/operator-roles"
  version = "0.0.15"

  cluster_id                  = rhcs_cluster_rosa_classic.rosa.id
  operator_role_prefix        = var.cluster_name
  oidc_endpoint_url           = rhcs_cluster_rosa_classic.rosa.sts.oidc_endpoint_url
  account_role_prefix         = var.cluster_name
  tags                        = var.tags

  depends_on = [module.rosa_account_roles]
}

################################################################################
# OIDC Provider for IRSA
################################################################################

data "rhcs_rosa_operator_roles" "operator_roles" {
  operator_role_prefix = var.cluster_name
  account_role_prefix  = var.cluster_name

  depends_on = [module.rosa_operator_roles]
}

################################################################################
# External Secrets IAM Role (IRSA)
################################################################################

resource "aws_iam_role" "external_secrets" {
  name = "${var.cluster_name}-external-secrets"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(rhcs_cluster_rosa_classic.rosa.sts.oidc_endpoint_url, "https://", "")}"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(rhcs_cluster_rosa_classic.rosa.sts.oidc_endpoint_url, "https://", "")}:sub" = [
            "system:serviceaccount:external-secrets:external-secrets",
            "system:serviceaccount:confluent:external-secrets-sa"
          ]
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "external_secrets" {
  name = "secrets-manager-access"
  role = aws_iam_role.external_secrets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecrets"
      ]
      Resource = "arn:${data.aws_partition.current.partition}:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:confluent/*"
    }]
  })
}

################################################################################
# cert-manager IAM Role (IRSA)
################################################################################

resource "aws_iam_role" "cert_manager" {
  name = "${var.cluster_name}-cert-manager"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(rhcs_cluster_rosa_classic.rosa.sts.oidc_endpoint_url, "https://", "")}"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(rhcs_cluster_rosa_classic.rosa.sts.oidc_endpoint_url, "https://", "")}:sub" = "system:serviceaccount:cert-manager:cert-manager"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "cert_manager_route53" {
  name = "route53-access"
  role = aws_iam_role.cert_manager.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "route53:GetChange"
        Resource = "arn:${data.aws_partition.current.partition}:route53:::change/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:route53:::hostedzone/${local.route53_zone_id}"
      },
      {
        Effect   = "Allow"
        Action   = "route53:ListHostedZonesByName"
        Resource = "*"
      }
    ]
  })
}

################################################################################
# ECR Pull IAM Role (Optional - for pulling from ECR)
################################################################################

resource "aws_iam_role" "ecr_pull" {
  name = "${var.cluster_name}-ecr-pull"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(rhcs_cluster_rosa_classic.rosa.sts.oidc_endpoint_url, "https://", "")}"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(rhcs_cluster_rosa_classic.rosa.sts.oidc_endpoint_url, "https://", "")}:sub" = [
            "system:serviceaccount:confluent:default",
            "system:serviceaccount:confluent-operator:default"
          ]
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "ecr_pull" {
  name = "ecr-pull-access"
  role = aws_iam_role.ecr_pull.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/confluent/*"
      },
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      }
    ]
  })
}
