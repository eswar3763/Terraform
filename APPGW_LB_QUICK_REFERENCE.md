# Application Gateway & Load Balancer - Quick Reference Card

## 🎯 What You Have

### New Modules
- ✅ **Application Gateway** (`modules/application_gateway/`) - Layer 7 LB with WAF
- ✅ **Load Balancer** (`modules/load_balancer/`) - Layer 4 LB 
- ✅ **Network Updates** - AppGW subnet + LB subnet

### New Kubernetes Manifests  
- ✅ **AGIC Config** (`examples/3-tier-architecture/agic-config.yaml`)
- ✅ **AppGW Ingress** (`examples/3-tier-architecture/appgw-ingress.yaml`)

### Updated Environments
- ✅ **Dev** - Single instance App Gateway, optional WAF
- ✅ **Staging** - HA App Gateway, WAF in Detection mode
- ✅ **Production** - HA App Gateway, WAF in Prevention mode

### Documentation
- ✅ [DOMAIN_AND_APPGATEWAY_SETUP.md](DOMAIN_AND_APPGATEWAY_SETUP.md) - 9-step complete guide
- ✅ [APPLICATION_GATEWAY_LB_SETUP_SUMMARY.md](APPLICATION_GATEWAY_LB_SETUP_SUMMARY.md) - This comprehensive guide

---

## 📝 Deployment Checklist

```bash
# Step 1: Prepare configuration
cd /Users/chetan/Terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Edit with your values

# Step 2: Initialize
terraform init
terraform validate

# Step 3: Plan
terraform plan -out=tfplan

# Step 4: Deploy
terraform apply tfplan
# Wait 20-30 minutes...

# Step 5: Get results
terraform output application_gateway_public_ip
# Copy IP address for DNS setup

# Step 6: Configure DNS
# Update your domain registrar with the IP address
# See DOMAIN_AND_APPGATEWAY_SETUP.md for details
```

---

## 🔑 Configuration Files Reference

### Template Files (Use These as Starting Points)
```
environments/dev/terraform.tfvars.example
environments/staging/terraform.tfvars.example
environments/prod/terraform.tfvars.example
```

### Key Variables to Update

**Development:**
```hcl
# terraform.tfvars (dev)
subscription_id       = "your-sub-id"
client_id            = "your-client-id"
client_secret        = "your-secret"
tenant_id            = "your-tenant-id"
mysql_admin_password = "StrongPassword123!"

# Optional
app_gateway_host_names     = ["myapp.com", "www.myapp.com"]
enable_waf                 = false  # No WAF for dev to save costs
```

**Staging:**
```hcl
# terraform.tfvars (staging)
app_gateway_capacity   = 2
enable_waf            = true
waf_mode              = "Detection"  # Test WAF in detection mode
```

**Production:**
```hcl
# terraform.tfvars (prod)
app_gateway_capacity   = 2
enable_waf            = true
waf_mode              = "Prevention"  # Strict WAF enforcement
certificate_secret_id = "https://kvname.vault.azure.net/secrets/cert/version"  # REQUIRED
```

---

## 🚀 Quick Commands

### Deploy Application Gateway & Load Balancer
```bash
cd environments/dev
terraform apply -var-file=terraform.tfvars
```

### Get Application Gateway IP (for DNS)
```bash
terraform output application_gateway_public_ip
```

### Get AGIC Managed Identity IDs
```bash
terraform output agic_client_id
terraform output agic_principal_id
```

### Get Domain Configuration Summary
```bash
terraform output domain_configuration_summary
```

### Check Application Gateway Status
```bash
az network application-gateway show \
  --resource-group rg-3tier-app-dev \
  --name appgw-3tier-dev
```

### View Application Gateway Public IP
```bash
az network public-ip show \
  --resource-group rg-3tier-app-dev \
  --name appgw-3tier-dev-pip
```

---

## 🔐 Domain & DNS Setup (Quick Steps)

1. **Get Application Gateway IP:**
   ```bash
   terraform output application_gateway_public_ip
   # Example: 40.123.45.67
   ```

2. **Update DNS A Records:**
   ```bash
   # Using Azure DNS
   az network dns record-set a add-record \
     --resource-group rg-3tier-app-dev \
     --zone-name myapp.com \
     --record-set-name "@" \
     --ipv4-address 40.123.45.67
   
   # Or in your DNS registrar (GoDaddy, Namecheap, etc.)
   # Add A record: myapp.com -> 40.123.45.67
   # Add A record: www.myapp.com -> 40.123.45.67
   ```

3. **Test DNS Resolution:**
   ```bash
   nslookup myapp.com
   # Should return: 40.123.45.67
   ```

4. **Test HTTPS (after cert setup):**
   ```bash
   curl -I https://myapp.com
   ```

---

## 🏗️ Architecture at a Glance

```
Internet → DNS (myapp.com → IP) → Application Gateway 
         ↓
    [SSL/TLS Termination]
    [Path-Based Routing]
    [WAF (optional)]
         ↓
        AGIC (in Kubernetes)
         ↓
    AKS Cluster Services
    ├─ User Service (8081)
    ├─ Order Service (8082)
    ├─ Payment Service (8083)
    └─ React Frontend (80)
         ↓
    Load Balancer (Layer 4 backup)
```

---

## 📊 Environment Comparison

| Feature | Dev | Staging | Prod |
|---------|-----|---------|------|
| **AppGW Capacity** | 1 | 2 | 2 |
| **WAF** | ❌ | ✅ Detection | ✅ Prevention |
| **AKS Nodes** | 1 | 2-4 | 3-10 |
| **MySQL SKU** | B1s | D2s | E4s |
| **Geo-Redundant** | ❌ | ❌ | ✅ |
| **Cost/Month** | ~$83 | ~$190 | ~$510 |

