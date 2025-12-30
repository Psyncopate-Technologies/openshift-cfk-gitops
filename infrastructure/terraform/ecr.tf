################################################################################
# ECR Repositories for Confluent Images
################################################################################

locals {
  confluent_images = [
    "cp-server",
    "cp-schema-registry",
    "cp-kafka-connect",
    "cp-ksqldb-server",
    "cp-control-center",
    "cp-kafka-rest",
    "confluent-init-container",
    "confluent-operator"
  ]
}

resource "aws_ecr_repository" "confluent" {
  for_each = toset(local.confluent_images)

  name                 = "confluent/${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, {
    Name      = "confluent/${each.key}"
    Component = each.key
  })
}

################################################################################
# ECR Lifecycle Policy
################################################################################

resource "aws_ecr_lifecycle_policy" "confluent" {
  for_each = aws_ecr_repository.confluent

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "8.", "7.", "2."]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

################################################################################
# ECR Repository Policy (Allow ROSA cluster to pull)
################################################################################

resource "aws_ecr_repository_policy" "confluent" {
  for_each = aws_ecr_repository.confluent

  repository = each.value.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowROSAPull"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}
