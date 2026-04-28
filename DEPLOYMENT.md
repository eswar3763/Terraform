# Terraform 3-Tier Architecture - Azure Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying a production-grade 3-tier architecture on Azure using Terraform, AKS, MySQL, Function Apps, and App Services.

### Architecture Components

```
┌─────────────────────────────────────────────────────────────┐
│                     Azure Cloud                              │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  AKS Kubernetes Cluster                              │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │                                                       │   │
│  │  ┌─────────────────┐  ┌──────────────────────────┐  │   │
│  │  │ React Frontend  │  │  Spring Boot Services    │  │   │
│  │  │  (NGINX + SPA)  │  │  - User Service (8081)   │  │   │
│  │  │                 │  │  - Order Service (8082)  │  │   │
│  │  │ 3 replicas      │  │  - Payment Service(8083) │  │   │
│  │  └────────┬────────┘  │  3+ replicas each        │  │   │
│  │           │           │  HPA enabled             │  │   │
│  │           │           └──────────────────────────┘  │   │
│  │           │                    ▲                     │   │
│  │           └────────────────────┘                     │   │
│  │                NGINX Ingress                         │   │
│  └──────────────────────────────────────────────────────┘   │
│           ▲                                                   │
│           │ Ingress IP / DNS                                │
│           │                                                   │
│  ┌────────┴────────────────────────────────────────────┐    │
│  │  App Service (Lightweight APIs)                     │    │
│  │  - Premium (P1v2) tier                              │    │
│  │  - Auto-scaling enabled                             │    │
│  └─────────────────────────────────────────────────────┘    │
│           │                                                   │
│  ┌────────┴────────────────────────────────────────────┐    │
│  │  MySQL Database                                     │    │
│  │  - Flexible Server                                  │    │
│  │  - Memory-optimized (prod)                          │    │
│  │  - 30-day backup retention (prod)                   │    │
│  │  - Geo-redundant backups (prod)                     │    │
│  └─────────────────────────────────────────────────────┘    │
│           │                                                   │
│  ┌────────┴────────────────────────────────────────────┐    │
│  │  Storage Account (Queues & Blobs)                  │    │
│  │  - Queue for async processing                       │    │
│  │  - Blob container for uploads (images, files)       │    │
│  │  - RAGRS replication (prod)                         │    │
│  └─────────────────────────────────────────────────────┘    │
│           │                                                   │
│  ┌────────┴────────────────────────────────────────────┐    │
│  │  Function Apps                                      │    │
│  │  - Queue-triggered (order processing)               │    │
│  │  - Blob-triggered (image processing)                │    │
│  │  - Timer-triggered (cleanup jobs)                   │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Key Vault (Secrets Management)                      │   │
│  │  - Database passwords                               │   │
│  │  - API keys and credentials                         │   │
│  │  - TLS certificates                                 │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Container Registry (ACR)                            │   │
│  │  - Store Docker images for microservices            │   │
│  │  - Store React frontend images                      │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### Local Environment Setup

1. **Install Required Tools:**
   ```bash
   # macOS (using Homebrew)
   brew install terraform azure-cli kubectl docker
   
   # Or download from:
   # - Terraform: https://www.terraform.io/downloads
   # - Azure CLI: https://docs.microsoft.com/cli/azure/install-azure-cli
   # - kubectl: https://kubernetes.io/docs/tasks/tools/
   # - Docker: https://www.docker.com/products/docker-desktop
   ```

2. **Azure Account Setup:**
   - Create an Azure subscription: https://azure.microsoft.com/en-us/free/
   - Create a Service Principal for Terraform automation:
     ```bash
     az login
     az account list --output table
     az account set --subscription "SUBSCRIPTION_ID"
     
     # Create service principal
     az ad sp create-for-rbac --role="Contributor" \
       --scopes="/subscriptions/SUBSCRIPTION_ID" \
       --name="terraform-sp"
     ```
   - Save the output (client_id, client_secret, subscription_id, tenant_id)

3. **Docker Hub / ACR Account:**
   - Create Azure Container Registry or use Docker Hub for pushing images
   - Save credentials for use in Terraform

4. **Git Repository:**
   ```bash
   cd /path/to/Terraform
   git init
   git remote add origin <your-repo-url>
   ```

---

## Phase 1: Terraform Infrastructure Deployment

### Step 1: Configure Azure Provider (Global)

**File:** `global/providers.tf`

This is already configured. Verify it contains:
```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}
```

### Step 2: Prepare Environment Variables

**For Development:**

1. Copy example variables:
   ```bash
   cd environments/dev
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your actual values:
   ```hcl
   subscription_id = "your-subscription-id"
   client_id       = "your-client-id"
   client_secret   = "your-client-secret"
   tenant_id       = "your-tenant-id"
   
   # Ensure unique names globally
   keyvault_name        = "kvunique1234"
   acr_name            = "acrunique1234"
   storage_account_name = "stunique1234"
   
   # Set MySQL password with strong credentials
   mysql_admin_password = "P@ssw0rd123456789"
   ```

