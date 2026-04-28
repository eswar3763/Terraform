# Real-Time Issues & RCA Guide for 3-Tier Application

## Complete Troubleshooting & Diagnostics for Terraform, AKS, Java, SQL

---

## 📋 Table of Contents

1. Real-Time Monitoring & Alerting
2. Terraform State Issues
3. AKS Cluster Issues
4. Pod Deployment Issues
5. Java Application Issues
6. SQL/Database Issues
7. Network & Connectivity Issues
8. Performance & Resource Issues
9. Security & Audit Logging
10. Complete RCA Procedures

---

## 1️⃣ Real-Time Monitoring & Alerting

### Azure Monitor Setup

```bash
# Create metric alert for pod restarts
az monitor metrics alert create \
  --name "Pod Restart Alert" \
  --resource-group rg-3tier-app-prod \
  --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-3tier-app-prod/providers/Microsoft.ContainerService/managedClusters/aks-prod \
  --condition "avg RestartingPodCount > 5" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --actions /subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-3tier-app-prod/providers/microsoft.insights/actionGroups/AlertGroup

# Create alert for high CPU
az monitor metrics alert create \
  --name "Pod CPU Alert" \
  --resource-group rg-3tier-app-prod \
  --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-3tier-app-prod/providers/Microsoft.ContainerService/managedClusters/aks-prod \
  --condition "avg CpuUsagePercentage > 80" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --actions /subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-3tier-app-prod/providers/microsoft.insights/actionGroups/AlertGroup

# Create alert for high memory
az monitor metrics alert create \
  --name "Pod Memory Alert" \
  --resource-group rg-3tier-app-prod \
  --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-3tier-app-prod/providers/Microsoft.ContainerService/managedClusters/aks-prod \
  --condition "avg MemoryUsagePercentage > 85" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --actions /subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-3tier-app-prod/providers/microsoft.insights/actionGroups/AlertGroup
```

### Prometheus & Grafana Dashboard

```yaml
# prometheus-rules.yml
groups:
  - name: kubernetes_pod_alerts
    rules:
      - alert: PodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0.1
        for: 5m
        annotations:
          summary: "Pod {{ $labels.pod_name }} is crash looping"

      - alert: PodNotHealthy
        expr: min_by(namespace, pod) (kube_pod_status_phase{phase=~"Pending|Unknown|Failed"}) == 1
        for: 15m
        annotations:
          summary: "Pod {{ $labels.pod }} in {{ $labels.namespace }} is unhealthy"

      - alert: HighMemoryUsage
        expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
        for: 5m
        annotations:
          summary: "Container {{ $labels.container_name }} memory usage is above 90%"

      - alert: HighCPUUsage
        expr: rate(container_cpu_usage_seconds_total[5m]) > 0.8
        for: 5m
        annotations:
          summary: "Container {{ $labels.container_name }} CPU usage is above 80%"

      - alert: PersistentVolumeUsageHigh
        expr: kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes > 0.85
        for: 5m
        annotations:
          summary: "PV {{ $labels.persistentvolumeclaim }} is 85% full"
```

---

## 2️⃣ Terraform State Issues & RCA

### Issue: Terraform State Lock (Deadlock)

**Symptoms:**
- `Error acquiring the state lock`
- `resource locked by another operation`
- Terraform commands hanging

**RCA Steps:**

```bash
# 1. Check current lock
az storage blob list \
  --container-name tfstate \
  --account-name $STORAGE_ACCOUNT_NAME \
  --query "[].name"

# 2. Identify lock file
# Look for .terraform.lock.hcl or lock files in blob storage

# 3. View lock details
az storage blob show \
  --container-name tfstate \
  --name "prod.tfstate.lock" \
  --account-name $STORAGE_ACCOUNT_NAME

# 4. If stuck, force unlock (CAUTION!)
az storage blob delete \
  --container-name tfstate \
  --name "prod.tfstate.lock" \
  --account-name $STORAGE_ACCOUNT_NAME \
  --account-key $STORAGE_KEY

# 5. Verify unlock
terraform state list
```

### Issue: State Drift (Resources Changed Outside Terraform)

**Symptoms:**
- `Resource has been changed outside of Terraform`
- Terraform wants to replace existing resources
- Unexpected plan changes

**RCA & Fix:**

```bash
# 1. Detect drift
terraform plan -out=tfplan
# Look for unexpected changes

# 2. Identify what changed
az resource show \
  --resource-group rg-3tier-app-prod \
  --name aks-prod \
  --resource-type "Microsoft.ContainerService/managedClusters"

# 3. Compare with state
terraform state show 'azurerm_kubernetes_cluster.aks'

# 4. Options to fix:

# Option A: Refresh state from reality
terraform refresh

# Option B: Import external changes
terraform import azurerm_kubernetes_cluster.aks \
  /subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-3tier-app-prod/providers/Microsoft.ContainerService/managedClusters/aks-prod

# Option C: Modify state manually (dangerous!)
terraform state pull > terraform.tfstate.backup
# Edit terraform.tfstate
terraform state push terraform.tfstate
```

### Issue: Resource Leaks (Orphaned Resources)

**Symptoms:**
- Azure billing for resources not in Terraform
- Resources exist but not tracked in state
- Unexpected costs

**RCA & Cleanup:**

