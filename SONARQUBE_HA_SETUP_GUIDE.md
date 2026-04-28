# SonarQube High Availability (HA) Setup Guide

## Complete Step-by-Step Installation with PostgreSQL Database

This guide covers setting up SonarQube with PostgreSQL in a High Availability configuration for production use.

---

## 📋 Prerequisites

### System Requirements
- **Server Specs**: 
  - CPU: 4+ cores (8 recommended for HA)
  - RAM: 8GB minimum (16GB+ for HA)
  - Storage: 100GB+ SSD recommended
  
- **Database**: PostgreSQL 9.6+
- **Java**: JDK 11 or OpenJDK 17+
- **OS**: Linux/macOS/Windows with Docker

### Required Credentials
- [ ] Azure subscription (if using Azure)
- [ ] Docker Hub account (optional, for private images)
- [ ] PostgreSQL admin password ready

### Network Requirements
- [ ] Port 9000 accessible (SonarQube web)
- [ ] Port 5432 accessible (PostgreSQL)
- [ ] Internet access for plugin downloads

---

## 🏗️ Architecture Options

### Option 1: Single Node (Development/Testing)
```
┌─────────────────────────────────────┐
│   SonarQube Container               │
│   (docker-compose)                  │
├─────────────────────────────────────┤
│   PostgreSQL Database               │
│   (Single instance)                 │
└─────────────────────────────────────┘
```
**Best for**: Testing, development
**Deployment time**: 15 minutes
**Cost**: Low
**Downtime risk**: High

---

### Option 2: HA with PostgreSQL (Recommended for Production)
```
┌──────────────────────────────────────────────────────┐
│                    Azure (or Cloud)                  │
├──────────────────────────────────────────────────────┤
│                                                      │
│  ┌────────────────┐  ┌────────────────┐            │
│  │  SonarQube-1   │  │  SonarQube-2   │            │
│  │  (App Server)  │  │  (App Server)  │            │
│  └────────────────┘  └────────────────┘            │
│         │                     │                     │
│         └─────────┬───────────┘                     │
│                   │ (Failover)                      │
│         ┌─────────▼──────────┐                      │
│         │  Load Balancer     │                      │
│         │  (App Gateway)     │                      │
│         └─────────┬──────────┘                      │
│                   │                                 │
│    ┌──────────────┴──────────────┐                 │
│    │                             │                 │
│  ┌─▼──────────────┐  ┌──────────▼┐                 │
│  │ PostgreSQL-HA  │  │  Replica  │                 │
│  │   (Primary)    │  │ (Standby) │                 │
│  └────────────────┘  └───────────┘                 │
│    Auto Failover:                                   │
│    - Automatic switchover                          │
│    - Zero data loss                                │
│                                                    │
└──────────────────────────────────────────────────────┘
```
**Best for**: Production
**Deployment time**: 45-60 minutes
**Cost**: Medium-High
**Downtime risk**: Very Low (<5 minutes)

---

### Option 3: Kubernetes (Azure AKS) - Most Scalable
```
┌──────────────────────────────────────────────────────┐
│          Azure AKS Cluster                          │
├──────────────────────────────────────────────────────┤
│                                                      │
│  ┌─────────────────────────────────────────────┐   │
│  │  Namespace: sonarqube                       │   │
│  │                                             │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐    │   │
│  │  │SonarQube│  │SonarQube│  │SonarQube│    │   │
│  │  │  Pod-1  │  │  Pod-2  │  │  Pod-3  │    │   │
│  │  └─────────┘  └─────────┘  └─────────┘    │   │
│  │       │            │            │         │   │
│  │       └────────────┼────────────┘         │   │
│  │                    │                      │   │
│  │            ┌───────▼────────┐             │   │
│  │            │  Service Mesh  │             │   │
│  │            │  Load Balancer │             │   │
│  │            └────────────────┘             │   │
│  │                                           │   │
│  │  ┌──────────────────────────────────┐    │   │
│  │  │   PostgreSQL StatefulSet        │    │   │
│  │  │   - Primary (read/write)        │    │   │
│  │  │   - Replicas (read-only)        │    │   │
│  │  │   - Persistent Volumes          │    │   │
│  │  │   - Auto Failover               │    │   │
│  │  └──────────────────────────────────┘    │   │
│  │                                           │   │
│  └───────────────────────────────────────────┘   │
│                                                  │
│  Monitoring: Prometheus + Grafana              │
│  Logging: ELK Stack                            │
│  Backup: Azure Backup                          │
│                                                  │
└──────────────────────────────────────────────────────┘
```
**Best for**: Enterprise/Large-scale
**Deployment time**: 90-120 minutes
**Cost**: High
**Downtime risk**: Minimal (<1 minute)

