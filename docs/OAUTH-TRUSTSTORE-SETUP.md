# OAuth Truststore Setup

This guide explains how to create the `oauth-truststore` secret required for Confluent Platform components to communicate with external OAuth/OIDC providers (e.g., Okta) over HTTPS.

## Why is this needed?

When Confluent Platform components (Kafka/MDS, Control Center, Connect, etc.) communicate with your OAuth provider (Okta), they need to trust the provider's SSL certificate. This requires adding the OAuth provider's CA certificate chain to a truststore.

## Prerequisites

- `keytool` (comes with Java JDK)
- `openssl`
- `oc` CLI logged into your OpenShift cluster

## Step 1: Download OAuth Provider's Certificate Chain

### For Okta

```bash
# Create working directory
mkdir -p /tmp/oauth-truststore && cd /tmp/oauth-truststore

# Download the full certificate chain from Okta
# Replace with your Okta domain
OKTA_DOMAIN="integrator-9299379.okta.com"

echo | openssl s_client -connect ${OKTA_DOMAIN}:443 -showcerts 2>/dev/null | \
  sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' > okta-chain.pem

# Verify the certificates were downloaded
openssl crl2pkcs7 -nocrl -certfile okta-chain.pem | \
  openssl pkcs7 -print_certs -noout
```

### Extract Individual Certificates

```bash
# Split the chain into individual certificate files
csplit -f cert- -b '%02d.pem' okta-chain.pem '/-----BEGIN CERTIFICATE-----/' '{*}' 2>/dev/null

# Remove empty first file if created
rm -f cert-00.pem

# View certificate subjects
for cert in cert-*.pem; do
  echo "=== $cert ==="
  openssl x509 -in $cert -noout -subject -issuer
done
```

## Step 2: Create the Truststore

```bash
cd /tmp/oauth-truststore

# Create a new truststore with Okta's certificates
# Import each certificate in the chain

# Import the intermediate CA (usually cert-01.pem or cert-02.pem)
keytool -importcert -noprompt \
  -alias okta-intermediate-ca \
  -file cert-02.pem \
  -keystore truststore.jks \
  -storepass changeit

# Import the root CA (usually the last cert in the chain)
keytool -importcert -noprompt \
  -alias okta-root-ca \
  -file cert-03.pem \
  -keystore truststore.jks \
  -storepass changeit

# Verify the truststore contents
keytool -list -keystore truststore.jks -storepass changeit
```

### Alternative: Use DigiCert Root CA Directly

Okta uses DigiCert. You can download DigiCert's root CA directly:

```bash
cd /tmp/oauth-truststore

# Download DigiCert Global Root CA
curl -o digicert-root-ca.pem https://cacerts.digicert.com/DigiCertGlobalRootCA.crt.pem

# Download DigiCert TLS RSA SHA256 2020 CA1 (intermediate)
curl -o digicert-intermediate.pem https://cacerts.digicert.com/DigiCertTLSRSASHA2562020CA1-1.crt.pem

# Create truststore with DigiCert certificates
keytool -importcert -noprompt \
  -alias digicert-root-ca \
  -file digicert-root-ca.pem \
  -keystore truststore.jks \
  -storepass changeit

keytool -importcert -noprompt \
  -alias digicert-intermediate-ca \
  -file digicert-intermediate.pem \
  -keystore truststore.jks \
  -storepass changeit

# Verify
keytool -list -keystore truststore.jks -storepass changeit
```

## Step 3: Create Kubernetes Secret

```bash
# Create the secret in the confluent namespace
oc create secret generic oauth-truststore \
  --from-file=truststore.jks=/tmp/oauth-truststore/truststore.jks \
  -n confluent \
  --dry-run=client -o yaml | oc apply -f -

# Verify the secret was created
oc get secret oauth-truststore -n confluent
```

## Step 4: Verify Components Can Access the Truststore

After the secret is created, restart affected pods to pick up the new truststore:

