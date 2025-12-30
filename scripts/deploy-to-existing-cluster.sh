#!/bin/bash

# Deploy Confluent Platform to existing ROSA cluster
# Usage: ./deploy-to-existing-cluster.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "Confluent Platform Deployment Script"
echo "=========================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v oc &> /dev/null; then
    echo "ERROR: OpenShift CLI (oc) is not installed."
    echo ""
    echo "Install it using:"
    echo "  macOS:  brew install openshift-cli"
    echo "  Linux:  curl -LO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo "ERROR: Helm is not installed."
    echo ""
    echo "Install it using:"
    echo "  macOS:  brew install helm"
    echo "  Linux:  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
    exit 1
fi

# Check if logged in
if ! oc whoami &> /dev/null; then
    echo "ERROR: Not logged in to OpenShift."
    echo ""
    echo "Login using one of these methods:"
    echo "  1. Go to your OpenShift console"
    echo "  2. Click your username → 'Copy login command'"
    echo "  3. Run the oc login command"
    exit 1
fi

echo "Logged in as: $(oc whoami)"
echo "Server: $(oc whoami --show-server)"
echo ""

# Confirm deployment
read -p "Deploy Confluent Platform to this cluster? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "Step 1: Creating namespaces..."
echo "----------------------------------------"
oc create namespace confluent --dry-run=client -o yaml | oc apply -f -
oc create namespace confluent-operator --dry-run=client -o yaml | oc apply -f -

echo ""
echo "Step 2: Applying Security Context Constraints..."
echo "----------------------------------------"
oc apply -f "$PROJECT_ROOT/environments/dev/cluster-config/scc.yaml"

# Grant SCC to service accounts
for sa in default kafka kraftcontroller schemaregistry connect ksqldb controlcenter kafkarestproxy; do
    oc adm policy add-scc-to-user confluent-scc -z $sa -n confluent 2>/dev/null || true
done

echo ""
echo "Step 3: Installing CFK Operator..."
echo "----------------------------------------"
helm repo add confluentinc https://packages.confluent.io/helm 2>/dev/null || true
helm repo update

helm upgrade --install confluent-operator confluentinc/confluent-for-kubernetes \
  --namespace confluent-operator \
  --set podSecurityContext.runAsUser=1000 \
  --set podSecurityContext.runAsNonRoot=true \
  --set podSecurityContext.fsGroup=1000 \
  --set namespaced=false \
  --set namespaceList="{confluent}" \
  --wait \
  --timeout 5m

echo ""
echo "Waiting for CFK Operator to be ready..."
oc wait --for=condition=Available deployment/confluent-operator \
  -n confluent-operator --timeout=300s

echo ""
echo "Step 4: Deploying Confluent Platform..."
echo "----------------------------------------"
oc apply -f "$PROJECT_ROOT/environments/dev/platform-dockerhub/"

echo ""
echo "Step 5: Waiting for components to start..."
echo "----------------------------------------"
echo "This may take 10-15 minutes..."
echo ""

# Wait for KRaft Controller
echo "Waiting for KRaft Controller..."
for i in {1..60}; do
    PHASE=$(oc get kraftcontroller kraftcontroller -n confluent -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
    if [ "$PHASE" == "RUNNING" ]; then
        echo "KRaft Controller is RUNNING"
        break
    fi
    echo "  KRaft Controller: $PHASE ($i/60)"
    sleep 10
done

# Wait for Kafka
echo "Waiting for Kafka..."
for i in {1..60}; do
    PHASE=$(oc get kafka kafka -n confluent -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
    if [ "$PHASE" == "RUNNING" ]; then
        echo "Kafka is RUNNING"
        break
    fi
    echo "  Kafka: $PHASE ($i/60)"
    sleep 10
done

echo ""
echo "=========================================="
echo "Deployment Status"
echo "=========================================="
echo ""

# Show component status
echo "Components:"
oc get kraftcontroller,kafka,schemaregistry,connect,ksqldb,controlcenter,kafkarestproxy -n confluent 2>/dev/null || echo "Components still deploying..."

echo ""
echo "Pods:"
oc get pods -n confluent

echo ""
echo "Routes:"
oc get routes -n confluent 2>/dev/null || echo "Routes will be created once components are ready"

echo ""
echo "=========================================="
echo "Access URLs (once ready):"
echo "=========================================="
DOMAIN="apps.rm2.thpm.p1.openshiftapps.com"
echo "Control Center:   https://controlcenter.${DOMAIN}"
echo "Schema Registry:  https://schemaregistry.${DOMAIN}"
echo "Connect:          https://connect.${DOMAIN}"
echo "ksqlDB:           https://ksqldb.${DOMAIN}"
echo "REST Proxy:       https://kafkarestproxy.${DOMAIN}"
echo ""
echo "Monitor progress with: oc get pods -n confluent -w"