---

## 🔧 Option 1: Docker Compose (Single Node)

### Step 1: Create Docker Compose Configuration

```bash
# Create directory for SonarQube
mkdir -p ~/sonarqube-setup
cd ~/sonarqube-setup

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:13-alpine
    container_name: sonarqube-postgres
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: sonar_secure_password_123  # CHANGE THIS!
      POSTGRES_DB: sonarqube
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - sonarnet
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U sonar"]
      interval: 10s
      timeout: 5s
      retries: 5

  sonarqube:
    image: sonarqube:10.2-community
    container_name: sonarqube
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://postgres:5432/sonarqube
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: sonar_secure_password_123  # MATCH POSTGRES PASSWORD!
      SONAR_ES_BOOTSTRAP_CHECKS_DISABLED: "true"
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs
    ports:
      - "9000:9000"
    networks:
      - sonarnet
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/api/system/status"]
      interval: 30s
      timeout: 10s
      retries: 5

networks:
  sonarnet:
    driver: bridge

volumes:
  postgres_data:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
EOF
```

### Step 2: Start Services

```bash
# Navigate to directory
cd ~/sonarqube-setup

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f sonarqube

# Wait 2-3 minutes for SonarQube to start

# Check status
docker-compose ps
# Expected output:
# NAME                COMMAND                 STATUS
# sonarqube           "/opt/sonarqube/bin..."  Up X seconds
# sonarqube-postgres  "docker-entrypoint..."   Up X seconds
```

### Step 3: Access SonarQube

```bash
# Open in browser
open http://localhost:9000

# Login
# Username: admin
# Password: admin (default)
# You'll be prompted to change it

# Create new password
# Make it strong: Min 8 chars, uppercase, numbers, special chars
```

### Step 4: Generate Admin Token

```bash
# In SonarQube UI:
1. Click Admin (top-right user icon)
2. Settings → Security → Users
3. Click on "admin" user
4. Generate token (save this for later)

# Example token: squ_1234567890abcdef1234567890abcdef12345678
```

---

## 🔒 Option 2: High Availability Setup (Azure PostgreSQL)

### Architecture: 2x SonarQube + Azure PostgreSQL HA

### Step 1: Create Azure Resources

```bash
# Set variables
RESOURCE_GROUP="rg-sonarqube"
LOCATION="eastus"
DB_NAME="sonarqube-db"
DB_USER="sonaradmin"
DB_PASSWORD="Sonar@Secure2026Pass123!"  # CHANGE THIS!

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# Create Storage Account (for persistent logs/data)
STORAGE_NAME="sonarqubesa$(date +%s)"
az storage account create \
  --name $STORAGE_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS

# Create Azure Database for PostgreSQL HA
az postgres flexible-server create \
  --name $DB_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --admin-user $DB_USER \
  --admin-password $DB_PASSWORD \
  --tier Burstable \
  --sku-name Standard_B4ms \
  --storage-size 102400 \
  --high-availability ZoneRedundant \
  --backup-retention 35 \
  --geo-redundant-backup Enabled \
  --zone 1 \
  --standby-availability-zone 2

# Note: This creates a hot standby replica in a different zone

# Get connection string
DB_HOST=$(az postgres flexible-server show \
  --name $DB_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "fullyQualifiedDomainName" \
  --output tsv)

echo "Database Host: $DB_HOST"
echo "Save for later: $DB_HOST"
```

### Step 2: Configure PostgreSQL

```bash
# Connect to Azure PostgreSQL
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER@$DB_NAME -d postgres

# Commands to run (in psql):
```

