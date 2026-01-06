# Deploying to Existing ROSA Cluster

This guide walks through deploying Confluent Platform to an existing ROSA cluster manually, without using GitHub Actions workflows.

## Prerequisites

### 1. Install Required CLI Tools

**macOS:**
```bash
# OpenShift CLI
brew install openshift-cli

# Helm
brew install helm
```

**Linux:**
```bash
# OpenShift CLI
curl -LO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz
tar -xzf openshift-client-linux.tar.gz
sudo mv oc kubectl /usr/local/bin/

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

**Windows:**
Download from: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-windows.zip

### 2. Login to OpenShift

**Option A - Using the web console token:**
1. Go to your OpenShift console
2. Click your username (top right) → "Copy login command"
3. Click "Display Token"
4. Copy and run the `oc login` command

**Option B - Using username/password:**
```bash
oc login https://api.<cluster-name>.<domain>:6443 \
  --username=cluster-admin \
  --password=<your-password>
```

**Verify connection:**
```bash
oc whoami
oc get nodes
```

## Deployment Steps

### Step 1: Create Namespaces and Apply SCCs

```bash
# Create namespaces (separate control plane and data plane)
oc create namespace confluent
oc create namespace confluent-operator

# Apply Security Context Constraints
oc apply -f env/dev/cluster-config/scc.yaml

# Grant SCC to service accounts
oc adm policy add-scc-to-user confluent-scc -z default -n confluent
oc adm policy add-scc-to-user confluent-scc -z kafka -n confluent
oc adm policy add-scc-to-user confluent-scc -z kraftcontroller -n confluent
oc adm policy add-scc-to-user confluent-scc -z schemaregistry -n confluent
oc adm policy add-scc-to-user confluent-scc -z connect -n confluent
oc adm policy add-scc-to-user confluent-scc -z ksqldb -n confluent
oc adm policy add-scc-to-user confluent-scc -z controlcenter -n confluent
oc adm policy add-scc-to-user confluent-scc -z kafkarestproxy -n confluent
```

### Step 2: Create TLS CA Certificate

```bash
# Generate CA key and certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/ca-key.pem \
  -out /tmp/ca-cert.pem \
  -subj "/CN=ca.confluent.svc.cluster.local/O=Confluent"

# Create Kubernetes secret
oc create secret tls ca-pair-sslcerts \
  --cert=/tmp/ca-cert.pem \
  --key=/tmp/ca-key.pem \
  -n confluent

# Clean up temp files
rm /tmp/ca-key.pem /tmp/ca-cert.pem
```

### Step 3: Create Docker Hub Pull Secret (Optional)

If you need to pull from Docker Hub with authentication:

```bash
oc create secret docker-registry dockerhub-secret \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<your-dockerhub-username> \
  --docker-password=<your-dockerhub-token> \
  -n confluent

# Link secret to default service account
oc secrets link default dockerhub-secret --for=pull -n confluent
```

### Step 4: Install CFK Operator

```bash
# Add Confluent Helm repository
helm repo add confluentinc https://packages.confluent.io/helm
helm repo update

# Install CFK Operator in confluent-operator namespace
helm upgrade --install confluent-operator confluentinc/confluent-for-kubernetes \
  --namespace confluent-operator \
  --set podSecurityContext.runAsUser=1000 \
  --set podSecurityContext.runAsNonRoot=true \
  --set podSecurityContext.fsGroup=1000 \
  --set namespaced=false \
  --set namespaceList="{confluent}"

# Wait for operator to be ready
oc wait --for=condition=Available deployment/confluent-operator \
  -n confluent-operator --timeout=300s

# Grant SCC to operator service account
oc adm policy add-scc-to-user confluent-scc \
  -z confluent-operator \
  -n confluent-operator

# Verify CRDs are installed
oc get crds | grep confluent
```

### Step 5: Deploy Confluent Platform

```bash
# Deploy all Confluent Platform components
oc apply -f env/dev/confluent-platform/
```

### Step 6: Monitor Deployment

```bash
# Watch pods come up
oc get pods -n confluent -w

# Check component status
oc get kraftcontroller,kafka,schemaregistry,connect,ksqldb,controlcenter,kafkarestproxy -n confluent
```

Wait for all components to show `READY` status (this takes 10-15 minutes).

## Accessing the Platform

### Check Routes

```bash
# List all routes
oc get routes -n confluent
```

### Control Center

```bash
# Get the route URL
oc get route controlcenter -n confluent -o jsonpath='{.spec.host}'
```

Access Control Center at `https://<route-url>`

### Other Components

```bash
# Schema Registry
oc get route schemaregistry -n confluent -o jsonpath='{.spec.host}'

# Kafka Connect
oc get route connect -n confluent -o jsonpath='{.spec.host}'

# ksqlDB
oc get route ksqldb -n confluent -o jsonpath='{.spec.host}'

# REST Proxy
oc get route kafkarestproxy -n confluent -o jsonpath='{.spec.host}'
```

## Testing Kafka

### Create a Test Topic

```bash
# Exec into a Kafka pod
oc exec -it kafka-0 -n confluent -- bash

# Create topic
kafka-topics --bootstrap-server kafka.confluent.svc.cluster.local:9092 \
  --create --topic test-topic --partitions 3 --replication-factor 3

# List topics
kafka-topics --bootstrap-server kafka.confluent.svc.cluster.local:9092 --list
```

### Produce and Consume Messages

```bash
# Produce messages
kafka-console-producer --bootstrap-server kafka.confluent.svc.cluster.local:9092 \
  --topic test-topic

# Consume messages (in another terminal)
kafka-console-consumer --bootstrap-server kafka.confluent.svc.cluster.local:9092 \
  --topic test-topic --from-beginning
```

## Uninstalling

### Remove Confluent Platform

```bash
# Delete all Confluent Platform components
oc delete -f env/dev/confluent-platform/

# Wait for pods to terminate
oc get pods -n confluent -w
```

### Remove CFK Operator

```bash
helm uninstall confluent-operator -n confluent-operator
```

### Remove Namespaces

```bash
oc delete namespace confluent
oc delete namespace confluent-operator
```

### Remove SCC

```bash
oc delete scc confluent-scc
```

## Troubleshooting

### Check Pod Logs

```bash
oc logs -f <pod-name> -n confluent
```

### Describe Resources

```bash
oc describe kafka kafka -n confluent
oc describe kraftcontroller kraftcontroller -n confluent
```

### Check Events

```bash
oc get events -n confluent --sort-by='.lastTimestamp'
```

### Check Operator Logs

```bash
oc logs -n confluent-operator -l app=confluent-operator
```

### Common Issues

1. **Pods stuck in Pending**: Check node resources with `oc describe nodes`
2. **Image pull errors**: Verify Docker Hub secret is configured
3. **TLS errors**: Ensure CA certificate secret exists
4. **SCC errors**: Verify service accounts have the confluent-scc

For more troubleshooting help, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