3. **Important:** Add `terraform.tfvars` to `.gitignore`:
   ```bash
   echo "terraform.tfvars" >> ../../.gitignore
   ```

### Step 3: Initialize Terraform

**Initialize the dev environment:**

```bash
cd environments/dev

# Download providers and initialize backend
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive ../../
```

**Expected output:**
```
Terraform has been successfully configured!
```

### Step 4: Plan Infrastructure Deployment

```bash
# Create a plan file
terraform plan -out=tfplan

# Review the output - should show:
# - 1 resource group
# - 1 virtual network + 1 subnet
# - 1 AKS cluster (1 node for dev)
# - 1 MySQL server + database
# - 1 Storage account with queue & blob
# - 1 Function App
# - 1 App Service
# - 1 Key Vault
# - 1 ACR
# - Network policies and RBAC assignments
```

### Step 5: Deploy Infrastructure

```bash
# Apply Terraform configuration
terraform apply tfplan

# Wait 15-20 minutes for AKS cluster to be fully deployed
# Monitor progress in Azure Portal: Resource Groups → rg-3tier-app-dev
```

### Step 6: Retrieve Outputs

```bash
# Get all outputs (connection strings, URLs, etc.)
terraform output

# Store key values (you'll need these for Kubernetes deployments):
export MYSQL_FQDN=$(terraform output -raw mysql_server_fqdn)
export ACR_SERVER=$(terraform output -raw acr_login_server)
export AKS_CLUSTER_NAME=$(terraform output -raw aks_cluster_name)
export STORAGE_CONNECTION=$(terraform output -raw storage_connection_string)
```

---

## Phase 2: AKS Cluster Access & Kubernetes Setup

### Step 1: Configure kubectl Access

```bash
# Get AKS cluster credentials
az aks get-credentials \
  --resource-group rg-3tier-app-dev \
  --name aks-3tier-dev \
  --overwrite-existing

# Verify cluster access
kubectl cluster-info
kubectl get nodes
```

**Expected output:**
```
NAME                       STATUS   ROLES   AGE   VERSION
aks-nodepool1-12345-0      Ready    agent   5m    v1.27.x
```

### Step 2: Install NGINX Ingress Controller

```bash
# Add Helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX ingress controller
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --wait

# Get Ingress IP
kubectl get service -n ingress-nginx
# Note the EXTERNAL-IP of nginx-ingress-ingress-nginx-controller
```

### Step 3: Create Kubernetes Namespace & ConfigMaps

```bash
# Apply namespace, ConfigMaps, and Secrets
kubectl apply -f examples/3-tier-architecture/namespace-and-config.yaml

# Verify
kubectl get namespace three-tier-app
kubectl get configmap -n three-tier-app
kubectl get secret -n three-tier-app
```

### Step 4: Update ConfigMaps with Terraform Outputs

```bash
# Update the ConfigMap with real values from Terraform
kubectl set env configmap/app-config \
  -n three-tier-app \
  MYSQL_HOST=$MYSQL_FQDN \
  ACR_LOGIN_SERVER=$ACR_SERVER

# Verify
kubectl get configmap app-config -n three-tier-app -o yaml
```

### Step 5: Create Docker Registry Secret (for ACR)

```bash
# Get ACR credentials from Terraform output
ACR_LOGIN_USER=$(terraform output -raw acr_admin_username)
ACR_LOGIN_PASSWORD=$(terraform output -raw acr_admin_password)
ACR_SERVER=$(terraform output -raw acr_login_server)

# Create Kubernetes secret for ACR
kubectl create secret docker-registry acr-secret \
  --docker-server=$ACR_SERVER \
  --docker-username=$ACR_LOGIN_USER \
  --docker-password=$ACR_LOGIN_PASSWORD \
  -n three-tier-app

# Verify
kubectl get secret acr-secret -n three-tier-app
```

---

## Phase 3: Build & Push Docker Images

### Step 1: Build Spring Boot Microservices

**Example for User Service:**

```bash
# Navigate to your Spring Boot project
cd /path/to/user-service

# Build Docker image
docker build -t ${ACR_SERVER}/user-service:v1.0 -f Dockerfile .

# Push to ACR
docker login -u $ACR_LOGIN_USER -p $ACR_LOGIN_PASSWORD $ACR_SERVER
docker push ${ACR_SERVER}/user-service:v1.0

# Repeat for order-service and payment-service
```