```sql
-- Create sonarqube database
CREATE DATABASE sonarqube OWNER sonaradmin;

-- Configure for SonarQube
ALTER DATABASE sonarqube SET max_parallel_workers_per_gather = 4;
ALTER DATABASE sonarqube SET max_parallel_workers = 4;
ALTER DATABASE sonarqube SET max_wal_size = '1000MB';

-- Enable necessary extensions
\c sonarqube
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create dedicated user (optional, for security)
CREATE ROLE sonarqube WITH LOGIN PASSWORD 'sonarqube_pass_123';
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonarqube;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO sonarqube;

-- Verify setup
\l  -- List databases
\du -- List users
```

### Step 3: Create Container Instances for SonarQube

```bash
# Create ACR (Azure Container Registry) for custom images
ACR_NAME="sonarqubeacr$(date +%s%N | cut -b1-20)"
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic

# Create ACI (Azure Container Instance) - SonarQube 1
az container create \
  --resource-group $RESOURCE_GROUP \
  --name sonarqube-1 \
  --image sonarqube:10.2-community \
  --cpu 2 \
  --memory 4 \
  --ports 9000 \
  --protocol TCP \
  --environment-variables \
    SONAR_JDBC_URL="jdbc:postgresql://$DB_HOST:5432/sonarqube" \
    SONAR_JDBC_USERNAME="sonarqube@$DB_NAME" \
    SONAR_JDBC_PASSWORD="$DB_PASSWORD" \
    SONAR_ES_BOOTSTRAP_CHECKS_DISABLED="true" \
  --dns-name-label sonarqube-1

# Create ACI - SonarQube 2 (for HA)
az container create \
  --resource-group $RESOURCE_GROUP \
  --name sonarqube-2 \
  --image sonarqube:10.2-community \
  --cpu 2 \
  --memory 4 \
  --ports 9000 \
  --protocol TCP \
  --environment-variables \
    SONAR_JDBC_URL="jdbc:postgresql://$DB_HOST:5432/sonarqube" \
    SONAR_JDBC_USERNAME="sonarqube@$DB_NAME" \
    SONAR_JDBC_PASSWORD="$DB_PASSWORD" \
    SONAR_ES_BOOTSTRAP_CHECKS_DISABLED="true" \
  --dns-name-label sonarqube-2

# Get IP addresses
az container show \
  --resource-group $RESOURCE_GROUP \
  --name sonarqube-1 \
  --query ipAddress.fqdn \
  --output tsv

az container show \
  --resource-group $RESOURCE_GROUP \
  --name sonarqube-2 \
  --query ipAddress.fqdn \
  --output tsv
```

### Step 4: Create Application Gateway Load Balancer

```bash
# Create public IP
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name sonarqube-pip \
  --sku Standard

# Create Application Gateway
az network application-gateway create \
  --name sonarqube-appgw \
  --resource-group $RESOURCE_GROUP \
  --capacity 1 \
  --sku Standard_v2 \
  --http-settings-cookie-based-affinity Disabled \
  --public-ip-address sonarqube-pip \
  --cert-file /path/to/cert.pfx \
  --cert-password <cert-password> \
  --http-settings-port 9000 \
  --http-settings-protocol Http \
  --frontend-port 443 \
  --http-settings-cookie-based-affinity Disabled

# Get Application Gateway public IP
APPGW_IP=$(az network public-ip show \
  --resource-group $RESOURCE_GROUP \
  --name sonarqube-pip \
  --query ipAddress \
  --output tsv)

echo "Access SonarQube at: https://$APPGW_IP"
```

---

## ☸️ Option 3: Kubernetes (AKS) - Enterprise Grade

### Step 1: Create AKS Cluster

```bash
# Set variables
RESOURCE_GROUP="rg-sonarqube-k8s"
CLUSTER_NAME="sonarqube-aks"
LOCATION="eastus"
NODE_COUNT=3

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# Create AKS cluster
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --node-count $NODE_COUNT \
  --vm-set-type VirtualMachineScaleSets \
  --load-balancer-sku standard \
  --enable-managed-identity \
  --network-plugin azure \
  --zones 1 2 3 \
  --enable-pod-identity \
  --network-policy azure

# Get credentials
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --overwrite-existing

# Verify cluster
kubectl get nodes
```

