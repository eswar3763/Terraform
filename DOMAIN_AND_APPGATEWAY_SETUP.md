# Domain & Application Gateway Configuration Guide

## 📋 Overview

This guide explains how to configure your domain name and integrate Azure Application Gateway with your AKS cluster using Application Gateway Ingress Controller (AGIC).

### What You'll Have After This Setup:
- ✅ Domain name (myapp.com) pointing to Application Gateway
- ✅ Application Gateway as Layer 7 load balancer
- ✅ HTTPS/SSL termination with automatic certificates
- ✅ Advanced routing rules (path-based, host-based)
- ✅ AGIC automatically syncing Kubernetes Ingress with Application Gateway
- ✅ Azure Load Balancer for Layer 4 redundancy

---

## 🏗️ Architecture

```
Internet (myapp.com)
    ↓
DNS Resolution → Application Gateway Public IP
    ↓
Application Gateway (Layer 7)
    ├─ SSL/TLS Termination
    ├─ Path-Based Routing (/api/*, /health, etc)
    ├─ WAF (optional)
    └─ Request Routing
    ↓
AGIC (Application Gateway Ingress Controller)
    ↓
AKS Cluster
    ├─ User Service (8081)
    ├─ Order Service (8082)
    ├─ Payment Service (8083)
    └─ React Frontend (3000/80)
    ↓
Load Balancer (Layer 4, Backup)
```

---

## 📝 Step 1: Register Your Domain

### Option A: Using Azure DNS
```bash
# Create DNS zone in Azure
az network dns zone create --resource-group rg-3tier-app-dev --name myapp.com

# Get nameservers assigned by Azure
az network dns zone show --resource-group rg-3tier-app-dev --name myapp.com --query "nameServers" -o tsv
```

### Option B: Using External Domain Registrar (GoDaddy, Namecheap, etc.)
1. Register domain at your preferred registrar
2. Get nameservers from Azure DNS or use your current DNS provider
3. Update domain nameservers at registrar

### Option C: Using Existing Domain
If you already own a domain:
1. Add Azure DNS nameservers to your domain registrar
2. Create DNS zone in Azure: `az network dns zone create --resource-group rg-3tier-app-dev --name myapp.com`

---

## 🌐 Step 2: Get Application Gateway Public IP

After running `terraform apply` for your dev environment:

```bash
# Get Application Gateway public IP
terraform output application_gateway_public_ip

# Example output: 40.123.45.67
```

**Save this IP address** - you'll need it for DNS records.

---

## 🔗 Step 3: Configure DNS Records

### Option A: Using Azure DNS
```bash
# Add A record for root domain
az network dns record-set a add-record \
  --resource-group rg-3tier-app-dev \
  --zone-name myapp.com \
  --record-set-name "@" \
  --ipv4-address <APP_GATEWAY_PUBLIC_IP>

# Add A record for www subdomain
az network dns record-set a add-record \
  --resource-group rg-3tier-app-dev \
  --zone-name myapp.com \
  --record-set-name "www" \
  --ipv4-address <APP_GATEWAY_PUBLIC_IP>

# Verify DNS records
az network dns record-set a list --resource-group rg-3tier-app-dev --zone-name myapp.com
```

### Option B: Using DNS Registrar Web UI
1. Go to your registrar (GoDaddy, Namecheap, etc.)
2. Find DNS management section
3. Create/Update A Records:
   - **Name:** @ (or leave blank for root domain)
   - **Type:** A
   - **Value:** `<APP_GATEWAY_PUBLIC_IP>`
   - **TTL:** 3600 (or default)

4. Create A Record for www:
   - **Name:** www
   - **Type:** A
   - **Value:** `<APP_GATEWAY_PUBLIC_IP>`
   - **TTL:** 3600

### Option C: Using CNAME (if you want subdomain only)
```bash
# Create CNAME for api subdomain
az network dns record-set cname create \
  --resource-group rg-3tier-app-dev \
  --zone-name myapp.com \
  --name api

az network dns record-set cname set-record \
  --resource-group rg-3tier-app-dev \
  --zone-name myapp.com \
  --record-set-name api \
  --cname <APP_GATEWAY_PUBLIC_IP>
```

