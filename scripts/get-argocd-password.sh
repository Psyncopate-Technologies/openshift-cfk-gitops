#!/bin/bash

# Get ArgoCD admin password from OpenShift GitOps
# Usage: ./get-argocd-password.sh

set -euo pipefail

echo "Retrieving ArgoCD admin password..."

# Check if logged in to OpenShift
if ! oc whoami &>/dev/null; then
    echo "Error: Not logged in to OpenShift. Run 'oc login' first."
    exit 1
fi

# Get the password
PASSWORD=$(oc get secret openshift-gitops-cluster -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d)

if [[ -z "$PASSWORD" ]]; then
    echo "Error: Could not retrieve password"
    exit 1
fi

# Get the route
ROUTE=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')

echo ""
echo "=========================================="
echo "ArgoCD Access Information"
echo "=========================================="
echo "URL:      https://$ROUTE"
echo "Username: admin"
echo "Password: $PASSWORD"
echo "=========================================="
