# Troubleshooting Guide

This guide covers common issues and their solutions when deploying Confluent Platform on OpenShift.

## Infrastructure Issues

### Terraform State Lock

**Symptom:** Terraform fails with "Error acquiring the state lock"

**Solution:**
```bash
# Check for running workflows first
# If no workflows running, force unlock
terraform force-unlock <LOCK_ID>
```

### ROSA Cluster Creation Fails

**Symptom:** Terraform timeout or "Cluster creation failed"

**Causes:**
1. AWS quota exceeded
2. Invalid RHCS token
3. Network configuration issues

**Solution:**
```bash
# Verify AWS quotas
rosa verify quota

# Check RHCS token
rosa login --token="$RHCS_TOKEN"
rosa whoami

# Check ROSA status
rosa describe cluster -c <cluster-name>
```

### VPC/Subnet Issues

**Symptom:** "Insufficient IP addresses" or subnet creation fails

**Solution:**
1. Check CIDR blocks don't overlap
2. Verify no existing VPCs with same CIDR
3. Increase subnet sizes if needed

## Cluster Configuration Issues

### Pod Security Admission Errors

**Symptom:** Pods fail to start with security context errors

**Solution:**
```bash
# Verify SCC is applied
oc get scc confluent-scc

# Check SCC users
oc describe scc confluent-scc | grep Users

# Add service account to SCC if missing
oc adm policy add-scc-to-user confluent-scc \
  system:serviceaccount:confluent:default
```

### ECR Pull Errors

**Symptom:** "ImagePullBackOff" or "ErrImagePull"

**Causes:**
1. ECR credentials expired
2. Images not mirrored
3. Wrong image path

**Solution:**
```bash
# Check if secret exists
oc get secret ecr-pull-secret -n confluent

# Refresh ECR credentials
aws ecr get-login-password --region us-east-1 | \
  oc create secret docker-registry ecr-pull-secret \
    --docker-server=<ECR_URL> \
    --docker-username=AWS \
    --docker-password-stdin \
    -n confluent \
    --dry-run=client -o yaml | oc apply -f -

# Verify images exist in ECR
aws ecr describe-images --repository-name confluent/cp-server
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

# Check PVC
oc get pvc -n confluent | grep kraftcontroller
```

**Common causes:**
1. Insufficient resources
2. PVC not binding (storage class issue)
3. Security context not allowed

### Kafka Not Connecting to KRaft

**Symptom:** Kafka pods failing with "Controller quorum not available"

**Solution:**
```bash
# Verify KRaft is running
oc get kraftcontroller -n confluent

# Check KRaft controller endpoints
oc get endpoints kraftcontroller -n confluent

# Check Kafka logs
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

## External Secrets Issues

### Secrets Not Syncing

**Symptom:** ExternalSecret shows "SecretSyncedError"

**Debugging:**
```bash
# Check ExternalSecret status
oc describe externalsecret confluent-credentials -n confluent

# Check SecretStore status
oc describe secretstore aws-secrets-manager -n confluent

# Verify IRSA is working
oc describe serviceaccount external-secrets-sa -n confluent
```

**Solution:**
```bash
# Test AWS access from pod
oc run aws-test --rm -it --image=amazon/aws-cli -- \
  sts get-caller-identity

# Verify secret exists in AWS
aws secretsmanager get-secret-value \
  --secret-id confluent/dev/credentials
```

## cert-manager Issues

### Certificate Not Issued

**Symptom:** Certificate stuck in "Pending" state

**Debugging:**
```bash
# Check certificate status
oc describe certificate wildcard-tls -n confluent

# Check certificate request
oc get certificaterequest -n confluent

# Check challenges
oc get challenges -n confluent

# Check ClusterIssuer
oc describe clusterissuer letsencrypt-staging
```

**Common causes:**
1. DNS propagation delay
2. Route53 permissions
3. Rate limiting (use staging first)

**Solution:**
```bash
# Check cert-manager logs
oc logs -n cert-manager -l app=cert-manager

# Verify Route53 access
aws route53 list-hosted-zones
```

## ArgoCD Issues

### Application Out of Sync

**Symptom:** ArgoCD shows application as "OutOfSync"

**Debugging:**
```bash
# Check sync status
argocd app get confluent-platform-dev

# Check diff
argocd app diff confluent-platform-dev

# Manual sync
argocd app sync confluent-platform-dev
```

### Git Repository Access Denied

**Symptom:** ArgoCD can't access repository

**Solution:**
```bash
# Verify repository secret
oc get secret repo-confluent-gitops -n openshift-gitops

# Check SSH key
oc get secret repo-confluent-gitops -n openshift-gitops \
  -o jsonpath='{.data.sshPrivateKey}' | base64 -d

# Test Git access
ssh -T git@github.com
```

## Monitoring Issues

### ServiceMonitor Not Scraping

**Symptom:** No metrics in Prometheus

**Debugging:**
```bash
# Check if user workload monitoring is enabled
oc get configmap cluster-monitoring-config -n openshift-monitoring

# Check ServiceMonitor
oc describe servicemonitor kafka -n confluent

# Verify target endpoints
oc get endpoints -n confluent | grep prometheus
```

## Performance Issues

### High Latency

**Debugging:**
```bash
# Check pod resource usage
oc top pods -n confluent

# Check node resources
oc top nodes

# Check Kafka metrics
oc exec kafka-0 -n confluent -- \
  kafka-run-class kafka.tools.JmxTool \
  --jmx-url service:jmx:rmi:///jndi/rmi://localhost:7203/jmxrmi \
  --object-name kafka.server:type=BrokerTopicMetrics,name=MessagesInPerSec
```

### Storage Issues

**Debugging:**
```bash
# Check PVC utilization
oc exec kafka-0 -n confluent -- df -h /var/lib/kafka/data

# Check storage class
oc get storageclass gp3-csi -o yaml

# Check PV status
oc get pv | grep confluent
```

## Useful Commands

```bash
# Get all Confluent resources
oc get kraftcontroller,kafka,schemaregistry,connect,ksqldb,controlcenter,kafkarestproxy -n confluent

# Watch pod status
oc get pods -n confluent -w

# Get all events (sorted by time)
oc get events -n confluent --sort-by='.lastTimestamp'

# Force delete stuck pods
oc delete pod <pod-name> -n confluent --grace-period=0 --force

# Restart all pods of a component
oc rollout restart statefulset/kafka -n confluent
```

## Getting Help

1. Check CFK documentation: https://docs.confluent.io/operator/current/
2. OpenShift documentation: https://docs.openshift.com/
3. Create GitHub issue with:
   - Environment details
   - Error messages
   - Relevant logs
   - Steps to reproduce