---

## 🔍 Step 4: Test DNS Resolution

```bash
# Test DNS propagation (wait 5-10 minutes after DNS changes)
nslookup myapp.com

# Expected output:
# Name:      myapp.com
# Address:   40.123.45.67

# Test with curl
curl -I myapp.com
# Should get HTTP/HTTPS response from Application Gateway
```

---

## 🔐 Step 5: Configure SSL/TLS Certificates

### Option A: Using Let's Encrypt (Automatic, Free)

#### 1. Install cert-manager in AKS:
```bash
# Add Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

# Verify installation
kubectl get deployment -n cert-manager
```

#### 2. Create ClusterIssuer for Let's Encrypt:
```bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
    - dns01:
        azureDNS:
          subscriptionID: YOUR_SUBSCRIPTION_ID
          tenantID: YOUR_TENANT_ID
          resourceGroupName: rg-3tier-app-dev
          hostedZoneName: myapp.com
          managedIdentity:
            clientID: <AGIC_IDENTITY_CLIENT_ID>
EOF
```

#### 3. Update Kubernetes Ingress to use cert-manager:
```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: three-tier-app
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    kubernetes.io/ingress.class: azure/application-gateway
spec:
  tls:
  - hosts:
    - myapp.com
    - www.myapp.com
    secretName: myapp-tls-secret
  rules:
  - host: myapp.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: react-frontend
            port:
              number: 80
  - host: www.myapp.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: react-frontend
            port:
              number: 80
EOF
```

### Option B: Using Azure Key Vault with Application Gateway

#### 1. Generate or Import Certificate:
```bash
# Generate self-signed certificate (for testing)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout myapp.key \
  -out myapp.crt \
  -subj "/CN=myapp.com/O=MyApp"

# Create PFX file
openssl pkcs12 -export \
  -in myapp.crt \
  -inkey myapp.key \
  -out myapp.pfx \
  -name "myapp-cert" \
  -passout pass:P@ssw0rd123
```

#### 2. Upload to Key Vault:
```bash
# Upload certificate to Key Vault
az keyvault certificate import \
  --vault-name kv3tierapp-dev \
  --name myapp-cert \
  --file myapp.pfx \
  --password "P@ssw0rd123"

# Get certificate secret ID
az keyvault certificate show \
  --vault-name kv3tierapp-dev \
  --name myapp-cert \
  --query "sid" -o tsv
```

#### 3. Update Terraform to use the certificate:
```hcl
# In environments/dev/terraform.tfvars
certificate_secret_id = "https://kv3tierapp-dev.vault.azure.net/secrets/myapp-cert/version"
```

#### 4. Reapply Terraform:
```bash
cd environments/dev
terraform plan -out=tfplan
terraform apply tfplan
```

### Option C: Using Application Gateway Managed Certificates (via Portal)

1. Go to Azure Portal → Application Gateway → Listeners
2. Click on HTTPS Listener
3. Select Certificate source: "Upload a certificate" or "Select from Key Vault"
4. Upload or select your PFX certificate
5. Set certificate password if needed

---

## 🚀 Step 6: Install AGIC (Application Gateway Ingress Controller)

AGIC automatically syncs Kubernetes Ingress resources with Application Gateway.

### 1. Grant AKS Managed Identity Access to Application Gateway:

```bash
# Get AKS managed identity
AKS_RESOURCE_ID=$(az aks show --resource-group rg-3tier-app-dev --name aks-3tier-dev --query "identity.principalId" -o tsv)

# Grant Contributor role on Application Gateway
APPGW_RESOURCE_ID=$(az resource show --name appgw-3tier-dev --resource-group rg-3tier-app-dev --resource-type "Microsoft.Network/applicationGateways" --query "id" -o tsv)

az role assignment create --assignee $AKS_RESOURCE_ID --role "Contributor" --scope $APPGW_RESOURCE_ID

# Also grant Network Contributor on resource group
az role assignment create --assignee $AKS_RESOURCE_ID --role "Network Contributor" --scope "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-3tier-app-dev"
```

### 2. Install AGIC via Helm:

