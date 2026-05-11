# Database Management - PostgreSQL on Azure for Kubernetes
## Complete Guide to Setup, Backup, Restore, Replication, and Monitoring

**Last Updated**: May 2026  
**Version**: 1.0.0

---

## Table of Contents
1. [PostgreSQL Architecture Overview](#postgresql-architecture-overview)
2. [Azure Database for PostgreSQL Setup](#azure-database-for-postgresql-setup)
3. [Connection Management from Kubernetes](#connection-management-from-kubernetes)
4. [Backup & Disaster Recovery](#backup--disaster-recovery)
5. [Replication & High Availability](#replication--high-availability)
6. [Performance Monitoring](#performance-monitoring)
7. [Database Migrations](#database-migrations)
8. [Interview Q&A](#interview-qa)

---

## PostgreSQL Architecture Overview

### Your 3-Tier Application Database Design

```
┌─────────────────────────────────────────────────────────┐
│              Azure Database for PostgreSQL               │
│              (Flexible Server - HA Setup)               │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  PRIMARY NODE (Active)                                 │
│  ├─ three_tier_prod database                          │
│  ├─ Users table (user-service)                        │
│  ├─ Orders table (order-service)                      │
│  ├─ Payments table (payment-service)                  │
│  ├─ Continuous replication to standby               │
│  └─ Receive traffic from AKS pods                   │
│                                                         │
│  STANDBY REPLICA NODE (Passive, Ready)                │
│  ├─ Exact copy of primary                             │
│  ├─ Receives WAL (Write-Ahead Logs) from primary      │
│  ├─ Read-only (no writes)                             │
│  ├─ Can be promoted if primary fails                 │
│  └─ Can be used for read-only queries (optional)     │
│                                                         │
│  BACKUP STORAGE (Azure Backup)                        │
│  ├─ Daily automated backups                           │
│  ├─ 7-day retention (configurable)                    │
│  ├─ Geo-redundant storage                             │
│  └─ Point-in-time restore capability                  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Tables & Schemas

```sql
-- User Service Database
CREATE SCHEMA user_service;

CREATE TABLE user_service.users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(100) UNIQUE NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  first_name VARCHAR(100),
  last_name VARCHAR(100),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  is_active BOOLEAN DEFAULT true,
  last_login TIMESTAMP
);

CREATE INDEX idx_users_email ON user_service.users(email);
CREATE INDEX idx_users_username ON user_service.users(username);
CREATE INDEX idx_users_created_at ON user_service.users(created_at DESC);

-- Order Service Database
CREATE SCHEMA order_service;

CREATE TABLE order_service.orders (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES user_service.users(id),
  order_date TIMESTAMP DEFAULT NOW(),
  total_amount DECIMAL(10, 2) NOT NULL,
  status VARCHAR(50) DEFAULT 'pending',
  shipping_address TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_orders_user_id ON order_service.orders(user_id);
CREATE INDEX idx_orders_status ON order_service.orders(status);
CREATE INDEX idx_orders_created_at ON order_service.orders(created_at DESC);

-- Payment Service Database
CREATE SCHEMA payment_service;

CREATE TABLE payment_service.payments (
  id SERIAL PRIMARY KEY,
  order_id INTEGER NOT NULL REFERENCES order_service.orders(id),
  amount DECIMAL(10, 2) NOT NULL,
  payment_method VARCHAR(50) NOT NULL,
  status VARCHAR(50) DEFAULT 'pending',
  transaction_id VARCHAR(255) UNIQUE,
  created_at TIMESTAMP DEFAULT NOW(),
  processed_at TIMESTAMP,
  error_message TEXT
);

CREATE INDEX idx_payments_order_id ON payment_service.payments(order_id);
CREATE INDEX idx_payments_status ON payment_service.payments(status);
CREATE INDEX idx_payments_transaction_id ON payment_service.payments(transaction_id);
```

---

## Azure Database for PostgreSQL Setup

### Step 1: Create Flexible Server

```bash
# Create resource group
az group create \
  --name rg-3tier-app \
  --location eastus

# Create PostgreSQL Flexible Server
az postgres flexible-server create \
  --resource-group rg-3tier-app \
  --name postgres-prod \
  --admin-user postgres \
  --admin-password "YourSecurePassword123!" \
  --sku-name Standard_B2s \
  --tier Burstable \
  --storage-size 32 \
  --version 14 \
  --high-availability Enabled \
  --backup-retention 7 \
  --backup-retention-type Days \
  --backup-interval-hours 24 \
  --geo-redundant-backup Enabled \
  --public-access Enabled \
  --tags Environment=prod Application=3tier-app

# Get connection details
az postgres flexible-server show \
  --resource-group rg-3tier-app \
  --name postgres-prod \
  --query "{host:host, port:network.delegatedSubnetResourceId, username:administratorLogin}"
```

### Step 2: Configure Network Access

```bash
# Allow AKS nodes to access database
az postgres flexible-server firewall-rule create \
  --resource-group rg-3tier-app \
  --name postgres-prod \
  --rule-name allow-aks \
  --start-ip-address 10.0.0.0 \
  --end-ip-address 10.255.255.255

# Allow local machine for management
az postgres flexible-server firewall-rule create \
  --resource-group rg-3tier-app \
  --name postgres-prod \
  --rule-name allow-local \
  --start-ip-address <YOUR-IP> \
  --end-ip-address <YOUR-IP>
```

### Step 3: Initialize Database

```bash
# Connect to database
psql -h postgres-prod.postgres.database.azure.com \
  -U postgres@postgres-prod \
  -d postgres

# Create databases for each service
CREATE DATABASE three_tier_prod;
CREATE DATABASE three_tier_staging;
CREATE DATABASE three_tier_dev;

# Create application user with least privileges
CREATE USER app_user WITH PASSWORD 'AppPassword123!';

GRANT CONNECT ON DATABASE three_tier_prod TO app_user;
GRANT CONNECT ON DATABASE three_tier_staging TO app_user;
GRANT CONNECT ON DATABASE three_tier_dev TO app_user;
```

### Step 4: Create Schemas and Tables

```bash
# Connect to production database
psql -h postgres-prod.postgres.database.azure.com \
  -U postgres@postgres-prod \
  -d three_tier_prod

# Run schema setup
\i /path/to/schema-setup.sql

# Grant permissions to app_user
GRANT USAGE ON SCHEMA user_service TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA user_service TO app_user;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA user_service TO app_user;

# Repeat for other schemas...
```

### Step 5: Create Azure Key Vault Secret

```bash
# Create Azure Key Vault
az keyvault create \
  --resource-group rg-3tier-app \
  --name vault-3tier-app

# Store database credentials
az keyvault secret set \
  --vault-name vault-3tier-app \
  --name db-host \
  --value "postgres-prod.postgres.database.azure.com"

az keyvault secret set \
  --vault-name vault-3tier-app \
  --name db-username \
  --value "app_user@postgres-prod"

az keyvault secret set \
  --vault-name vault-3tier-app \
  --name db-password \
  --value "AppPassword123!"

az keyvault secret set \
  --vault-name vault-3tier-app \
  --name db-port \
  --value "5432"
```

---

## Connection Management from Kubernetes

### Step 1: Create Kubernetes Secret for Database Credentials

```bash
# Create secret from Key Vault
kubectl create secret generic postgres-credentials \
  --from-literal=host=postgres-prod.postgres.database.azure.com \
  --from-literal=port=5432 \
  --from-literal=username=app_user@postgres-prod \
  --from-literal=password='AppPassword123!' \
  -n three-tier-app

# Verify secret created
kubectl get secret postgres-credentials -n three-tier-app -o yaml
```

### Step 2: Configure Helm Charts to Use Secrets

```yaml
# helm-charts/user-service/values.yaml

database:
  host: ${DB_HOST}
  port: ${DB_PORT}
  username: ${DB_USERNAME}
  password: ${DB_PASSWORD}
  name: three_tier_prod
  pool_size: 20
  hikari:
    maximumPoolSize: 30
    minimumIdle: 10
    connectionTimeout: 60000
    maxLifetime: 1800000
    idleTimeout: 600000
    leakDetectionThreshold: 60000

env:
  - name: DB_HOST
    valueFrom:
      secretKeyRef:
        name: postgres-credentials
        key: host
  
  - name: DB_PORT
    valueFrom:
      secretKeyRef:
        name: postgres-credentials
        key: port
  
  - name: DB_USERNAME
    valueFrom:
      secretKeyRef:
        name: postgres-credentials
        key: username
  
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: postgres-credentials
        key: password
  
  - name: SPRING_DATASOURCE_URL
    value: "jdbc:postgresql://$(DB_HOST):$(DB_PORT)/three_tier_prod?sslmode=require"
  
  - name: SPRING_DATASOURCE_USERNAME
    valueFrom:
      secretKeyRef:
        name: postgres-credentials
        key: username
  
  - name: SPRING_DATASOURCE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: postgres-credentials
        key: password
```

### Step 3: Application Configuration

For Java/Spring Boot applications:

```yaml
# application.properties

spring.datasource.url=jdbc:postgresql://${DB_HOST}:${DB_PORT}/three_tier_prod?sslmode=require
spring.datasource.username=${DB_USERNAME}
spring.datasource.password=${DB_PASSWORD}
spring.datasource.driver-class-name=org.postgresql.Driver

# HikariCP Connection Pool
spring.datasource.hikari.maximum-pool-size=30
spring.datasource.hikari.minimum-idle=10
spring.datasource.hikari.connection-timeout=60000
spring.datasource.hikari.max-lifetime=1800000
spring.datasource.hikari.idle-timeout=600000
spring.datasource.hikari.leak-detection-threshold=60000
spring.datasource.hikari.auto-commit=true

# JPA Configuration
spring.jpa.database=postgresql
spring.jpa.show-sql=false
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQL14Dialect
spring.jpa.properties.hibernate.jdbc.batch_size=20
spring.jpa.properties.hibernate.order_inserts=true
spring.jpa.properties.hibernate.order_updates=true
```

---

## Backup & Disaster Recovery

### Automated Backups (Azure-Managed)

```bash
# Verify backup settings
az postgres flexible-server show \
  --resource-group rg-3tier-app \
  --name postgres-prod \
  --query "{backupRetention:backup.backupRetentionDays, geoRedundant:backup.geoRedundantBackup}"

# List backups
az postgres flexible-server list-backups \
  --resource-group rg-3tier-app \
  --name postgres-prod

# Restore from backup to a point in time
az postgres flexible-server restore \
  --resource-group rg-3tier-app \
  --name postgres-prod-restored \
  --source-server postgres-prod \
  --restore-time "2026-05-15T10:00:00Z"  # Point in time
```

### Manual Backup

```bash
# Full database dump
pg_dump -h postgres-prod.postgres.database.azure.com \
  -U postgres@postgres-prod \
  -d three_tier_prod \
  --format=custom \
  --compress=9 \
  > three_tier_prod_backup_$(date +%Y%m%d_%H%M%S).dump

# Backup specific schema
pg_dump -h postgres-prod.postgres.database.azure.com \
  -U postgres@postgres-prod \
  -d three_tier_prod \
  --schema=user_service \
  --format=custom \
  > user_service_backup_$(date +%Y%m%d_%H%M%S).dump

# Store backup in Azure Blob Storage
az storage blob upload \
  --account-name storageaccountname \
  --container-name backups \
  --name "three_tier_prod_backup_$(date +%Y%m%d_%H%M%S).dump" \
  --file three_tier_prod_backup_*.dump
```

### Restore from Backup

```bash
# Restore entire database
pg_restore -h postgres-prod.postgres.database.azure.com \
  -U postgres@postgres-prod \
  -d three_tier_prod \
  --verbose \
  three_tier_prod_backup_20260515_100000.dump

# Restore specific schema only
pg_restore -h postgres-prod.postgres.database.azure.com \
  -U postgres@postgres-prod \
  -d three_tier_prod \
  --schema-only \
  three_tier_prod_backup_20260515_100000.dump

# Restore to new database for testing
createdb -h postgres-prod.postgres.database.azure.com \
  -U postgres@postgres-prod \
  three_tier_test

pg_restore -h postgres-prod.postgres.database.azure.com \
  -U postgres@postgres-prod \
  -d three_tier_test \
  three_tier_prod_backup_20260515_100000.dump
```

---

## Replication & High Availability

### Primary-Replica Replication

```bash
# Check replication status on primary
psql -h postgres-prod.postgres.database.azure.com \
  -U postgres@postgres-prod \
  -d postgres

# View replication status
SELECT * FROM pg_stat_replication;

# Check WAL level
SHOW wal_level;  # Should be 'replica' or 'logical'

# Monitor replication lag
SELECT 
  client_addr,
  state,
  sync_state,
  write_lag,
  flush_lag,
  replay_lag
FROM pg_stat_replication;
```

### Manual Failover Procedure

```bash
# Step 1: Check if replica is caught up
SELECT * FROM pg_last_wal_receive_lsn();  # On replica
SELECT * FROM pg_current_wal_lsn();       # On primary

# Step 2: Promote replica to primary
SELECT pg_ctl('promote', 'immediate');  # On replica

# Step 3: Update connection strings in AKS
kubectl set env deployment/user-service \
  -n three-tier-app \
  DB_HOST=postgres-replica.postgres.database.azure.com

# Step 4: Verify connection
kubectl exec user-service-xxxxx -n three-tier-app -- \
  psql -h postgres-replica.postgres.database.azure.com \
  -U app_user@postgres-replica \
  -d three_tier_prod \
  -c "SELECT VERSION();"
```

---

## Performance Monitoring

### Key Metrics to Monitor

```bash
# Connect to database
psql -h postgres-prod.postgres.database.azure.com \
  -U postgres@postgres-prod \
  -d three_tier_prod

# 1. Connection count
SELECT 
  usename,
  count(*) AS connection_count
FROM pg_stat_activity
GROUP BY usename;

# 2. Long-running queries
SELECT 
  pid,
  usename,
  query,
  age(now(), query_start) AS duration
FROM pg_stat_activity
WHERE query != '<IDLE>'
ORDER BY duration DESC;

# 3. Slow queries
SELECT 
  query,
  calls,
  total_time,
  mean_time,
  max_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;

# 4. Index usage
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_scan
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC;

# 5. Cache hit ratio (should be > 99%)
SELECT 
  sum(heap_blks_read) AS heap_read,
  sum(heap_blks_hit) AS heap_hit,
  sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) AS ratio
FROM pg_statio_user_tables;

# 6. Table bloat
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

# 7. Vacuum and Analyze status
SELECT 
  schemaname,
  tablename,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  last_autoanalyze
FROM pg_stat_user_tables;
```

### Create Prometheus ServiceMonitor for PostgreSQL

```yaml
# helm-charts/postgres-exporter/templates/servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: postgres-exporter
  namespace: three-tier-app
spec:
  selector:
    matchLabels:
      app: postgres-exporter
  endpoints:
    - port: metrics
      interval: 30s
      scrapeTimeout: 10s
```

### Prometheus Queries for Database Monitoring

```promql
# Connection count
sum(pg_stat_activity_count) by (usename)

# Query latency (P99)
histogram_quantile(0.99, rate(pg_query_duration_seconds_bucket[5m]))

# Cache hit ratio
pg_cache_hit_ratio

# Transactions per second
rate(pg_transactions_committed_total[1m]) + rate(pg_transactions_aborted_total[1m])

# Replication lag
pg_replication_lag_seconds

# Disk space used
pg_database_size_bytes

# Index bloat
pg_index_bloat_ratio
```

---

## Database Migrations

### Using Liquibase/Flyway with Kubernetes

```yaml
# helm-charts/user-service/templates/job-db-migration.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "user-service.fullname" . }}-db-migration
  namespace: {{ .Release.Namespace }}
spec:
  backoffLimit: 3
  template:
    metadata:
      labels:
        {{- include "user-service.selectorLabels" . | nindent 8 }}
    spec:
      serviceAccountName: {{ include "user-service.serviceAccountName" . }}
      containers:
        - name: migration
          image: "{{ .Values.image.registry }}/{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          env:
            - name: DB_HOST
              valueFrom:
                secretKeyRef:
                  name: postgres-credentials
                  key: host
            - name: DB_PORT
              valueFrom:
                secretKeyRef:
                  name: postgres-credentials
                  key: port
            - name: DB_USERNAME
              valueFrom:
                secretKeyRef:
                  name: postgres-credentials
                  key: username
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-credentials
                  key: password
            - name: DB_NAME
              value: "three_tier_prod"
          command:
            - sh
            - -c
            - |
              echo "Running database migrations..."
              java -jar /app/liquibase-core.jar \
                --url="jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}" \
                --username="${DB_USERNAME}" \
                --password="${DB_PASSWORD}" \
                --changeLogFile="db/changelog/master.xml" \
                update
              echo "Migrations completed successfully!"
      restartPolicy: Never
```

### Liquibase Changelog Example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog
  xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
    http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-4.1.xsd">

  <changeSet id="001-create-users-table" author="devops">
    <createTable tableName="users" schemaName="user_service">
      <column name="id" type="SERIAL" autoIncrement="true">
        <constraints primaryKey="true" nullable="false"/>
      </column>
      <column name="username" type="VARCHAR(100)" remarks="User login username">
        <constraints nullable="false" unique="true"/>
      </column>
      <column name="email" type="VARCHAR(100)">
        <constraints nullable="false" unique="true"/>
      </column>
      <column name="created_at" type="TIMESTAMP" defaultValueDb="NOW()">
        <constraints nullable="false"/>
      </column>
    </createTable>
    <createIndex tableName="users" schemaName="user_service" indexName="idx_users_email">
      <column name="email"/>
    </createIndex>
  </changeSet>

  <changeSet id="002-add-is-active-column" author="devops">
    <addColumn tableName="users" schemaName="user_service">
      <column name="is_active" type="BOOLEAN" defaultValue="true">
        <constraints nullable="false"/>
      </column>
    </addColumn>
  </changeSet>

</databaseChangeLog>
```

---

## Interview Q&A

### Q1: How do you design the database for a 3-tier microservices architecture?

**Answer**:
> "For a 3-tier microservices architecture, I use a shared database approach with separate schemas for each service to maintain clear boundaries:
>
> **Architecture**:
> - Single PostgreSQL cluster on Azure (Flexible Server with HA)
> - Multiple databases: three_tier_prod, three_tier_staging, three_tier_dev
> - Separate schemas: user_service, order_service, payment_service
> - This avoids running separate databases per service (which is expensive) while maintaining logical separation
>
> **Tables**:
> - user_service.users (user credentials, profiles)
> - order_service.orders (order details with foreign key to users)
> - payment_service.payments (payment records with foreign key to orders)
>
> **Foreign Keys**: Orders reference Users, Payments reference Orders
> - This maintains referential integrity
> - Enables cross-service queries when needed
> - Still allows each service to own its schema
>
> **Each service gets**:
> - Own database user with limited permissions (only SELECT, INSERT, UPDATE, DELETE on their schema)
> - Connection pooling via HikariCP (20-30 connections per pod)
> - Separate database migrations per service
>
> **High Availability**:
> - Azure PostgreSQL Flexible Server with automatic failover
> - Primary-replica replication with automatic promotion on failure
> - Automated daily backups with 7-day retention
> - Point-in-time restore capability
>
> This design balances operational complexity (single database to manage) with logical separation (schemas per service)."

---

### Q2: How would you handle a database failover scenario in production?

**Answer**:
> "A database failover happens when the primary database becomes unavailable. Azure handles this automatically, but here's how to manage it:
>
> **Automatic Failover (< 5 minutes)**:
> 1. Primary node detects failure or becomes unresponsive
> 2. Replica node automatically promoted to primary
> 3. New replicas created to restore redundancy
> 4. DNS updated automatically
> 5. Kubernetes pods reconnect automatically on next failed attempt
>
> **Manual Steps if Needed**:
> 1. Verify primary is truly down: `az postgres flexible-server show --name postgres-prod`
> 2. Check replica lag: `SELECT * FROM pg_stat_replication` on primary (if still accessible)
> 3. Promote replica: `SELECT pg_ctl('promote', 'immediate')` on replica
> 4. Update connection strings if needed (usually automatic)
> 5. Verify pod connectivity: `kubectl exec pod -- psql -c 'SELECT version()'`
> 6. Monitor application logs for connection errors
>
> **Preventing Application Impact**:
> - HikariCP connection pool automatically reconnects on connection failure
> - Database connection timeout: 60 seconds (pods will retry)
> - Application health checks detect database unavailability quickly
> - Readiness probes fail if database is unreachable
> - Application containers restart and reconnect
>
> **Total Impact**:
> - Zero to minimal (< 30 second) query failures during failover
> - No data loss (replica is always current)
> - No manual intervention needed for most scenarios
>
> **Verification After Failover**:
> - Check replication is working: `pg_stat_replication`
> - Verify backup is running: `pg_stat_archiver`
> - Monitor connection count: `SELECT COUNT(*) FROM pg_stat_activity`
> - Check for any errors in application logs"

---

### Q3: What's your approach to database performance monitoring in Kubernetes?

**Answer**:
> "I monitor database performance at three levels:
>
> **Level 1: Kubernetes Pod Level**:
> - Database pod memory usage (should be stable, not increasing)
> - Database pod CPU usage (should peak during high load, not idle)
> - Database pod restart count (should be 0)
> - Disk space available (alert when < 10% free)
>
> **Level 2: PostgreSQL-Level Metrics**:
> - Connection count (alert when > 80% of max_connections)
> - Active connections by username/application
> - Long-running queries (queries running > 5 minutes)
> - Slow queries from pg_stat_statements
> - Cache hit ratio (should be > 99%)
> - Replication lag (should be < 1 second)
>
> **Level 3: Application-Level Metrics**:
> - Database query latency (p50, p95, p99)
> - Connection pool utilization
> - Prepared statement cache hit rate
> - Transaction duration
> - Deadlock frequency (should be 0)
>
> **Tools I Use**:
> - Prometheus with PostgreSQL exporter for metrics
> - Grafana dashboards for visualization
> - PgBadger for query analysis
> - pg_stat_statements for slow query identification
>
> **Alerts I've Configured**:
> - Connection count > 80% of max → Scale HikariCP pool
> - Cache hit ratio < 95% → Add indexes or increase shared_buffers
> - Replication lag > 10 seconds → Investigate replica health
> - Query running > 30 minutes → Kill and investigate
> - Disk space < 10% → Auto-scale storage
>
> **Regular Maintenance**:
> - VACUUM runs automatically (default)
> - ANALYZE runs automatically (default)
> - Index bloat check monthly
> - Query performance review weekly
> - Backup verification daily"

---

## Complete Database Deployment Script

```bash
#!/bin/bash
# scripts/setup-postgres-db.sh

set -e

RESOURCE_GROUP="rg-3tier-app"
SERVER_NAME="postgres-prod"
LOCATION="eastus"

echo "🗄️ Setting up PostgreSQL..."

# Create server
echo "Creating PostgreSQL Flexible Server..."
az postgres flexible-server create \
  --resource-group $RESOURCE_GROUP \
  --name $SERVER_NAME \
  --location $LOCATION \
  --admin-user postgres \
  --admin-password "PostgresPassword123!" \
  --tier Burstable \
  --sku-name Standard_B2s \
  --storage-size 32 \
  --version 14 \
  --high-availability Enabled \
  --backup-retention 7 \
  --backup-interval-hours 24 \
  --geo-redundant-backup Enabled

# Configure firewall
echo "Configuring firewall rules..."
az postgres flexible-server firewall-rule create \
  --resource-group $RESOURCE_GROUP \
  --server-name $SERVER_NAME \
  --rule-name allow-aks \
  --start-ip-address 10.0.0.0 \
  --end-ip-address 10.255.255.255

# Create databases
echo "Creating databases..."
PGPASSWORD="PostgresPassword123!" psql -h ${SERVER_NAME}.postgres.database.azure.com \
  -U postgres@${SERVER_NAME} \
  -d postgres \
  -c "CREATE DATABASE three_tier_prod;"

# Create secrets in Kubernetes
echo "Creating Kubernetes secrets..."
kubectl create secret generic postgres-credentials \
  --from-literal=host=${SERVER_NAME}.postgres.database.azure.com \
  --from-literal=port=5432 \
  --from-literal=username=app_user@${SERVER_NAME} \
  --from-literal=password='AppPassword123!' \
  -n three-tier-app

echo "✅ PostgreSQL setup complete!"
```

---

## Summary

Your database setup provides:
- ✅ High availability with automatic failover
- ✅ Automated daily backups with point-in-time restore
- ✅ Logical schema separation for microservices
- ✅ Connection pooling for efficiency
- ✅ Comprehensive monitoring and alerting
- ✅ Simple credentials management via Kubernetes secrets