### Step 2: Create PostgreSQL Operator (for HA database)

```bash
# Add Bitnami Helm repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Create namespace
kubectl create namespace sonarqube

# Create PostgreSQL with HA
helm install postgres bitnami/postgresql \
  --namespace sonarqube \
  --set auth.postgresPassword=postgres_admin_pass \
  --set auth.username=sonar \
  --set auth.password=sonar_password_123 \
  --set auth.database=sonarqube \
  --set primary.persistence.size=50Gi \
  --set primary.persistence.storageClassName=managed-premium \
  --set replica.replicaCount=2 \
  --set replica.persistence.size=50Gi \
  --set replica.persistence.storageClassName=managed-premium \
  --set metrics.enabled=true \
  --set metrics.serviceMonitor.enabled=true

# Wait for PostgreSQL to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=postgresql \
  -n sonarqube \
  --timeout=300s

# Verify
kubectl get pods -n sonarqube
kubectl get pvc -n sonarqube
```

### Step 3: Deploy SonarQube (Helm Chart)

```bash
# Add SonarQube Helm repository
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo update

# Create values.yaml for SonarQube
cat > sonarqube-values.yaml << 'EOF'
replicaCount: 3

image:
  repository: sonarqube
  tag: 10.2-community
  pullPolicy: IfNotPresent

service:
  type: LoadBalancer
  port: 9000

resources:
  requests:
    memory: "2Gi"
    cpu: "1"
  limits:
    memory: "4Gi"
    cpu: "2"

postgresql:
  enabled: true
  auth:
    username: sonar
    password: sonar_password_123
    database: sonarqube
  primary:
    persistence:
      enabled: true
      size: 50Gi
      storageClassName: managed-premium
  replica:
    replicaCount: 2
    persistence:
      enabled: true
      size: 50Gi
      storageClassName: managed-premium

persistence:
  enabled: true
  size: 50Gi
  storageClassName: managed-premium

metrics:
  enabled: true
  serviceMonitor:
    enabled: true

ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: sonarqube.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: sonarqube-tls
      hosts:
        - sonarqube.example.com
EOF

# Deploy SonarQube
helm install sonarqube sonarqube/sonarqube \
  --namespace sonarqube \
  --values sonarqube-values.yaml \
  --wait

# Wait for deployment
kubectl rollout status deployment/sonarqube -n sonarqube

# Check status
kubectl get all -n sonarqube
kubectl get svc -n sonarqube
```

### Step 4: Access SonarQube on Kubernetes

```bash
# Get external IP
SONARQUBE_IP=$(kubectl get svc sonarqube \
  -n sonarqube \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Access SonarQube at: http://$SONARQUBE_IP:9000"

# Or use port-forward for testing
kubectl port-forward -n sonarqube svc/sonarqube 9000:9000

# Then access: http://localhost:9000
```

---

## 🔐 Step: Post-Installation Configuration

### 1. Change Default Admin Password

```bash
# Access SonarQube at http://localhost:9000
# 1. Login with admin/admin
# 2. Top-right → My Account
# 3. Change Password
# 4. New password: SonarQube@Secure2026!
```

### 2. Generate Authentication Token

```bash
# In SonarQube UI:
1. Top-right → My Account → Security → Tokens
2. Generate token (name: ci-user-token)
3. Copy and save: squ_abc1234567890def1234567890abcdef12345678

# For pipeline use:
export SONAR_TOKEN="squ_abc1234567890def1234567890abcdef12345678"
```

### 3. Create Project Quality Gate

```bash
# In SonarQube UI:
1. Administration → Configuration → Quality Gates
2. Create New Quality Gate: "3-Tier-App"
3. Add conditions:
   - Coverage ≥ 80%
   - Duplications ≤ 3%
   - Security Hotspots Reviewed = 100%
   - Maintainability Rating: A or better
   - Security Rating: A or better
   - Reliability Rating: A or better
4. Save

# Set as default
1. Settings → Projects → Default Quality Gate
2. Select "3-Tier-App"
```

### 4. Create Projects