```bash
# 1. Find all resources in resource group
az resource list \
  --resource-group rg-3tier-app-prod \
  --output table

# 2. Find resources in state
terraform state list

# 3. Import orphaned resources
terraform import azurerm_resource_group.main \
  /subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-3tier-app-prod

# 4. Or remove unneeded resources
terraform destroy -target=azurerm_resource.name

# 5. Verify cleanup
terraform plan
# Should show no unintended changes
```

### Issue: Terraform Apply Fails Mid-Execution

**Symptoms:**
- Some resources created, others failed
- State is inconsistent
- Subsequent applies fail

**RCA & Recovery:**

```bash
# 1. Check state consistency
terraform state list
terraform state show resource_name

# 2. Identify partially created resources
az resource list --resource-group rg-3tier-app-prod --output json | jq '.[] | .name'

# 3. Options to recover:

# Option A: Remove failed resource from state
terraform state rm 'azurerm_kubernetes_cluster.aks'
# Then re-import
terraform import azurerm_kubernetes_cluster.aks <resource_id>

# Option B: Taint resource for recreation
terraform taint azurerm_kubernetes_cluster.aks
terraform apply

# Option C: Manual cleanup then retry
az resource delete --id <resource_id>
terraform apply
```

---

## 3️⃣ AKS Cluster Issues & RCA

### Issue: Node Not Ready

**Symptoms:**
- `kubectl get nodes` shows `NotReady` status
- Pods cannot be scheduled
- Container runtime errors

**Diagnosis & Fix:**

```bash
# 1. Get node details
kubectl describe node <node-name>
# Check: Conditions, Events, Allocatable Resources

# 2. Check kubelet status
kubectl get node <node-name> -o yaml | grep -A 10 "conditions:"

# 3. Common causes and solutions:

# Cause: Disk pressure
# Solution: Clean container images and unused volumes
kubectl exec -it <pod-name> -- df -h
kubectl exec -it <pod-name> -- docker image prune -a -f
kubectl exec -it <pod-name> -- docker volume prune -f

# Cause: Memory pressure
# Solution: Evict low-priority pods
kubectl get pods -A --sort-by='.spec.priority'
kubectl delete pod <low-priority-pod> -n <namespace>

# Cause: Network plugin issue
# Solution: Restart kubelet
az aks nodepool upgrade \
  --resource-group rg-3tier-app-prod \
  --cluster-name aks-prod \
  --nodepool-name nodepool1 \
  --kubernetes-version 1.28.0

# 4. Restart node if needed
az aks node reboot \
  --resource-group rg-3tier-app-prod \
  --cluster-name aks-prod \
  --node-names <node-name>

# 5. Verify node recovery
kubectl get nodes -w
```

### Issue: Pods Stuck in Pending State

**Symptoms:**
- `kubectl get pods` shows `Pending` for extended time
- No error message in pod status
- Scheduler cannot find node

**Diagnosis & Fix:**

```bash
# 1. Get detailed pod status
kubectl describe pod <pod-name> -n three-tier-app
# Look for "Events" section

# 2. Check pod resource requests
kubectl get pod <pod-name> -n three-tier-app -o yaml | grep -A 5 "resources:"

# 3. Check node resources available
kubectl top nodes
kubectl top pod -n three-tier-app

# 4. Common causes and fixes:

# Cause: Insufficient CPU/Memory
# Fix: Scale down other pods or add nodes
kubectl scale deployment <deployment> --replicas=1
# OR
az aks nodepool scale \
  --resource-group rg-3tier-app-prod \
  --cluster-name aks-prod \
  --nodepool-name nodepool1 \
  --node-count 5

# Cause: Node selector not matching
# Fix: Check node labels
kubectl get nodes --show-labels
# Fix pod: Update deployment nodeSelector

# Cause: PVC not available
# Fix: Check PVC status
kubectl get pvc -n three-tier-app
kubectl describe pvc <pvc-name> -n three-tier-app

# 5. View scheduler logs
kubectl logs -n kube-system -l component=kube-scheduler | tail -100

# 6. Force pod scheduling
kubectl patch pod <pod-name> -n three-tier-app --type='json' \
  -p='[{"op": "remove", "path": "/spec/nodeName"}]'
```

### Issue: Pod CrashLooping (Restarting Continuously)

**Symptoms:**
- Pod restarts every few seconds
- `kubectl get pods` shows high restart count
- Application logs show repeated errors

**Diagnosis & Fix:**

```bash
# 1. Get pod logs (current and previous)
kubectl logs <pod-name> -n three-tier-app

# 2. Get previous crash logs
kubectl logs <pod-name> -n three-tier-app --previous
# Shows logs from last run before crash

# 3. Detailed pod status
kubectl describe pod <pod-name> -n three-tier-app
# Check: Last State, Last Termination Reason

# 4. Check resource limits
kubectl get pod <pod-name> -n three-tier-app -o yaml | grep -A 10 "resources:"

# 5. Common causes and solutions:

# Cause: OOMKilled (Out of Memory)
# Fix: Increase memory limit
kubectl set resources deployment user-service \
  --limits=memory=1Gi \
  -n three-tier-app

# Cause: Application startup failure
# Fix: Check application logs
kubectl logs <pod-name> -n three-tier-app -f
# Check Java startup: "java.lang.Exception", "ClassNotFoundException"

# Cause: Liveness probe failing
# Fix: Disable probe temporarily to diagnose
kubectl patch deployment user-service -n three-tier-app --type='json' \
  -p='[{"op": "remove", "path": "/spec/template/spec/containers/0/livenessProbe"}]'

# Cause: Database connection failure
# Fix: Verify database connectivity
kubectl exec <pod-name> -n three-tier-app -- nc -zv postgres-service 5432

# 6. Detailed event logs
kubectl get events -n three-tier-app --sort-by='.lastTimestamp'
```

