# Azure AKS Deployment - Visual Quick Reference

## 📊 Complete Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        AZURE CLOUD (3 Environments)                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐      │
│  │   DEV CLUSTER    │  │ STAGING CLUSTER  │  │  PROD CLUSTER    │      │
│  │  (1 node B2s)    │  │  (2-4 B4ms nodes)│  │  (3+ D2s nodes)  │      │
│  ├──────────────────┤  ├──────────────────┤  ├──────────────────┤      │
│  │                  │  │                  │  │                  │      │
│  │ ┌──────────────┐ │  │ ┌──────────────┐ │  │ ┌──────────────┐ │      │
│  │ │ NGINX Ingress│ │  │ │ NGINX Ingress│ │  │ │ NGINX Ingress│ │      │
│  │ └──────┬───────┘ │  │ └──────┬───────┘ │  │ └──────┬───────┘ │      │
│  │        │         │  │        │         │  │        │         │      │
│  │   ┌────┴─────────┴──────────────────┐ │  │   ┌────┴───────┐ │      │
│  │   │  Spring Boot Services (Pods)     │ │  │   │  Services  │ │      │
│  │   │  - User Service (8081, 3 replicas)  │  │   │  - User    │ │      │
│  │   │  - Order Service (8082, 3 replicas) │  │   │  - Order   │ │      │
│  │   │  - Payment Service (8083, 2 replicas)  │   │  - Payment │ │      │
│  │   │  - React Frontend (80, 3 replicas)  │  │   │  - React   │ │      │
│  │   └────┬─────────────────────────────┘ │  │   └────┬───────┘ │      │
│  │        │                                │  │        │        │      │
│  │   ┌────▼──────────────────────────────┐ │  │   ┌────▼───────┐ │      │
│  │   │    MySQL Database                  │ │  │   │  MySQL    │ │      │
│  │   │ (Burstable B1s, 20GB, 7-day bkp)  │ │  │   │  (Mem-opt) │ │      │
│  │   └─────────────────────────────────  │ │  │   └───────────┘ │      │
│  │                                        │  │                   │      │
│  └────────────────────────────────────────┘  └───────────────────┘      │
│          ▲                                              ▲                │
│          │                                              │                │
│  ┌───────┴────────────────────────────┬───────────────┴─────┐           │
│  │                                    │                     │           │
│  ▼                                    ▼                     ▼           │
│ ┌──────────────┐    ┌───────────────┐  ┌──────────────┐               │
│ │ Key Vault    │    │ Container     │  │ App Service  │               │
│ │ (Secrets,    │    │ Registry      │  │ (Lightweight)               │
│ │  Certs)      │    │ (Docker imgs) │  │              │               │
│ └──────────────┘    └───────────────┘  └──────────────┘               │
│                                                                           │
│ ┌──────────────────────────────────────────────────────────────────┐    │
│ │ Terraform State Storage (Recommended)                             │    │
│ │ - Resource Group definitions                                      │    │
│ │ - Network configurations                                          │    │
│ │ - Security policies                                               │    │
│ └──────────────────────────────────────────────────────────────────┘    │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 📋 Step-by-Step Deployment Flow

