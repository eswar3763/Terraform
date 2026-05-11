# Kubernetes Storage Management - Complete Guide
## Persistent Volumes, Storage Classes, and Data Persistence in AKS

**Last Updated**: May 2026  
**Version**: 1.0.0

---

## Table of Contents
1. [Storage Architecture Overview](#storage-architecture-overview)
2. [Storage Classes in AKS](#storage-classes-in-aks)
3. [Persistent Volumes & Claims](#persistent-volumes--claims)
4. [Data Persistence Patterns](#data-persistence-patterns)
5. [Backup & Recovery](#backup--recovery)
6. [Performance Optimization](#performance-optimization)
7. [Interview Q&A](#interview-qa)
8. [Troubleshooting Guide](#troubleshooting-guide)

---

## Storage Architecture Overview

### Storage Tiers in AKS

```
┌──────────────────────────────────────────────────────────┐
│            Kubernetes Storage Hierarchy                  │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  TIER 1: Container Filesystem (Ephemeral)               │
│  ├─ Lifecycle: Container lifetime                       │
│  ├─ Performance: High (local node disk)                │
│  ├─ Use Case: Logs, cache, temp files                  │
│  ├─ Data Loss: Lost when pod terminates               │
│  └─ Example: /tmp, /var/log inside container          │
│                                                          │
│  TIER 2: emptyDir (Ephemeral)                          │
│  ├─ Lifecycle: Pod lifetime                             │
│  ├─ Performance: High (node disk)                       │
│  ├─ Use Case: Shared data between containers           │
│  ├─ Data Loss: Lost when pod terminates               │
│  └─ Storage: Node disk (counted toward node resources) │
│                                                          │
│  TIER 3: Persistent Volumes (Durable)                  │
│  ├─ Lifecycle: Persistent (outlives pods)              │
│  ├─ Performance: Medium-High (network storage)         │
│  ├─ Use Case: Databases, stateful applications         │
│  ├─ Data Loss: Data survives pod/node failures        │
│  └─ Storage: Azure Managed Disks or Azure Files       │
│                                                          │
│  TIER 4: ConfigMap/Secrets (Configuration)             │
│  ├─ Lifecycle: Pod lifetime (can be updated)           │
│  ├─ Performance: N/A (config data)                     │
│  ├─ Use Case: Configuration, credentials               │
│  ├─ Data Loss: Lost when pod terminates               │
│  └─ Storage: etcd (cluster memory)                     │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

### Your 3-Tier App Storage Needs

```
APPLICATION TIER (Stateless - No PV Needed)
├─ user-service pods: Any node, no persistent data
├─ order-service pods: Any node, no persistent data
└─ payment-service pods: Any node, no persistent data

DATABASE TIER (Stateful - PV Required)
├─ PostgreSQL: Requires persistent disk for data
├─ Data: /var/lib/postgresql/data
├─ Backup: Azure Backup Storage
└─ Replication: Network-based (not storage)

CACHE TIER (Optional - No PV Needed if stateless)
├─ Redis: Can use emptyDir for session cache
├─ Or: Persistent disk for durable cache
└─ Replicated: Multi-replica redis-cluster
```

---

## Storage Classes in AKS

### Pre-Built Storage Classes

List existing storage classes:

```bash
# View all storage classes
kubectl get storageclass

# Default output:
# NAME                        PROVISIONER             RECLAIMPOLICY   
# default (standard)          disk.csi.azure.com      Delete          
# managed-premium (premium)   disk.csi.azure.com      Delete          
# azurefile-csi              file.csi.azure.com      Delete          
# azurefile-csi-premium      file.csi.azure.com      Delete          
```

### Azure Managed Disk Storage Classes

| StorageClass | Provisioner | Disk Type | IOPS | Throughput | Use Case |
|---|---|---|---|---|---|
| **default** (Standard) | disk.csi.azure.com | HDD | 500 | 60 MB/s | Dev/Test, low I/O |
| **managed-premium** | disk.csi.azure.com | SSD | 7500 | 250 MB/s | Production databases |
| **ultra** | disk.csi.azure.com | Ultra SSD | 160K | 2000 MB/s | High-performance DB |

### Create Custom Storage Class

```yaml
# helm-charts/storage/storage-classes.yaml

# High-performance SSD for database
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: disk.csi.azure.com
allowVolumeExpansion: true
parameters:
  skuname: Premium_LRS  # Local Redundant Storage
  cachingmode: ReadWrite
reclaimPolicy: Retain  # Keep data even after PVC deletion

---
# Cost-optimized Standard for logs/cache
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard-storage
provisioner: disk.csi.azure.com
allowVolumeExpansion: true
parameters:
  skuname: Standard_LRS
  cachingmode: ReadOnly
reclaimPolicy: Delete

---
# Network File Share for shared data
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile
provisioner: file.csi.azure.com
allowVolumeExpansion: true
parameters:
  skuName: Standard_LRS  # or Premium_LRS
reclaimPolicy: Delete
mountOptions:
  - dir_mode=0755
  - file_mode=0644
  - uid=1000
  - gid=1000
```

---

## Persistent Volumes & Claims

### Create PersistentVolumeClaim for Database

```yaml
# helm-charts/postgres/templates/pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
  namespace: three-tier-app
  labels:
    app: postgres
spec:
  accessModes:
    - ReadWriteOnce  # Single pod only
  storageClassName: fast-ssd  # High-performance SSD
  resources:
    requests:
      storage: 100Gi  # 100GB for database
---
# Separate PVC for WAL logs (write-ahead logs)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-wal
  namespace: three-tier-app
  labels:
    app: postgres
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 50Gi
---
# Separate PVC for backups
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-backups
  namespace: three-tier-app
  labels:
    app: postgres
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: standard-storage  # Lower cost
  resources:
    requests:
      storage: 200Gi  # Large backup storage
```

### Create PVC for Application Logs

```yaml
# helm-charts/shared/pvc-logs.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-logs
  namespace: three-tier-app
spec:
  accessModes:
    - ReadWriteMany  # Multiple pods can read/write
  storageClassName: azurefile  # Network file share
  resources:
    requests:
      storage: 50Gi

---
# StatefulSet using PVC
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: three-tier-app
spec:
  serviceName: postgres
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:14
          volumeMounts:
            - name: postgres-data
              mountPath: /var/lib/postgresql/data
            - name: postgres-wal
              mountPath: /var/lib/postgresql/wal
            - name: postgres-backups
              mountPath: /backups
  
  volumeClaimTemplates:
    - metadata:
        name: postgres-data
      spec:
        accessModes: [ "ReadWriteOnce" ]
        storageClassName: fast-ssd
        resources:
          requests:
            storage: 100Gi
```

---

## Data Persistence Patterns

### Pattern 1: Database with Persistent Storage

```yaml
# helm-charts/user-service/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "user-service.fullname" . }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "user-service.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "user-service.selectorLabels" . | nindent 8 }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          volumeMounts:
            # Application logs on persistent storage
            - name: logs
              mountPath: /var/log/app
            # Temporary cache (ephemeral)
            - name: tmp
              mountPath: /tmp
      
      volumes:
        # Persistent volume for logs
        - name: logs
          persistentVolumeClaim:
            claimName: app-logs
        
        # Ephemeral volume for temp files
        - name: tmp
          emptyDir:
            sizeLimit: 1Gi
```

### Pattern 2: Stateful Service with StatefulSet

```yaml
# helm-charts/cache/templates/statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis-cluster
  namespace: three-tier-app
spec:
  serviceName: redis-cluster
  replicas: 3
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
        - name: redis
          image: redis:7-alpine
          command:
            - redis-server
            - --cluster-enabled
            - "yes"
            - --cluster-node-timeout
            - "5000"
            - --appendonly
            - "yes"
          ports:
            - containerPort: 6379
            - containerPort: 16379
          resources:
            requests:
              cpu: 250m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
          volumeMounts:
            - name: redis-data
              mountPath: /data
            - name: redis-config
              mountPath: /etc/redis
  
  volumeClaimTemplates:
    - metadata:
        name: redis-data
      spec:
        accessModes: [ "ReadWriteOnce" ]
        storageClassName: fast-ssd
        resources:
          requests:
            storage: 10Gi
```

### Pattern 3: Shared Logs with emptyDir + Network Share

```yaml
# Log shipping sidecar pattern
apiVersion: v1
kind: Pod
metadata:
  name: app-with-logging
spec:
  containers:
    # Main application
    - name: app
      image: user-service:1.0.0
      volumeMounts:
        - name: logs
          mountPath: /var/log/app
    
    # Log shipper sidecar
    - name: log-shipper
      image: fluentd:v1
      volumeMounts:
        - name: logs
          mountPath: /var/log/app
      command:
        - fluentd
        - -c
        - /etc/fluentd/fluent.conf
  
  volumes:
    # Ephemeral shared volume
    - name: logs
      emptyDir:
        sizeLimit: 5Gi
```

---

## Backup & Recovery

### Automated Volume Snapshots

```yaml
# helm-charts/backup/volume-snapshot-class.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-snapshot-class
driver: disk.csi.azure.com
deletionPolicy: Delete
---
# Create snapshot of PVC
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: postgres-data-snapshot
  namespace: three-tier-app
spec:
  volumeSnapshotClassName: csi-snapshot-class
  source:
    persistentVolumeClaimName: postgres-data
---
# Restore from snapshot
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data-restored
  namespace: three-tier-app
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: fast-ssd
  dataSource:
    name: postgres-data-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  resources:
    requests:
      storage: 100Gi
```

### Backup Job with CronJob

```yaml
# helm-charts/backup/templates/backup-job.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: three-tier-app
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: backup-runner
          containers:
            - name: backup
              image: postgres:14
              env:
                - name: PGPASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: postgres-credentials
                      key: password
              command:
                - sh
                - -c
                - |
                  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
                  pg_dump -h postgres-prod.postgres.database.azure.com \
                    -U app_user@postgres-prod \
                    -d three_tier_prod \
                    --format=custom \
                    --compress=9 \
                    --file=/backups/postgres_backup_$TIMESTAMP.dump
                  
                  # Keep only last 7 days of backups
                  find /backups -name "postgres_backup_*.dump" -mtime +7 -delete
              volumeMounts:
                - name: backup-storage
                  mountPath: /backups
          volumes:
            - name: backup-storage
              persistentVolumeClaim:
                claimName: postgres-backups
          restartPolicy: OnFailure
```

---

## Performance Optimization

### I/O Performance Tuning

```yaml
# Optimized for database workloads
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data-optimized
  namespace: three-tier-app
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 500Gi  # Larger size = better performance
---
# StorageClass with performance settings
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: database-optimized
provisioner: disk.csi.azure.com
allowVolumeExpansion: true
parameters:
  skuname: Premium_LRS
  iops: "7500"      # Max IOPS
  throughput: "250"  # MB/s
  cachingmode: ReadWrite  # Enable caching
reclaimPolicy: Retain
```

### Caching Strategy

```yaml
# Multi-tier caching
spec:
  containers:
    - name: app
      volumeMounts:
        # L1: Local container cache (fast, no persistence)
        - name: local-cache
          mountPath: /cache/local
        
        # L2: Node disk cache (fast, survives pod restart)
        - name: node-cache
          mountPath: /cache/node
        
        # L3: Persistent cache (survives node restart)
        - name: persistent-cache
          mountPath: /cache/persistent
  
  volumes:
    # L1: emptyDir (fast, lost on pod termination)
    - name: local-cache
      emptyDir:
        sizeLimit: 1Gi
    
    # L2: Node local storage (fast, survives pod restart)
    - name: node-cache
      emptyDir:
        medium: Memory
        sizeLimit: 500Mi
    
    # L3: Persistent disk (survives everything)
    - name: persistent-cache
      persistentVolumeClaim:
        claimName: cache-volume
```

---

## Interview Q&A

### Q1: How do you handle persistent storage for stateful applications in Kubernetes?

**Answer**:
> "For stateful applications like databases, I use a combination of PersistentVolumes (PVs), PersistentVolumeClaims (PVCs), and StatefulSets:
>
> **1. Storage Class Selection**:
> - For databases: `fast-ssd` (Premium_LRS) for high IOPS
> - For logs: `standard-storage` (Standard_LRS) for cost efficiency
> - For shared data: `azurefile` (Network File Share) for multiple pod access
>
> **2. PersistentVolumeClaim Definition**:
> - AccessMode: ReadWriteOnce for databases (single pod)
> - Size: Based on data growth (500GB for production database)
> - ReclaimPolicy: Retain for critical data (manual deletion required)
>
> **3. StatefulSet for Databases**:
> - Provides stable network identity (postgres-0, postgres-1)
> - Maintains ordering during scaling
> - Volumeclaimtemplate: Each replica gets own PVC
> - Headless service for stable DNS names
>
> **4. Disaster Recovery**:
> - Automated snapshots via VolumeSnapshot
> - Daily backups via CronJob
> - Point-in-time restore capability
> - Multi-zone redundancy for critical data
>
> **5. Performance Optimization**:
> - Use fast-ssd for databases (7500 IOPS)
> - Separate PVCs for data, logs, and backups
> - Enable ReadWrite caching
> - Monitor disk usage and expand proactively
>
> The key is matching storage type to workload needs: ephemeral emptyDir for cache, persistent disk for data, network share for shared logs."

---

### Q2: How would you design storage for your 3-tier application?

**Answer**:
> "My storage design separates concerns based on data durability needs:
>
> **Tier 1: Application Pods (user-service, order-service, payment-service)**
> - Storage: emptyDir (ephemeral)
> - Data: Application logs, temporary cache
> - Lifetime: Pod lifetime (lost on termination)
> - Cost: Free (node disk)
> - Rationale: Stateless services don't need persistence
>
> **Tier 2: Centralized Logs**
> - Storage: PVC with azurefile (network file share)
> - Data: All application logs aggregated
> - Lifetime: Persistent (survives pod/node restarts)
> - Size: 50Gi (configurable)
> - Rationale: Need centralized logging for troubleshooting
>
> **Tier 3: Database (PostgreSQL)**
> - Storage: PVC with fast-ssd (Premium SSD)
> - Data: Database files, WAL logs, backups
> - Separate PVCs:
>   - postgres-data: 500Gi (main data)
>   - postgres-wal: 50Gi (write-ahead logs)
>   - postgres-backups: 200Gi (backup storage)
> - Lifetime: Persistent (survives everything)
> - Rationale: Critical data requires durable storage
>
> **Tier 4: Cache (Optional Redis)**
> - Storage: StatefulSet with PVC (fast-ssd)
> - Data: Session cache, query results
> - Lifetime: Persistent for data durability
> - Rationale: Optional - can be ephemeral if not critical
>
> **Total Storage Footprint**:
> - Application: 0 GB (ephemeral)
> - Logs: 50 GB (network share)
> - Database: 750 GB (fast SSD)
> - Total: ~800 GB across all tiers"

---

### Q3: How do you ensure data isn't lost during pod/node failures?

**Answer**:
> "Data loss protection happens at multiple levels:
>
> **Level 1: Pod Failure (Same Node)**
> - Deployment automatically recreates pod
> - PVC is attached to new pod (if used)
> - Data persists (PV not deleted)
> - Pod recovers with all data intact
>
> **Level 2: Node Failure (Different Node)**
> - Kubernetes detects node down (5-minute detection)
> - Pod rescheduled to healthy node
> - PVC is detached from failed node and reattached
> - Database recovers and replays any in-flight transactions
> - No data loss
>
> **Level 3: Entire Cluster Failure**
> - PVC data is stored in Azure managed disk (regional)
> - Database snapshots taken hourly
> - Full backups taken daily to Azure storage
> - Point-in-time restore possible to any moment in last 7 days
> - Worst case: 1-hour data loss (since last backup)
>
> **Level 4: Regional Disaster**
> - Geo-redundant backups stored in different region
> - Can restore entire database in different region
> - Requires failover procedures (manual for now)
>
> **Specific Protections for Database**:
> - Primary-replica replication: Replica always current
> - Automatic failover: Primary fails → Replica promoted (< 5 min)
> - WAL archiving: Transaction logs backed up separately
> - Point-in-time restore: Restore to any second in past 7 days
>
> **Monitoring for Data Safety**:
> - Replication lag alert: > 10 seconds = immediate alert
> - Backup success monitoring: Daily verification
> - Disk space alert: > 80% used = scale storage
> - Recovery testing: Monthly restore drills"

---

## Troubleshooting Guide

### PVC Stuck in Pending

```bash
# Check PVC status
kubectl describe pvc postgres-data -n three-tier-app

# Common causes and solutions:
# 1. StorageClass doesn't exist
kubectl get storageclass
# Solution: Create missing StorageClass

# 2. Quota exceeded
kubectl describe pvc postgres-data | grep message
# Solution: Request more quota or delete unused PVCs

# 3. No nodes available
kubectl top nodes
# Solution: Scale node pool or reduce resource requests
```

### PVC Performance Issues

```bash
# Monitor disk I/O
kubectl exec postgres-0 -n three-tier-app -- \
  iostat -x 1 5

# Check PVC metrics
kubectl describe pvc postgres-data -n three-tier-app
# Look for: ProvisioningSucceeded event

# Upgrade storage class
kubectl patch pvc postgres-data \
  -p '{"spec":{"storageClassName":"fast-ssd"}}'
```

### Data Recovery from Snapshot

```bash
# List available snapshots
kubectl get volumesnapshot -n three-tier-app

# Create PVC from snapshot
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data-recovered
  namespace: three-tier-app
spec:
  dataSource:
    name: postgres-data-snapshot-20260515
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 500Gi
EOF

# Attach to new pod for verification
kubectl run postgres-verify \
  -it --rm \
  --image=postgres:14 \
  --mount=volumeClaim=postgres-data-recovered,mountPath=/data \
  -- /bin/bash
```

---

## Summary

Your storage architecture provides:
- ✅ Persistent data for stateful services (databases)
- ✅ High performance with SSD tier
- ✅ Cost optimization with standard tier for logs
- ✅ Automated backups and snapshots
- ✅ Disaster recovery capabilities
- ✅ Scalable storage with volume expansion