```bash
# In SonarQube UI:
1. Projects → Create Project
2. Project Key: user-service
3. Project Name: User Service
4. Visibility: Private
5. Set Quality Gate: "3-Tier-App"

# Repeat for:
- order-service
- payment-service
```

---

## 📊 Step: Configure Monitoring & Alerts

### For Docker Compose Setup

```yaml
# Add to docker-compose.yml:

  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    ports:
      - "9090:9090"
    networks:
      - sonarnet

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    networks:
      - sonarnet

volumes:
  prometheus_data:
  grafana_data:
```

### Create Prometheus Configuration

```bash
cat > prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'sonarqube'
    metrics_path: '/api/ce/metrics'
    static_configs:
      - targets: ['sonarqube:9000']
    basic_auth:
      username: admin
      password: admin

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres:5432']
EOF
```

---

## 🔄 Step: Database Backup & Recovery

### Backup Strategy

```bash
# For Docker Compose
# Daily backup script
cat > backup-sonarqube.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/backups/sonarqube"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup PostgreSQL
docker exec sonarqube-postgres pg_dump \
  -U sonar sonarqube \
  | gzip > $BACKUP_DIR/sonarqube_db_$TIMESTAMP.sql.gz

# Backup SonarQube data
docker exec sonarqube tar -czf - /opt/sonarqube/data \
  > $BACKUP_DIR/sonarqube_data_$TIMESTAMP.tar.gz

# Keep only last 7 days
find $BACKUP_DIR -type f -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR"
EOF

chmod +x backup-sonarqube.sh

# Run daily with cron
crontab -e
# Add: 0 2 * * * /path/to/backup-sonarqube.sh
```

### Recovery Procedure

```bash
# 1. Stop SonarQube
docker-compose down

# 2. Restore database
BACKUP_FILE="sonarqube_db_20260428_120000.sql.gz"
zcat /backups/sonarqube/$BACKUP_FILE | \
  docker exec -i sonarqube-postgres psql \
  -U sonar -d sonarqube

# 3. Restore data
docker exec -i sonarqube tar -xzf - \
  -C /opt/sonarqube < /backups/sonarqube/sonarqube_data_20260428_120000.tar.gz

# 4. Restart
docker-compose up -d
```

---

## 🧪 Step: Test Configuration

### Test SonarQube Scanner

```bash
# 1. Install SonarScanner
brew install sonar-scanner

# 2. Create test project
mkdir ~/test-sonarqube-scan
cd ~/test-sonarqube-scan

# 3. Create simple Java file
cat > HelloWorld.java << 'EOF'
public class HelloWorld {
    public static void main(String[] args) {
        System.out.println("Hello, World!");
    }
}
EOF

# 4. Run scan
sonar-scanner \
  -Dsonar.projectKey=test-project \
  -Dsonar.sources=. \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.login=squ_abc1234567890def1234567890abcdef12345678

# 5. Check results in SonarQube UI
# http://localhost:9000/projects
```

---

## 🔍 Troubleshooting

### SonarQube Won't Start

```bash
# Check logs
docker logs sonarqube

# Common issues:

# 1. Database connection error
# Solution: Verify PostgreSQL is running
docker logs sonarqube-postgres

# 2. Elasticsearch error
# Solution: Check vm.max_map_count
sysctl -w vm.max_map_count=262144

# 3. Out of memory
# Solution: Increase Docker memory
# Docker Desktop → Preferences → Resources → Memory
```

### Database Connection Issues

```bash
# Test database connection
psql -h localhost -U sonar -d sonarqube

# If fails, check:
# 1. PostgreSQL running
docker ps | grep postgres

# 2. Credentials correct
# In docker-compose.yml

# 3. Network connectivity
docker network inspect sonarnet
```

### Performance Issues

```bash
# Check database performance
docker exec sonarqube-postgres psql \
  -U sonar -d sonarqube \
  -c "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size FROM pg_tables ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 10;"

# Increase resources
# Edit docker-compose.yml:
services:
  sonarqube:
    environment:
      - SONAR_JAVA_OPTS=-Xmx4g -Xms1024m
```

---

## 📈 Monitoring Dashboard