**Spring Boot Dockerfile example:**
```dockerfile
# Build stage
FROM maven:3.8.1-openjdk-16-slim as builder
WORKDIR /app
COPY . .
RUN mvn clean package -DskipTests

# Runtime stage
FROM openjdk:16-jdk-slim
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### Step 2: Build React Frontend

```bash
cd /path/to/react-app

# Build using Dockerfile.react
docker build -t ${ACR_SERVER}/react-frontend:v1.0 \
  -f Dockerfile.react .

# Push to ACR
docker push ${ACR_SERVER}/react-frontend:v1.0
```

---

## Phase 4: Deploy Kubernetes Applications

### Step 1: Deploy Spring Boot Services

```bash
# Deploy microservices
kubectl apply -f examples/3-tier-architecture/spring-boot-services.yaml

# Monitor deployment
kubectl get pods -n three-tier-app -w
kubectl get svc -n three-tier-app

# Check logs
kubectl logs -n three-tier-app -l app=user-service --tail=50 -f
```

**Expected output:**
```
NAME                              READY   STATUS    RESTARTS   AGE
user-service-xxxxxxxxxx-xxxxx     1/1     Running   0          2m
order-service-xxxxxxxxxx-xxxxx    1/1     Running   0          1m
payment-service-xxxxxxxxxx-xxxxx  1/1     Running   0          1m
```

### Step 2: Deploy React Frontend

```bash
# Deploy React frontend
kubectl apply -f examples/3-tier-architecture/react-frontend.yaml

# Monitor
kubectl get pods -n three-tier-app -l app=react-frontend
kubectl get ingress -n three-tier-app
```

### Step 3: Test Kubernetes Connectivity

```bash
# Port forward to user service
kubectl port-forward -n three-tier-app svc/user-service 8081:8081 &

# Test API endpoint
curl http://localhost:8081/actuator/health

# Port forward to React frontend
kubectl port-forward -n three-tier-app svc/react-frontend 3000:80 &

# Open in browser
open http://localhost:3000
```

---

## Phase 5: Deploy Function Apps

### Step 1: Prepare Function App Code

Copy the Function App examples to your function project:
- `examples/3-tier-architecture/function-app-queue-trigger.ts`
- `examples/3-tier-architecture/function-app-blob-trigger.ts`

### Step 2: Install Dependencies

```bash
# In your Function App project
npm install
npm install @azure/functions
npm install @azure/storage-blob
npm install sharp
npm install mysql2
```

### Step 3: Deploy Function App

```bash
# Build
npm run build

# Deploy (requires Azure Functions CLI or VS Code extension)
func azure functionapp publish func-3tier-dev

# Or via Azure CLI
az functionapp deployment source config-zip \
  -g rg-3tier-app-dev \
  -n func-3tier-dev \
  --src-url https://your-deployment-zip-url
```

### Step 4: Configure Function App Settings

```bash
# Set environment variables
az functionapp config appsettings set \
  -n func-3tier-dev \
  -g rg-3tier-app-dev \
  --settings \
  MYSQL_HOST=$MYSQL_FQDN \
  MYSQL_DATABASE="appdb" \
  MYSQL_USER="azureuser" \
  "MYSQL_PASSWORD=YourPassword" \
  "API_KEY=your-api-key" \
  FUNCTIONS_WORKER_RUNTIME=node
```

### Step 5: Test Function Triggers

```bash
# Send test message to queue
az storage message put \
  --queue-name function-queue \
  --text '{"orderId": "12345", "userId": "67890", "amount": 99.99}' \
  --account-name st3tierappdev \
  --account-key <storage-key>

# Monitor function execution
az functionapp log tail -n func-3tier-dev -g rg-3tier-app-dev

# Or in Azure Portal: Function App → Monitor or Log Stream
```

---

## Phase 6: Staging & Production Deployment

### Deploy to Staging

```bash
cd environments/staging
cp ../dev/terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with staging values

terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Repeat Kubernetes deployment steps with staging cluster
```

### Deploy to Production

```bash
cd environments/prod
cp ../dev/terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with production values
# NOTE: Enable monitoring, set up API server authorized IPs

terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Repeat Kubernetes deployment steps with production cluster
```

**Production-specific steps:**
```bash
# 1. Configure Application Insights for monitoring
az monitor app-insights component create \
  -g rg-3tier-app-prod \
  -a app-insights-prod

# 2. Set up Log Analytics if not already done
az monitor log-analytics workspace create \
  -g rg-3tier-app-prod \
  -n logs-3tier-prod

