# Azure Deployment Quick Start Guide

## 📋 Prerequisites Checklist

Before starting, ensure you have:

- [ ] Azure subscription with billing enabled
- [ ] Local tools installed: Terraform, Azure CLI, kubectl, Docker, Maven
- [ ] Docker Desktop running
- [ ] Git configured
- [ ] ~$2-3/hour budget for resources while testing

## 🚀 Quick Start (5 Steps)

### Step 1: Setup Azure Account (5 minutes)

```bash
# Login to Azure
az login

# Get subscription ID
az account list --output table

# Set subscription
export SUBSCRIPTION_ID="your-subscription-id"
az account set --subscription "$SUBSCRIPTION_ID"

# Create Service Principal
az ad sp create-for-rbac \
  --role="Contributor" \
  --scopes="/subscriptions/$SUBSCRIPTION_ID" \
  --name="terraform-sp-3tier"

# Save credentials - you'll need them!
# {
#   "appId": "...",
#   "password": "...",
#   "tenant": "..."
# }
```

### Step 2: Build Docker Images (10 minutes)

```bash
cd examples/maven-services

# Build images
docker build -t user-service:1.0 -f ../3-tier-architecture/Dockerfile.springboot ./user-service
docker build -t order-service:1.0 -f ../3-tier-architecture/Dockerfile.springboot ./order-service
docker build -t payment-service:1.0 -f ../3-tier-architecture/Dockerfile.springboot ./payment-service

# Verify
docker images | grep -E "(user|order|payment)-service"
```

### Step 3: Deploy to Dev Environment (30 minutes)

```bash
cd environments/dev

# Create terraform variables file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values:
# subscription_id = "your-subscription-id"
# client_id = "appId from Service Principal"
# client_secret = "password from Service Principal"
# tenant_id = "tenant from Service Principal"
# keyvault_name = "kv3tierdev"  (must be globally unique)
# acr_name = "acr3tierappprod"  (must be globally unique)
# storage_account_name = "st3tierdev"  (must be globally unique)
# mysql_admin_password = "YourSecurePassword123!"

# Initialize and deploy
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan

# ⏱️ Wait 15-20 minutes for AKS cluster to deploy...
```

### Step 4: Setup Kubernetes (10 minutes)

```bash
# Get cluster credentials
az aks get-credentials \
  --resource-group "rg-3tier-app-dev" \
  --name "aks-3tier-dev" \
  --overwrite-existing

# Verify connection
kubectl cluster-info

# Run quick setup script
bash ../../quick-setup-env.sh dev

# This script will:
# ✓ Install NGINX Ingress
# ✓ Create namespace and configuration
# ✓ Deploy all microservices
# ✓ Deploy React frontend
```

### Step 5: Test Your Deployment (5 minutes)

```bash
# Check pod status
kubectl get pods -n three-tier-app

# Port forward for testing
kubectl port-forward svc/user-service 8081:8081 -n three-tier-app &
kubectl port-forward svc/react-frontend 3000:80 -n three-tier-app &

# Test API
curl http://localhost:8081/actuator/health

# Open frontend in browser
open http://localhost:3000

# Test creating a user
curl -X POST http://localhost:8081/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "pass123",
    "firstName": "Test",
    "lastName": "User"
  }'
```

## 📊 Environment Specifications

| Aspect | Dev | Staging | Prod |
|--------|-----|---------|------|
| AKS Nodes | 1 (B2s) | 2-4 (B4ms) | 3+ (D2s_v3) |
| MySQL SKU | B1s | GP (D2s) | MO (E4s) |
| Storage | LRS | GRS | RAGRS |
| Cost/month | ~$70 | ~$170 | ~$600 |
| Replicas | 1-3 | 2-5 | 3+ |
| Monitoring | Basic | Standard | Premium |

## 🛠️ Common Tasks

### Push Docker Images to ACR

```bash
# Login to ACR
az acr login --name acr3tierappprod

# Set ACR URL
ACR_URL="acr3tierappprod.azurecr.io"

# Tag images
docker tag user-service:1.0 $ACR_URL/user-service:1.0
docker tag order-service:1.0 $ACR_URL/order-service:1.0
docker tag payment-service:1.0 $ACR_URL/payment-service:1.0

# Push images
docker push $ACR_URL/user-service:1.0
docker push $ACR_URL/order-service:1.0
docker push $ACR_URL/payment-service:1.0
```

### View Logs

```bash
# User Service logs
kubectl logs -n three-tier-app -l app=user-service -f

# Order Service logs
kubectl logs -n three-tier-app -l app=order-service -f

# Payment Service logs
kubectl logs -n three-tier-app -l app=payment-service -f

# All pods
kubectl logs -n three-tier-app -l app --all-containers=true -f
```

### Scale Services

