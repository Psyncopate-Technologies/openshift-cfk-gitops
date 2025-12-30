# Troubleshooting Guide

This guide covers common issues and their solutions when deploying Confluent Platform on OpenShift.

## Workflow Issues

### "Cluster not found" Error

**Symptom:** Workflows 02, 03, or 04 fail with "cluster not found"

**Causes:**
1. Cluster name mismatch between workflows
2. Cluster still provisioning
3. Cluster failed to create

**Solution:**
```bash
# Check cluster status via ROSA CLI
rosa describe cluster -c <cluster-name>

# List all clusters
rosa list clusters
```

### OpenShift Login Fails

**Symptom:** Workflow fails at "Login to OpenShift" step

**Causes:**
1. `OPENSHIFT_ADMIN_PASSWORD` secret not set
2. Cluster not ready
3. API endpoint not accessible

**Solution:**
1. Check workflow 01 logs for admin password
2. Add/update `OPENSHIFT_ADMIN_PASSWORD` secret
3. Verify cluster state is "ready"

### ROSA Cluster Creation Fails

**Symptom:** Workflow 01 fails during cluster creation

**Causes:**
1. AWS quota exceeded
2. Invalid RHCS token
3. Account roles not created

**Solution:**
```bash
# Check AWS quotas
rosa verify quota

# Verify RHCS token
rosa login --token="$RHCS_TOKEN"
rosa whoami

# Check account roles
rosa list account-roles
```

## Cluster Configuration Issues

### Pod Security Errors

**Symptom:** Pods fail to start with security context errors

**Solution:**
```bash
# Verify SCC is applied
oc get scc confluent-scc

# Check SCC users
oc describe scc confluent-scc | grep Users

# Manually add service account to SCC if missing
oc adm policy add-scc-to-user confluent-scc \
  system:serviceaccount:confluent:default
```

### Image Pull Errors

**Symptom:** "ImagePullBackOff" or "ErrImagePull"

**Causes:**
1. Docker Hub rate limiting
2. Network connectivity issues
3. Wrong image tag

**Solution:**
```bash
# Check pod events
oc describe pod <pod-name> -n confluent

# Check image pull status
oc get events -n confluent | grep -i pull

# If rate limited, wait or add Docker Hub credentials
```

## Confluent Platform Issues

### KRaft Controller Not Starting

**Symptom:** KRaft pods in Pending or CrashLoopBackOff

**Debugging:**
```bash
# Check pod status
oc get pods -n confluent -l app=kraftcontroller

# Check events
oc describe pod kraftcontroller-0 -n confluent

# Check logs
oc logs kraftcontroller-0 -n confluent

# Check PVC binding
oc get pvc -n confluent | grep kraftcontroller
```

**Common causes:**
1. Insufficient node resources
2. PVC not binding (storage class issue)
3. Security context not allowed

### Kafka Not Connecting to KRaft

**Symptom:** Kafka pods failing with "Controller quorum not available"

**Solution:**
```bash
# Verify KRaft is running
oc get kraftcontroller -n confluent

# Check KRaft endpoints
oc get endpoints kraftcontroller -n confluent

# Check Kafka logs for controller connectivity
oc logs kafka-0 -n confluent | grep -i controller
```

### Schema Registry Connection Issues

**Symptom:** Schema Registry can't connect to Kafka

**Debugging:**
```bash
# Check SR logs
oc logs schemaregistry-0 -n confluent

# Verify Kafka bootstrap endpoint
oc get service kafka -n confluent

# Test connectivity from SR pod
oc exec schemaregistry-0 -n confluent -- \
  curl -v kafka.confluent.svc.cluster.local:9071
```

### Connect Worker Failures

**Symptom:** Connect pods restarting or connectors failing

**Debugging:**
```bash
# Check Connect logs
oc logs connect-0 -n confluent

# List connectors
oc exec connect-0 -n confluent -- \
  curl -s localhost:8083/connectors | jq .

# Get connector status
oc exec connect-0 -n confluent -- \
  curl -s localhost:8083/connectors/<connector-name>/status | jq .
```

### Control Center Not Accessible

**Symptom:** Control Center route returns 503 or connection refused

**Debugging:**
```bash
# Check Control Center pod
oc get pods -n confluent -l app=controlcenter

# Check route
oc get route controlcenter -n confluent

# Check service endpoints
oc get endpoints controlcenter -n confluent

# Check logs
oc logs controlcenter-0 -n confluent
```

## Resource Issues

### Pods Pending Due to Resources

**Symptom:** Pods stuck in "Pending" state

**Debugging:**
```bash
# Check pod events
oc describe pod <pod-name> -n confluent | grep -A5 Events

# Check node resources
oc top nodes

# Check if nodes have capacity
oc describe nodes | grep -A5 "Allocated resources"
```

**Solution:**
1. Scale down other workloads
2. Add more worker nodes
3. Reduce resource requests in manifests

### Storage Issues

**Symptom:** PVCs not binding or pods failing with volume errors

**Debugging:**
```bash
# Check PVC status
oc get pvc -n confluent

# Check storage class
oc get storageclass

# Check PV availability
oc get pv
```

## Useful Commands

```bash
# Get all Confluent resources
oc get kraftcontroller,kafka,schemaregistry,connect,ksqldb,controlcenter,kafkarestproxy -n confluent

# Watch pod status
oc get pods -n confluent -w

# Get all events (sorted by time)
oc get events -n confluent --sort-by='.lastTimestamp'

# Check operator logs
oc logs -n confluent-operator -l app=confluent-operator

# Force delete stuck pod
oc delete pod <pod-name> -n confluent --grace-period=0 --force

# Restart all pods of a component
oc rollout restart statefulset/kafka -n confluent

# Get component status
oc get kafka kafka -n confluent -o jsonpath='{.status.phase}'
```

## Getting Help

1. Check CFK documentation: https://docs.confluent.io/operator/current/
2. OpenShift documentation: https://docs.openshift.com/
3. ROSA documentation: https://docs.openshift.com/rosa/
4. Create GitHub issue with:
   - Workflow logs
   - Error messages
   - `oc get pods -n confluent` output
   - `oc get events -n confluent` output