### Issue: Service Cannot Reach Backend Pods

**Symptoms:**
- `curl` from pod to service fails
- External traffic cannot reach pods
- DNS resolution fails

**Diagnosis & Fix:**

```bash
# 1. Check service endpoints
kubectl get endpoints user-service -n three-tier-app
# Should show pod IPs

# 2. Check if pods are ready
kubectl get pods -n three-tier-app -o wide
# Check READY column (should be 1/1)

# 3. Test DNS resolution
kubectl exec -it <test-pod> -n three-tier-app -- nslookup user-service
kubectl exec -it <test-pod> -n three-tier-app -- nslookup user-service.three-tier-app.svc.cluster.local

# 4. Test connectivity
kubectl exec -it <test-pod> -n three-tier-app -- curl -v http://user-service:8080/health

# 5. Check service definition
kubectl describe service user-service -n three-tier-app
# Verify: Selector matches pod labels
# Verify: Port mapping is correct

# 6. Fix common issues:

# Issue: Pod labels don't match selector
# Fix: Update labels
kubectl label pods <pod-name> -n three-tier-app app=user-service

# Issue: Service port mismatch
# Fix: Check service ports
kubectl patch service user-service -n three-tier-app -p '{"spec":{"ports":[{"port":8080,"targetPort":8080}]}}'

# Issue: Network policy blocking traffic
# Fix: Check network policies
kubectl get networkpolicies -n three-tier-app
kubectl describe networkpolicy <policy-name> -n three-tier-app

# 7. Test from different pod
kubectl run -it test-pod --image=busybox --restart=Never -n three-tier-app -- sh
# Inside pod: wget -O- http://user-service:8080/health
```

---

## 4️⃣ Java Application Issues & RCA

### Issue: High Memory Usage / Memory Leak

**Symptoms:**
- Pod memory constantly increasing
- OOMKilled errors appearing
- Slow performance degradation

**Diagnosis & Fix:**

```bash
# 1. Get memory usage trend
kubectl top pod <pod-name> -n three-tier-app --containers
# Watch for continuous increase

# 2. Check Java heap settings
kubectl exec <pod-name> -n three-tier-app -- ps aux | grep java
# Look for: -Xmx (max heap), -Xms (initial heap)

# 3. Get heap dump for analysis
kubectl exec <pod-name> -n three-tier-app -- \
  jmap -dump:live,format=b,file=/tmp/heap.bin $(pgrep -f java)

# Copy heap dump for analysis
kubectl cp three-tier-app/<pod-name>:/tmp/heap.bin ./heap.bin

# Analyze with jhat (Java heap analysis tool)
jhat -J-Xmx4g heap.bin
# Open http://localhost:7000 for analysis

# 4. Enable GC logging
# Add to JVM_OPTS in deployment:
# -XX:+PrintGCDetails -XX:+PrintGCDateStamps -Xloggc:/var/log/gc.log

# 5. Check for leaks
kubectl exec <pod-name> -n three-tier-app -- tail -100 /var/log/gc.log

# 6. Fix common causes:

# Cause: Unbounded cache
# Fix: Add cache eviction policy in application code
# Check code: 
kubectl exec <pod-name> -n three-tier-app -- grep -r "HashMap\|ConcurrentHashMap" /app

# Cause: Database connection pool leak
# Fix: Check connection settings
kubectl exec <pod-name> -n three-tier-app -- \
  cat /app/application.properties | grep -i pool

# Solution: Limit pool size and ensure connections are closed
# spring.datasource.hikari.maximum-pool-size=10
# spring.datasource.hikari.connection-timeout=30000

# Cause: Thread leak
# Fix: Monitor thread count
kubectl exec <pod-name> -n three-tier-app -- \
  jstack $(pgrep -f java) | grep -i "tid\|nid" | wc -l

# 7. Increase memory as temporary fix
kubectl set resources deployment user-service \
  --limits=memory=2Gi,cpu=2000m \
  --requests=memory=512Mi,cpu=500m \
  -n three-tier-app
```

### Issue: High CPU Usage

**Symptoms:**
- CPU constantly at 100%
- Application slow
- Pods evicted for resource pressure

**Diagnosis & Fix:**