```bash
# Add AGIC Helm repository
helm repo add application-gateway-kubernetes-ingress https://appgwk8s.blob.core.windows.net/helm/
helm repo update

# Install AGIC
helm install agic application-gateway-kubernetes-ingress/ingress-azure \
  --namespace kube-system \
  --set appgw.subscriptionId="<SUBSCRIPTION_ID>" \
  --set appgw.resourceGroup="rg-3tier-app-dev" \
  --set appgw.name="appgw-3tier-dev" \
  --set rbac.enabled=true \
  --set armAuth.type=managedIdentity \
  --set armAuth.identityResourceID="<AGIC_IDENTITY_RESOURCE_ID>" \
  --set armAuth.identityClientID="<AGIC_CLIENT_ID>"

# Verify AGIC installation
kubectl get deployment -n kube-system | grep agic
kubectl get pods -n kube-system | grep agic
```

### 3. Configure Ingress Class:

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: azure-application-gateway
spec:
  controller: azure/application-gateway
EOF
```

---

## 📋 Step 7: Create Kubernetes Ingress for Application Gateway

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: three-tier-app-ingress
  namespace: three-tier-app
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
    appgw.ingress.kubernetes.io/health-probe-path: /actuator/health
    appgw.ingress.kubernetes.io/health-probe-interval: "30"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - myapp.com
    - www.myapp.com
    secretName: myapp-tls-cert
  rules:
  # Frontend
  - host: myapp.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: react-frontend
            port:
              number: 80

  # API Routes
  - host: api.myapp.com
    http:
      paths:
      - path: /api/users
        pathType: Prefix
        backend:
          service:
            name: user-service
            port:
              number: 8081
      - path: /api/orders
        pathType: Prefix
        backend:
          service:
            name: order-service
            port:
              number: 8082
      - path: /api/payments
        pathType: Prefix
        backend:
          service:
            name: payment-service
            port:
              number: 8083

  # Health checks
  - host: health.myapp.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: user-service
            port:
              number: 8081
EOF
```

---

## ✅ Step 8: Verify Configuration

```bash
# 1. Check Ingress status
kubectl get ingress -n three-tier-app
kubectl describe ingress three-tier-app-ingress -n three-tier-app

# 2. Check AGIC logs
kubectl logs -f deployment/agic -n kube-system | head -50

# 3. Verify Application Gateway updated
az network application-gateway show --resource-group rg-3tier-app-dev --name appgw-3tier-dev | jq '.httpListeners, .backendAddressPools'

# 4. Test HTTPS connection
curl -I https://myapp.com

# 5. Monitor certificate issuance (for Let's Encrypt)
kubectl get certificate -n three-tier-app
kubectl describe certificate myapp-tls-cert -n three-tier-app

# 6. View certificate secret
kubectl get secret myapp-tls-cert -n three-tier-app -o yaml
```

---

## 🐛 Troubleshooting

### Issue: DNS Not Resolving

```bash
# Check DNS propagation
nslookup myapp.com
dig myapp.com
dig myapp.com @8.8.8.8

# Flush local DNS cache
# macOS:
sudo dscacheutil -flushcache

# Windows:
ipconfig /flushdns

# Linux:
sudo systemctl restart systemd-resolved
```

### Issue: Certificate Not Issuing (Let's Encrypt)

```bash
# Check cert-manager logs
kubectl logs -f deployment/cert-manager -n cert-manager

# Check CertificateRequest status
kubectl get certificaterequest -n three-tier-app
kubectl describe certificaterequest <name> -n three-tier-app

# Check Order status
kubectl get order -n three-tier-app
kubectl describe order <name> -n three-tier-app

# Check Challenge status
kubectl get challenge -n three-tier-app
kubectl describe challenge <name> -n three-tier-app
```

### Issue: AGIC Not Updating Application Gateway

```bash
# Check AGIC pod status
kubectl get pods -n kube-system | grep agic
kubectl describe pod <agic-pod-name> -n kube-system

# Check AGIC logs
kubectl logs deployment/agic -n kube-system -f

# Verify AGIC configuration
kubectl get configmap -n kube-system | grep agic
kubectl describe configmap <configmap-name> -n kube-system

# Common fixes:
# 1. Verify Managed Identity has correct permissions
# 2. Check IngressClass is correct (azure/application-gateway)
# 3. Verify Application Gateway exists and is in correct resource group
```

