# ROSA & OpenShift CLI Cheatsheet

## ROSA CLI Commands

### Cluster Management

```bash
# List all clusters
rosa list clusters

# Create a cluster
rosa create cluster --cluster-name=<name> --region=<region>

# Create cluster with STS (recommended)
rosa create cluster --cluster-name=<name> --sts --mode=auto

# Delete a cluster
rosa delete cluster --cluster=<name>

# Describe cluster details
rosa describe cluster --cluster=<name>

# Watch cluster installation progress
rosa logs install --cluster=<name> --watch
```

### Account & Authentication

```bash
# Login to ROSA
rosa login --token=<token>

# Verify credentials
rosa whoami

# Verify quota
rosa verify quota

# Verify permissions
rosa verify permissions
```

### Identity Provider (IDP)

```bash
# Add HTPasswd IDP
rosa create idp --cluster=<name> --type=htpasswd --name=htpasswd-idp

# Add LDAP IDP
rosa create idp --cluster=<name> --type=ldap --name=ldap-idp

# List IDPs
rosa list idps --cluster=<name>

# Delete IDP
rosa delete idp --cluster=<name> <idp-name>
```

### Users & Roles

```bash
# Create admin user
rosa create admin --cluster=<name>

# Grant user cluster-admin
rosa grant user cluster-admin --cluster=<name> --user=<username>

# Revoke cluster-admin
rosa revoke user cluster-admin --cluster=<name> --user=<username>

# List users
rosa list users --cluster=<name>
```

### Machine Pools

```bash
# List machine pools
rosa list machinepools --cluster=<name>

# Create machine pool
rosa create machinepool --cluster=<name> --name=<pool-name> \
  --replicas=3 --instance-type=m5.xlarge

# Edit machine pool
rosa edit machinepool --cluster=<name> <pool-name> --replicas=5

# Delete machine pool
rosa delete machinepool --cluster=<name> <pool-name>
```

### Upgrades

```bash
# List available upgrades
rosa list upgrades --cluster=<name>

# Schedule upgrade
rosa upgrade cluster --cluster=<name> --version=<version>
```

---

## OpenShift CLI (oc) Commands

### Authentication & Context

```bash
# Login to cluster
oc login <api-url> -u <username> -p <password>

# Login with token
oc login --token=<token> --server=<api-url>

# Show current user
oc whoami

# Show current context
oc whoami --show-context

# Show API server
oc whoami --show-server

# Get authentication token
oc whoami -t
```

### Project/Namespace Management

```bash
# List all projects
oc projects

# Switch to project
oc project <project-name>

# Create new project
oc new-project <name> --description="<desc>"

# Delete project
oc delete project <name>
```

### Resource Management

```bash
# Get resources
oc get pods
oc get deployments
oc get services
oc get routes
oc get configmaps
oc get secrets
oc get pvc
oc get nodes

# Get all resources in namespace
oc get all

# Get resources across all namespaces
oc get pods -A
oc get pods --all-namespaces

# Watch resources
oc get pods -w

# Get with wide output
oc get pods -o wide

# Get YAML output
oc get pod <name> -o yaml

# Get JSON output
oc get pod <name> -o json
```

### Describe & Logs

```bash
# Describe resource
oc describe pod <name>
oc describe node <name>
oc describe deployment <name>

# Get logs
oc logs <pod-name>

# Follow logs
oc logs -f <pod-name>

# Logs for specific container
oc logs <pod-name> -c <container-name>

# Previous container logs
oc logs <pod-name> --previous

# Tail logs
oc logs <pod-name> --tail=100
```

### Create & Apply

```bash
# Create from file
oc create -f <file.yaml>

# Apply configuration
oc apply -f <file.yaml>

# Apply from directory
oc apply -f <directory>/

# Apply from URL
oc apply -f https://example.com/resource.yaml

# Create secret
oc create secret generic <name> --from-literal=key=value
oc create secret generic <name> --from-file=<path>

# Create configmap
oc create configmap <name> --from-literal=key=value
oc create configmap <name> --from-file=<path>
```