### Key Metrics to Monitor

```
1. SonarQube Health
   - API response time
   - Database connection pool usage
   - Elasticsearch cluster status

2. Code Quality Trends
   - Lines of code
   - Code coverage
   - Technical debt
   - Issues by severity

3. Database Performance
   - Query response time
   - Connection pool utilization
   - Replication lag (for HA)

4. System Resources
   - CPU usage
   - Memory usage
   - Disk space
   - Network I/O
```

### Grafana Dashboard

```json
{
  "dashboard": {
    "title": "SonarQube Monitoring",
    "panels": [
      {
        "title": "Code Coverage",
        "targets": [
          {
            "expr": "sonarqube_coverage{project=\"user-service\"}"
          }
        ]
      },
      {
        "title": "Technical Debt",
        "targets": [
          {
            "expr": "sonarqube_technical_debt"
          }
        ]
      },
      {
        "title": "Database Connections",
        "targets": [
          {
            "expr": "pg_connections_used"
          }
        ]
      },
      {
        "title": "SonarQube Uptime",
        "targets": [
          {
            "expr": "up{job=\"sonarqube\"}"
          }
        ]
      }
    ]
  }
}
```

---

## ✅ Verification Checklist

```
Setup Verification:
  ☐ Docker/Kubernetes cluster running
  ☐ PostgreSQL database accessible
  ☐ SonarQube web interface loads
  ☐ Admin login successful
  ☐ Default password changed
  ☐ Authentication token generated

Configuration:
  ☐ Quality gates created
  ☐ Projects created (3 services)
  ☐ Quality gate assigned to projects
  ☐ Backup script running daily
  ☐ Monitoring alerts configured
  ☐ SSL/TLS certificates installed

Integration:
  ☐ SonarScanner can connect
  ☐ Pipeline can reach SonarQube
  ☐ Results visible in UI
  ☐ Database replication working (HA)
  ☐ Load balancer routing traffic

Maintenance:
  ☐ Backup running successfully
  ☐ Database logs clean
  ☐ No connection errors
  ☐ Performance within threshold
  ☐ Disk space adequate
```

---

## 📋 Security Hardening

```bash
# 1. Change default ports (optional)
# Edit docker-compose.yml
ports:
  - "9001:9000"  # Change 9000 to custom port

# 2. Enable HTTPS
# Create self-signed cert:
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout sonarqube.key \
  -out sonarqube.crt

# 3. Restrict network access
# Firewall rules: Only allow from CI/CD system

# 4. Enable LDAP/SAML integration
# Administration → Security → Authentication

# 5. Enable audit logging
# Administration → Configuration → Audit
```

---

## 🚀 Integration with DevSecOps Pipeline

Once SonarQube is running, add to `azure-pipelines.yml`:

```yaml
- stage: CodeQuality
  dependsOn: Build
  jobs:
  - job: SonarQubeAnalysis
    steps:
    - task: SonarQubePrepare@5
      inputs:
        SonarQube: 'SonarQube'  # Service connection
        scannerMode: 'CLI'
        configMode: 'manual'
        cliProjectKey: 'user-service'
        cliProjectName: 'User Service'
        cliSources: 'user-service/src'
        extraProperties: |
          sonar.java.coverage.reportPaths=$(System.DefaultWorkingDirectory)/**/target/site/jacoco/jacoco.xml
          
    - task: SonarQubePublish@5
      inputs:
        pollingTimeoutSec: '300'
```

---

## 📞 Support & References

- **Official Documentation**: https://docs.sonarqube.org/
- **Docker Image**: https://hub.docker.com/_/sonarqube
- **Helm Chart**: https://github.com/SonarSource/helm-chart-sonarqube
- **Community Forum**: https://community.sonarsource.com/

---

## Next Steps

1. ✅ Choose deployment option (Docker/K8s/Azure)
2. ✅ Follow step-by-step guide above
3. ✅ Test with sample project
4. ✅ Integrate with CI/CD pipeline
5. ✅ Configure backup strategy
6. ✅ Setup monitoring

---

**SonarQube HA Setup Complete!** 🎉

Your code quality analysis platform is ready for production use.