```bash
# 1. Identify high CPU process
kubectl exec <pod-name> -n three-tier-app -- top -b -n 1
# Shows which process consuming CPU

# 2. Get Java thread dump
kubectl exec <pod-name> -n three-tier-app -- \
  jstack $(pgrep -f java) > threadump.txt

# 3. Analyze for busy threads
grep "runnable\|waiting" threadump.txt | wc -l

# 4. Find infinite loops or busy waiting
grep -B 5 "java.lang.Thread.run" threadump.txt | head -50

# 5. Check for specific issues:

# Cause: Inefficient query
# Fix: Monitor database queries
kubectl logs <pod-name> -n three-tier-app | grep -i "slow query"

# Enable query logging in application:
# logging.level.org.hibernate.SQL=DEBUG
# logging.level.org.hibernate.type.descriptor.sql.BasicBinder=TRACE

# Cause: Inefficient algorithm
# Fix: Profile using JFR (Java Flight Recorder)
kubectl exec <pod-name> -n three-tier-app -- \
  jcmd $(pgrep -f java) JFR.start name=profile duration=60s

# Dump results
kubectl exec <pod-name> -n three-tier-app -- \
  jcmd $(pgrep -f java) JFR.dump name=profile

# 6. Reduce resource requirements
# Optimize code or add more CPU resources
kubectl set resources deployment user-service \
  --limits=cpu=2000m \
  --requests=cpu=1000m \
  -n three-tier-app

# 7. Scale horizontally
kubectl scale deployment user-service --replicas=3 -n three-tier-app
```

### Issue: Database Connection Timeout

**Symptoms:**
- SQL exceptions: "connection timeout"
- Application logs: "Cannot acquire a connection, pool error"
- Intermittent failures

**Diagnosis & Fix:**

```bash
# 1. Check database connectivity
kubectl exec <pod-name> -n three-tier-app -- \
  timeout 5 nc -zv postgres-service 5432

# 2. Check connection pool status
kubectl exec <pod-name> -n three-tier-app -- \
  curl localhost:8080/actuator/health/db

# Expected response:
# {"status":"UP","details":{"database":"PostgreSQL",...}}

# 3. View connection pool metrics
kubectl exec <pod-name> -n three-tier-app -- \
  curl localhost:8080/actuator/metrics/jdbc.connections.active

# 4. Check application logs
kubectl logs <pod-name> -n three-tier-app | grep -i "connection\|timeout"

# 5. Common causes and fixes:

# Cause: Connection pool exhausted
# Fix: Increase pool size
# In application.properties:
# spring.datasource.hikari.maximum-pool-size=20

# Cause: Slow queries blocking connections
# Fix: Kill long-running queries
kubectl exec -it postgres-pod -n three-tier-app -- psql -U sonar -d sonarqube
# SQL: SELECT pid, now() - pg_stat_activity.query_start AS duration, query FROM pg_stat_activity WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes';
# Kill: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE duration > interval '5 minutes';

# Cause: Network partition
# Fix: Verify network policy
kubectl get networkpolicies -n three-tier-app
kubectl describe networkpolicy <policy> -n three-tier-app

# 6. View HikariCP metrics
kubectl exec <pod-name> -n three-tier-app -- \
  curl -s localhost:8080/actuator/prometheus | grep hikari

# 7. Restart connection pool
kubectl delete pod <pod-name> -n three-tier-app
# New pod will have fresh connection pool
```

---

## 5️⃣ SQL/Database Issues & RCA

### Issue: Slow Queries

**Symptoms:**
- Database response time > 5 seconds
- CPU usage high on database
- Application timeouts

**Diagnosis & Fix:**

```bash
# 1. Enable slow query log
kubectl exec -it postgres-pod -n three-tier-app -- psql -U postgres

# SQL to run (in psql):
ALTER SYSTEM SET log_min_duration_statement = 1000;  -- Log queries > 1 second
SELECT pg_reload_conf();

# 2. View slow queries
kubectl exec -it postgres-pod -n three-tier-app -- \
  tail -100 /var/log/postgresql/postgresql.log | grep -i "duration:"

# 3. Identify expensive queries
kubectl exec -it postgres-pod -n three-tier-app -- psql -U postgres -d sonarqube

# SQL queries to run:
SELECT query, calls, mean_exec_time, max_exec_time 
FROM pg_stat_statements 
ORDER BY mean_exec_time DESC LIMIT 10;

# 4. Analyze query execution plan
EXPLAIN ANALYZE SELECT * FROM users WHERE status = 'active';
# Look for: Sequential Scans (should be Index Scans)
# Look for: High cost/time estimates

# 5. Create missing indexes
CREATE INDEX idx_users_status ON users(status);

# 6. Verify statistics are up to date
ANALYZE users;

# 7. Check for table bloat
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
FROM pg_tables 
WHERE schemaname NOT IN ('pg_catalog', 'information_schema') 
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

# 8. Perform maintenance
VACUUM ANALYZE;

# 9. Monitor ongoing
kubectl logs postgres-pod -n three-tier-app -f | grep "duration:"
```

### Issue: Disk Space Full

**Symptoms:**
- "No space left on device" errors
- Database becomes read-only
- Pod evicted for disk pressure

**Diagnosis & Fix:**

