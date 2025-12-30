################################################################################
# AWS Secrets Manager - Confluent Secrets
################################################################################

# Placeholder secrets for Confluent Platform components
# These will be populated manually or via CI/CD

resource "aws_secretsmanager_secret" "confluent_credentials" {
  count = var.create_sample_secrets ? 1 : 0

  name                    = "confluent/${var.environment}/credentials"
  description             = "Confluent Platform credentials for ${var.environment}"
  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(var.tags, {
    Component = "confluent"
  })
}

resource "aws_secretsmanager_secret_version" "confluent_credentials" {
  count = var.create_sample_secrets ? 1 : 0

  secret_id = aws_secretsmanager_secret.confluent_credentials[0].id
  secret_string = jsonencode({
    # Kafka credentials
    kafka_admin_username = "admin"
    kafka_admin_password = "CHANGE_ME_PLACEHOLDER"

    # Schema Registry credentials
    schema_registry_username = "sr-user"
    schema_registry_password = "CHANGE_ME_PLACEHOLDER"

    # Connect credentials
    connect_username = "connect-user"
    connect_password = "CHANGE_ME_PLACEHOLDER"

    # Control Center credentials
    controlcenter_username = "cc-admin"
    controlcenter_password = "CHANGE_ME_PLACEHOLDER"

    # ksqlDB credentials
    ksqldb_username = "ksql-user"
    ksqldb_password = "CHANGE_ME_PLACEHOLDER"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

################################################################################
# TLS Certificates Secret (for custom certificates)
################################################################################

resource "aws_secretsmanager_secret" "confluent_tls" {
  count = var.create_sample_secrets ? 1 : 0

  name                    = "confluent/${var.environment}/tls"
  description             = "TLS certificates for Confluent Platform ${var.environment}"
  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(var.tags, {
    Component = "confluent"
    Type      = "tls"
  })
}

resource "aws_secretsmanager_secret_version" "confluent_tls" {
  count = var.create_sample_secrets ? 1 : 0

  secret_id = aws_secretsmanager_secret.confluent_tls[0].id
  secret_string = jsonencode({
    # Placeholder - replace with actual certificates
    ca_crt     = "PLACEHOLDER_CA_CERTIFICATE"
    tls_crt    = "PLACEHOLDER_TLS_CERTIFICATE"
    tls_key    = "PLACEHOLDER_TLS_KEY"
    truststore = "PLACEHOLDER_TRUSTSTORE_BASE64"
    keystore   = "PLACEHOLDER_KEYSTORE_BASE64"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

################################################################################
# License Secret
################################################################################

resource "aws_secretsmanager_secret" "confluent_license" {
  count = var.create_sample_secrets ? 1 : 0

  name                    = "confluent/${var.environment}/license"
  description             = "Confluent Platform license for ${var.environment}"
  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(var.tags, {
    Component = "confluent"
    Type      = "license"
  })
}

resource "aws_secretsmanager_secret_version" "confluent_license" {
  count = var.create_sample_secrets ? 1 : 0

  secret_id = aws_secretsmanager_secret.confluent_license[0].id
  secret_string = jsonencode({
    license = "PLACEHOLDER_CONFLUENT_LICENSE"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

################################################################################
# SASL/JAAS Credentials
################################################################################

resource "aws_secretsmanager_secret" "confluent_jaas" {
  count = var.create_sample_secrets ? 1 : 0

  name                    = "confluent/${var.environment}/jaas"
  description             = "JAAS configuration for Confluent Platform ${var.environment}"
  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(var.tags, {
    Component = "confluent"
    Type      = "jaas"
  })
}

resource "aws_secretsmanager_secret_version" "confluent_jaas" {
  count = var.create_sample_secrets ? 1 : 0

  secret_id = aws_secretsmanager_secret.confluent_jaas[0].id
  secret_string = jsonencode({
    # PLAIN credentials for internal authentication
    plain_users = jsonencode({
      admin         = "CHANGE_ME_ADMIN_PASSWORD"
      kafka         = "CHANGE_ME_KAFKA_PASSWORD"
      schemaregistry = "CHANGE_ME_SR_PASSWORD"
      connect       = "CHANGE_ME_CONNECT_PASSWORD"
      ksqldb        = "CHANGE_ME_KSQL_PASSWORD"
      controlcenter = "CHANGE_ME_CC_PASSWORD"
      restproxy     = "CHANGE_ME_RP_PASSWORD"
    })
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
