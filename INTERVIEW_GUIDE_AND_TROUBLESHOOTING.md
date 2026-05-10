# Helm & ArgoCD Setup - Interview Guide & Troubleshooting
## Real-World Production Scenarios, Azure Issues, and Technical Deep Dives

**Last Updated**: May 2026  
**Version**: 1.0.0

---

## Table of Contents
1. [Executive Summary & Interview Intro](#executive-summary--interview-intro)
2. [Architecture Overview](#architecture-overview)
3. [Real-Time Azure & Azure DevOps Issues](#real-time-azure--azure-devops-issues)
4. [AKS Deployment Issues & Solutions](#aks-deployment-issues--solutions)
5. [Comprehensive Interview Q&A](#comprehensive-interview-qa)
6. [Troubleshooting Guide](#troubleshooting-guide)
7. [Production Scenarios](#production-scenarios)

---

## Executive Summary & Interview Intro

### How to Introduce This Setup in an Interview

**Your Opening Statement:**

> "I've designed and implemented a production-grade **Helm & ArgoCD-based GitOps platform** for a 3-tier microservices architecture running on Azure Kubernetes Service (AKS). The solution provides complete **Infrastructure as Code**, **automated deployments**, and **self-healing capabilities** across dev, staging, and production environments.
>
> The architecture consists of **three core components**:
> 1. **Helm Charts** for templating and packaging Kubernetes applications
> 2. **ArgoCD** for declarative GitOps deployments
> 3. **Azure DevOps Pipeline** for CI/CD automation
>
> This solution handles **real-world production challenges** including multi-environment deployments, RBAC, security scanning, database migrations, and automatic rollbacks. I've also built comprehensive automation scripts for setup, validation, and release management."

### Key Selling Points

✅ **Complete End-to-End Solution**: From code commit to production deployment  
✅ **GitOps Best Practices**: Git as single source of truth  
✅ **Multi-Environment Support**: Dev/Staging/Prod with different configurations  
✅ **Production-Ready**: Includes RBAC, security contexts, health checks  
✅ **Automation**: 4 comprehensive scripts for setup and management  
✅ **Troubleshooting**: Covers 50+ real-world issues with solutions  
✅ **Documentation**: 5000+ lines of guides and examples  

---

## Architecture Overview

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Developer Workflow                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Code Push (main branch)                                │
│       ↓                                                     │
│  2. GitHub Repository                                       │
│       ↓                                                     │
│  3. Azure Pipeline (Webhook)                               │
│       • Build Docker images                                │
│       • Run tests & security scans                         │
│       • Push to ACR (Azure Container Registry)            │
│       • Update Helm values with new image tag             │
│       • Commit back to Git                                │
│       ↓                                                     │
│  4. ArgoCD Detects Changes                                 │
│       • Webhook notification or polling                    │
│       • Fetch latest from Git                             │
│       • Render Helm templates                             │
│       • Compare with cluster state                        │
│       ↓                                                     │
│  5. Automatic Sync to AKS Cluster                         │
│       • Apply Kubernetes manifests                        │
│       • Perform rolling updates                           │
│       • Health checks & self-healing                      │
│       ↓                                                     │
│  6. Production Workloads Running                          │
│       • 3-tier microservices                              │
│       • Load balanced via Application Gateway             │
│       • Monitored with Prometheus/Grafana                │
│       ↓                                                     │
│  7. Automatic Rollback on Issues                          │
│       • Detect deployment failures                        │
│       • Automatic rollback to previous Git commit         │
│       • Alert operations team                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Technology Stack

```
┌──────────────────────────────────────────────────────────┐
│                  Cloud Platform: Azure                    │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─────────────────────────────────────────────┐        │
│  │      AKS Cluster (Kubernetes 1.28)         │        │
│  │  ┌──────────────────────────────────────┐  │        │
│  │  │  three-tier-app Namespace            │  │        │
│  │  │  • User Service (3 replicas)         │  │        │
│  │  │  • Order Service (3 replicas)        │  │        │
│  │  │  • Payment Service (3 replicas)      │  │        │
│  │  │  • PostgreSQL (HA with replication)  │  │        │
│  │  └──────────────────────────────────────┘  │        │
│  │  ┌──────────────────────────────────────┐  │        │
│  │  │  argocd Namespace                    │  │        │
│  │  │  • ArgoCD Server (API + UI)          │  │        │
│  │  │  • Repo Server (Git sync)            │  │        │
│  │  │  • Controller (Sync logic)           │  │        │
│  │  │  • Redis (cache)                     │  │        │
│  │  └──────────────────────────────────────┘  │        │
│  └─────────────────────────────────────────────┘        │
│                                                          │
│  Other Azure Services:                                   │
│  • Azure Container Registry (ACR)                       │
│  • Azure Key Vault (secrets)                           │
│  • Azure Database for PostgreSQL (Flexible Server)     │
│  • Application Gateway (load balancing)                │
│  • Azure Monitor (logs & metrics)                      │
│  • Log Analytics (query & analysis)                    │
│                                                          │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│              CI/CD Pipeline: Azure DevOps                │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  10-Stage Pipeline:                                      │
│  1. Initialize (tool versions, validation)             │
│  2. Build (Maven compile, tests)                        │
│  3. Code Quality (SonarQube analysis)                   │
│  4. Security Scan (Snyk, OWASP, Trivy)                │
│  5. Unit Tests (code coverage)                         │
│  6. Build Containers (multi-stage Docker)             │
│  7. Push to ACR (image versioning)                     │
│  8. Deploy to Dev (automatic)                         │
│  9. Deploy to Staging (approval gate)                 │
│  10. Deploy to Production (approval gate)             │
│                                                          │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│          GitOps & Infrastructure as Code                 │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  GitHub Repository:                                      │
│  • helm-charts/ (3 services, 39 files)                 │
│  • argocd/ (Applications, Projects, Repos)            │
│  • scripts/ (4 automation scripts)                     │
│  • azure-pipelines.yml (10-stage CI/CD)              │
│  • environments/ (dev/staging/prod values)           │
│                                                          │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│              Monitoring & Observability                   │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  • Azure Monitor (CPU, memory, request metrics)        │
│  • Prometheus (Kubernetes metrics)                     │
│  • Grafana (visualization dashboards)                  │
│  • Log Analytics (centralized logging)                 │
│  • Application Insights (app performance)              │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

### Deployment Workflow

```
Git Commit
    │
    ├─→ Azure Pipeline Triggered
    │     ├─→ Build & Test Code
    │     ├─→ Scan for Vulnerabilities
    │     ├─→ Build Docker Images
    │     ├─→ Push to Azure Container Registry (ACR)
    │     └─→ Update Helm values with new image tag
    │           ↓
    │           Commit back to Git
    │
    ├─→ ArgoCD Webhook Notified
    │     ├─→ Fetch Latest Helm Charts from Git
    │     ├─→ Render Kubernetes Manifests
    │     └─→ Compare with Current Cluster State
    │
    ├─→ Diff Analysis
    │     ├─→ If Match: No action
    │     ├─→ If Differ: Apply changes
    │     └─→ If Drift: Self-heal
    │
    ├─→ Deployment to Cluster
    │     ├─→ Apply manifests via kubectl
    │     ├─→ Rolling update of pods
    │     └─→ Health checks
    │
    ├─→ Monitoring & Alerting
    │     ├─→ Track deployment status
    │     ├─→ Monitor pod health
    │     └─→ Alert on failures
    │
    └─→ Automatic Rollback (if needed)
          └─→ Revert Git commit or previous version
```

---

## Real-Time Azure & Azure DevOps Issues

### Issue #1: Azure DevOps Pipeline - "Private Docker Registry Access Denied"

**Scenario**: Pipeline builds Docker image successfully but fails to push to ACR.

**Error Message**:
```
Error response from daemon: Head "https://acrname.azurecr.io/v2/user-service/manifests/latest": 
unauthorized: authentication required, bearer realm="https://acrname.azurecr.io/oauth2/token", 
service="acrname.azurecr.io"
```

**Root Causes**:
1. ACR credentials not configured in Azure Pipeline
2. Service principal doesn't have AcrPush role
3. Personal Access Token expired or revoked
4. ACR firewall rules blocking pipeline agent

**Solution**:

```bash
# Step 1: Verify ACR exists and get login server
az acr list --query "[].{name:name, loginServer:loginServer}"

# Step 2: Check service principal has AcrPush role
az role assignment list \
  --assignee <service-principal-id> \
  --query "[].roleDefinitionName"

# Step 3: Grant AcrPush role if not present
REGISTRY_ID=$(az acr show \
  --resource-group rg-3tier-app \
  --name acrname \
  --query id --output tsv)

az role assignment create \
  --assignee <service-principal-id> \
  --role AcrPush \
  --scope $REGISTRY_ID

# Step 4: Create ACR credentials
az acr credential show \
  --name acrname \
  --query "{username:username, password:passwords[0].value}"

# Step 5: In Azure Pipeline, add Docker Registry Service Connection
# Project Settings → Service Connections → New Service Connection
# Type: Docker Registry
# Registry Type: Azure Container Registry
# Azure subscription: (select your subscription)
# Azure container registry: acrname

# Step 6: Update azure-pipelines.yml
stages:
  - stage: PushACR
    jobs:
      - job: PushImage
        steps:
          - task: Docker@2
            inputs:
              command: 'login'
              containerRegistry: 'acrServiceConnection'  # Name of service connection
          
          - task: Docker@2
            inputs:
              command: 'push'
              repository: '$(ACR_URL)/user-service'
              tags: '$(Build.BuildId)'
              containerRegistry: 'acrServiceConnection'
```

**Interview Answer**:
> "This is a common issue in Azure DevOps when the pipeline doesn't have proper credentials to access ACR. The solution involves three parts: First, ensure the service principal has the AcrPush role assigned on the ACR resource. Second, create a Docker Registry service connection in Azure DevOps with the ACR credentials. Third, reference that service connection in the Docker push task. I always verify the ACR exists with `az acr list`, check role assignments, and then configure the service connection with proper Azure subscription context."

---

### Issue #2: Azure DevOps - "Stage Approval Failed - Deployment Gate Not Triggered"

**Scenario**: Production deployment stage is waiting for approval but no one receives approval notification.

**Error Message**:
```
The deployment approval has been pending for 3 days.
Requested by: Azure Pipeline
Status: Pending
No approvers have been notified.
```

**Root Causes**:
1. Approval settings not configured in stage
2. Approvers list is empty or invalid
3. Email notifications disabled
4. Pipeline has no permissions to trigger approval
5. Service principal doesn't have contributor access

**Solution**:

```yaml
# azure-pipelines.yml - Configure Approval Gate

stages:
  - stage: DeployStaging
    dependsOn: PushACR
    condition: succeeded()
    jobs:
      - deployment: DeployToStaging
        displayName: 'Deploy to Staging'
        environment: 
          name: 'staging-aks'
          resourceType: 'kubernetes'
          resourceName: 'staging-cluster'
        
        # Pre-deployment approval
        strategy:
          runOnce:
            preDeploy:
              steps:
                - script: echo "Pre-deployment stage"
  
  - stage: DeployProduction
    dependsOn: DeployStaging
    condition: succeeded()
    jobs:
      - deployment: DeployToProduction
        displayName: 'Deploy to Production'
        environment: 
          name: 'production-aks'
          resourceType: 'kubernetes'
          resourceName: 'production-cluster'
        strategy:
          runOnce:
            deploy:
              steps:
                - script: echo "Deploying to production"
```

**Configure Approval in Azure DevOps UI**:

```
1. Go to Pipelines → Environments
2. Select 'staging-aks' environment
3. Click "Approvals and checks" (⚙️)
4. Add "Approval" check
   - Approvers: Select users/groups
   - Instructions: "Please review deployment"
   - Timeout: 24 hours
   - Allow approvers to approve their own runs: Unchecked
5. Save settings
6. Repeat for 'production-aks'
```

**PowerShell Script to Configure Approvals**:

```powershell
# Set up environment approvals via Azure DevOps API

$orgUrl = "https://dev.azure.com/your-organization"
$project = "your-project"
$token = "your-pat-token"
$encodedToken = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$token"))

# Get environment ID
$envUrl = "$orgUrl/$project/_apis/distributedtask/environments"
$environments = Invoke-RestMethod -Uri $envUrl -Headers @{Authorization = "Basic $encodedToken"} -Method GET

$stagingEnv = $environments.value | Where-Object { $_.name -eq "staging-aks" }
$prodEnv = $environments.value | Where-Object { $_.name -eq "production-aks" }

# Add approval check to staging
$approvalBody = @{
    type = @{
        id = "8C6F20A7-A545-4486-9777-F762FCEA4767"  # Built-in Approval type ID
    }
    settings = @{
        approvers = @(
            @{
                displayName = "DevOps Team"
                id = "user-group-id"  # Get from Azure AD
            }
        )
        instructions = "Please review and approve staging deployment"
        blockedApprovers = @()
        minRequiredApprovers = 1
        useAdvancedOptions = $false
        timeout = 86400  # 24 hours in seconds
    }
} | ConvertTo-Json -Depth 10

$approvalUrl = "$orgUrl/$project/_apis/pipelines/checks/configurations"
Invoke-RestMethod -Uri $approvalUrl `
    -Headers @{Authorization = "Basic $encodedToken"} `
    -Method POST `
    -Body $approvalBody `
    -ContentType "application/json"
```

**Interview Answer**:
> "Deployment gates and approvals require proper configuration in Azure DevOps Environments. First, you need to define environments for each deployment target (staging, production) in the pipeline. Then, configure approval checks on those environments through the UI or API. Key points: approvers must be valid Azure AD users/groups, email notifications must be enabled, and the pipeline service principal needs contributor access to trigger approvals. I usually set up multiple approvers for production to ensure proper oversight."

---

### Issue #3: Azure Container Registry (ACR) - "Image Pull Backoff - Authentication Failed"

**Scenario**: AKS pods fail to start with ImagePullBackOff error.

**Error Message**:
```
Failed to pull image "acrname.azurecr.io/user-service:latest": 
rpc error: code = Unknown desc = Error response from daemon: 
Head "https://acrname.azurecr.io/v2/user-service/manifests/latest": 
no basic auth credentials
```

**Root Causes**:
1. ImagePullSecret not configured in pod spec
2. ACR credentials secret is missing or invalid
3. Service principal credentials expired
4. ACR IP firewall blocking AKS nodes
5. Image tag doesn't exist in ACR

**Solution**:

```bash
# Step 1: Create secret for ACR credentials
kubectl create secret docker-registry acr-secret \
  --docker-server=acrname.azurecr.io \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=admin@example.com \
  -n three-tier-app

# Step 2: Verify secret created
kubectl get secret acr-secret -n three-tier-app -o yaml

# Step 3: Update Helm values to include imagePullSecrets
# helm-charts/user-service/values.yaml
imagePullSecrets:
  - name: acr-secret

# Step 4: Patch default service account (if using default SA)
kubectl patch serviceaccount default \
  -n three-tier-app \
  -p '{"imagePullSecrets": [{"name":"acr-secret"}]}'

# Step 5: Verify image exists in ACR
az acr repository show \
  --name acrname \
  --image user-service:1.0.0

# Step 6: If image missing, push it
docker tag user-service:1.0.0 acrname.azurecr.io/user-service:1.0.0
docker push acrname.azurecr.io/user-service:1.0.0

# Step 7: Check ACR firewall rules
az acr firewall show --name acrname --resource-group rg-3tier-app

# Step 8: If firewall enabled, allow AKS subnet
AKS_SUBNET_ID=$(az aks show \
  --resource-group rg-3tier-app \
  --name aks-cluster \
  --query "networkProfile.containerNetworkProfile.podCidrs[0]" -o tsv)

az acr network-rule add \
  --name acrname \
  --resource-group rg-3tier-app \
  --subnet-id $AKS_SUBNET_ID
```

**Kubernetes Manifest with ImagePullSecret**:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: acr-secret
  namespace: three-tier-app
type: kubernetes.io/dockercfg
data:
  .dockercfg: <base64-encoded-docker-config>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: three-tier-app
spec:
  template:
    spec:
      imagePullSecrets:
        - name: acr-secret
      serviceAccountName: user-service-sa
      containers:
        - name: user-service
          image: acrname.azurecr.io/user-service:1.0.0
          imagePullPolicy: IfNotPresent
```

**Troubleshooting Commands**:

```bash
# Check pod events
kubectl describe pod <pod-name> -n three-tier-app

# Check service account
kubectl get sa default -n three-tier-app -o yaml

# Test image pull manually
kubectl run debug \
  --image=acrname.azurecr.io/user-service:1.0.0 \
  --rm -it \
  --restart=Never \
  -- /bin/sh

# Check ACR access logs
az monitor activity-log list \
  --resource-group rg-3tier-app \
  --query "[?resourceProvider=='Microsoft.ContainerRegistry']"
```

**Interview Answer**:
> "ImagePullBackOff is usually caused by missing or invalid credentials to pull images from ACR. The solution involves creating a Kubernetes secret with ACR credentials, then referencing it in the pod spec via imagePullSecrets. Additionally, ensure the image tag exists in ACR and that AKS nodes can reach the ACR endpoint (check firewall rules). For Helm deployments, I configure imagePullSecrets in values.yaml so they're consistent across all deployments. I also always verify the image exists with `az acr repository show` before deploying."

---

### Issue #4: Azure DevOps - "Pipeline Timeout - Stage Taking Too Long"

**Scenario**: Docker build stage times out after 60 minutes default timeout.

**Error Message**:
```
The job was canceled because the build job exceeded the maximum execution time of 60 minutes
```

**Root Causes**:
1. Default timeout too short for large applications
2. Maven dependencies not cached
3. Docker layer caching not configured
4. Large Docker image build
5. Network latency downloading dependencies

**Solution**:

```yaml
# azure-pipelines.yml - Configure Timeouts and Caching

trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

variables:
  MAVEN_CACHE_FOLDER: $(Pipeline.Workspace)/.m2/repository
  DOCKER_BUILDKIT: 1  # Enable Docker BuildKit for better caching
  ACR_URL: acrname.azurecr.io

stages:
  - stage: Build
    displayName: 'Build & Test'
    jobs:
      - job: MavenBuild
        displayName: 'Maven Build'
        timeoutInMinutes: 120  # Set timeout to 120 minutes
        steps:
          # Cache Maven dependencies
          - task: Cache@2
            inputs:
              key: 'maven | "$(Agent.OS)" | **/pom.xml'
              restoreKeys: |
                maven | "$(Agent.OS)"
              path: $(MAVEN_CACHE_FOLDER)
            displayName: 'Cache Maven packages'
          
          - task: Maven@3
            inputs:
              mavenPomFile: 'pom.xml'
              mavenOptions: '-Xmx3072m -DskipTests'
              javaHomeOption: 'JDKVersion'
              jdkVersionOption: '11'
              publishJUnitResults: true
              testResultsFiles: '**/surefire-reports/TEST-*.xml'
              goals: 'clean package'
            env:
              M2_HOME: '$(MAVEN_CACHE_FOLDER)'
            timeoutInMinutes: 90

  - stage: BuildContainers
    displayName: 'Build Docker Images'
    dependsOn: Build
    jobs:
      - job: BuildImages
        displayName: 'Build Images'
        timeoutInMinutes: 120  # Separate timeout for Docker build
        steps:
          # Build with BuildKit for better caching
          - task: Docker@2
            inputs:
              command: 'build'
              Dockerfile: 'Dockerfile.user-service'
              tags: |
                $(ACR_URL)/user-service:latest
                $(ACR_URL)/user-service:$(Build.BuildId)
              arguments: |
                --cache-from=$(ACR_URL)/user-service:latest
                --build-arg BUILDKIT_INLINE_CACHE=1
            displayName: 'Build user-service image'
          
          - task: Docker@2
            inputs:
              command: 'login'
              containerRegistry: 'acrServiceConnection'
          
          - task: Docker@2
            inputs:
              command: 'push'
              repository: '$(ACR_URL)/user-service'
              tags: |
                latest
                $(Build.BuildId)
            displayName: 'Push user-service image'
            timeoutInMinutes: 60
```

**Optimized Dockerfile with Layer Caching**:

```dockerfile
# Dockerfile - Optimized for faster builds with caching

FROM maven:3.8.1-jdk-11-slim AS builder

# Cache Maven dependencies
COPY pom.xml /app/pom.xml
WORKDIR /app
RUN mvn dependency:go-offline -B

# Copy source and build
COPY src /app/src
RUN mvn clean package -DskipTests

# Final image
FROM openjdk:11-jre-slim

RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/target/*.jar application.jar

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-Xmx512m", "-XX:+UseG1GC", "-jar", "application.jar"]
```

**Configure Build Cache in ACR**:

```bash
# Enable ACR task to build with caching
az acr build \
  --registry acrname \
  --image user-service:latest \
  --image user-service:$(date +%Y%m%d-%H%M%S) \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  .

# Or configure ACR Tasks for scheduled builds with caching
az acr task create \
  --registry acrname \
  --name build-user-service \
  --image user-service:{{.Run.ID}} \
  --image user-service:latest \
  --context https://github.com/eswar3763/Terraform.git \
  --file Dockerfile.user-service \
  --git-trigger-branch main \
  --status Enabled
```

**Interview Answer**:
> "Pipeline timeouts usually indicate inefficient build processes. My approach is three-pronged: First, increase the timeout for long-running stages (I typically set 120 minutes for Maven builds). Second, implement dependency caching - Maven dependencies are cached between builds, reducing download time significantly. Third, optimize Docker images using multi-stage builds and BuildKit caching which reuses layers from previous builds. I also split long stages into smaller jobs that can run in parallel. This combination typically reduces build times from 60+ minutes to 20-30 minutes."

---

### Issue #5: Azure Database for PostgreSQL - "Connection Pool Exhaustion"

**Scenario**: Application suddenly starts failing with connection timeout errors after running fine for months.

**Error Message**:
```
Exception: HikariPool-1 - Connection is not available, request timed out after 30000ms.
java.sql.SQLTransientConnectionException: HikariPool-1 - Connection is not available
```

**Root Causes**:
1. Increased traffic consuming all connections
2. Long-running queries holding connections
3. Connection leak in application code
4. Database firewall blocking connections
5. Replica lag causing queries to queue
6. Connection pool size too small

**Solution**:

```bash
# Step 1: Check PostgreSQL connection status
psql -h postgres-prod.postgres.database.azure.com \
  -U postgres@postgres-prod \
  -d three_tier_prod \
  -c "SELECT count(*) FROM pg_stat_activity;"

# Step 2: Identify idle connections
psql -h postgres-prod.postgres.database.azure.com \
  -U postgres@postgres-prod \
  -d three_tier_prod \
  -c "SELECT pid, usename, application_name, state, state_change 
      FROM pg_stat_activity 
      WHERE state = 'idle' 
      ORDER BY state_change DESC;"

# Step 3: Identify long-running queries
psql -h postgres-prod.postgres.database.azure.com \
  -U postgres@postgres-prod \
  -d three_tier_prod \
  -c "SELECT pid, usename, application_name, duration, query 
      FROM pg_stat_statements 
      WHERE mean_time > 5000 
      ORDER BY mean_time DESC LIMIT 10;"

# Step 4: Check connection limits
psql -h postgres-prod.postgres.database.azure.com \
  -U postgres@postgres-prod \
  -d three_tier_prod \
  -c "SHOW max_connections;"

# Step 5: Monitor connections in real-time
watch -n 1 "psql -h postgres-prod.postgres.database.azure.com \
  -U postgres@postgres-prod \
  -d three_tier_prod \
  -c \"SELECT count(*) as total_connections, \
            state, \
            COUNT(*) as count \
      FROM pg_stat_activity \
      GROUP BY state;\""

# Step 6: Enable connection pooling with PgBouncer
# Deploy PgBouncer as sidecar or separate pod
kubectl create configmap pgbouncer-config \
  --from-literal=pgbouncer.ini="
[databases]
three_tier_prod = host=postgres-prod.postgres.database.azure.com port=5432 dbname=three_tier_prod

[pgbouncer]
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 20
min_pool_size = 5
reserve_pool_size = 5
reserve_pool_timeout = 3
max_db_connections = 100
max_user_connections = 100
" -n three-tier-app

# Step 7: Scale up connection pool in Helm values
# helm-charts/user-service/values-prod.yaml
database:
  hikari:
    maximumPoolSize: 30  # Increase from 20
    minimumIdle: 10      # Increase from 5
    connectionTimeout: 60000  # Increase from 30000
    maxLifetime: 1800000
    idleTimeout: 600000

# Step 8: Scale Azure Database
az postgres flexible-server parameter set \
  --resource-group rg-3tier-app \
  --server-name postgres-prod \
  --name max_connections \
  --value 500

# Step 9: Update application config
kubectl set env deployment/user-service \
  -n three-tier-app \
  SPRING_DATASOURCE_HIKARI_MAXIMUMpoolsize=30 \
  SPRING_DATASOURCE_HIKARI_MINIMUMIDLE=10

# Step 10: Kill idle connections if necessary
psql -h postgres-prod.postgres.database.azure.com \
  -U postgres@postgres-prod \
  -d three_tier_prod \
  -c "SELECT pg_terminate_backend(pid) 
      FROM pg_stat_activity 
      WHERE state = 'idle' 
      AND state_change < NOW() - INTERVAL '30 minutes';"
```

**Kubernetes Deployment with Connection Pooling**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
spec:
  template:
    spec:
      containers:
        - name: user-service
          env:
            # HikariCP Connection Pool Settings
            - name: SPRING_DATASOURCE_HIKARI_MAXIMUMPOOLSIZE
              value: "30"
            - name: SPRING_DATASOURCE_HIKARI_MINIMUMIDLE
              value: "10"
            - name: SPRING_DATASOURCE_HIKARI_CONNECTIONTIMEOUT
              value: "60000"
            - name: SPRING_DATASOURCE_HIKARI_MAXLIFETIME
              value: "1800000"
            - name: SPRING_DATASOURCE_HIKARI_IDLETIMEOUT
              value: "600000"
            - name: SPRING_DATASOURCE_HIKARI_LEAKDETECTIONTHRESHOLD
              value: "60000"
      
      # Sidecar for PgBouncer connection pooling
      - name: pgbouncer
        image: pgbouncer:1.18
        volumeMounts:
          - name: pgbouncer-config
            mountPath: /etc/pgbouncer
        ports:
          - containerPort: 6432
      
      volumes:
        - name: pgbouncer-config
          configMap:
            name: pgbouncer-config
```

**Interview Answer**:
> "Connection pool exhaustion typically manifests as sudden timeouts after the application has been running fine. This usually indicates a traffic spike or a query performance regression. My troubleshooting approach: First, check current connections and identify long-running queries with `pg_stat_activity` and `pg_stat_statements`. Second, scale up the HikariCP connection pool size in the Helm values (I typically increase from 20 to 30-50 for production). Third, implement PgBouncer as a connection pooler to multiplex connections at the protocol level. Fourth, investigate slow queries and add appropriate indexes. For Azure Database, I also monitor replica lag since that can cause connection queuing. I set up alerts when connection usage exceeds 80% of max_connections to proactively scale before hitting the limit."

---

## AKS Deployment Issues & Solutions

### Issue #1: AKS - "Pod CrashLoopBackOff - OutOfMemory (OOMKilled)"

**Scenario**: Pods restart continuously with OOMKilled status after successful startup.

**Error Message**:
```
kubectl describe pod user-service-xxxxx
Status: OOMKilled (exit code 137)
Last State: Terminated
  Reason: OOMKilled
  Message: The container was terminated
```

**Root Causes**:
1. Memory limit too low for application
2. Memory leak in Java application
3. Increased data processing causing higher memory usage
4. Node memory pressure

**Solution**:

```bash
# Step 1: Check pod memory usage
kubectl top pod -n three-tier-app

# Step 2: Check node memory availability
kubectl top nodes

# Step 3: Get detailed pod information
kubectl describe pod user-service-xxxxx -n three-tier-app

# Step 4: Check memory usage over time
kubectl logs user-service-xxxxx -n three-tier-app | grep -i memory

# Step 5: Capture heap dump if still running
kubectl exec user-service-xxxxx -n three-tier-app -- \
  jmap -dump:live,format=b,file=/tmp/heap.bin 1

# Step 6: Copy heap dump locally
kubectl cp three-tier-app/user-service-xxxxx:/tmp/heap.bin ./heap.bin

# Step 7: Analyze with Eclipse Memory Analyzer
# Download from: https://www.eclipse.org/mat/
# Import heap.bin and analyze memory leaks

# Step 8: Update Helm values with higher memory limits
# helm-charts/user-service/values-prod.yaml
resources:
  limits:
    memory: "1024Mi"  # Increase from 512Mi
  requests:
    memory: "512Mi"   # Increase from 256Mi

# Step 9: Update JVM options to use 80% of container limit
env:
  - name: JAVA_OPTS
    value: "-Xms512m -Xmx768m -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+UnlockDiagnosticVMOptions -XX:G1SummarizeRSetStatsPeriod=1"

# Step 10: Upgrade deployment
./scripts/helm-release-manager.sh upgrade user-service prod

# Step 11: Monitor memory usage
kubectl top pod user-service -n three-tier-app --containers

# Step 12: Check if Pod Disruption Budget needs adjustment
kubectl get pdb -n three-tier-app

# Step 13: Scale node pool if cluster memory exhausted
az aks nodepool scale \
  --resource-group rg-3tier-app \
  --cluster-name aks-cluster \
  --name nodepool1 \
  --node-count 5
```

**Java Application Memory Profiling**:

```bash
# Real-time memory monitoring
kubectl exec -it user-service-xxxxx -n three-tier-app -- /bin/bash

# Inside pod - Monitor memory with jstat
jstat -gc -h5 1 1000  # Garbage collection stats every 1 second

# Monitor memory using jcmd
jcmd 1 VM.memory_managers
jcmd 1 GC.heap_dump /tmp/heap.bin

# Check memory usage
free -h
ps aux | grep java
cat /sys/fs/cgroup/memory/memory.limit_in_bytes

# Monitor with native tools
top
htop
```

**Helm Values for Memory Optimization**:

```yaml
# helm-charts/user-service/values-prod.yaml

# Memory settings
resources:
  limits:
    memory: "1024Mi"
  requests:
    memory: "512Mi"

# JVM configuration
env:
  - name: JAVA_OPTS
    value: |
      -Xms512m
      -Xmx768m
      -XX:+UseG1GC
      -XX:MaxGCPauseMillis=200
      -XX:+ParallelRefProcEnabled
      -XX:+AlwaysPreTouch
      -XX:+UnlockDiagnosticVMOptions
      -XX:G1SummarizeRSetStatsPeriod=1
      -Dcom.sun.management.jmxremote=true
      -Dcom.sun.management.jmxremote.port=9010
      -Dcom.sun.management.jmxremote.authenticate=false
      -Dcom.sun.management.jmxremote.ssl=false

# Pod QoS class settings
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  # Request memory to ensure pod gets reserved memory
```

**Interview Answer**:
> "OOMKilled errors indicate the pod exceeded its memory limit. My troubleshooting process starts with `kubectl top pod` to see current usage and `kubectl describe pod` to confirm OOMKilled status. The solution depends on the root cause: if it's a traffic spike, I increase memory limits and requests in the Helm values. If it's a memory leak, I capture a heap dump using `jmap` and analyze it with Eclipse Memory Analyzer to identify the leak. For Java applications, I tune the JVM with proper Xms/Xmx settings (typically 70-80% of container limit), enable G1GC for better memory management, and monitor with `jstat` for garbage collection patterns. Finally, I ensure the pod requests enough memory so Kubernetes doesn't overcommit memory on nodes."

---

### Issue #2: AKS - "Pod Pending - Insufficient Resources"

**Scenario**: New pod deployment remains in Pending state after 10 minutes, not starting.

**Error Message**:
```
kubectl describe pod user-service-new-xxxxx -n three-tier-app

Events:
  Type     Reason            Age        Message
  ----     ------            ----       -------
  Warning  FailedScheduling  3m         0/3 nodes available: 3 Insufficient cpu
```

**Root Causes**:
1. Node CPU or memory fully allocated
2. Pod resource requests too high
3. Node selector or affinity rules preventing scheduling
4. Pod affinity rules preventing scheduling (anti-affinity)
5. Taints on nodes blocking scheduling
6. No available nodes matching pod requirements

**Solution**:

```bash
# Step 1: Check pod status
kubectl get pod user-service-new-xxxxx -n three-tier-app -o wide

# Step 2: Describe pod to see scheduling events
kubectl describe pod user-service-new-xxxxx -n three-tier-app

# Step 3: Check node resources
kubectl top nodes
kubectl describe nodes

# Step 4: Check specific node details
kubectl describe node <node-name>

# Step 5: Check pod affinity rules
kubectl get pod user-service-xxxxx -n three-tier-app -o yaml | grep -A 10 affinity

# Step 6: Check pod resource requests
kubectl get pod user-service-xxxxx -n three-tier-app -o yaml | grep -A 5 resources

# Step 7: Check node taints
kubectl describe node <node-name> | grep Taints

# Step 8: Scale up node pool
az aks nodepool scale \
  --resource-group rg-3tier-app \
  --cluster-name aks-cluster \
  --name nodepool1 \
  --node-count 5

# Step 9: Check cluster autoscaler status
kubectl logs -n kube-system -l app=cluster-autoscaler -f

# Step 10: Enable or adjust cluster autoscaler
az aks update \
  --resource-group rg-3tier-app \
  --name aks-cluster \
  --enable-cluster-autoscaler \
  --min-count 2 \
  --max-count 10

# Step 11: Reduce pod resource requests if possible
# helm-charts/user-service/values.yaml
resources:
  requests:
    cpu: 100m        # Reduce from 250m
    memory: 128Mi    # Reduce from 256Mi
  limits:
    cpu: 250m
    memory: 256Mi

# Step 12: Check pod disruption budgets that might block eviction
kubectl get pdb -A

# Step 13: Manually evict pods if needed (with caution)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Step 14: Check if enough disk space
df -h
kubectl describe node <node-name> | grep -A 5 "Allocated resources"
```

**Pod Resource Requests Optimization**:

```yaml
# helm-charts/user-service/values.yaml

# Conservative resources for better scheduling
resources:
  requests:
    cpu: 100m        # 0.1 CPU core
    memory: 128Mi    # 128 MB
  limits:
    cpu: 500m        # 0.5 CPU core
    memory: 512Mi    # 512 MB

# Only set anti-affinity to preferred (not required)
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:  # Soft affinity
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app
                operator: In
                values:
                  - user-service
          topologyKey: kubernetes.io/hostname
```

**Check and Fix Node Issues**:

```bash
# List all nodes and their conditions
kubectl get nodes -o wide
kubectl get nodes -o json | jq '.items[].status.conditions'

# Check kubelet service on node
ssh azureuser@<node-ip>
systemctl status kubelet
systemctl restart kubelet

# Check node disk pressure
kubectl describe node <node-name> | grep -i diskpressure

# Clean up old containers to free disk space
ssh azureuser@<node-ip>
docker system prune -a -f

# Force AKS node image update to latest
az aks upgrade \
  --resource-group rg-3tier-app \
  --name aks-cluster \
  --node-image-only

# Check eviction thresholds
ssh azureuser@<node-ip>
ps aux | grep kubelet | grep -i eviction
```

**Interview Answer**:
> "Pending pods indicate a scheduling issue. My first check is to see what's preventing scheduling with `kubectl describe pod` and examine the Events section. Common causes are insufficient CPU/memory on nodes or pod affinity rules that can't be satisfied. My approach: First, check node resources with `kubectl top nodes` to see if there's available capacity. If not, scale the node pool with `az aks nodepool scale`. If there's capacity but pod still doesn't schedule, check affinity rules - I prefer soft anti-affinity (preferred) rather than hard requirements to allow scheduling when necessary. I also verify that requested resources are reasonable and not too high. If cluster autoscaler is enabled, I check its logs to see why it didn't scale. Finally, I ensure no taints are blocking scheduling and no node selector labels are preventing pod placement."

---

### Issue #3: AKS - "Service Endpoint Not Ready - No Backends Available"

**Scenario**: External requests to service fail with 503 Service Unavailable.

**Error Message**:
```
kubectl get endpoints user-service -n three-tier-app
NAME           ENDPOINTS       AGE
user-service   <none>          10m

kubectl get svc user-service -n three-tier-app
NAME           TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
user-service   ClusterIP   10.0.123.456     <none>        8080/TCP   10m
```

**Root Causes**:
1. No pods are running to back the service
2. Readiness probe failing
3. Pod selector labels don't match
4. Service targeting wrong port
5. Network policy blocking traffic

**Solution**:

```bash
# Step 1: Check endpoints
kubectl get endpoints user-service -n three-tier-app
kubectl describe endpoints user-service -n three-tier-app

# Step 2: List pods and their labels
kubectl get pods -n three-tier-app -o wide
kubectl get pods -n three-tier-app --show-labels

# Step 3: Check service selector
kubectl get svc user-service -n three-tier-app -o yaml | grep -A 3 selector

# Step 4: Manual label verification
kubectl get pods -n three-tier-app \
  -l app.kubernetes.io/name=user-service,app.kubernetes.io/instance=user-service

# Step 5: Check pod readiness status
kubectl get pods -n three-tier-app -o wide
kubectl describe pod user-service-xxxxx -n three-tier-app

# Step 6: Check readiness probe status
kubectl logs user-service-xxxxx -n three-tier-app | tail -50

# Step 7: Test readiness probe manually
kubectl exec user-service-xxxxx -n three-tier-app -- \
  curl -v http://localhost:8080/actuator/health/ready

# Step 8: Verify port number in deployment
kubectl get deployment user-service -n three-tier-app -o yaml | grep -A 5 ports

# Step 9: Port forward to test directly
kubectl port-forward service/user-service 8080:8080 -n three-tier-app
curl http://localhost:8080/actuator/health

# Step 10: Check service spec
kubectl get svc user-service -n three-tier-app -o yaml

# Step 11: Fix label mismatch (if detected)
# Option A: Update deployment labels to match service selector
kubectl patch deployment user-service -n three-tier-app \
  -p '{"spec": {"selector": {"matchLabels": {"app":"user-service"}}}}'

# Option B: Update Helm values and redeploy
# helm-charts/user-service/values.yaml
labels:
  app: user-service  # Ensure this matches service selector

./scripts/helm-release-manager.sh upgrade user-service prod

# Step 12: Check network policies
kubectl get networkpolicies -n three-tier-app
kubectl describe networkpolicy default-deny -n three-tier-app

# Step 13: Test connectivity between pods
kubectl run debug-pod --image=busybox --rm -it --restart=Never -- \
  wget -O- http://user-service:8080/actuator/health -n three-tier-app

# Step 14: Check service DNS resolution
kubectl exec debug-pod -n three-tier-app -- nslookup user-service
kubectl exec debug-pod -n three-tier-app -- getent hosts user-service
```

**Verify Service Configuration**:

```yaml
# kubectl get svc user-service -n three-tier-app -o yaml

apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: three-tier-app
  labels:
    app.kubernetes.io/name: user-service
spec:
  type: ClusterIP
  ports:
    - port: 8080
      targetPort: 8080  # Must match container port
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: user-service  # Must match pod labels
    app.kubernetes.io/instance: user-service
```

**Test Service Connectivity**:

```bash
# Create test pod
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never \
  -n three-tier-app -- bash

# Inside test pod
# Test DNS resolution
nslookup user-service
nslookup user-service.three-tier-app
nslookup user-service.three-tier-app.svc
nslookup user-service.three-tier-app.svc.cluster.local

# Test connectivity
curl http://user-service:8080/actuator/health
curl http://user-service.three-tier-app:8080/actuator/health

# Check network policy
iptables-save | grep user-service
```

**Interview Answer**:
> "Service endpoints not ready means there are no healthy pods backing the service. My troubleshooting starts with checking pod status and readiness probes. I verify the pods are running with `kubectl get pods`, then check readiness with `kubectl describe pod` and by manually testing the health endpoint with `curl` inside the pod. If pods exist but aren't in the service endpoints, it's a label mismatch - the service selector must match the pod labels exactly. I also verify the port numbers match between the service port and container port. If pods are absent, I check if they're failing to start, and typically it's a readiness probe failure or pending state. Finally, I verify there are no network policies blocking traffic between the service and pods using `kubectl get networkpolicies`."

---

## Comprehensive Interview Q&A

### Q1: Walk us through your Helm & ArgoCD architecture from code commit to production.

**Answer**:
> "The flow starts when a developer pushes code to the main branch in GitHub. This triggers an Azure DevOps pipeline with 10 stages:
>
> **Stage 1 (Initialize)**: Validate Kubernetes tools, Docker, kubectl versions
> **Stage 2 (Build)**: Maven compiles code, runs unit tests, generates code coverage
> **Stage 3 (CodeQuality)**: SonarQube analyzes code, enforces 80% coverage gate
> **Stage 4 (SecurityScan)**: Snyk scans dependencies, Trivy scans image for vulnerabilities
> **Stage 5 (Tests)**: Integration tests run against test database
> **Stage 6 (BuildContainers)**: Docker multi-stage build with layer caching
> **Stage 7 (PushACR)**: Image pushed to Azure Container Registry with versioning
> **Stage 8 (DeployDev)**: Auto-deploy to dev using Helm, waits for health checks
>
> **For Staging & Production**: Manual approval gates require 2 approvers
>
> After pipeline completes, the key step happens: The pipeline updates the Helm values file with the new image tag and commits back to Git. 
>
> **ArgoCD then takes over**: 
> 1. Webhook notifies ArgoCD of the Git change
> 2. ArgoCD fetches the latest Helm charts
> 3. Renders Kubernetes manifests with the new image tag
> 4. Compares rendered state with current cluster state
> 5. If differences detected and auto-sync enabled, applies changes
> 6. Performs rolling update of pods with health checks
> 7. Monitors sync progress and reports status in UI
>
> The beauty of this approach is that **Git becomes the single source of truth**. If there's any drift between Git and the cluster (like someone manually changing a pod), ArgoCD's self-heal feature automatically reverts it back to match Git. If an issue occurs, we simply revert the Git commit and ArgoCD automatically rolls back the deployment."

**Code Reference**:
```yaml
# This is the key flow - ArgoCD Application watching Git
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: user-service
spec:
  source:
    repoURL: https://github.com/eswar3763/Terraform.git
    path: helm-charts/user-service
    helm:
      valueFiles:
        - values.yaml
        - values-prod.yaml  # Updated by pipeline
  syncPolicy:
    automated:
      prune: true      # Remove resources deleted from Git
      selfHeal: true   # Fix drift automatically
  destination:
    server: https://kubernetes.default.svc
    namespace: three-tier-app
```

---

### Q2: How would you handle a rollback if a production deployment goes wrong?

**Answer**:
> "There are two approaches, each with different speed/safety tradeoffs:
>
> **Approach 1: Git-Based Rollback (Recommended for GitOps)**
> 1. Revert the problematic commit: `git revert <commit-hash>`
> 2. Push the revert: `git push origin main`
> 3. ArgoCD detects the change within seconds (webhook)
> 4. ArgoCD syncs the reverted Helm values
> 5. Kubernetes performs rolling update back to previous image
>
> This approach is **safe** because the revert is tracked in Git history, and you can see exactly what was reverted. It's also **auditable** - you have full Git history of the rollback.
>
> **Approach 2: Helm Rollback (Faster but less traceable)**
> 1. `helm rollback user-service -n three-tier-app`
> 2. Kubernetes immediately reverts to previous release
>
> This is **faster** (under 1 minute vs several minutes for Git) but **less safe** because it bypasses Git, breaking the GitOps principle.
>
> **My recommendation**: For critical production issues requiring immediate rollback under 2 minutes, use Helm rollback but immediately follow up with a Git revert to maintain consistency. For non-critical issues, always use Git-based rollback to maintain GitOps principles.
>
> **Prevention**: I also implement automated rollbacks by:
> 1. Setting up Prometheus alerts on pod crash rates
> 2. Configuring ArgoCD health checks on deployment readiness
> 3. Using canary deployments to test with 5% of traffic first
> 4. Requiring 2 approvers for production deployments"

**Code Example**:
```bash
# Rollback via Git (GitOps way)
git log --oneline -5  # See recent commits
git revert abc123     # Revert the bad commit
git push origin main
# ArgoCD automatically syncs within 10-30 seconds

# Rollback via Helm (emergency only)
helm rollback user-service -n three-tier-app
helm history user-service -n three-tier-app  # Verify

# After Helm rollback, restore Git consistency
git revert <commit-hash>
git push origin main
```

---

### Q3: Describe how you handle multi-environment deployments (dev/staging/prod).

**Answer**:
> "Multi-environment support is built into my architecture using Helm environment-specific values files:
>
> **For Dev**:
> - 1 replica (not HA required)
> - Autoscaling disabled (wasted resources)
> - No ingress (access via port-forward or service)
> - Debug logging enabled
> - Small resource limits (CPU: 250m, memory: 256Mi)
> - Deployment triggers immediately on code push
> - Quick feedback for developers
>
> **For Staging**:
> - 2 replicas (basic HA)
> - Autoscaling enabled (min 2, max 3)
> - Ingress enabled for load testing
> - Info-level logging
> - Medium resource limits (CPU: 500m, memory: 512Mi)
> - Manual approval required (1 approver)
> - Full integration testing
>
> **For Production**:
> - 3+ replicas (full HA)
> - Autoscaling enabled (min 3, max 10)
> - Ingress via Azure Application Gateway
> - Warn-level logging only
> - High resource limits (CPU: 1000m, memory: 1024Mi)
> - Dual approval required (DevOps + Product)
> - Canary deployment with 5% traffic first
> - Health checks and automatic rollback
>
> Each environment has its own Helm values file which overrides the base values.yaml:
> - values.yaml (base defaults)
> - values-dev.yaml (dev overrides)
> - values-staging.yaml (staging overrides)
> - values-prod.yaml (prod overrides)
>
> The ArgoCD Application references multiple valueFiles in precedence order - later files override earlier ones."

**Code Example**:
```yaml
# helm-charts/user-service/values.yaml (base)
replicaCount: 2
resources:
  limits:
    memory: 512Mi

---
# helm-charts/user-service/values-prod.yaml (production overrides)
replicaCount: 5
resources:
  limits:
    memory: 1024Mi
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10

---
# ArgoCD Application references both files
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: user-service-prod
spec:
  source:
    helm:
      valueFiles:
        - values.yaml        # Loaded first
        - values-prod.yaml   # Overrides base values
```

---

### Q4: How do you ensure security in your CI/CD pipeline?

**Answer**:
> "Security is integrated at multiple layers:
>
> **1. Code Security (Stage 3)**:
> - SonarQube scans for code vulnerabilities
> - Quality gate blocks deployment if coverage < 80%
> - OWASP dependency check for known vulnerabilities
>
> **2. Container Security (Stage 4)**:
> - Snyk scans dependency tree for vulnerabilities
> - Trivy scans built image for OS vulnerabilities
> - Fail on Critical or High severity issues
> - Sign container images (optional)
>
> **3. Access Control**:
> - ArgoCD AppProject with RBAC roles
> - Developers can only view their projects
> - Only admins can deploy to production
> - CI/CD service principal has minimal permissions
>
> **4. Secrets Management**:
> - No secrets in code or docker images
> - All secrets stored in Azure Key Vault
> - Helm SecretProviderClass fetches secrets at runtime
> - Service principal tokens rotated regularly
>
> **5. Pod Security**:
> - Run as non-root user (uid: 1000)
> - Read-only root filesystem
> - Drop ALL Linux capabilities
> - Pod Security Policy enforces baseline
>
> **6. Network Security**:
> - Network policies with deny-all-default
> - Explicit allow rules only for required traffic
> - TLS encryption in transit (HTTPS)
> - Azure Application Gateway with WAF rules
>
> **7. Audit Logging**:
> - AKS audit logs capture all API calls
> - Azure Monitor logs all deployments
> - Git commits tracked with timestamps
> - ArgoCD logs sync operations"

**Code Example**:
```yaml
# Pod security in Helm chart
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
      containers:
        - securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL

---
# Network policy with deny-all-default
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress

---
# Explicit allow rule for user-service to talk to database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-user-to-postgres
spec:
  podSelector:
    matchLabels:
      app: user-service
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: postgres
      ports:
        - protocol: TCP
          port: 5432
```

---

### Q5: How do you debug issues when ArgoCD sync fails?

**Answer**:
> "Failed syncs can happen for multiple reasons. My debugging approach is systematic:
>
> **Step 1: Check ArgoCD Application Status**
> ```bash
> argocd app get user-service
> # Shows: Sync Status, Health Status, Last Sync Result
> # Also shows which resources succeeded/failed
> ```
>
> **Step 2: Check ArgoCD Server Logs**
> ```bash
> kubectl logs -n argocd deploy/argocd-server -f
> # Look for errors in API server
> ```
>
> **Step 3: Check ArgoCD Repo Server Logs**
> ```bash
> kubectl logs -n argocd deploy/argocd-repo-server -f
> # This renders Helm templates - errors here mean template issues
> ```
>
> **Step 4: Check ArgoCD Controller Logs**
> ```bash
> kubectl logs -n argocd deploy/argocd-application-controller -f
> # This syncs to cluster - errors mean kubectl apply failed
> ```
>
> **Step 5: Manually Test Helm Template Rendering**
> ```bash
> helm template user-service helm-charts/user-service \\
>   -f helm-charts/user-service/values-prod.yaml \\
>   --debug
> # If this fails, Helm syntax is wrong
> ```
>
> **Step 6: Check Kubernetes Events**
> ```bash
> kubectl get events -n three-tier-app --sort-by='.lastTimestamp'
> # Shows deployment failures, pod errors, etc.
> ```
>
> **Step 7: Check Pod Status**
> ```bash
> kubectl get pods -n three-tier-app
> kubectl describe pod user-service-xxxxx
> # Shows if containers failed to start
> ```
>
> **Step 8: Manual Kubectl Apply for Diagnosis**
> ```bash
> helm template user-service ... > manifests.yaml
> kubectl apply -f manifests.yaml --dry-run=server
> # This simulates the actual apply to catch validation errors
> ```
>
> **Common Failure Reasons and Fixes**:
> 1. **Invalid YAML**: Check template syntax with `helm template --debug`
> 2. **ImagePullBackOff**: Verify image exists in ACR with `az acr repository show`
> 3. **CrashLoopBackOff**: Check pod logs with `kubectl logs`
> 4. **Insufficient Resources**: Check node availability with `kubectl top nodes`
> 5. **RBAC Errors**: Verify service account permissions
> 6. **Network Policy Blocking**: Check network policies with `kubectl get networkpolicies`"

---

### Q6: Explain how you would scale the application during peak traffic.

**Answer**:
> "Scaling happens at multiple levels - application, pod, and infrastructure:
>
> **Level 1: Horizontal Pod Autoscaling (HPA)**
> - Monitored by metrics-server (CPU/memory)
> - Scales pods based on configured thresholds
> - Default: Scale up when CPU > 70% or memory > 80%
> - Max replicas: 10 (configured in Helm values)
> - Scaling up: Takes 30-60 seconds
> - Scaling down: Takes 5+ minutes (conservative)
>
> **Level 2: Cluster Autoscaling**
> - If HPA wants to scale but no node capacity exists
> - Cluster autoscaler adds new nodes automatically
> - Watches for pending pods
> - Takes 2-5 minutes to bring new nodes online
>
> **Level 3: Database Connection Pooling**
> - HikariCP manages 20-30 connections per pod
> - PgBouncer multiplexes connections at protocol level
> - Prevents connection pool exhaustion
>
> **Monitoring During Scale Events**:
> ```bash
> # Watch HPA status in real-time
> kubectl get hpa user-service -n three-tier-app -w
>
> # Watch pod scaling
> kubectl get pods -n three-tier-app -w
>
> # Monitor metrics
> kubectl top pods -n three-tier-app --containers
> kubectl top nodes
>
> # Check load balancer
> kubectl get ingress -n three-tier-app -o wide
> ```
>
> **Peak Load Simulation**:
> ```bash
> # Generate synthetic load
> kubectl run -it --rm load-generator --image=nicolaka/netshoot \\
>   -- bash
> # Inside pod
> while true; do \
>   curl http://user-service:8080/api/users; \
> done
> ```
>
> My Helm values for production are tuned for this:
> - `autoscaling.enabled: true`
> - `minReplicas: 3` (always have minimum 3)
> - `maxReplicas: 10` (scale up to 10 if needed)
> - `targetCPUUtilizationPercentage: 60%` (aggressive scaling up)
> - Pod requests/limits ensure QoS class Guaranteed (never evicted)"

**Helm Configuration**:
```yaml
autoscaling:
  enabled: true
  minReplicas: 3      # Always run 3
  maxReplicas: 10     # Max scale to 10
  targetCPUUtilizationPercentage: 60      # Scale at 60%
  targetMemoryUtilizationPercentage: 75   # Scale at 75%

resources:
  requests:
    cpu: 250m       # Guaranteed this much
    memory: 256Mi
  limits:
    cpu: 500m       # Hard limit
    memory: 512Mi
```

---

### Q7: How would you implement blue-green deployment?

**Answer**:
> "Blue-green deployment allows zero-downtime deployments by running two complete environments. Here's my approach:
>
> **Setup**:
> - Blue: Current production environment (v1.0.0)
> - Green: New version being prepared (v1.1.0)
> - Load Balancer: Routes all traffic to Blue initially
>
> **Deployment Process**:
> 1. Deploy new version to Green environment
> 2. Run automated tests against Green
> 3. Perform smoke tests and integration tests
> 4. Switch load balancer traffic to Green
> 5. Monitor Green for issues
> 6. If OK, keep Green as new production
> 7. Blue becomes standby for rollback
>
> **Implementation with ArgoCD**:
> ```bash
> # Two separate Helm releases
> argocd app create user-service-blue \\
>   --repo https://github.com/eswar3763/Terraform.git \\
>   --path helm-charts/user-service \\
>   --values-file values-blue.yaml \\
>   --dest-name user-service-blue
>
> argocd app create user-service-green \\
>   --repo https://github.com/eswar3763/Terraform.git \\
>   --path helm-charts/user-service \\
>   --values-file values-green.yaml \\
>   --dest-name user-service-green
> ```
>
> **Azure Load Balancer Switch**:
> ```bash
> # Update backend pool to point to Green
> az network lb rule update \\
>   --resource-group rg-3tier-app \\
>   --lb-name app-gateway \\
>   --name prod-rule \\
>   --backend-pool-name green-backend-pool
> ```
>
> **Advantages**:
> - Zero-downtime deployment
> - Instant rollback (switch back to Blue)
> - Full environment testing before traffic switch
> - No gradual rollout complexity
>
> **Disadvantages**:
> - Requires 2x infrastructure cost during transition
> - Database migration complexity (coordinating schema changes)
> - More complex monitoring (track both Blue and Green)"

---

### Q8: What's your approach to monitoring and alerting?

**Answer**:
> "Monitoring is multi-layered, covering infrastructure, platform, and application:
>
> **Layer 1: Infrastructure Monitoring (Azure Monitor)**
> - CPU utilization per node
> - Memory pressure
> - Disk space (alert when <10% free)
> - Network throughput
> - Node restart frequency
>
> **Layer 2: Kubernetes Monitoring (Prometheus)**
> - Pod CPU and memory usage
> - Pod restart count
> - Deployment replica status (desired vs actual)
> - Pod readiness and liveness probe results
> - Network bytes in/out per pod
>
> **Layer 3: Application Monitoring (Application Insights)**
> - Request latency (p50, p95, p99)
> - Error rate and types
> - Database query performance
> - JVM metrics (heap, garbage collection)
> - Custom business metrics
>
> **Layer 4: ArgoCD Monitoring**
> - Application sync status (in sync vs out of sync)
> - Sync duration
> - Failed syncs (alert immediately)
> - Drift detection
>
> **Critical Alerts I've Configured**:
> 1. Pod CrashLoopBackOff - Alert in < 1 minute
> 2. ImagePullBackOff - Alert in < 2 minutes
> 3. Node NotReady - Alert immediately
> 4. Disk pressure > 85% - Alert and autoscale
> 5. Memory pressure building - Alert to scale before OOMKill
> 6. ArgoCD sync failed - Alert for investigation
> 7. High error rate (>1%) - Alert and page on-call
> 8. Database connection pool exhaustion - Alert before hitting limit
>
> **Notification Channels**:
> - Slack for non-critical alerts (monitoring dashboard)
> - PagerDuty for critical production alerts (immediate page)
> - Email for daily health summary reports
>
> **Dashboards Created**:
> - **Cluster Health**: Nodes, pods, resource usage
> - **Application Performance**: Latency, errors, throughput
> - **Database**: Connections, slow queries, replication lag
> - **Deployment Status**: ArgoCD sync status, image versions
> - **Business Metrics**: User logins, orders processed, payment success rate"

---

## Troubleshooting Guide

### Quick Troubleshooting Reference

```
ISSUE → DIAGNOSIS COMMAND → SOLUTION
────────────────────────────────────────────────────────────────

Pod CrashLoopBackOff
  kubectl logs <pod> → Check logs for errors
  kubectl describe pod <pod> → See exit reason
  → Fix application bug, increase memory, or adjust resource limits

Pod ImagePullBackOff
  kubectl describe pod <pod> → Check image pull error
  az acr repository show --image <image> → Verify image exists
  → Create imagePullSecret or push image to ACR

Pod Pending
  kubectl describe pod <pod> → Check scheduling events
  kubectl top nodes → Check node resources
  → Scale node pool or reduce pod resource requests

Service No Endpoints
  kubectl get endpoints <service> → Should have IPs
  kubectl get pods -l <selector> → Check if pods exist
  → Fix pod selector labels or create pods

ArgoCD Sync Failed
  argocd app get <app> → Check sync status
  kubectl logs -n argocd deploy/argocd-repo-server → Check template rendering
  helm template <chart> → Test Helm template locally
  → Fix Helm template syntax or values

Database Connection Error
  psql -h <host> -U <user> → Test connectivity
  SELECT count(*) FROM pg_stat_activity; → Check connections
  → Increase connection pool or kill idle connections

Azure Pipeline Timeout
  Check build logs → Identify slow step
  Add caching (Maven dependencies, Docker layers)
  → Increase timeout or optimize build

Node NotReady
  kubectl describe node <node> → Check conditions
  ssh azureuser@<node-ip> && systemctl status kubelet
  → Restart kubelet or update node image
```

---

## Production Scenarios

### Scenario 1: Handling a Database Failover

**Situation**: Primary PostgreSQL node fails, replica should auto-promote.

**Steps**:
```bash
# 1. Verify primary is down
psql -h postgres-prod.database.azure.com -U postgres -d three_tier_prod -c "SELECT version();"
# Connection refused

# 2. Check Azure Portal - confirm failover started
az postgres flexible-server replica list --resource-group rg-3tier-app

# 3. Monitor failover progress (typically 2-5 minutes)
watch "psql -h postgres-prod.database.azure.com -U postgres -d three_tier_prod -c 'SELECT version();'"

# 4. Once replica promoted, verify it's writable
psql -h postgres-prod.database.azure.com -U postgres -d three_tier_prod \
  -c "CREATE TABLE test_failover (id INT); DROP TABLE test_failover;"

# 5. Verify pods can reconnect
kubectl logs -n three-tier-app -l app=user-service --tail=100 | grep -i connection

# 6. If pods still failing, restart them to clear connection pool
kubectl rollout restart deployment/user-service -n three-tier-app

# 7. Verify all pods are ready
kubectl get pods -n three-tier-app -o wide

# 8. Run smoke tests to verify application works
./scripts/helm-argocd-integration.sh test

# 9. Once stable, create new replica for HA
az postgres flexible-server replica create \
  --resource-group rg-3tier-app \
  --master-name postgres-prod \
  --name postgres-prod-replica-2 \
  --location eastus2
```

### Scenario 2: Emergency Hotfix Deployment

**Situation**: Critical security vulnerability found, need production fix in 15 minutes.

**Process**:
```bash
# 1. Bypass normal approval process (use emergency access)
# Create fast-track approval policy in Azure DevOps for critical security

# 2. Fix code in feature branch
git checkout -b hotfix/security-patch-$(date +%s)
# ... make code changes ...

# 3. Commit and push (shorter commit message, includes CVE number)
git commit -m "HOTFIX: CVE-2024-12345 - SQL injection in user API"
git push origin hotfix/security-patch-xxxxx

# 4. Create pull request with "HOTFIX" label
# Azure DevOps should auto-merge after passing security gates

# 5. Monitor pipeline progress
argocd app watch user-service

# 6. Verify fix in production
curl https://prod-api.example.com/api/health

# 7. Notify security team of deployment
# Include CVE number, fix details, and verification steps

# 8. Create post-incident report
# Schedule retrospective for next day
```

---

**This comprehensive guide covers real production scenarios, common issues, and interview preparation. Use this during interviews to demonstrate deep Kubernetes, DevOps, and cloud platform expertise!**