```bash
# 1. Check disk usage
kubectl exec -it postgres-pod -n three-tier-app -- df -h

# 2. Find large files
kubectl exec -it postgres-pod -n three-tier-app -- \
  du -sh /var/lib/postgresql/13/main/* | sort -h

# 3. Check log file size
kubectl exec -it postgres-pod -n three-tier-app -- \
  du -sh /var/log/postgresql/

# 4. Archive and clean logs
kubectl exec -it postgres-pod -n three-tier-app -- \
  gzip /var/log/postgresql/postgresql.log.* && \
  rm /var/log/postgresql/postgresql.log.*.gz

# 5. Vacuum database to reclaim space
kubectl exec -it postgres-pod -n three-tier-app -- psql -U postgres -d sonarqube

# SQL:
VACUUM FULL;  -- Aggressive cleanup, locks table
-- OR
VACUUM ANALYZE;  -- Non-blocking, safer

# 6. Identify table bloat
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

# 7. Reindex if needed
REINDEX DATABASE sonarqube;

# 8. Expand PVC (permanent fix)
# Edit PersistentVolumeClaim
kubectl edit pvc postgres-pvc -n three-tier-app
# Change: storage: 100Gi to 200Gi

# 9. Verify expansion
kubectl get pvc -n three-tier-app

# 10. Check WAL archive
ls -lah /var/lib/postgresql/13/main/pg_wal/
# Remove if too large:
rm /var/lib/postgresql/13/main/pg_wal/000000010000*
```

### Issue: Connection Pool Exhaustion

**Symptoms:**
- "Too many connections" error
- New connections cannot be established
- Application unresponsive

**Diagnosis & Fix:**

```bash
# 1. Check active connections
kubectl exec -it postgres-pod -n three-tier-app -- psql -U postgres

# SQL:
SELECT count(*) as connection_count FROM pg_stat_activity;
SELECT usename, count(*) FROM pg_stat_activity GROUP BY usename;

# 2. View connection details
SELECT pid, usename, application_name, client_addr, query_start, state
FROM pg_stat_activity 
ORDER BY query_start;

# 3. Identify idle connections
SELECT pid, usename, application_name, state, query_start
FROM pg_stat_activity 
WHERE state = 'idle' AND query_start < now() - interval '1 hour';

# 4. Kill idle connections
SELECT pg_terminate_backend(pid) FROM pg_stat_activity
WHERE state = 'idle' AND query_start < now() - interval '1 hour';

# 5. Increase max connections (temporary)
ALTER SYSTEM SET max_connections = 300;
SELECT pg_reload_conf();

# 6. Verify change
SHOW max_connections;

# 7. Check application connection pool settings
# In application.properties:
# spring.datasource.hikari.maximum-pool-size=20
# spring.datasource.hikari.idle-timeout=600000
# spring.datasource.hikari.max-lifetime=1800000

# 8. Monitor connections in real-time
watch -n 1 "kubectl exec -it postgres-pod -n three-tier-app -- psql -U postgres -c 'SELECT count(*) FROM pg_stat_activity;'"
```

### Issue: Replication Lag (HA Setup)

**Symptoms:**
- Read replicas out of sync
- Data inconsistency between primary and replica
- Failover to replica loses recent data

**Diagnosis & Fix:**

```bash
# 1. Check replication status on primary
kubectl exec -it postgres-primary -n three-tier-app -- psql -U postgres

# SQL:
SELECT client_addr, state, write_lag, flush_lag, replay_lag
FROM pg_stat_replication;

# 2. Check replica status
kubectl exec -it postgres-replica -n three-tier-app -- psql -U postgres

# SQL:
SELECT pg_is_wal_replay_paused();
SHOW hot_standby_feedback;

# 3. Monitor WAL progression
SELECT pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0');

# 4. Common causes and fixes:

# Cause: Network latency
# Fix: Verify network performance
kubectl exec postgres-primary -n three-tier-app -- \
  ping -c 10 postgres-replica

# Cause: Replica behind on replay
# Fix: Check replica resources
kubectl top pod postgres-replica -n three-tier-app

# Scale up replica resources
kubectl set resources pod postgres-replica -n three-tier-app \
  --limits=cpu=2000m,memory=2Gi

# Cause: WAL files being deleted too fast
# Fix: Increase WAL retention
# On primary:
ALTER SYSTEM SET wal_keep_size = '2GB';
SELECT pg_reload_conf();

# 5. Pause replay if needed (to catch up)
kubectl exec -it postgres-replica -n three-tier-app -- psql -U postgres

# SQL:
SELECT pg_wal_replay_pause();
-- Let it catch up
SELECT pg_wal_replay_resume();

# 6. Monitor replication slot status
SELECT slot_name, active, restart_lsn FROM pg_replication_slots;
```

---

## 6️⃣ Network & Connectivity Issues

### Issue: External Traffic Cannot Reach Application

**Symptoms:**
- External curl fails
- Application Gateway returning 502 (Bad Gateway)
- DNS resolves but traffic doesn't reach pod

**Diagnosis & Fix:**

