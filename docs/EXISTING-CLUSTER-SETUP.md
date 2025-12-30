# Deploying to Existing ROSA Cluster

This guide walks through deploying Confluent Platform to an existing ROSA cluster using direct Docker Hub images and Kubernetes secrets.

## Prerequisites

### 1. Install OpenShift CLI

**macOS:**
```bash
brew install openshift-cli
```

**Linux:**
```bash
curl -LO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz
tar -xzf openshift-client-linux.tar.gz
sudo mv oc kubectl /usr/local/bin/
```

**Windows:**
Download from: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-windows.zip

### 2. Install Helm

**macOS:**
```bash
brew install helm
```

**Linux:**
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 3. Login to OpenShift

Option A - Using the web console token:
1. Go to your OpenShift console
2. Click your username (top right) → "Copy login command"
3. Click "Display Token"
4. Copy and run the `oc login` command

Option B - Using username/password:
```bash
oc login https://api.rm2.thpm.p1.openshiftapps.com:6443 \
  --username=<your-username> \
  --password=<your-password>
```

Verify connection:
```bash
oc whoami
oc get nodes
```

## Deployment Steps

### Step 1: Create Namespaces and Apply SCCs

```bash
# Create namespaces
oc create namespace confluent
oc create namespace confluent-operator

# Apply Security Context Constraints
oc apply -f environments/dev/cluster-config/scc.yaml

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

### Step 2: Install CFK Operator

```bash
# Add Confluent Helm repository
helm repo add confluentinc https://packages.confluent.io/helm
helm repo update

# Install CFK Operator
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

# Verify CRDs are installed
oc get crds | grep confluent
```

### Step 3: Deploy Confluent Platform

```bash
# Deploy using the simplified manifests
oc apply -f environments/dev/confluent-platform/
```

### Step 4: Monitor Deployment

```bash
# Watch pods come up
oc get pods -n confluent -w

# Check component status
oc get kraftcontroller,kafka,schemaregistry,connect,ksqldb,controlcenter -n confluent
```

### Step 5: Create Routes for External Access

```bash
# Apply routes
oc apply -f environments/dev/routes-simple/
```

## Accessing the Platform

### Control Center
```bash
# Get the route URL
oc get route controlcenter -n confluent -o jsonpath='{.spec.host}'
```

### Other Components
```bash
oc get routes -n confluent
```

## Troubleshooting

### Check pod logs
```bash
oc logs -f <pod-name> -n confluent
```

### Describe resources
```bash
oc describe kafka kafka -n confluent
oc describe kraftcontroller kraftcontroller -n confluent
```

### Check events
```bash
oc get events -n confluent --sort-by='.lastTimestamp'
```