# 3. Configure Azure DevOps or GitHub Actions for CI/CD
# 4. Set up backup/disaster recovery policies
# 5. Configure custom domain and SSL certificates
# 6. Enable Azure Firewall or DDoS protection (optional)
```

---

## Monitoring & Troubleshooting

### View Kubernetes Logs

```bash
# All pods in namespace
kubectl get pods -n three-tier-app

# Describe a pod (useful for debugging)
kubectl describe pod user-service-xxx -n three-tier-app

# View pod logs
kubectl logs -n three-tier-app pod/user-service-xxx --tail=100

# Stream logs
kubectl logs -f -n three-tier-app -l app=user-service
```

### Monitor AKS Cluster

```bash
# Check node health
kubectl get nodes
kubectl describe node <node-name>

# Check resource usage
kubectl top nodes
kubectl top pods -n three-tier-app

# Check events
kubectl get events -n three-tier-app --sort-by='.lastTimestamp'
```

### MySQL Database Connectivity

```bash
# From a pod in AKS, test connectivity
kubectl run -it --rm debug --image=mysql:8.0 \
  --restart=Never \
  -n three-tier-app \
  -- mysql -h $MYSQL_FQDN -u azureuser -p appdb

# Run a test query
SELECT VERSION();
```

### Function App Logs

```bash
# View function execution logs
az functionapp log tail -n func-3tier-dev -g rg-3tier-app-dev --provider Trace

# Query Application Insights (if configured)
az monitor app-insights query \
  --app app-insights-prod \
  --analytics-query "traces | limit 100"
```

---

## Cleanup & Tear Down

### Delete All Resources (if needed)

```bash
# WARNING: This will delete all resources!

# Delete Kubernetes resources first
kubectl delete namespace three-tier-app
kubectl delete namespace ingress-nginx

# Delete Terraform-managed infrastructure
cd environments/prod
terraform destroy

# Answer 'yes' to confirm deletion
# This will take 15-20 minutes for AKS to be fully deleted
```

---

## Best Practices & Tips

1. **Secrets Management:**
   - Never commit `terraform.tfvars` with real credentials
   - Use Azure Key Vault for sensitive data
   - Use external-secrets operator in Kubernetes

2. **Monitoring:**
   - Enable Application Insights for application telemetry
   - Set up Log Analytics for centralized logging
   - Configure alerts for CPU, memory, and error rates

3. **Backup & Disaster Recovery:**
   - Enable automated backups for MySQL (default: 7-30 days)
   - Implement regular disaster recovery drills
   - Use geo-redundant storage for critical data

4. **Security:**
   - Use network policies to restrict pod communication
   - Enable Azure Firewall for network security
   - Run security scans on container images (Trivy, Aqua)
   - Use managed identities instead of connection strings

5. **Cost Optimization:**
   - Use spot instances for non-critical workloads
   - Right-size VM SKUs based on actual usage
   - Use reserved instances for predictable workloads
   - Monitor costs regularly in Azure Cost Management

6. **CI/CD Pipeline:**
   - Automate image builds and pushes to ACR
   - Use GitOps (ArgoCD, Flux) for Kubernetes deployments
   - Implement automated testing before production deployments

---

## Support & Documentation

- **Terraform Azure Provider:** https://registry.terraform.io/providers/hashicorp/azurerm/latest
- **AKS Documentation:** https://learn.microsoft.com/en-us/azure/aks/
- **Azure MySQL:** https://learn.microsoft.com/en-us/azure/mysql/flexible-server/
- **Azure Functions:** https://learn.microsoft.com/en-us/azure/azure-functions/
- **Kubernetes Documentation:** https://kubernetes.io/docs/

---

## Quick Reference Commands

```bash
# Terraform
terraform init              # Initialize workspace
terraform validate          # Validate syntax
terraform plan             # Preview changes
terraform apply            # Deploy infrastructure
terraform destroy          # Delete infrastructure
terraform output           # View outputs
terraform state list       # List managed resources

# kubectl
kubectl get pods           # List pods
kubectl describe pod <name> # Get detailed info
kubectl logs <pod>        # View pod logs
kubectl apply -f file.yaml # Deploy manifest
kubectl delete pod <name>  # Delete pod
kubectl port-forward       # Forward port to local
kubectl exec -it <pod> /bin/bash  # Enter pod shell

# Azure CLI
az aks get-credentials     # Get AKS credentials
az acr login              # Login to ACR
az functionapp log tail   # View function logs
az mysql server show      # Show MySQL server info
```

---

**Last Updated:** April 24, 2026
**Version:** 1.0
**Maintainer:** Your Team