```bash
# 1. Check Application Gateway backend health
az network application-gateway http-settings list \
  --resource-group rg-3tier-app-prod \
  --gateway-name appgw-3tier

# View backend pool health
az network application-gateway address-pool list \
  --resource-group rg-3tier-app-prod \
  --gateway-name appgw-3tier

# 2. Check if pods are healthy
kubectl get pods -n three-tier-app -o wide
# Check STATUS and READY columns

# 3. Manually test from AppGW
# SSH to AppGW and test:
kubectl exec <appgw-pod> -- curl -v http://<pod-ip>:8080/health

# 4. Check Application Gateway rules
az network application-gateway rule list \
  --resource-group rg-3tier-app-prod \
  --gateway-name appgw-3tier \
  --output table

# 5. Verify listener configuration
az network application-gateway http-listener list \
  --resource-group rg-3tier-app-prod \
  --gateway-name appgw-3tier

# 6. Test routing rules
# Ensure URL paths are correct
# Example: /api should route to user-service
# /orders should route to order-service
# /payments should route to payment-service

# 7. Check for firewall rules
az network nsg list -g rg-3tier-app-prod --output table

# Verify inbound rules allow traffic to port 443/80
az network nsg rule list \
  --resource-group rg-3tier-app-prod \
  --nsg-name appgw-nsg \
  --output table

# 8. Test HTTPS certificate
openssl s_client -connect yourdomain.com:443

# 9. Enable AppGW diagnostic logs
az monitor diagnostic-settings create \
  --resource /subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-3tier-app-prod/providers/Microsoft.Network/applicationGateways/appgw-3tier \
  --name appgw-logs \
  --logs '[{"category": "ApplicationGatewayAccessLog", "enabled": true}]' \
  --workspace /subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-3tier-app-prod/providers/microsoft.operationalinsights/workspaces/law-3tier

# 10. View AppGW logs
az monitor log-analytics query \
  --workspace rg-3tier-app-prod \
  --analytics-query "AzureDiagnostics | where ResourceType == 'APPLICATIONGATEWAYS' | top 100 by TimeGenerated desc"
```

### Issue: Pod-to-Pod Communication Fails

**Symptoms:**
- Pods on same cluster cannot reach each other
- Cross-namespace communication fails
- Network policy violation errors

**Diagnosis & Fix:**

```bash
# 1. Test connectivity between pods
kubectl exec -it <source-pod> -n three-tier-app -- \
  curl -v http://target-service:8080/health

# 2. Test DNS resolution
kubectl exec -it <source-pod> -n three-tier-app -- \
  nslookup order-service
kubectl exec -it <source-pod> -n three-tier-app -- \
  nslookup order-service.three-tier-app.svc.cluster.local

# 3. Check network policies
kubectl get networkpolicies -n three-tier-app
kubectl describe networkpolicy <policy> -n three-tier-app

# 4. Test without network policy (temp)
kubectl delete networkpolicy <policy> -n three-tier-app
# Retry connectivity
# Reinstall policy after testing

# 5. Fix network policy if needed
# Ensure ingress rules allow traffic from source pods:
kubectl patch networkpolicy user-service -n three-tier-app --type='json' \
  -p='[{"op":"add","path":"/spec/ingress/0/from/0/podSelector","value":{"matchLabels":{"app":"order-service"}}}]'

# 6. Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns

# 7. Test DNS
kubectl run -it dnsutils --image=gcr.io/kubernetes-e2e-test-images/dnsutils:1.3 -- sh
# Inside pod:
nslookup kubernetes.default
nslookup order-service.three-tier-app

# 8. Check service endpoints
kubectl get endpoints order-service -n three-tier-app
# Should show pod IPs

# 9. Verify pod labels
kubectl get pods -n three-tier-app --show-labels
# Ensure labels match service selector

# 10. View network policy logs
kubectl logs -n kube-system -l app=calico-node | grep -i "drop\|deny"
```

---

## 7️⃣ Performance & Resource Issues

### Issue: Node Under Memory Pressure

**Symptoms:**
- Pods evicted suddenly
- "Memory pressure" in node status
- OOMKilled pods increasing

**Diagnosis & Fix:**

```bash
# 1. Check node memory status
kubectl describe node <node-name> | grep -A 10 "Conditions:"

# 2. View memory usage by pod
kubectl top pods -n three-tier-app

# 3. Find high-memory pods
kubectl top pods --all-namespaces --sort-by=memory | head -20

# 4. Check node capacity vs allocated
kubectl describe node <node-name> | grep -A 5 "Allocated resources"

# 5. Common solutions:

# Solution A: Scale down less important pods
kubectl scale deployment logging --replicas=0

# Solution B: Increase node count
az aks nodepool scale \
  --resource-group rg-3tier-app-prod \
  --cluster-name aks-prod \
  --nodepool-name nodepool1 \
  --node-count 5

# Solution C: Reduce resource requests
kubectl set resources deployment user-service \
  --requests=memory=256Mi \
  --limits=memory=512Mi \
  -n three-tier-app

# Solution D: Enable horizontal pod autoscaler
kubectl autoscale deployment user-service \
  --min=2 --max=5 \
  --cpu-percent=80 \
  -n three-tier-app

# 6. Set pod priority for eviction order
kubectl patch pod <pod-name> -n three-tier-app \
  -p '{"spec":{"priority":1000}}'

# 7. Monitor for improvements
watch -n 5 kubectl top pods -n three-tier-app
```

### Issue: Disk I/O Bottleneck

**Symptoms:**
- High disk latency
- Slow database queries despite good query plans
- Pods slowly reading/writing data

**Diagnosis & Fix:**

```bash
# 1. Monitor disk I/O
kubectl exec -it <pod> -- iostat -x 1 5
# Look for: high await, util > 80%

# 2. Check PVC usage
kubectl get pvc -n three-tier-app
kubectl exec -it <pod> -- df -h /data

# 3. Monitor disk activity
kubectl exec -it <pod> -- \
  iotop -P -b -n 1 -o | head -20

# 4. Check for large sequential reads/writes
kubectl exec -it <pod> -- strace -e open,read,write -c ls -la /data

# 5. Solutions:

# Solution A: Switch to SSD storage class
kubectl patch pvc postgres-pvc -n three-tier-app \
  -p '{"spec":{"storageClassName":"premium-ssd"}}'

# Solution B: Enable read caching in application
# Add to Java application:
# @Cacheable(cacheNames="users")
# public User getUser(String id)

# Solution C: Disable disk sync for non-critical data
# In PostgreSQL:
ALTER SYSTEM SET synchronous_commit = off;

# 6. Monitor improvements
watch -n 2 "kubectl exec -it postgres-pod -- iostat -x 1 1"
```

