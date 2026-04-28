# Complete Azure AKS Deployment Guide
## Maven Microservices - 3-Tier Architecture
### Setup for Dev, Staging, and Production Environments

**Last Updated:** April 25, 2026  
**Version:** 1.0  
**Duration:** ~2-3 hours for complete setup

---

## Table of Contents

1. [Prerequisites & Azure Account Setup](#prerequisites)
2. [Phase 1: Local Development Setup](#phase-1-local-development)
3. [Phase 2: Azure Infrastructure Setup](#phase-2-azure-infrastructure)
4. [Phase 3: Build & Push Docker Images](#phase-3-docker-images)
5. [Phase 4: Deploy with Terraform](#phase-4-terraform-deployment)
6. [Phase 5: Configure AKS & Kubernetes](#phase-5-kubernetes-setup)
7. [Phase 6: Deploy Applications](#phase-6-application-deployment)
8. [Phase 7: Environment-Specific Setup](#phase-7-environment-setup)
9. [Verification & Testing](#verification)
10. [Cleanup & Troubleshooting](#cleanup)

---

## Prerequisites

### Hardware Requirements
- 8GB RAM minimum
- 10GB disk space
- Stable internet connection

### Software Requirements
- macOS 10.15+ or Linux/Windows with WSL2
- Git
- Docker Desktop
- VS Code (recommended)

### Azure Requirements
- Azure subscription (free tier eligible)
- Service Principal with Contributor role
- Storage account for Terraform state (recommended)

---

## PHASE 1: LOCAL DEVELOPMENT SETUP

### Step 1.1: Install Required Tools

#### On macOS (using Homebrew):

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install terraform azure-cli kubectl docker git maven

# Verify installations
terraform -version      # Expected: Terraform v1.x.x
az --version           # Expected: azure-cli 2.50.x
kubectl version        # Expected: Client Version x.y.z
docker --version       # Expected: Docker version xx.x.x
mvn -version          # Expected: Apache Maven 3.8.x
```

#### On Linux (Ubuntu/Debian):

```bash
# Update package manager
sudo apt update

# Install tools
sudo apt install -y curl git maven

# Install Terraform
wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
unzip terraform_1.5.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify installations
terraform -version && az --version && kubectl version --client && docker --version && mvn -version
```

#### On Windows (with WSL2):

```powershell
# Using Chocolatey (install from https://chocolatey.org/install if needed)
choco install terraform azure-cli kubernetes-cli docker-desktop maven git -y

# Or download from official websites
# Terraform: https://www.terraform.io/downloads
# Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
# kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/
# Docker: https://www.docker.com/products/docker-desktop
# Maven: https://maven.apache.org/download.cgi
```

### Step 1.2: Clone or Navigate to Project

```bash
# Navigate to Terraform project directory
cd /Users/chetan/Terraform

# Verify project structure
ls -la
# Expected output:
# drwxr-xr-x  global/
# drwxr-xr-x  modules/
# drwxr-xr-x  environments/
# drwxr-xr-x  examples/
# -rw-r--r--  README.md
# -rw-r--r--  DEPLOYMENT.md
```

### Step 1.3: Test Maven Project Locally

```bash
# Navigate to Maven services
cd examples/maven-services

# Option A: Using Docker Compose (Easiest - includes MySQL)
docker-compose up --build

# Expected output after ~30 seconds:
# user-service      | Started UserServiceApplication in x.xxx seconds
# order-service     | Started OrderServiceApplication in x.xxx seconds
# payment-service   | Started PaymentServiceApplication in x.xxx seconds

# Option B: Manual Maven build (requires MySQL)
# Terminal 1: Start MySQL
docker run -d --name mysql-dev -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=appdb -e MYSQL_USER=azureuser -e MYSQL_PASSWORD=password123 -p 3306:3306 mysql:8.0

# Terminal 2: Build and start User Service
cd user-service
mvn clean install
mvn spring-boot:run

# Terminal 3: Build and start Order Service
cd order-service
mvn clean install
mvn spring-boot:run

# Terminal 4: Build and start Payment Service
cd payment-service
mvn clean install
mvn spring-boot:run
```

### Step 1.4: Verify Local Services

```bash
# Test User Service
curl -s http://localhost:8081/actuator/health | jq .

# Expected response:
# {
#   "status": "UP",
#   "components": {
#     "db": { "status": "UP" },
#     "diskSpace": { "status": "UP" },
#     "livenessState": { "status": "UP" },
#     "readinessState": { "status": "UP" }
#   }
# }

# Test Order Service
curl -s http://localhost:8082/actuator/health | jq .

# Test Payment Service
curl -s http://localhost:8083/actuator/health | jq .

# All should return "status": "UP"
```

### Step 1.5: Verify Terraform Project

```bash
# Navigate to Terraform directory
cd /Users/chetan/Terraform

# Validate all Terraform modules
terraform validate

# Expected output:
# Success! The configuration is valid.

# Format all Terraform files
terraform fmt -recursive .

# Plan dev environment (without applying)
cd environments/dev
terraform plan -out=tfplan
# (This will fail without Azure credentials - expected at this stage)
```

✅ **Phase 1 Complete:** Local development environment ready

---

## PHASE 2: AZURE INFRASTRUCTURE SETUP

### Step 2.1: Create Azure Account & Subscription

```bash
# Log in to Azure
az login

# Expected output:
# You have logged in. Now let us find all the subscriptions to which you have access...
# [
#   {
#     "cloudName": "AzureCloud",
#     "homeTenantId": "...",
#     "id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
#     "isDefault": true,
#     "name": "Your Subscription Name",
#     "state": "Enabled",
#     "tenantId": "...",
#     "user": { "name": "your@email.com", "type": "user" }
#   }
# ]

# Save your subscription ID
SUBSCRIPTION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Set default subscription
az account set --subscription "$SUBSCRIPTION_ID"

# Verify
az account show --query "{name: name, subscription_id: id}"
```

### Step 2.2: Create Service Principal

```bash
# Create Service Principal for Terraform
az ad sp create-for-rbac \
  --role="Contributor" \
  --scopes="/subscriptions/$SUBSCRIPTION_ID" \
  --name="terraform-sp-3tier"

# Expected output (SAVE THIS SECURELY):
# {
#   "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
#   "displayName": "terraform-sp-3tier",
#   "password": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
#   "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
# }

# Export as environment variables for later use
export AZURE_CLIENT_ID="appId from above"
export AZURE_CLIENT_SECRET="password from above"
export AZURE_SUBSCRIPTION_ID="$SUBSCRIPTION_ID"
export AZURE_TENANT_ID="tenant from above"
```

### Step 2.3: Create Resource Groups

```bash
# Set location (change as needed: eastus, westus2, northeurope, etc.)
LOCATION="eastus"

# Create resource groups for each environment
az group create \
  --name "rg-3tier-app-dev" \
  --location "$LOCATION"

az group create \
  --name "rg-3tier-app-staging" \
  --location "$LOCATION"

az group create \
  --name "rg-3tier-app-prod" \
  --location "$LOCATION"

# Verify
az group list --query "[?contains(name, '3tier')].{name: name, location: location}"
```

### Step 2.4: Create Azure Container Registry (ACR)

```bash
# ACR names must be globally unique (lowercase, no hyphens)
DEV_ACR_NAME="acr3tierappprod"  # Change this to a unique name
STAGING_ACR_NAME="acr3tierappstaging"
PROD_ACR_NAME="acr3tierappdev"

# Create ACR for Dev (Basic tier - cheapest)
az acr create \
  --resource-group "rg-3tier-app-dev" \
  --name "$DEV_ACR_NAME" \
  --sku Basic

# Create ACR for Staging (Standard tier)
az acr create \
  --resource-group "rg-3tier-app-staging" \
  --name "$STAGING_ACR_NAME" \
  --sku Standard

# Create ACR for Prod (Premium tier - best performance)
az acr create \
  --resource-group "rg-3tier-app-prod" \
  --name "$PROD_ACR_NAME" \
  --sku Premium

# Get ACR login credentials
az acr credential show \
  --name "$DEV_ACR_NAME" \
  --resource-group "rg-3tier-app-dev" \
  --query "{username: username, password: passwords[0].value}"

# Expected output:
# {
#   "username": "acr3tierappprod",
#   "password": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
# }

# Save credentials - you'll need them later
```

### Step 2.5: Create Storage Account for Terraform State (Optional but Recommended)

```bash
# Storage account name must be globally unique (lowercase, alphanumeric only, 3-24 chars)
STORAGE_ACCOUNT="tfstate3tier$(date +%s)"  # Unique name with timestamp

# Create storage account
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "rg-3tier-app-prod" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2

# Create container for Terraform state
az storage container create \
  --name "terraform-state" \
  --account-name "$STORAGE_ACCOUNT"

# Get storage account key
STORAGE_KEY=$(az storage account keys list \
  --resource-group "rg-3tier-app-prod" \
  --account-name "$STORAGE_ACCOUNT" \
  --query "[0].value" -o tsv)

echo "Storage Account: $STORAGE_ACCOUNT"
echo "Storage Key: $STORAGE_KEY"
```

### Step 2.6: Create Key Vaults for Secrets

```bash
# Key Vault names must be globally unique and 3-24 characters
KV_DEV="kv3tierdev"
KV_STAGING="kv3tierstaging"
KV_PROD="kv3tierprod"

# Create Key Vaults
az keyvault create \
  --name "$KV_DEV" \
  --resource-group "rg-3tier-app-dev" \
  --location "$LOCATION" \
  --sku standard

az keyvault create \
  --name "$KV_STAGING" \
  --resource-group "rg-3tier-app-staging" \
  --location "$LOCATION" \
  --sku standard

az keyvault create \
  --name "$KV_PROD" \
  --resource-group "rg-3tier-app-prod" \
  --location "$LOCATION" \
  --sku premium

# Store secrets in Key Vault (example for dev)
az keyvault secret set \
  --vault-name "$KV_DEV" \
  --name "mysql-password" \
  --value "P@ssw0rd123456789"

az keyvault secret set \
  --vault-name "$KV_DEV" \
  --name "api-key" \
  --value "dev-api-key-$(date +%s)"
```

✅ **Phase 2 Complete:** Azure infrastructure ready

---

## PHASE 3: BUILD & PUSH DOCKER IMAGES

### Step 3.1: Build Docker Images Locally

```bash
# Navigate to Maven services directory
cd /Users/chetan/Terraform/examples/maven-services

# Build User Service image
docker build -t user-service:1.0.0 \
  -f ../3-tier-architecture/Dockerfile.springboot \
  ./user-service

# Build Order Service image
docker build -t order-service:1.0.0 \
  -f ../3-tier-architecture/Dockerfile.springboot \
  ./order-service

# Build Payment Service image
docker build -t payment-service:1.0.0 \
  -f ../3-tier-architecture/Dockerfile.springboot \
  ./payment-service

# Verify images
docker images | grep -E "(user-service|order-service|payment-service)"

# Expected output:
# user-service       1.0.0         xxxx  1 second ago   450MB
# order-service      1.0.0         xxxx  2 seconds ago  450MB
# payment-service    1.0.0         xxxx  3 seconds ago  450MB
```

### Step 3.2: Login to Azure Container Registry

```bash
# Login to Dev ACR
az acr login --name "$DEV_ACR_NAME"

# Get ACR URL
ACR_URL="$DEV_ACR_NAME.azurecr.io"

# Expected output:
# Login Succeeded
```

### Step 3.3: Tag Images for ACR

```bash
# Set ACR URL variable
ACR_URL="$DEV_ACR_NAME.azurecr.io"

# Tag images
docker tag user-service:1.0.0 "$ACR_URL/user-service:1.0.0"
docker tag order-service:1.0.0 "$ACR_URL/order-service:1.0.0"
docker tag payment-service:1.0.0 "$ACR_URL/payment-service:1.0.0"

# Also tag as latest
docker tag user-service:1.0.0 "$ACR_URL/user-service:latest"
docker tag order-service:1.0.0 "$ACR_URL/order-service:latest"
docker tag payment-service:1.0.0 "$ACR_URL/payment-service:latest"

# Verify tags
docker images | grep "$ACR_URL"
```

### Step 3.4: Push Images to ACR

```bash
# Push images to Dev ACR
docker push "$ACR_URL/user-service:1.0.0"
docker push "$ACR_URL/user-service:latest"

docker push "$ACR_URL/order-service:1.0.0"
docker push "$ACR_URL/order-service:latest"

docker push "$ACR_URL/payment-service:1.0.0"
docker push "$ACR_URL/payment-service:latest"

# Verify images in ACR
az acr repository list --name "$DEV_ACR_NAME"

# Expected output:
# [
#   "order-service",
#   "payment-service",
#   "user-service"
# ]

# Check image tags
az acr repository show-tags --name "$DEV_ACR_NAME" --repository "user-service"
```

### Step 3.5: Create Script for Automated Image Builds

```bash
# Save this as build-and-push-images.sh
cat > /Users/chetan/Terraform/examples/maven-services/push-to-acr.sh << 'EOF'
#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
ACR_NAME=${1:-}
SERVICES=("user-service" "order-service" "payment-service")
VERSION=${2:-1.0.0}

if [ -z "$ACR_NAME" ]; then
    echo -e "${RED}Usage: $0 <acr-name> [version]${NC}"
    echo "Example: $0 acr3tierappprod 1.0.0"
    exit 1
fi

ACR_URL="$ACR_NAME.azurecr.io"

echo -e "${YELLOW}Logging in to $ACR_NAME...${NC}"
az acr login --name "$ACR_NAME"

for service in "${SERVICES[@]}"; do
    echo ""
    echo -e "${YELLOW}Processing $service...${NC}"
    
    # Build image
    echo -e "${YELLOW}Building image...${NC}"
    docker build -t "$service:$VERSION" \
        -f ../3-tier-architecture/Dockerfile.springboot \
        ./$service
    
    # Tag for ACR
    echo -e "${YELLOW}Tagging image...${NC}"
    docker tag "$service:$VERSION" "$ACR_URL/$service:$VERSION"
    docker tag "$service:$VERSION" "$ACR_URL/$service:latest"
    
    # Push to ACR
    echo -e "${YELLOW}Pushing to ACR...${NC}"
    docker push "$ACR_URL/$service:$VERSION"
    docker push "$ACR_URL/$service:latest"
    
    echo -e "${GREEN}✓ $service pushed successfully${NC}"
done

echo ""
echo -e "${GREEN}All images pushed to $ACR_URL${NC}"
EOF

chmod +x /Users/chetan/Terraform/examples/maven-services/push-to-acr.sh

# Use the script
cd /Users/chetan/Terraform/examples/maven-services
./push-to-acr.sh acr3tierappprod 1.0.0
```

✅ **Phase 3 Complete:** Docker images built and pushed to ACR

---

## PHASE 4: TERRAFORM DEPLOYMENT

### Step 4.1: Configure Terraform Variables for Dev

```bash
# Navigate to dev environment
cd /Users/chetan/Terraform/environments/dev

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
cat > terraform.tfvars << 'EOF'
# Azure Configuration
subscription_id = "YOUR_SUBSCRIPTION_ID"
client_id       = "YOUR_CLIENT_ID"
client_secret   = "YOUR_CLIENT_SECRET"
tenant_id       = "YOUR_TENANT_ID"

# Resource Names (must be globally unique)
keyvault_name        = "kv3tierdev"
acr_name             = "acr3tierappprod"
storage_account_name = "st3tierdev"

# MySQL Configuration
mysql_admin_username = "azureuser"
mysql_admin_password = "P@ssw0rd123456789"
mysql_version        = "8.0.21"

# Network Configuration
vnet_address_space = ["10.0.0.0/16"]
subnet_address_prefixes = {
  aks     = "10.0.1.0/24"
  app     = "10.0.2.0/24"
  db      = "10.0.3.0/24"
  func    = "10.0.4.0/24"
}

# AKS Configuration
aks_node_count    = 1
aks_vm_size       = "Standard_B2s"
aks_os_disk_size  = 30

# MySQL Database Configuration
mysql_sku_name      = "B_Standard_B1s"
mysql_storage_size  = 20

# Tags
environment = "dev"
project     = "3tier-app"
EOF

# Security: Don't commit terraform.tfvars to git
echo "terraform.tfvars" >> ../../.gitignore
```

### Step 4.2: Initialize Terraform

```bash
# In dev directory
terraform init

# Expected output:
# Initializing the backend...
# Initializing modules...
# Initializing provider plugins...
# Terraform has been successfully configured!

# Verify
terraform validate
# Expected: Success! The configuration is valid.
```

### Step 4.3: Plan Terraform Deployment

```bash
# Create a plan (review before applying)
terraform plan -out=tfplan

# Expected output should show:
# Plan: XX to add, 0 to change, 0 to destroy.
# 
# This will:
# - Create 1 resource group
# - Create 1 virtual network with subnets
# - Create 1 AKS cluster (1 node)
# - Create 1 MySQL server
# - Create 1 App Service
# - Create 1 Function App
# - Create storage account
# - Create key vault
# - Create ACR
# - Create various network policies and RBAC

# Review the plan - takes 2-3 minutes
```

### Step 4.4: Apply Terraform

```bash
# Apply the plan (this will create resources)
terraform apply tfplan

# Expected output:
# Apply complete! Resources: XX added, 0 changed, 0 destroyed.
#
# Outputs:
#
# acr_admin_password = <sensitive>
# acr_admin_username = "acr3tierappprod"
# acr_login_server = "acr3tierappprod.azurecr.io"
# aks_cluster_name = "aks-3tier-dev"
# mysql_server_fqdn = "mysql-3tier-dev.mysql.database.azure.com"
# ...

# ⏱️ Wait 15-20 minutes for AKS cluster to be fully deployed

# Monitor progress in Azure Portal:
# Home → Resource Groups → rg-3tier-app-dev → Deployments
```

### Step 4.5: Retrieve and Save Outputs

```bash
# Get all outputs
terraform output

# Save specific outputs to environment variables
export MYSQL_FQDN=$(terraform output -raw mysql_server_fqdn)
export ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server)
export AKS_CLUSTER_NAME=$(terraform output -raw aks_cluster_name)
export RESOURCE_GROUP="rg-3tier-app-dev"

# Verify
echo "MySQL FQDN: $MYSQL_FQDN"
echo "ACR Server: $ACR_LOGIN_SERVER"
echo "AKS Cluster: $AKS_CLUSTER_NAME"

# Save to file for later reference
terraform output > /tmp/terraform-outputs-dev.txt
```

### Step 4.6: Repeat for Staging & Production

```bash
# For Staging
cd /Users/chetan/Terraform/environments/staging
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with staging-specific values
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Wait 15-20 minutes...

# For Production
cd /Users/chetan/Terraform/environments/prod
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with production-specific values
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Wait 15-20 minutes...
```

✅ **Phase 4 Complete:** All Azure infrastructure deployed

---

## PHASE 5: KUBERNETES SETUP

### Step 5.1: Configure kubectl Access to Dev Cluster

```bash
# Get AKS cluster credentials
az aks get-credentials \
  --resource-group "rg-3tier-app-dev" \
  --name "aks-3tier-dev" \
  --overwrite-existing

# Verify connection
kubectl cluster-info
# Expected: Kubernetes control plane is running at https://...

kubectl get nodes
# Expected output:
# NAME                       STATUS   ROLES   AGE   VERSION
# aks-nodepool1-12345-0      Ready    agent   5m    v1.27.x
```

### Step 5.2: Install NGINX Ingress Controller

```bash
# Add Helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX Ingress
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.externalTrafficPolicy=Local \
  --wait

# Get external IP (may take 1-2 minutes)
kubectl get service -n ingress-nginx

# Expected output:
# NAME                              TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)                      AGE
# nginx-ingress-ingress-nginx-controller   LoadBalancer   10.0.xxx.xxx   20.xxx.xxx.xxx   80:30xxx/TCP,443:30xxx/TCP   1m
```

### Step 5.3: Create Application Namespace and Config

```bash
# Create namespace and resources
kubectl apply -f /Users/chetan/Terraform/examples/3-tier-architecture/namespace-and-config.yaml

# Verify
kubectl get namespace three-tier-app
kubectl get configmap -n three-tier-app
kubectl get secret -n three-tier-app

# Expected output:
# NAME          STATUS   AGE
# three-tier-app Active   10s

# NAME         DATA   AGE
# app-config   8      10s
# 
# NAME         TYPE                  DATA   AGE
# acr-secret   kubernetes.io/dockercfg   1      10s
# app-secrets  Opaque                10      10s
```

### Step 5.4: Update ConfigMaps with Database Info

```bash
# Get values from Terraform outputs
MYSQL_FQDN=$(cd /Users/chetan/Terraform/environments/dev && terraform output -raw mysql_server_fqdn)
ACR_SERVER=$(cd /Users/chetan/Terraform/environments/dev && terraform output -raw acr_login_server)

# Update ConfigMap
kubectl set env configmap/app-config \
  -n three-tier-app \
  MYSQL_HOST="$MYSQL_FQDN" \
  MYSQL_DATABASE="appdb" \
  MYSQL_USER="azureuser" \
  ACR_LOGIN_SERVER="$ACR_SERVER" \
  --record

# Verify
kubectl get configmap app-config -n three-tier-app -o yaml
```

### Step 5.5: Create Docker Registry Secret

```bash
# Get ACR credentials from Terraform
ACR_USERNAME=$(cd /Users/chetan/Terraform/environments/dev && terraform output -raw acr_admin_username)
ACR_PASSWORD=$(cd /Users/chetan/Terraform/environments/dev && terraform output -raw acr_admin_password)
ACR_SERVER=$(cd /Users/chetan/Terraform/environments/dev && terraform output -raw acr_login_server)

# Create secret for image pulls
kubectl create secret docker-registry acr-secret \
  --docker-server="$ACR_SERVER" \
  --docker-username="$ACR_USERNAME" \
  --docker-password="$ACR_PASSWORD" \
  -n three-tier-app \
  --dry-run=client \
  -o yaml | kubectl apply -f -

# Verify
kubectl get secret acr-secret -n three-tier-app
```

### Step 5.6: Repeat for Staging & Production Clusters

```bash
# For Staging
az aks get-credentials \
  --resource-group "rg-3tier-app-staging" \
  --name "aks-3tier-staging" \
  --overwrite-existing

# Install NGINX
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --wait

# Create namespace and config
kubectl apply -f /Users/chetan/Terraform/examples/3-tier-architecture/namespace-and-config.yaml

# Update with staging database info
MYSQL_FQDN=$(cd /Users/chetan/Terraform/environments/staging && terraform output -raw mysql_server_fqdn)
ACR_SERVER=$(cd /Users/chetan/Terraform/environments/staging && terraform output -raw acr_login_server)
kubectl set env configmap/app-config -n three-tier-app MYSQL_HOST="$MYSQL_FQDN" ACR_LOGIN_SERVER="$ACR_SERVER"

# Repeat for Production cluster
```

✅ **Phase 5 Complete:** Kubernetes configured with NGINX Ingress

---

## PHASE 6: APPLICATION DEPLOYMENT

### Step 6.1: Deploy Microservices to Dev

```bash
# Ensure you're on the dev cluster
kubectl config current-context
# Should show: aks-3tier-dev

# Update image names in deployment file (optional - if using ACR)
sed -i '' "s|acr.azurecr.io|acr3tierappprod.azurecr.io|g" \
  /Users/chetan/Terraform/examples/3-tier-architecture/spring-boot-services.yaml

# Deploy Spring Boot services
kubectl apply -f /Users/chetan/Terraform/examples/3-tier-architecture/spring-boot-services.yaml

# Expected output:
# deployment.apps/user-service created
# service/user-service created
# horizontalpodautoscaler.autoscaling/user-service-hpa created
# ...

# Watch deployment progress
kubectl rollout status deployment/user-service -n three-tier-app
kubectl rollout status deployment/order-service -n three-tier-app
kubectl rollout status deployment/payment-service -n three-tier-app

# Expected output:
# deployment "user-service" successfully rolled out
```

### Step 6.2: Deploy React Frontend

```bash
# Deploy frontend
kubectl apply -f /Users/chetan/Terraform/examples/3-tier-architecture/react-frontend.yaml

# Watch deployment
kubectl rollout status deployment/react-frontend -n three-tier-app

# Expected output:
# deployment "react-frontend" successfully rolled out
```

### Step 6.3: Verify Deployments

```bash
# Check all pods
kubectl get pods -n three-tier-app

# Expected output:
# NAME                                   READY   STATUS    RESTARTS   AGE
# user-service-xxxxxxxxxx-xxxxx         1/1     Running   0          2m
# order-service-xxxxxxxxxx-xxxxx        1/1     Running   0          1m
# payment-service-xxxxxxxxxx-xxxxx      1/1     Running   0          1m
# react-frontend-xxxxxxxxxx-xxxxx       1/1     Running   0          30s

# Check services
kubectl get svc -n three-tier-app

# Check ingress
kubectl get ingress -n three-tier-app

# Expected output:
# NAME             CLASS   HOSTS            ADDRESS         PORTS     AGE
# react-frontend   nginx   example.com      20.xxx.xxx.xxx  80, 443   1m
```

### Step 6.4: Check Logs

```bash
# Get logs from User Service
kubectl logs -n three-tier-app -l app=user-service --tail=50 -f

# Get logs from Order Service
kubectl logs -n three-tier-app -l app=order-service --tail=50 -f

# Get logs from Payment Service
kubectl logs -n three-tier-app -l app=payment-service --tail=50 -f

# Get logs from React Frontend
kubectl logs -n three-tier-app -l app=react-frontend --tail=50 -f

# Get pod descriptions (useful for debugging)
kubectl describe pod <pod-name> -n three-tier-app
```

### Step 6.5: Test Services

```bash
# Port forward to User Service
kubectl port-forward -n three-tier-app svc/user-service 8081:8081 &

# Test health endpoint
curl http://localhost:8081/actuator/health

# Create a user
curl -X POST http://localhost:8081/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "test",
    "email": "test@example.com",
    "password": "pass123",
    "firstName": "Test",
    "lastName": "User"
  }'

# Port forward to React Frontend
kubectl port-forward -n three-tier-app svc/react-frontend 3000:80 &

# Open browser
open http://localhost:3000
```

### Step 6.6: Repeat for Staging & Production

```bash
# Switch to staging cluster
az aks get-credentials \
  --resource-group "rg-3tier-app-staging" \
  --name "aks-3tier-staging" \
  --overwrite-existing

# Deploy all services
kubectl apply -f /Users/chetan/Terraform/examples/3-tier-architecture/spring-boot-services.yaml
kubectl apply -f /Users/chetan/Terraform/examples/3-tier-architecture/react-frontend.yaml

# Verify
kubectl get pods -n three-tier-app

# Switch to production cluster
az aks get-credentials \
  --resource-group "rg-3tier-app-prod" \
  --name "aks-3tier-prod" \
  --overwrite-existing

# Deploy all services
kubectl apply -f /Users/chetan/Terraform/examples/3-tier-architecture/spring-boot-services.yaml
kubectl apply -f /Users/chetan/Terraform/examples/3-tier-architecture/react-frontend.yaml

# Verify
kubectl get pods -n three-tier-app
```

✅ **Phase 6 Complete:** Applications deployed to all clusters

---

## PHASE 7: ENVIRONMENT-SPECIFIC CONFIGURATION

### Step 7.1: Configure Dev Environment

**Dev Characteristics:**
- Single node AKS cluster (cost optimization)
- Basic tier resources
- Local redundancy (LRS)
- Minimal monitoring

```bash
# Already deployed by Terraform with:
# - 1 node Standard_B2s VM
# - Burstable MySQL B1s
# - Basic ACR
# - Standard Key Vault
# - LRS storage

# Dev namespace defaults:
kubectl get configmap app-config -n three-tier-app -o yaml
# Shows environment-specific defaults for development

# No special configuration needed - use defaults
```

### Step 7.2: Configure Staging Environment

**Staging Characteristics:**
- 2-4 nodes with auto-scaling
- Standard tier resources
- Geo-redundancy (GRS)
- Moderate monitoring
- Pre-production testing

```bash
# Switch to staging
az aks get-credentials --resource-group "rg-3tier-app-staging" --name "aks-3tier-staging" --overwrite-existing

# Verify auto-scaling
kubectl get hpa -n three-tier-app

# Expected output shows HPA (Horizontal Pod Autoscaler) configured
# NAME                 REFERENCE                       TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
# order-service-hpa    Deployment/order-service        50%/70%   2         5         2          5m
# ...

# Update service replicas for staging (higher availability)
kubectl set replicas deployment/user-service=2 -n three-tier-app
kubectl set replicas deployment/order-service=3 -n three-tier-app
kubectl set replicas deployment/payment-service=2 -n three-tier-app

# Verify
kubectl get deployment -n three-tier-app
```

### Step 7.3: Configure Production Environment

**Production Characteristics:**
- 3+ nodes with auto-scaling across AZs
- Memory-optimized resources
- Geo-redundant with backups (RAGRS)
- Full monitoring with Log Analytics
- HA and DR capabilities

```bash
# Switch to production
az aks get-credentials --resource-group "rg-3tier-app-prod" --name "aks-3tier-prod" --overwrite-existing

# Verify HA setup (nodes across availability zones)
kubectl get nodes -o wide

# Expected output shows nodes in different zones:
# aks-nodepool1-xxxxx   Ready   agent   10m   v1.27.x   X.X.X.X   <none>   AZ 1
# aks-nodepool1-yyyyy   Ready   agent   10m   v1.27.x   Y.Y.Y.Y   <none>   AZ 2
# aks-nodepool1-zzzzz   Ready   agent   10m   v1.27.x   Z.Z.Z.Z   <none>   AZ 3

# Scale production replicas higher for HA
kubectl set replicas deployment/user-service=3 -n three-tier-app
kubectl set replicas deployment/order-service=4 -n three-tier-app
kubectl set replicas deployment/payment-service=3 -n three-tier-app

# Enable pod disruption budgets for high availability
cat > pdb.yaml << 'EOF'
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: user-service-pdb
  namespace: three-tier-app
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: user-service
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: order-service-pdb
  namespace: three-tier-app
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: order-service
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: payment-service-pdb
  namespace: three-tier-app
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: payment-service
EOF

kubectl apply -f pdb.yaml

# Configure backup for MySQL
az mysql flexible-server backup create \
  --resource-group "rg-3tier-app-prod" \
  --server-name "mysql-3tier-prod" \
  --backup-name "prod-backup-$(date +%Y%m%d)"

# Configure monitoring (Log Analytics)
az monitor log-analytics workspace create \
  --resource-group "rg-3tier-app-prod" \
  --workspace-name "logs-3tier-prod"
```

### Step 7.4: Setup Custom Domains (Optional)

```bash
# Get ingress external IP
kubectl get ingress -n three-tier-app

# For dev: dev.example.com
# For staging: staging.example.com
# For prod: app.example.com (or your domain)

# Update DNS records (in your DNS provider):
# dev.example.com          -> [INGRESS_EXTERNAL_IP]
# staging.example.com      -> [INGRESS_EXTERNAL_IP]
# app.example.com          -> [INGRESS_EXTERNAL_IP]

# Update ingress resource with domain
kubectl patch ingress react-frontend -n three-tier-app -p '{"spec":{"host":"dev.example.com"}}'
```

✅ **Phase 7 Complete:** Environment-specific configurations applied

---

## VERIFICATION & TESTING

### Step 8.1: Verify Dev Environment

```bash
# Switch to dev cluster
az aks get-credentials --resource-group "rg-3tier-app-dev" --name "aks-3tier-dev" --overwrite-existing

# Check all pods are running
kubectl get pods -n three-tier-app

# Port forward and test
kubectl port-forward svc/user-service 8081:8081 -n three-tier-app &

# Test API
curl -s http://localhost:8081/actuator/health | jq .
curl -s http://localhost:8081/api/users | jq .

# Test inter-service communication
curl -X POST http://localhost:8082/api/orders \
  -H "Content-Type: application/json" \
  -d '{"userId":1,"amount":99.99,"currency":"USD"}'

# Check logs for errors
kubectl logs -n three-tier-app -l app=order-service --tail=100

# Expected: Service started successfully with no errors
```

### Step 8.2: Verify Staging Environment

```bash
# Switch to staging
az aks get-credentials --resource-group "rg-3tier-app-staging" --name "aks-3tier-staging" --overwrite-existing

# Verify auto-scaling is active
kubectl get hpa -n three-tier-app

# Check metrics
kubectl top pods -n three-tier-app

# Load test (optional)
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://order-service:8082/api/orders; done" &

# Monitor HPA response
watch kubectl get hpa -n three-tier-app
# Should see replicas increasing under load
```

### Step 8.3: Verify Production Environment

```bash
# Switch to production
az aks get-credentials --resource-group "rg-3tier-app-prod" --name "aks-3tier-prod" --overwrite-existing

# Verify all pods
kubectl get pods -n three-tier-app

# Verify pod distribution across nodes
kubectl get pods -n three-tier-app -o wide

# Verify PDB (Pod Disruption Budgets)
kubectl get pdb -n three-tier-app

# Check MySQL backups
az mysql flexible-server backup list \
  --resource-group "rg-3tier-app-prod" \
  --server-name "mysql-3tier-prod"

# Verify monitoring
az monitor diagnostic-settings list \
  --resource /subscriptions/SUBSCRIPTION_ID/resourceGroups/rg-3tier-app-prod/providers/Microsoft.ContainerService/managedClusters/aks-3tier-prod
```

### Step 8.4: End-to-End Testing

```bash
# Test complete flow: Create User → Create Order → Process Order → Payment

# 1. Create User
USER_ID=$(curl -s -X POST http://localhost:8081/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "securePass123",
    "firstName": "Test",
    "lastName": "User"
  }' | jq -r '.id')

echo "Created User: $USER_ID"

# 2. Create Order
ORDER_ID=$(curl -s -X POST http://localhost:8082/api/orders \
  -H "Content-Type: application/json" \
  -d "{
    \"userId\": $USER_ID,
    \"amount\": 99.99,
    \"currency\": \"USD\",
    \"description\": \"Test order\"
  }" | jq -r '.id')

echo "Created Order: $ORDER_ID"

# 3. Process Order (calls Payment Service)
PAYMENT=$(curl -s -X POST http://localhost:8082/api/orders/$ORDER_ID/process)
echo "Order Processing Result:"
echo $PAYMENT | jq .

# 4. Verify Payment
PAYMENT_ID=$(echo $PAYMENT | jq -r '.id')
curl -s http://localhost:8083/api/payments/$PAYMENT_ID | jq .

# Expected: Order and Payment status = "completed"
```

### Step 8.5: Performance Testing

```bash
# Install Apache Bench (if not installed)
# macOS
brew install httpd

# Linux
sudo apt install apache2-utils

# Test User Service
ab -n 100 -c 10 http://localhost:8081/api/users

# Expected output shows response times and throughput

# Test Order Service
ab -n 100 -c 10 -p order.json -T application/json http://localhost:8082/api/orders

# Monitor during load
watch kubectl top pods -n three-tier-app
```

✅ **Verification Complete:** All environments tested and working

---

## CLEANUP & TROUBLESHOOTING

### Step 9.1: Common Issues & Solutions

**Issue 1: AKS cluster taking too long to deploy**
```bash
# Monitor in Azure Portal
# Home → Resource Groups → rg-3tier-app-dev → Deployments

# Check specific resource status
az aks show -g rg-3tier-app-dev -n aks-3tier-dev --query "{provisioningState: provisioningState}"
```

**Issue 2: Pods in CrashLoopBackOff or pending**
```bash
# Check pod events
kubectl describe pod <pod-name> -n three-tier-app

# Check logs
kubectl logs <pod-name> -n three-tier-app

# Common issues:
# - Image pull errors: Check ACR credentials and image names
# - Database connection: Verify MYSQL_HOST and credentials
# - Memory/CPU: Check resource requests vs. node capacity
```

**Issue 3: Database connection failed**
```bash
# Test MySQL connection from pod
kubectl run -it --rm mysql-test --image=mysql:8.0 \
  --restart=Never \
  -n three-tier-app \
  -- mysql -h mysql-3tier-dev.mysql.database.azure.com \
  -u azureuser -p appdb

# Check firewall rules
az mysql flexible-server firewall-rule list \
  --resource-group "rg-3tier-app-dev" \
  --server-name "mysql-3tier-dev"

# Add AKS subnet to firewall
az mysql flexible-server firewall-rule create \
  --resource-group "rg-3tier-app-dev" \
  --server-name "mysql-3tier-dev" \
  --name "AllowAKSSubnet" \
  --start-ip-address "10.0.1.0" \
  --end-ip-address "10.0.1.255"
```

**Issue 4: Ingress not getting external IP**
```bash
# Check NGINX ingress
kubectl get service -n ingress-nginx

# If EXTERNAL-IP is pending:
kubectl describe svc -n ingress-nginx

# Check Azure Load Balancer
az network lb list -g rg-3tier-app-dev --query "[].name"

# Wait up to 10 minutes for IP assignment
```

**Issue 5: Inter-service communication failing**
```bash
# Test from inside pod
kubectl exec -it <pod-name> -n three-tier-app -- /bin/sh

# Inside pod, test connectivity
curl http://order-service:8082/actuator/health

# If fails, check service discovery
kubectl get svc -n three-tier-app
kubectl get endpoints -n three-tier-app
```

### Step 9.2: Rollback Deployment (if needed)

```bash
# View rollout history
kubectl rollout history deployment/user-service -n three-tier-app

# Rollback to previous version
kubectl rollout undo deployment/user-service -n three-tier-app

# Rollback to specific revision
kubectl rollout undo deployment/user-service --to-revision=2 -n three-tier-app

# Verify rollback
kubectl rollout status deployment/user-service -n three-tier-app
```

### Step 9.3: Delete Resources (Clean Up)

```bash
# Delete Kubernetes resources FIRST
kubectl delete namespace three-tier-app

# Then delete Terraform resources
cd /Users/chetan/Terraform/environments/dev
terraform destroy

# Answer 'yes' to confirm

# Repeat for staging and prod
cd /Users/chetan/Terraform/environments/staging
terraform destroy

cd /Users/chetan/Terraform/environments/prod
terraform destroy

# (Optional) Delete Resource Groups
az group delete --name "rg-3tier-app-dev" --yes
az group delete --name "rg-3tier-app-staging" --yes
az group delete --name "rg-3tier-app-prod" --yes

# (Optional) Delete ACR
az acr delete --name "acr3tierappprod" --yes
az acr delete --name "acr3tierappstaging" --yes
az acr delete --name "acr3tierappdev" --yes
```

---

## QUICK REFERENCE CHECKLIST

### Pre-Deployment Checklist

- [ ] Azure account created
- [ ] Service Principal created and credentials saved
- [ ] Resource groups created (dev, staging, prod)
- [ ] ACR created and accessible
- [ ] Docker images built and pushed to ACR
- [ ] Maven services tested locally
- [ ] Git repository initialized and .gitignore configured

### Deployment Checklist (Per Environment)

- [ ] terraform.tfvars configured with correct values
- [ ] terraform init successful
- [ ] terraform plan reviewed
- [ ] terraform apply completed (15-20 min wait)
- [ ] Terraform outputs saved
- [ ] kubectl credentials configured (az aks get-credentials)
- [ ] NGINX Ingress installed
- [ ] Kubernetes namespace created
- [ ] ConfigMaps and Secrets applied
- [ ] Docker registry secret created
- [ ] Spring Boot services deployed
- [ ] React frontend deployed
- [ ] Health checks passing
- [ ] Inter-service communication working
- [ ] Custom domain configured (optional)

### Post-Deployment Verification

- [ ] All pods running
- [ ] All services healthy
- [ ] Logs show no errors
- [ ] API endpoints responding
- [ ] Inter-service calls working
- [ ] Database connected and accessible
- [ ] Monitoring alerts configured (prod)
- [ ] Backups scheduled (prod)

---

## ESTIMATED COSTS

### Development Environment (Monthly)
- AKS: $40-50 (1 node Standard_B2s)
- MySQL: $15-20 (Burstable B1s)
- Storage: $5
- Other: $5
- **Total: ~$70/month**

### Staging Environment (Monthly)
- AKS: $100-150 (2-4 nodes Standard_B4ms)
- MySQL: $40-50 (General Purpose)
- Storage: $10
- Other: $10
- **Total: ~$170/month**

### Production Environment (Monthly)
- AKS: $300-400 (3+ nodes Standard_D2s_v3)
- MySQL: $150-200 (Memory Optimized)
- Storage: $20
- Premium services: $50
- **Total: ~$600/month**

**Total for all 3 environments: ~$840/month**

---

## NEXT STEPS

1. **Configure CI/CD Pipeline** (GitHub Actions or Azure DevOps)
2. **Setup Monitoring & Alerts** (Application Insights, Log Analytics)
3. **Configure Auto-Scaling Policies** (based on metrics)
4. **Implement Backup Strategy** (MySQL, configurations)
5. **Setup Disaster Recovery** (failover procedures)
6. **Configure Custom Domains** (SSL/TLS certificates)
7. **Implement Security Policies** (network policies, RBAC)
8. **Document Runbooks** (operations procedures)

---

## SUPPORT & DOCUMENTATION

- [Terraform Azure Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest)
- [AKS Documentation](https://learn.microsoft.com/en-us/azure/aks/)
- [Azure MySQL Docs](https://learn.microsoft.com/en-us/azure/mysql/)
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [Spring Boot Docs](https://spring.io/projects/spring-boot)
- [Maven Docs](https://maven.apache.org/)

---

**Document Version:** 1.0  
**Last Updated:** April 25, 2026  
**Status:** Production Ready  
**Tested On:** Terraform 1.5.0, AKS 1.27.x, Spring Boot 2.7.10