```bash
# Scale replicas
kubectl scale deployment user-service --replicas=2 -n three-tier-app
kubectl scale deployment order-service --replicas=3 -n three-tier-app
kubectl scale deployment payment-service --replicas=2 -n three-tier-app

# Check HPA (auto-scaling)
kubectl get hpa -n three-tier-app
```

### Update Services

```bash
# Update image (when you rebuild and push)
kubectl set image deployment/user-service \
  user-service=acr3tierappprod.azurecr.io/user-service:1.1 \
  -n three-tier-app

# Check rollout status
kubectl rollout status deployment/user-service -n three-tier-app

# Rollback if needed
kubectl rollout undo deployment/user-service -n three-tier-app
```

## 🔍 Troubleshooting

### Pods Not Running

```bash
# Check pod status
kubectl describe pod <pod-name> -n three-tier-app

# Check events
kubectl get events -n three-tier-app --sort-by='.lastTimestamp'

# Check logs
kubectl logs <pod-name> -n three-tier-app
```

### Database Connection Failed

```bash
# Test MySQL connection
kubectl run -it --rm mysql-test --image=mysql:8.0 \
  --restart=Never \
  -n three-tier-app \
  -- mysql -h mysql-3tier-dev.mysql.database.azure.com \
  -u azureuser -p appdb

# Check firewall rules
az mysql flexible-server firewall-rule list \
  --resource-group "rg-3tier-app-dev" \
  --server-name "mysql-3tier-dev"
```

### Images Not Pulling from ACR

```bash
# Check secret
kubectl get secret acr-secret -n three-tier-app

# Recreate secret
ACR_SERVER=$(terraform output -raw acr_login_server)
ACR_USERNAME=$(terraform output -raw acr_admin_username)
ACR_PASSWORD=$(terraform output -raw acr_admin_password)

kubectl delete secret acr-secret -n three-tier-app
kubectl create secret docker-registry acr-secret \
  --docker-server="$ACR_SERVER" \
  --docker-username="$ACR_USERNAME" \
  --docker-password="$ACR_PASSWORD" \
  -n three-tier-app
```

## 📦 Resource Cleanup

```bash
# Delete Kubernetes resources
kubectl delete namespace three-tier-app

# Delete Terraform resources
cd environments/dev
terraform destroy

# Delete resource group
az group delete --name "rg-3tier-app-dev" --yes
```

## 📚 Full Documentation

- **Main Guide:** See `AZURE_DEPLOYMENT_GUIDE.md` for complete step-by-step instructions
- **Terraform:** See `DEPLOYMENT.md` for infrastructure details
- **Maven Services:** See `examples/maven-services/README.md` for application details
- **Kubernetes:** See `examples/3-tier-architecture/` for K8s manifests

## ⏱️ Timeline Estimate

| Phase | Duration | Notes |
|-------|----------|-------|
| Prerequisites | 10 min | Tool installation |
| Azure Setup | 5 min | Service Principal, Resource Groups |
| Docker Build | 10 min | Build 3 images |
| Terraform Deploy | 20 min | AKS cluster creation |
| AKS Wait | 15 min | Cluster initialization |
| Kubernetes Setup | 10 min | NGINX, namespace, config |
| Application Deploy | 5 min | Deploy services and frontend |
| Verification | 5 min | Testing and validation |
| **Total** | **80 minutes** | **~1.5 hours** |

## 🎯 Next Steps After Deployment

1. **Configure Custom Domain** (optional)
   - Update DNS records to point to Ingress IP
   - Configure SSL/TLS certificates

2. **Setup CI/CD Pipeline** (optional)
   - GitHub Actions or Azure DevOps
   - Auto-build and deploy on code push

3. **Enable Monitoring** (important for production)
   - Application Insights
   - Log Analytics
   - Alerts and dashboards

4. **Configure Backups** (important for production)
   - MySQL automated backups
   - Configuration backups
   - Disaster recovery procedures

5. **Repeat for Staging & Production**
   - Use same process with staging/prod credentials
   - Different resource names and SKUs

## 📞 Support

- **Terraform Issues:** Check `terraform destroy` and try again
- **AKS Issues:** Check Azure Portal → Resource Groups → Deployments
- **Kubernetes Issues:** Use `kubectl describe` and `kubectl logs` for debugging
- **Database Issues:** Test MySQL connection directly
- **Image Issues:** Check ACR repository and pull errors

## 🔐 Security Notes

⚠️ **Important:**
- Never commit `terraform.tfvars` with credentials
- Use Azure Key Vault for production secrets
- Rotate credentials regularly
- Enable network policies in Kubernetes
- Use managed identities instead of passwords
- Enable Azure Firewall in production

---

**Status:** Ready for deployment  
**Last Updated:** April 25, 2026  
**Version:** 1.0
