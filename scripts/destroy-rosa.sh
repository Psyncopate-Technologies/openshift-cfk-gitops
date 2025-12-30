#!/bin/bash

# Destroy ROSA cluster to stop incurring charges
# Usage: ./destroy-rosa.sh [cluster-name]

set -euo pipefail

CLUSTER_NAME="${1:-cfk-test}"

echo "=========================================="
echo "ROSA Cluster Destruction"
echo "=========================================="
echo ""
echo "Cluster: $CLUSTER_NAME"
echo ""

# Check ROSA login
if ! rosa whoami &> /dev/null; then
    echo "ERROR: Not logged in to ROSA"
    echo "Run: rosa login --token=<your-token>"
    exit 1
fi

# Check cluster exists
if ! rosa describe cluster --cluster="$CLUSTER_NAME" &> /dev/null; then
    echo "ERROR: Cluster '$CLUSTER_NAME' not found"
    rosa list clusters
    exit 1
fi

# Show current cost info
echo "Current cluster status:"
rosa describe cluster --cluster="$CLUSTER_NAME" | grep -E "State|Created|Region"
echo ""

# Confirm destruction
echo "WARNING: This will permanently delete the cluster and all data!"
echo ""
read -p "Type the cluster name to confirm deletion: " CONFIRM

if [ "$CONFIRM" != "$CLUSTER_NAME" ]; then
    echo "Cluster name doesn't match. Aborting."
    exit 1
fi

echo ""
echo "Deleting cluster..."
rosa delete cluster --cluster="$CLUSTER_NAME" --yes

echo ""
echo "Waiting for cluster deletion..."
rosa logs uninstall --cluster="$CLUSTER_NAME" --watch || true

echo ""
echo "Cleaning up operator roles..."
rosa delete operator-roles -c "$CLUSTER_NAME" --mode auto --yes 2>/dev/null || true

echo ""
echo "Cleaning up OIDC provider..."
rosa delete oidc-provider -c "$CLUSTER_NAME" --mode auto --yes 2>/dev/null || true

echo ""
echo "=========================================="
echo "Cluster destroyed successfully!"
echo "=========================================="
echo ""
echo "Remaining account roles (shared, don't delete unless removing ROSA entirely):"
rosa list account-roles