```bash
# Rolling restart of Kafka (includes MDS)
oc rollout restart statefulset/kafka -n confluent

# Rolling restart of Control Center
oc rollout restart statefulset/controlcenter -n confluent

# Rolling restart of Connect (if using OAuth)
oc rollout restart statefulset/connect -n confluent
```

### Verify the truststore is mounted correctly:

```bash
# Check Kafka pod
oc exec -n confluent kafka-0 -- ls -la /mnt/secrets/oauth-truststore/

# List certificates in the mounted truststore
oc exec -n confluent kafka-0 -- keytool -list \
  -keystore /mnt/secrets/oauth-truststore/truststore.jks \
  -storepass changeit
```

## Component Configuration

The following components need to reference the truststore:

### Kafka (for MDS)

```yaml
spec:
  mountedSecrets:
    - secretRef: oauth-truststore
  podTemplate:
    env:
      - name: KAFKA_OPTS
        value: "-Djavax.net.ssl.trustStore=/mnt/secrets/oauth-truststore/truststore.jks -Djavax.net.ssl.trustStorePassword=changeit"
```

### Control Center

```yaml
spec:
  mountedSecrets:
    - secretRef: oauth-truststore
  podTemplate:
    env:
      - name: KAFKA_OPTS
        value: "-Djavax.net.ssl.trustStore=/mnt/secrets/oauth-truststore/truststore.jks -Djavax.net.ssl.trustStorePassword=changeit"
```

### Connect

```yaml
spec:
  mountedSecrets:
    - secretRef: oauth-truststore
  podTemplate:
    env:
      - name: KAFKA_OPTS
        value: "-Djavax.net.ssl.trustStore=/mnt/secrets/oauth-truststore/truststore.jks -Djavax.net.ssl.trustStorePassword=changeit"
```

## Troubleshooting

### SSL Handshake Errors

If you see errors like:
```
PKIX path building failed: unable to find valid certification path to requested target
```

This means the truststore doesn't contain the correct CA certificates.

**Debug steps:**

```bash
# Check what CA signed the OAuth provider's certificate
echo | openssl s_client -connect ${OKTA_DOMAIN}:443 2>/dev/null | \
  openssl x509 -noout -issuer

# Compare with what's in the truststore
oc exec -n confluent kafka-0 -- keytool -list -v \
  -keystore /mnt/secrets/oauth-truststore/truststore.jks \
  -storepass changeit | grep -A2 "Alias name"
```

### Certificate Chain Issues

Some OAuth providers require the full certificate chain (root + intermediate). Make sure you import both:

```bash
# List all certificates in your truststore
keytool -list -v -keystore truststore.jks -storepass changeit
```

## Quick Reference: One-Liner Setup

For Okta with DigiCert certificates:

```bash
# Run this on your local machine with oc access
cd /tmp && mkdir -p oauth-truststore && cd oauth-truststore && \
curl -sO https://cacerts.digicert.com/DigiCertGlobalRootCA.crt.pem && \
curl -sO https://cacerts.digicert.com/DigiCertTLSRSASHA2562020CA1-1.crt.pem && \
keytool -importcert -noprompt -alias digicert-root -file DigiCertGlobalRootCA.crt.pem -keystore truststore.jks -storepass changeit && \
keytool -importcert -noprompt -alias digicert-intermediate -file DigiCertTLSRSASHA2562020CA1-1.crt.pem -keystore truststore.jks -storepass changeit && \
oc create secret generic oauth-truststore --from-file=truststore.jks -n confluent --dry-run=client -o yaml | oc apply -f - && \
echo "Done! oauth-truststore secret created."
```

## Updating the Truststore

If you need to add more certificates or update existing ones:

```bash
# Download the current truststore from the secret
oc get secret oauth-truststore -n confluent -o jsonpath='{.data.truststore\.jks}' | base64 -d > truststore.jks

# Add new certificate
keytool -importcert -noprompt -alias new-ca -file new-ca.pem -keystore truststore.jks -storepass changeit

# Update the secret
oc create secret generic oauth-truststore --from-file=truststore.jks -n confluent --dry-run=client -o yaml | oc apply -f -

# Restart affected pods
oc rollout restart statefulset/kafka -n confluent
```