```
START
  │
  ├─► 1. PREREQUISITES
  │    ├─ Install tools (Terraform, Azure CLI, kubectl, Docker, Maven)
  │    ├─ Verify installations
  │    └─ Test Maven locally
  │
  ├─► 2. AZURE ACCOUNT SETUP
  │    ├─ Create subscription
  │    ├─ Create Service Principal
  │    ├─ Create Resource Groups (dev, staging, prod)
  │    ├─ Create ACR (Container Registry)
  │    └─ Create Key Vaults (optional)
  │
  ├─► 3. BUILD DOCKER IMAGES
  │    ├─ User Service → user-service:1.0
  │    ├─ Order Service → order-service:1.0
  │    ├─ Payment Service → payment-service:1.0
  │    └─ Push to Azure Container Registry
  │
  ├─► 4. TERRAFORM DEPLOYMENT (for each environment)
  │    │
  │    ├─► DEV ENVIRONMENT
  │    │    ├─ terraform init
  │    │    ├─ terraform plan
  │    │    ├─ terraform apply ⏱️ (15-20 min wait)
  │    │    └─ Save outputs
  │    │
  │    ├─► STAGING ENVIRONMENT (same process)
  │    │    ├─ Copy terraform.tfvars.example → terraform.tfvars
  │    │    ├─ Update with staging-specific values
  │    │    ├─ terraform init → plan → apply
  │    │    └─ Save outputs
  │    │
  │    └─► PRODUCTION ENVIRONMENT (same process)
  │         ├─ Copy terraform.tfvars.example → terraform.tfvars
  │         ├─ Update with production-specific values
  │         ├─ terraform init → plan → apply
  │         └─ Save outputs
  │
  ├─► 5. KUBERNETES SETUP (for each environment)
  │    ├─ az aks get-credentials (configure kubectl)
  │    ├─ helm install nginx-ingress
  │    ├─ kubectl apply namespace-and-config.yaml
  │    └─ Create ACR secret
  │
  ├─► 6. APPLICATION DEPLOYMENT (for each environment)
  │    ├─ kubectl apply spring-boot-services.yaml
  │    ├─ kubectl apply react-frontend.yaml
  │    └─ Wait for pods to be Ready
  │
  ├─► 7. VERIFICATION
  │    ├─ kubectl get pods (verify all running)
  │    ├─ curl health endpoints (verify responsive)
  │    ├─ Test inter-service calls
  │    └─ Access frontend in browser
  │
  └─► 8. CLEANUP (when done)
       ├─ kubectl delete namespace three-tier-app
       ├─ terraform destroy
       └─ az group delete (optional)

END
```

---

## 🎯 Quick Reference Commands

### Login & Setup
```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "SUBSCRIPTION_ID"

# Create Service Principal
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/$SUBSCRIPTION_ID"
```

### Build & Push Docker
```bash
# Build images
docker build -t user-service:1.0 -f ../3-tier-architecture/Dockerfile.springboot ./user-service
docker build -t order-service:1.0 -f ../3-tier-architecture/Dockerfile.springboot ./order-service
docker build -t payment-service:1.0 -f ../3-tier-architecture/Dockerfile.springboot ./payment-service

# Login to ACR
az acr login --name acr3tierappprod

# Tag and push
docker tag user-service:1.0 acr3tierappprod.azurecr.io/user-service:1.0
docker push acr3tierappprod.azurecr.io/user-service:1.0
# (repeat for other services)
```

### Terraform Deployment
```bash
# Per environment (dev, staging, prod)
cd environments/dev

# Configure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Deploy
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan

# ⏱️ Wait 15-20 minutes...

# Retrieve outputs
terraform output
```

### Kubernetes Setup
```bash
# Get cluster credentials
az aks get-credentials --resource-group "rg-3tier-app-dev" --name "aks-3tier-dev"

# Install NGINX
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace --set controller.service.type=LoadBalancer --wait

# Or use quick-setup script
bash quick-setup-env.sh dev
```

### Application Deployment
```bash
# Apply configurations
kubectl apply -f examples/3-tier-architecture/namespace-and-config.yaml

# Deploy services
kubectl apply -f examples/3-tier-architecture/spring-boot-services.yaml

# Deploy frontend
kubectl apply -f examples/3-tier-architecture/react-frontend.yaml

# Monitor
kubectl rollout status deployment/user-service -n three-tier-app
```

### Verification
```bash
# Check pods
kubectl get pods -n three-tier-app

# Check services
kubectl get svc -n three-tier-app

# Port forward
kubectl port-forward svc/user-service 8081:8081 -n three-tier-app &

# Test health
curl http://localhost:8081/actuator/health

# View logs
kubectl logs -n three-tier-app -l app=user-service -f
```

---

## 📊 Environment Comparison

```
╔════════════════════════════════════════════════════════════════════════╗
║                   DEVELOPMENT  │  STAGING  │  PRODUCTION               ║
╠════════════════════════════════════════════════════════════════════════╣
║ Purpose     │ Development      │ Pre-prod  │ Production Workloads     ║
║ Duration    │ ~80 minutes      │ ~80 min   │ ~80 min + setup          ║
║ Cost/Month  │ ~$70             │ ~$170     │ ~$600                    ║
╠════════════════════════════════════════════════════════════════════════╣
║ AKS Nodes   │ 1 (Standard_B2s) │ 2-4 B4ms  │ 3+ D2s_v3 (across AZs)  ║
║ MySQL SKU   │ Burstable B1s    │ GP D2s    │ Memory-opt E4s           ║
║ Storage     │ LRS (local)      │ GRS (geo) │ RAGRS (read-access)      ║
║ Replicas    │ 1-3              │ 2-5       │ 3+                       ║
║ Auto-Scale  │ No               │ Yes       │ Yes (aggressive)         ║
║ Availability│ Single Zone      │ Single    │ Multiple Zones (HA)      ║
║ Monitoring  │ Basic            │ Standard  │ Premium + Alerts         ║
║ Backups     │ 7 days           │ 14 days   │ 30 days + geo-redundant ║
╚════════════════════════════════════════════════════════════════════════╝
```