### Edit & Patch

```bash
# Edit resource
oc edit deployment <name>

# Patch resource
oc patch deployment <name> -p '{"spec":{"replicas":3}}'

# Add label
oc label pod <name> env=production

# Add annotation
oc annotate pod <name> description="my pod"
```

### Delete Resources

```bash
# Delete resource
oc delete pod <name>
oc delete -f <file.yaml>

# Delete with label selector
oc delete pods -l app=myapp

# Force delete
oc delete pod <name> --force --grace-period=0

# Delete all pods in namespace
oc delete pods --all
```

### Exec & Debug

```bash
# Execute command in pod
oc exec <pod-name> -- <command>

# Interactive shell
oc exec -it <pod-name> -- /bin/bash
oc exec -it <pod-name> -- /bin/sh

# Execute in specific container
oc exec -it <pod-name> -c <container> -- /bin/bash

# Debug node
oc debug node/<node-name>

# Debug with image
oc debug deployment/<name> --image=<debug-image>

# Copy files to/from pod
oc cp <pod-name>:<path> <local-path>
oc cp <local-path> <pod-name>:<path>
```

### Scaling & Rollouts

```bash
# Scale deployment
oc scale deployment <name> --replicas=3

# Autoscale
oc autoscale deployment <name> --min=2 --max=10 --cpu-percent=80

# Rollout status
oc rollout status deployment/<name>

# Rollout history
oc rollout history deployment/<name>

# Rollback
oc rollout undo deployment/<name>

# Restart deployment
oc rollout restart deployment/<name>

# Pause/Resume rollout
oc rollout pause deployment/<name>
oc rollout resume deployment/<name>
```

### Routes & Networking

```bash
# Expose service
oc expose svc/<service-name>

# Create route with TLS
oc create route edge --service=<svc> --hostname=<host>

# Get route URL
oc get route <name> -o jsonpath='{.spec.host}'

# Port forward
oc port-forward pod/<name> 8080:8080
oc port-forward svc/<name> 8080:8080
```

### Service Accounts & RBAC

```bash
# Create service account
oc create serviceaccount <name>

# Add role to user
oc adm policy add-role-to-user <role> <user>

# Add cluster role to user
oc adm policy add-cluster-role-to-user cluster-admin <user>

# Add SCC to service account
oc adm policy add-scc-to-user anyuid -z <sa-name>

# View who can perform action
oc adm policy who-can <verb> <resource>
```

### Cluster Administration

```bash
# Get cluster version
oc get clusterversion

# Get cluster operators
oc get clusteroperators
oc get co

# Node management
oc get nodes
oc describe node <name>
oc adm top nodes

# Cordon/Uncordon node
oc adm cordon <node>
oc adm uncordon <node>

# Drain node
oc adm drain <node> --ignore-daemonsets --delete-emptydir-data

# Get cluster info
oc cluster-info
```

### Troubleshooting

```bash
# Get events
oc get events --sort-by='.lastTimestamp'

# Get events for specific resource
oc get events --field-selector involvedObject.name=<pod-name>

# Check resource usage
oc adm top pods
oc adm top nodes

# Run diagnostics
oc adm diagnostics

# API resources
oc api-resources

# Explain resource
oc explain pod.spec.containers
```

### Useful Shortcuts

```bash
# Quick resource aliases
oc get po          # pods
oc get deploy      # deployments
oc get svc         # services
oc get cm          # configmaps
oc get ns          # namespaces
oc get no          # nodes
oc get pv          # persistentvolumes
oc get pvc         # persistentvolumeclaims
oc get rs          # replicasets
oc get ds          # daemonsets
oc get sts         # statefulsets
oc get ing         # ingresses
oc get crd         # customresourcedefinitions
```

### JSONPath Examples

```bash
# Get pod IPs
oc get pods -o jsonpath='{.items[*].status.podIP}'

# Get node names
oc get nodes -o jsonpath='{.items[*].metadata.name}'

# Get image names
oc get pods -o jsonpath='{.items[*].spec.containers[*].image}'

# Custom columns
oc get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase
```