### Issue: HTTPS Not Working

```bash
# 1. Check if certificate is loaded in Application Gateway
az network application-gateway ssl-cert list --resource-group rg-3tier-app-dev --gateway-name appgw-3tier-dev

# 2. Verify HTTPS listener is configured
az network application-gateway http-listener list --resource-group rg-3tier-app-dev --gateway-name appgw-3tier-dev

# 3. Test with curl
curl -v https://myapp.com

# 4. Check certificate validity
openssl s_client -connect myapp.com:443
```

### Issue: Application Gateway Returning 502 Bad Gateway

```bash
# Check backend health
az network application-gateway probe show --resource-group rg-3tier-app-dev --gateway-name appgw-3tier-dev --name health-probe

# Verify AKS pod is running
kubectl get pods -n three-tier-app
kubectl describe pod <pod-name> -n three-tier-app

# Check pod logs
kubectl logs <pod-name> -n three-tier-app

# Test service accessibility
kubectl port-forward svc/user-service 8081:8081 -n three-tier-app
curl http://localhost:8081/actuator/health
```

---

## 🔄 Common Configuration Changes

### Change Certificate

```bash
# Update Key Vault certificate
az keyvault certificate import --vault-name kv3tierapp-dev --name myapp-cert --file newcert.pfx

# Or in Application Gateway (via Portal):
# Settings → HTTPS Settings → Update Certificate
```

### Add New Domain/Subdomain

```bash
# 1. Add DNS record
az network dns record-set a add-record \
  --resource-group rg-3tier-app-dev \
  --zone-name myapp.com \
  --record-set-name "api" \
  --ipv4-address <APP_GATEWAY_PUBLIC_IP>

# 2. Update Kubernetes Ingress
kubectl edit ingress three-tier-app-ingress -n three-tier-app
# Add new host to rules and spec.hosts

# 3. Update Application Gateway host_names in Terraform
# Edit environments/dev/terraform.tfvars
app_gateway_host_names = ["myapp.com", "www.myapp.com", "api.myapp.com"]

# 4. Reapply Terraform
cd environments/dev && terraform apply
```

### Enable WAF (Web Application Firewall)

```bash
# Update Terraform variable
enable_waf = true
waf_mode   = "Prevention"  # or "Detection"

# Apply changes
cd environments/dev && terraform apply
```

---

## 📊 Monitoring

### Application Gateway Metrics

```bash
# View Application Gateway metrics in Azure Portal:
# Azure Portal → Application Gateway → Metrics

# Key metrics to monitor:
# - Backend Health Status
# - Request Count
# - Failed Requests
# - Response Time
# - Throughput (Bytes Sent/Received)
```

### AGIC Metrics

```bash
# View Prometheus metrics
kubectl port-forward deployment/agic 8888:8888 -n kube-system
# Visit: http://localhost:8888/metrics

# Key metrics:
# - agic_ingress_updated_total
# - agic_ingress_error_total
# - agic_reconcile_duration_seconds
```

---

## 🎯 Summary Commands Cheatsheet

```bash
# Get Application Gateway Public IP
terraform output application_gateway_public_ip

# Create DNS A Record
az network dns record-set a add-record --resource-group rg-3tier-app-dev --zone-name myapp.com --record-set-name "@" --ipv4-address <IP>

# Install AGIC
helm install agic application-gateway-kubernetes-ingress/ingress-azure --namespace kube-system

# Create Ingress
kubectl apply -f ingress.yaml

# Verify Ingress
kubectl get ingress -n three-tier-app
kubectl describe ingress three-tier-app-ingress -n three-tier-app

# Test Domain
curl -I https://myapp.com

# Check Certificate
openssl s_client -connect myapp.com:443

# Monitor AGIC
kubectl logs -f deployment/agic -n kube-system
```

---

**Status:** ✅ Complete Domain & Application Gateway Configuration Guide  
**Last Updated:** April 25, 2026  
**Version:** 1.0