---

## 🔄 Services & Ports

```
┌─────────────────────────────────────────────────┐
│          MICROSERVICES NETWORK MAP               │
├─────────────────────────────────────────────────┤
│                                                  │
│  React Frontend                                 │
│  ├─ Port: 80 (HTTP) / 443 (HTTPS)              │
│  ├─ URL: http://localhost:3000                 │
│  └─ Status: http://localhost:3000/health       │
│                                                  │
│  User Service                                   │
│  ├─ Port: 8081                                 │
│  ├─ Health: /actuator/health                   │
│  ├─ Endpoints: /api/users                      │
│  └─ Metrics: /actuator/prometheus              │
│                                                  │
│  Order Service                                  │
│  ├─ Port: 8082                                 │
│  ├─ Health: /actuator/health                   │
│  ├─ Endpoints: /api/orders                     │
│  ├─ Calls User Service (8081)                  │
│  ├─ Calls Payment Service (8083)               │
│  └─ Metrics: /actuator/prometheus              │
│                                                  │
│  Payment Service                                │
│  ├─ Port: 8083                                 │
│  ├─ Health: /actuator/health                   │
│  ├─ Endpoints: /api/payments                   │
│  ├─ API Key Required: X-API-KEY header         │
│  └─ Metrics: /actuator/prometheus              │
│                                                  │
│  MySQL Database                                 │
│  ├─ Port: 3306                                 │
│  ├─ Host: mysql-3tier-*.mysql.database.azure.com
│  ├─ Database: appdb                            │
│  ├─ User: azureuser                            │
│  └─ Shared by all services                     │
│                                                  │
└─────────────────────────────────────────────────┘

CALL FLOW:
  Frontend (3000) 
    ├─► User Service (8081)
    ├─► Order Service (8082)
    │    ├─► User Service (8081) - verify user
    │    └─► Payment Service (8083) - process payment
    └─► Payment Service (8083)
```

---

## 📈 Scaling & Auto-Scaling

```
AUTO-SCALING CONFIGURATION
═════════════════════════════════════════

DEV ENVIRONMENT:
  • User Service:    1-3 replicas    (manual scaling)
  • Order Service:   1-3 replicas    (manual scaling)
  • Payment Service: 1-2 replicas    (manual scaling)
  • AKS Nodes:       1 node          (no scale)

STAGING ENVIRONMENT:
  • User Service:    2-5 replicas    (CPU: 70%, Memory: 80%)
  • Order Service:   2-5 replicas    (CPU: 70%, Memory: 80%)
  • Payment Service: 1-3 replicas    (CPU: 75%, Memory: 85%)
  • AKS Nodes:       2-4 nodes       (auto-scale enabled)

PRODUCTION ENVIRONMENT:
  • User Service:    3+ replicas     (CPU: 70%, Memory: 80%)
  • Order Service:   4+ replicas     (CPU: 70%, Memory: 80%)
  • Payment Service: 3+ replicas     (CPU: 75%, Memory: 85%)
  • AKS Nodes:       3-10 nodes      (auto-scale across 3 AZs)
  • Pod Disruption:  Min 2 running   (HA policy)
```

---

## 🔐 Security Configuration

```
SECURITY LAYERS
═════════════════════════════════════════

NETWORK SECURITY:
  ✓ Azure Virtual Network with subnets
  ✓ Network Security Groups (firewalls)
  ✓ Kubernetes Network Policies
  ✓ AKS-restricted API server (prod)
  ✓ HTTPS/TLS on Ingress (cert-manager)

IDENTITY & ACCESS:
  ✓ Azure Service Principal for Terraform
  ✓ Managed Identities for AKS & services
  ✓ RBAC at Kubernetes level
  ✓ Key Vault for secrets management
  ✓ ACR credentials via secrets

APPLICATION SECURITY:
  ✓ Non-root container execution
  ✓ Read-only root filesystem
  ✓ Dropped Linux capabilities
  ✓ Pod Security Policies (network isolation)
  ✓ Input validation on all endpoints

DATABASE SECURITY:
  ✓ Non-admin user (azureuser)
  ✓ Password via Key Vault
  ✓ Firewall rules (AKS subnet only)
  ✓ SSL required for connections
  ✓ Encrypted backups
  ✓ Geo-redundant backups (prod)
```

