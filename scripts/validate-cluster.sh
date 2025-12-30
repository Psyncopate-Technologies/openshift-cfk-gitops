#!/bin/bash

# Validate OpenShift cluster and Confluent Platform deployment
# Usage: ./validate-cluster.sh

set -euo pipefail

echo "=========================================="
echo "OpenShift CFK Cluster Validation"
echo "=========================================="

# Check if logged in to OpenShift
if ! oc whoami &>/dev/null; then
    echo "Error: Not logged in to OpenShift. Run 'oc login' first."
    exit 1
fi

echo ""
echo "1. Cluster Information"
echo "----------------------------------------"
echo "Logged in as: $(oc whoami)"
echo "API Server: $(oc whoami --show-server)"
echo "Cluster Version: $(oc get clusterversion version -o jsonpath='{.status.desired.version}')"

echo ""
echo "2. Nodes Status"
echo "----------------------------------------"
oc get nodes -o wide

echo ""
echo "3. Namespaces"
echo "----------------------------------------"
oc get namespaces | grep -E "confluent|external-secrets|cert-manager|openshift-gitops"

echo ""
echo "4. CFK Operator"
echo "----------------------------------------"
if oc get deployment confluent-operator -n confluent-operator &>/dev/null; then
    echo "Deployment Status:"
    oc get deployment confluent-operator -n confluent-operator
    echo ""
    echo "Pods:"
    oc get pods -n confluent-operator
else
    echo "CFK Operator not found"
fi

echo ""
echo "5. Confluent Platform Components"
echo "----------------------------------------"

components=("kraftcontroller" "kafka" "schemaregistry" "connect" "ksqldb" "controlcenter" "kafkarestproxy")

printf "%-20s %-15s %-10s\n" "COMPONENT" "STATUS" "REPLICAS"
printf "%-20s %-15s %-10s\n" "---------" "------" "--------"

for component in "${components[@]}"; do
    if oc get "$component" "$component" -n confluent &>/dev/null; then
        phase=$(oc get "$component" "$component" -n confluent -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        replicas=$(oc get "$component" "$component" -n confluent -o jsonpath='{.status.replicas}' 2>/dev/null || echo "0")
        printf "%-20s %-15s %-10s\n" "$component" "$phase" "$replicas"
    else
        printf "%-20s %-15s %-10s\n" "$component" "NotFound" "-"
    fi
done

echo ""
echo "6. Pods in confluent namespace"
echo "----------------------------------------"
oc get pods -n confluent -o wide

echo ""
echo "7. PVCs in confluent namespace"
echo "----------------------------------------"
oc get pvc -n confluent

echo ""
echo "8. Routes in confluent namespace"
echo "----------------------------------------"
oc get routes -n confluent

echo ""
echo "9. External Secrets Status"
echo "----------------------------------------"
if oc get externalsecrets -n confluent &>/dev/null 2>&1; then
    oc get externalsecrets -n confluent
else
    echo "No ExternalSecrets found"
fi

echo ""
echo "10. Certificates"
echo "----------------------------------------"
if oc get certificates -n confluent &>/dev/null 2>&1; then
    oc get certificates -n confluent
else
    echo "No Certificates found"
fi

echo ""
echo "11. ServiceMonitors"
echo "----------------------------------------"
if oc get servicemonitors -n confluent &>/dev/null 2>&1; then
    oc get servicemonitors -n confluent
else
    echo "No ServiceMonitors found"
fi

echo ""
echo "=========================================="
echo "Validation Complete"
echo "=========================================="