---

## 8️⃣ Security & Audit Logging

### Enable AKS Audit Logging

```bash
# 1. Create Log Analytics Workspace
az monitor log-analytics workspace create \
  --resource-group rg-3tier-app-prod \
  --workspace-name law-aks-audit \
  --location eastus

# 2. Enable diagnostic logging for AKS
az monitor diagnostic-settings create \
  --name "aks-audit-logs" \
  --resource /subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-3tier-app-prod/providers/Microsoft.ContainerService/managedClusters/aks-prod \
  --logs '[
    {"category":"kube-apiserver-audit","enabled":true},
    {"category":"kube-audit","enabled":true},
    {"category":"kube-audit-admin","enabled":true},
    {"category":"kube-controller-manager","enabled":true},
    {"category":"kube-scheduler","enabled":true}
  ]' \
  --workspace /subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-3tier-app-prod/providers/microsoft.operationalinsights/workspaces/law-aks-audit

# 3. Query audit logs
az monitor log-analytics query \
  --workspace rg-3tier-app-prod \
  --analytics-query "
    AzureDiagnostics
    | where Category == 'kube-apiserver-audit'
    | where verb in ('create', 'delete', 'patch')
    | project TimeGenerated, verb, objectRef_namespace, objectRef_name, user_username, sourceIPs_s
    | order by TimeGenerated desc
    | limit 100
  "

# 4. View specific event types
# Pod creation events
az monitor log-analytics query \
  --workspace rg-3tier-app-prod \
  --analytics-query "
    AzureDiagnostics
    | where Category == 'kube-apiserver-audit'
    | where verb == 'create' and objectRef_resource == 'pods'
    | project TimeGenerated, objectRef_namespace, objectRef_name, user_username
  "

# 5. View failed authentication
az monitor log-analytics query \
  --workspace rg-3tier-app-prod \
  --analytics-query "
    AzureDiagnostics
    | where Category == 'kube-apiserver-audit'
    | where responseStatus_code >= 400
    | where responseStatus_code < 500
    | project TimeGenerated, user_username, verb, objectRef_resource, responseStatus_code
  "

# 6. Monitor suspicious activities
az monitor log-analytics query \
  --workspace rg-3tier-app-prod \
  --analytics-query "
    AzureDiagnostics
    | where Category == 'kube-apiserver-audit'
    | where verb == 'delete' or verb == 'patch'
    | where objectRef_resource in ('secrets', 'configmaps', 'rbac')
    | project TimeGenerated, user_username, verb, objectRef_namespace, objectRef_name
  "

# 7. Create alert for suspicious activities
az monitor metrics alert create \
  --name "Pod Exec Alert" \
  --resource-group rg-3tier-app-prod \
  --description "Alert when exec command runs in pod" \
  --condition "AzureDiagnostics | where verb == 'create' and objectRef_resource == 'pods/exec'"

# 8. Enable Pod Security Policy
kubectl create ns three-tier-app
kubectl label namespace three-tier-app pod-security.kubernetes.io/enforce=baseline
kubectl label namespace three-tier-app pod-security.kubernetes.io/warn=restricted

# 9. View Pod Security Policy violations
kubectl get events -n three-tier-app --field-selector type=Warning
```

### View Kubernetes Events (Audit Trail)

```bash
# 1. Get all events in cluster
kubectl get events -A --sort-by='.lastTimestamp'

# 2. Get events for specific namespace
kubectl get events -n three-tier-app

# 3. Get events for specific pod
kubectl get events -n three-tier-app | grep <pod-name>

# 4. Watch real-time events
kubectl get events -n three-tier-app -w

# 5. Get detailed event information
kubectl describe event <event-name> -n three-tier-app

# 6. Export events for analysis
kubectl get events -A -o json > events.json
kubectl get events -A -o yaml > events.yaml
kubectl get events -A -o csv > events.csv

# 7. Filter specific event types
# Pod warnings
kubectl get events -n three-tier-app --field-selector type=Warning

# Pod normal events
kubectl get events -n three-tier-app --field-selector type=Normal

# 8. Monitor pod creation/deletion
kubectl get events -n three-tier-app | grep -E "Created|Deleted"

# 9. Monitor resource warnings
kubectl get events -n three-tier-app | grep -i "memory\|cpu\|disk"

# 10. Check RBAC permission changes
kubectl get events -n three-tier-app | grep -i "rbac\|permission\|forbidden"
```

---

## 9️⃣ Complete RCA Procedure

### RCA Workflow