---

## 🚨 Troubleshooting Decision Tree

```
PROBLEM: Pods not running
├─► Check status: kubectl describe pod <pod>
├─► Check logs: kubectl logs <pod> -n three-tier-app
├─► Likely issues:
│   ├─ Image not found → verify ACR secret
│   ├─ Memory/CPU → increase resource requests
│   ├─ Database connection → check MySQL firewall
│   └─ Missing env vars → verify ConfigMap
└─► Solution: Fix issue and redeploy

PROBLEM: Database connection failed
├─► Test connection: kubectl run mysql-test --image=mysql:8.0
├─► Check credentials: echo $MYSQL_PASSWORD
├─► Check firewall: az mysql flexible-server firewall-rule list
├─► Likely issues:
│   ├─ Wrong password → update Secret
│   ├─ Firewall blocking → add AKS subnet
│   └─ Network issue → check VNet configuration
└─► Solution: Update settings and restart pods

PROBLEM: Services can't reach each other
├─► Verify DNS: kubectl exec <pod> -- nslookup order-service
├─► Check network policy: kubectl get networkpolicy -n three-tier-app
├─► Test connectivity: kubectl exec <pod> -- curl order-service:8082/health
├─► Likely issues:
│   ├─ Network policy blocking → update rules
│   ├─ Service name wrong → check service names
│   └─ Port mismatch → verify target port
└─► Solution: Update network policy and restart pods

PROBLEM: Can't reach frontend from internet
├─► Check ingress: kubectl get ingress -n three-tier-app
├─► Get external IP: kubectl get svc -n ingress-nginx
├─► Test internally: kubectl port-forward svc/react-frontend 3000:80
├─► Likely issues:
│   ├─ No external IP → wait 5+ minutes for LB
│   ├─ Wrong domain → update DNS records
│   └─ Certificate issue → check cert-manager
└─► Solution: Wait for IP assignment or check DNS configuration
```

---

## 📞 Quick Help Links

| Issue | Command |
|-------|---------|
| Check pod status | `kubectl get pods -n three-tier-app` |
| Describe pod | `kubectl describe pod <name> -n three-tier-app` |
| View pod logs | `kubectl logs <name> -n three-tier-app` |
| Follow logs | `kubectl logs -f <name> -n three-tier-app` |
| Check all events | `kubectl get events -n three-tier-app` |
| Execute command in pod | `kubectl exec -it <pod> -n three-tier-app -- /bin/sh` |
| Port forward service | `kubectl port-forward svc/<name> 8080:8080 -n three-tier-app` |
| Scale deployment | `kubectl scale deployment <name> --replicas=3 -n three-tier-app` |
| View deployment status | `kubectl rollout status deployment/<name> -n three-tier-app` |
| Rollback deployment | `kubectl rollout undo deployment/<name> -n three-tier-app` |
| View resource usage | `kubectl top pods -n three-tier-app` |
| Edit deployment | `kubectl edit deployment <name> -n three-tier-app` |
| Delete pod | `kubectl delete pod <name> -n three-tier-app` |
| View service details | `kubectl get svc <name> -n three-tier-app -o yaml` |

---

## 📅 Timeline Summary

```
Start
  │
  ├─► Phase 1: Prerequisites         (10 min)    = 10 min total
  ├─► Phase 2: Azure Setup           (5 min)     = 15 min total
  ├─► Phase 3: Build Docker          (10 min)    = 25 min total
  ├─► Phase 4: Terraform Deploy      (30 min + 20 wait) = 75 min total
  ├─► Phase 5: Kubernetes Setup      (10 min)    = 85 min total
  ├─► Phase 6: Deploy Apps           (5 min)     = 90 min total
  ├─► Phase 7: Verification          (5 min)     = 95 min total
  └─► DONE! (~95 minutes for DEV)

For each additional environment:
  └─► Repeat Phase 4-7: ~65 minutes per environment

Total for all 3 environments: ~225 minutes (~3.75 hours)
```

---

**Status:** ✅ Complete Reference Guide  
**Version:** 1.0  
**Last Updated:** April 25, 2026
