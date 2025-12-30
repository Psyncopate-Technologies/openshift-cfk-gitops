#!/bin/bash

# Create a minimal cost-effective ROSA cluster for testing
# Estimated cost: ~$15-20/day
#
# Prerequisites:
#   1. AWS CLI configured (aws configure)
#   2. ROSA CLI installed (brew install rosa-cli)
#   3. Red Hat account with ROSA enabled
#
# Usage:
#   ./create-minimal-rosa.sh [cluster-name]
#
# To destroy:
#   rosa delete cluster --cluster=<cluster-name> --yes

set -euo pipefail

CLUSTER_NAME="${1:-cfk-test}"
AWS_REGION="${AWS_REGION:-us-east-1}"
COMPUTE_NODES=2
INSTANCE_TYPE="m5.xlarge"  # 4 vCPU, 16GB RAM - minimum for Kafka

echo "=========================================="
echo "Minimal ROSA Cluster Creation"
echo "=========================================="
echo ""
echo "Cluster Name:  $CLUSTER_NAME"
echo "Region:        $AWS_REGION"
echo "Nodes:         $COMPUTE_NODES x $INSTANCE_TYPE"
echo ""
echo "Estimated Cost: ~\$15-20/day (\$0.60-0.85/hour)"
echo "  - ROSA fee:     \$0.171/hr"
echo "  - 2x m5.xlarge: \$0.384/hr"
echo "  - NAT Gateway:  \$0.045/hr"
echo "  - Storage:      ~\$0.02/hr"
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI not installed"
    echo "Install: brew install awscli"
    exit 1
fi

if ! command -v rosa &> /dev/null; then
    echo "ERROR: ROSA CLI not installed"
    echo "Install: brew install rosa-cli"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "ERROR: AWS credentials not configured"
    echo "Run: aws configure"
    exit 1
fi

echo "AWS Account: $(aws sts get-caller-identity --query Account --output text)"

# Check ROSA login
if ! rosa whoami &> /dev/null; then
    echo ""
    echo "Not logged in to ROSA. Getting token..."
    echo "1. Go to: https://cloud.redhat.com/openshift/token/rosa"
    echo "2. Click 'Load token' or 'Generate token'"
    echo "3. Copy the token"
    echo ""
    read -p "Paste your ROSA token: " ROSA_TOKEN
    rosa login --token="$ROSA_TOKEN"
fi

echo "ROSA User: $(rosa whoami --output json | jq -r '.username // .Username')"

# Verify account
echo ""
echo "Verifying AWS account for ROSA..."
rosa verify quota --region=$AWS_REGION
rosa verify permissions

# Check if account roles exist
echo ""
echo "Checking account roles..."
if ! rosa list account-roles 2>/dev/null | grep -q "ManagedOpenShift"; then
    echo "Creating account roles (one-time setup)..."
    rosa create account-roles --mode auto --yes
fi

# Confirm creation
echo ""
echo "=========================================="
read -p "Create cluster '$CLUSTER_NAME'? This will incur AWS charges. (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Create the cluster
echo ""
echo "Creating ROSA cluster (this takes 30-45 minutes)..."
echo ""

rosa create cluster \
    --cluster-name="$CLUSTER_NAME" \
    --region="$AWS_REGION" \
    --compute-nodes=$COMPUTE_NODES \
    --compute-machine-type="$INSTANCE_TYPE" \
    --machine-cidr="10.0.0.0/16" \
    --service-cidr="172.30.0.0/16" \
    --pod-cidr="10.128.0.0/14" \
    --host-prefix=23 \
    --multi-az=false \
    --sts \
    --mode=auto \
    --yes

# Create operator roles
echo ""
echo "Creating operator roles..."
rosa create operator-roles --cluster="$CLUSTER_NAME" --mode auto --yes

# Create OIDC provider
echo ""
echo "Creating OIDC provider..."
rosa create oidc-provider --cluster="$CLUSTER_NAME" --mode auto --yes

echo ""
echo "=========================================="
echo "Cluster creation initiated!"
echo "=========================================="
echo ""
echo "Monitor progress:"
echo "  rosa describe cluster --cluster=$CLUSTER_NAME"
echo "  rosa logs install --cluster=$CLUSTER_NAME --watch"
echo ""
echo "Once ready, create admin user:"
echo "  rosa create admin --cluster=$CLUSTER_NAME"
echo ""
echo "To destroy (IMPORTANT - avoid ongoing charges):"
echo "  rosa delete cluster --cluster=$CLUSTER_NAME --yes"
echo "  rosa delete operator-roles -c $CLUSTER_NAME --mode auto --yes"
echo "  rosa delete oidc-provider -c $CLUSTER_NAME --mode auto --yes"
echo ""

# Wait for cluster
echo "Waiting for cluster to be ready..."
rosa logs install --cluster="$CLUSTER_NAME" --watch || true

# Check if ready
STATE=$(rosa describe cluster --cluster="$CLUSTER_NAME" --output json | jq -r '.state // .status.state')
if [ "$STATE" == "ready" ]; then
    echo ""
    echo "=========================================="
    echo "Cluster is READY!"
    echo "=========================================="

    # Create admin user
    echo ""
    echo "Creating cluster admin user..."
    rosa create admin --cluster="$CLUSTER_NAME"

    echo ""
    echo "Login command above. After logging in, run:"
    echo "  cd $(dirname "$0")/.."
    echo "  ./scripts/deploy-to-existing-cluster.sh"
fi