```bash
#!/bin/bash

# Step 1: Collect System Information
echo "=== COLLECTING SYSTEM INFO ==="
echo "Cluster status:"
kubectl cluster-info
kubectl get nodes
kubectl top nodes

echo "Pod status:"
kubectl get pods -n three-tier-app -o wide
kubectl top pods -n three-tier-app

# Step 2: Collect Pod Logs
echo "=== COLLECTING POD LOGS ==="
for pod in $(kubectl get pods -n three-tier-app -o name); do
  echo "=== Logs for $pod ==="
  kubectl logs $pod -n three-tier-app --tail=100 > logs_$(basename $pod).txt
  kubectl logs $pod -n three-tier-app --previous >> logs_$(basename $pod)_previous.txt 2>/dev/null
done

# Step 3: Collect Resource Metrics
echo "=== COLLECTING METRICS ==="
kubectl describe nodes > nodes_info.txt
kubectl describe pod -n three-tier-app > pods_info.txt
kubectl get events -n three-tier-app -o wide > events.txt

# Step 4: Collect Application Metrics
echo "=== COLLECTING APP METRICS ==="
for pod in $(kubectl get pods -n three-tier-app -o name); do
  echo "Health check for $pod:"
  kubectl exec $(basename $pod) -n three-tier-app -- \
    curl -s localhost:8080/actuator/health >> app_health.txt 2>&1
done

# Step 5: Database Diagnostics
echo "=== DATABASE DIAGNOSTICS ==="
kubectl exec -it postgres-pod -n three-tier-app -- psql -U postgres << EOF >> db_diagnostics.txt
SELECT version();
SELECT count(*) as connection_count FROM pg_stat_activity;
SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;
SELECT * FROM pg_stat_replication;
EOF

# Step 6: Network Diagnostics
echo "=== NETWORK DIAGNOSTICS ==="
kubectl exec test-pod -n three-tier-app -- \
  curl -v http://user-service:8080/health >> network_test.txt 2>&1

# Step 7: Summary Report
echo "=== RCA SUMMARY ==="
echo "Timestamp: $(date)"
echo "Cluster: $(kubectl config current-context)"
echo "Issue: $1"
echo "Logs collected in: $(pwd)"
ls -la *.txt

# Step 8: Generate summary for analysis
cat > RCA_REPORT.md << 'REPORT'
# Root Cause Analysis Report

## Issue Summary
$(cat RCA_ISSUE.txt)

## Timeline
- Start time: 
- End time: 
- Duration: 

## Affected Services
- 
- 

## Investigation Steps
1. Collected pod logs
2. Analyzed resource metrics
3. Reviewed database statistics
4. Tested network connectivity
5. Examined application health endpoints

## Findings
- 

## Root Cause
- 

## Resolution
- 

## Prevention
- 

## Lessons Learned
- 
REPORT

echo "RCA Report generated: RCA_REPORT.md"
```

---

## 🔟 Common Issues Quick Reference

| Issue | Symptoms | Quick Fix |
|-------|----------|-----------|
| Pod Pending | Can't schedule | `kubectl describe pod`, check node resources |
| Pod CrashLoop | Restarting | `kubectl logs --previous`, check startup errors |
| OOMKilled | Out of memory | `kubectl top pod`, increase memory limit |
| High CPU | CPU at 100% | `jstack`, identify busy threads |
| Connection Timeout | DB unreachable | `nc -zv`, check network policies |
| Slow Query | Query > 5s | Enable slow log, `EXPLAIN ANALYZE` |
| Disk Full | No space | `df -h`, `VACUUM`, expand PVC |
| Node NotReady | Unavailable node | Check kubelet, restart if needed |
| DNS Fail | Can't resolve | Check CoreDNS pods, restart if needed |
| Replication Lag | Data out of sync | Check `pg_stat_replication`, increase WAL |

---

## 📊 Monitoring Dashboard Queries

### Prometheus Queries for Monitoring

```promql
# Pod restart rate
rate(kube_pod_container_status_restarts_total[15m])

# Memory usage percentage
container_memory_usage_bytes / container_spec_memory_limit_bytes * 100

# CPU usage
rate(container_cpu_usage_seconds_total[5m])

# Pod count by namespace
count(kube_pod_info) by (namespace)

# PVC usage
kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes * 100

# Database connections
pg_stat_activity_count

# Database query latency
rate(pg_query_duration_seconds_bucket[5m])
```

---

## ✅ Verification & Testing

```bash
# Complete system health check script
#!/bin/bash

echo "=== SYSTEM HEALTH CHECK ==="

# 1. Cluster health
echo "Cluster Status:"
kubectl cluster-info

# 2. Node health
echo "Node Status:"
kubectl get nodes
echo "Node Resources:"
kubectl top nodes

# 3. Pod health
echo "Pod Status:"
kubectl get pods -A
echo "Pod Restarts:"
kubectl get pods -A -o json | jq '.items[] | select(.status.containerStatuses[].restartCount > 5)'

# 4. Database health
echo "Database Connections:"
kubectl exec -it postgres-pod -- psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# 5. Application health
echo "Application Health:"
kubectl exec <user-service-pod> -- curl -s localhost:8080/actuator/health

# 6. Network connectivity
echo "Network Connectivity:"
kubectl exec test-pod -- curl -s http://user-service:8080/health

# 7. Storage health
echo "Storage Status:"
kubectl get pvc -A

echo "=== HEALTH CHECK COMPLETE ==="
```

---

**Complete RCA & Troubleshooting Guide Ready!** 🎉

All stages covered: Terraform, AKS, Java, SQL with real-time diagnostics and audit logging.