---

## 🔧 Common Tasks

### Add New Domain/Subdomain
```bash
# 1. Add DNS record
az network dns record-set a add-record \
  --resource-group rg-3tier-app-dev \
  --zone-name myapp.com \
  --record-set-name "api" \
  --ipv4-address <APP_GATEWAY_IP>

# 2. Update Kubernetes Ingress
kubectl edit ingress three-tier-app-ingress -n three-tier-app
# Add: - host: api.myapp.com

# 3. Update Terraform (optional)
# Edit environments/dev/terraform.tfvars
app_gateway_host_names = ["myapp.com", "www.myapp.com", "api.myapp.com"]
terraform apply

# 4. Update AGIC config
helm upgrade agic ... --set hosts="myapp.com,api.myapp.com"
```

### Update SSL Certificate
```bash
# 1. Upload new cert to Key Vault
az keyvault certificate import \
  --vault-name kv3tierapp-dev \
  --name myapp-cert \
  --file newcert.pfx

# 2. Get secret ID
az keyvault certificate show \
  --vault-name kv3tierapp-dev \
  --name myapp-cert \
  --query "sid"

# 3. Update Terraform
# Edit terraform.tfvars
certificate_secret_id = "https://kv3tierapp-dev.vault.azure.net/secrets/..."
terraform apply
```

### Enable/Disable WAF
```bash
# In terraform.tfvars
enable_waf = true  # or false
waf_mode   = "Prevention"  # or "Detection"
terraform apply
```

---

## 🐛 Troubleshooting Quick Links

| Issue | Check |
|-------|-------|
| DNS not resolving | `nslookup myapp.com` |
| HTTPS not working | `openssl s_client -connect myapp.com:443` |
| 502 Bad Gateway | Pod health: `kubectl get pods -n three-tier-app` |
| AGIC not syncing | AGIC logs: `kubectl logs deployment/agic -n kube-system` |
| High latency | AppGW metrics in Azure Portal |

**For detailed troubleshooting**, see:
- Phase 9 in [DOMAIN_AND_APPGATEWAY_SETUP.md](DOMAIN_AND_APPGATEWAY_SETUP.md)
- "Troubleshooting" section in [AZURE_DEPLOYMENT_GUIDE.md](AZURE_DEPLOYMENT_GUIDE.md)

---

## 📚 Documentation Map

| Document | Purpose | Read Time |
|----------|---------|-----------|
| [DOMAIN_AND_APPGATEWAY_SETUP.md](DOMAIN_AND_APPGATEWAY_SETUP.md) | Step-by-step setup | 30 min |
| [APPLICATION_GATEWAY_LB_SETUP_SUMMARY.md](APPLICATION_GATEWAY_LB_SETUP_SUMMARY.md) | Complete guide | 20 min |
| [QUICK_START.md](QUICK_START.md) | Quick reference | 5 min |
| [AZURE_DEPLOYMENT_GUIDE.md](AZURE_DEPLOYMENT_GUIDE.md) | Full deployment | 30 min |
| [VISUAL_REFERENCE.md](VISUAL_REFERENCE.md) | Diagrams | 10 min |

---

## 🎯 Key Outputs to Save

After `terraform apply`, save these:

```bash
# Save these for later reference
terraform output application_gateway_id > appgw_id.txt
terraform output application_gateway_public_ip > appgw_ip.txt
terraform output agic_client_id > agic_client_id.txt
terraform output agic_principal_id > agic_principal_id.txt
terraform output domain_configuration_summary > domain_config.txt

# Display saved values
cat appgw_ip.txt
cat domain_config.txt
```

---

## ✅ Verification Checklist

After deployment, verify:

- [ ] Application Gateway created: `terraform output application_gateway_id`
- [ ] Public IP assigned: `terraform output application_gateway_public_ip`
- [ ] DNS records point to AppGW IP
- [ ] AGIC pod running: `kubectl get pods -n kube-system | grep agic`
- [ ] Ingress synced: `kubectl get ingress -n three-tier-app`
- [ ] SSL certificate present: `openssl s_client -connect myapp.com:443`
- [ ] Services responding: `curl https://myapp.com`
- [ ] Logs clean: `kubectl logs deployment/agic -n kube-system`

---

## 💰 Cost Control

### Reduce Dev Costs
```hcl
enable_waf = false           # Save ~$10/month
app_gateway_capacity = 1     # Minimum instance
# Total dev: ~$70/month
```

### Scale for Staging
```hcl
app_gateway_capacity = 2
enable_waf = true
waf_mode = "Detection"
# Total staging: ~$190/month
```

### Production HA Setup
```hcl
app_gateway_capacity = 2
enable_waf = true
waf_mode = "Prevention"
certificate_secret_id = "..."  # REQUIRED
# Total prod: ~$510/month
```

---

## 🚀 Next Steps

1. **Read** [DOMAIN_AND_APPGATEWAY_SETUP.md](DOMAIN_AND_APPGATEWAY_SETUP.md) - Full setup guide
2. **Deploy** - Run `terraform apply` in environments/dev
3. **Configure DNS** - Point your domain to AppGW IP
4. **Setup AGIC** - Install Application Gateway Ingress Controller
5. **Deploy Ingress** - Apply appgw-ingress.yaml to Kubernetes
6. **Verify** - Test https://myapp.com

---

**Quick Start:** Run `cd /Users/chetan/Terraform/environments/dev && terraform apply`  
**More Info:** See [DOMAIN_AND_APPGATEWAY_SETUP.md](DOMAIN_AND_APPGATEWAY_SETUP.md)  
**Status:** ✅ Ready for Deployment
