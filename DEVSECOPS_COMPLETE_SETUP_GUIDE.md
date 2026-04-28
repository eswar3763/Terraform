# DevSecOps Pipeline - Complete Setup & Deployment Guide

## 📋 Prerequisites

Before starting, ensure you have:

```bash
✓ Azure DevOps project created
✓ Azure subscription with sufficient credits ($200+)
✓ GitHub repository linked to Azure DevOps
✓ Local machine with Git, Docker, Maven installed
✓ Admin access to Azure DevOps
✓ Basic understanding of CI/CD pipelines
```

**Estimated Setup Time:** 2-3 hours  
**Estimated Monthly Cost:** $83 (dev) to $510 (prod)

---

## 🚀 PHASE 1: Configure Azure DevOps

### **Step 1.1: Create Azure DevOps Project**

```
1. Go to: https://dev.azure.com/
2. Sign in with your Microsoft account
3. Click: Create project
4. Name: "three-tier-app"
5. Description: "DevSecOps Pipeline for Three-Tier Microservices"
6. Visibility: Private (or Public)
7. Click: Create
```

### **Step 1.2: Link Your GitHub Repository**

```
1. In Azure DevOps project
2. Go to: Repos → Files
3. Click: Import a repository
4. Repository type: Git
5. Clone URL: [Your GitHub repo URL]
6. Click: Import
```

### **Step 1.3: Create Service Connections**

#### **For Azure Subscription:**

```
1. Go to: Project Settings → Service connections
2. Click: New service connection
3. Type: Azure Resource Manager
4. Authentication method: Service principal (automatic)
5. Subscription: [Your Azure subscription]
6. Resource Group: [Leave blank - will use tfvars]
7. Name: "Azure-Subscription"
8. Save
```

#### **For Azure Container Registry (ACR):**

```
1. New service connection
2. Type: Docker Registry
3. Registry type: Azure Container Registry
4. Subscription: [Your subscription]
5. Registry: acr3tierapp (if exists) or create new
6. Name: "ACR"
7. Save
```

#### **For Kubernetes Clusters:**

```
For each environment (dev, staging, prod):

1. New service connection
2. Type: Kubernetes
3. Authentication: Service Account
4. Server URL: [Get from AKS cluster]
5. Kubernetes secret: [Generate service account token]
6. Name: "dev-aks" (or staging-aks, prod-aks)
7. Save
```

Get AKS connection details:

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group rg-3tier-app-dev \
  --name aks-3tier-dev

# Verify connection
kubectl cluster-info
```

### **Step 1.4: Create Variable Groups (Secrets Management)**

In Azure DevOps:

```
Pipelines → Library → Variable groups
```

**Create Group 1: "sonarqube-secrets"**

```
Variables:
  sonarAuthToken: [Your SonarQube token]
  Check: "Keep this value secret" ✓
```

**Create Group 2: "snyk-secrets"**

```
Variables:
  snykToken: [Your Snyk API token]
  Check: "Keep this value secret" ✓
```

**Create Group 3: "azure-credentials"**

```
Variables:
  subscriptionId: [Your Azure subscription ID]
  clientId: [Service Principal client ID]
  clientSecret: [Service Principal secret]
  tenantId: [Azure tenant ID]
  All marked as secret ✓
```

---

## 🔐 PHASE 2: Setup SonarQube

### **Step 2.1: Deploy SonarQube**

**Option A: Docker Compose (Quick Start)**

```bash
mkdir ~/sonarqube-setup
cd ~/sonarqube-setup

# Create docker-compose file
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  sonarqube:
    image: sonarqube:9.9.3-community
    ports:
      - "9000:9000"
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://postgres:5432/sonarqube
      SONAR_JDBC_USERNAME: sonarqube
      SONAR_JDBC_PASSWORD: sonarqube_pass_123
    volumes:
      - ./sonarqube-data:/opt/sonarqube/data
      - ./sonarqube-logs:/opt/sonarqube/logs
    depends_on:
      - postgres

  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: sonarqube
      POSTGRES_PASSWORD: sonarqube_pass_123
      POSTGRES_DB: sonarqube
    volumes:
      - postgres-data:/var/lib/postgresql/data

volumes:
  postgres-data:
EOF

# Start services
docker-compose up -d

# Wait 2-3 minutes for startup
docker logs -f sonarqube
```

**Option B: Azure Container Instances (Cloud)**

```bash
# See SONARQUBE_SETUP_GUIDE.md for detailed steps
```

### **Step 2.2: Configure SonarQube**

```
1. Access: http://localhost:9000
2. Default login: admin / admin
3. Change password immediately
4. Go to: Administration → Security → Users
5. Create project: three-tier-app
6. Generate token: Profile → My Account → Security → Tokens
7. Name: "azure-pipeline"
8. Copy token to Azure DevOps secret variable
```

### **Step 2.3: Create Quality Gate**

```
In SonarQube:

1. Quality Gates → Create
2. Name: "Three-Tier App Gate"
3. Add conditions:
   - Code Coverage ≥ 80%
   - Bugs = 0
   - Vulnerabilities = 0
   - Security Hotspots reviewed = 100%
4. Set as default
```

---

## 🔓 PHASE 3: Setup Snyk

### **Step 3.1: Create Snyk Account**

```
1. Visit: https://snyk.io/
2. Sign up (GitHub, GitLab, or email)
3. Verify email
4. Complete onboarding
```

### **Step 3.2: Generate API Token**

```
1. In Snyk: Account Settings (bottom-left)
2. API Token tab
3. Click: "Show"
4. Copy token
5. Save to Azure DevOps secret variable: snykToken
```

### **Step 3.3: Connect Repository (Optional)**

```
1. In Snyk: Integrations
2. Select: GitHub
3. Authorize Snyk
4. Select repositories to monitor
5. Snyk will scan on pushes automatically
```

---

## 🔑 PHASE 4: Setup RBAC & Access Control

### **Step 4.1: Create Azure Service Principals**

```bash
# Run the script
chmod +x rbac/azure-service-principals.sh
./rbac/azure-service-principals.sh

# Output will contain credentials for:
# - dev-sp-credentials.json
# - staging-sp-credentials.json
# - prod-sp-credentials.json
```

### **Step 4.2: Configure Kubernetes RBAC**

```bash
# Apply RBAC policies
kubectl apply -f k8s/rbac-network-policies.yaml

# Verify
kubectl get roles -n three-tier-app
kubectl get rolebindings -n three-tier-app
kubectl get networkpolicies -n three-tier-app
```

### **Step 4.3: Setup Azure DevOps RBAC**

```
In Azure DevOps:

Project Settings → Security → Permissions
```

**Assign Roles:**

```
Developers:
  - Member (limited permissions)
  
DevOps Team:
  - Project Administrator
  
Security Team:
  - Stakeholder (read-only)
  
Release Manager:
  - Project Administrator
```

**Set Pipeline Approval:**

```
Pipelines → Environments → staging
  Approvers: [DevOps Lead name]
  Check: Auto-reject new changes
  Timeout: 24 hours

Pipelines → Environments → production
  Approvers: [Release Manager, Security Lead]
  Check: Auto-reject new changes
  Timeout: 48 hours
```

---

## 📝 PHASE 5: Create & Configure Pipeline

### **Step 5.1: Add Pipeline YAML File**

```bash
# Copy the azure-pipelines.yml to your repo root
cp azure-pipelines.yml /path/to/your/repo/

# Update with your values
sed -i 's/acr3tierapp/YOUR_ACR_NAME/g' azure-pipelines.yml
sed -i 's/sonarqube.example.com/YOUR_SONARQUBE_URL/g' azure-pipelines.yml

# Commit and push
git add azure-pipelines.yml
git commit -m "feat: Add DevSecOps CI/CD pipeline"
git push origin main
```

### **Step 5.2: Create Pipeline in Azure DevOps**

```
1. In Azure DevOps: Pipelines → New pipeline
2. Where is your code? GitHub
3. Select repository: [your-repo]
4. Configure: Existing Azure Pipelines YAML
5. Path: /azure-pipelines.yml
6. Click: Save and run
```

### **Step 5.3: Configure Pipeline Triggers**

```
Pipeline → Edit

Triggers:
  ✓ Pull request validation
    - Branches: main, develop
  ✓ Continuous integration
    - Branches: include main, develop
    - Paths: exclude docs/**

Scheduled Triggers:
  ✓ Nightly scans (optional)
    - Frequency: Daily
    - Time: 2:00 AM UTC
    - Branch: main
```

---

## 🧪 PHASE 6: Testing the Pipeline

### **Step 6.1: First Test Run - Feature Branch**

```bash
# Create feature branch
git checkout -b feature/test-pipeline

# Make small code change (not security-critical)
echo "# Test" >> README.md

# Commit and push
git add README.md
git commit -m "test: trigger pipeline"
git push origin feature/test-pipeline

# Create Pull Request in GitHub
# Azure DevOps will automatically trigger pipeline
```

### **Step 6.2: Monitor Pipeline Execution**

```
In Azure DevOps:

1. Go to: Pipelines → Runs
2. Click: Latest run
3. Watch each stage execute:
   - Initialize & Security Checks (5 min)
   - Build & Compile (5 min)
   - Code Quality Analysis (10 min)
   - Security Scanning (5 min)
   - Testing (10 min)
   - Build Containers (10 min)
   - Deploy Dev (5 min)
   - (Staging/Prod awaiting approval)
4. Total time: ~45-50 minutes first run
```

### **Step 6.3: Review Results**

```
After pipeline completes:

Artifacts:
  - Click: "Published" tab
  - Download: snyk-dependencies.json
  - Download: jacoco-report/

Test Results:
  - Click: "Tests" tab
  - View: Unit test results
  - View: Code coverage percentage

SonarQube:
  - Visit: http://localhost:9000
  - Project: three-tier-app
  - Review: Quality gate status

Snyk:
  - Visit: https://app.snyk.io/
  - Organization: three-tier-app
  - Review: Vulnerability findings
```

---

## 🚀 PHASE 7: Deployment Workflow

### **Step 7.1: Dev Deployment (Automatic)**

Dev environment deploys automatically on successful build:

```
✓ All stages pass
  ↓
[Auto-deploy to Dev]
  ↓
Services running in dev cluster
```

### **Step 7.2: Staging Deployment (Manual Approval)**

```
Pipeline reaches Stage 8: Deploy Staging
  ↓
Pipeline pauses (waiting for approval)
  ↓
Azure DevOps sends approval request email
  ↓
DevOps Lead logs into Azure DevOps
  ↓
Navigates to: Pipelines → Runs → [Pipeline ID]
  ↓
Clicks: [Approve] button
  ↓
Pre-deployment validation runs
  ↓
Services deployed to staging cluster
```

### **Step 7.3: Production Deployment (Multi-Approval)**

```
Pipeline reaches Stage 9: Deploy Production
  ↓
Checks if pushed to main branch:
  ✓ Yes: Continue
  ✗ No: Skip (only deploy from main)
  ↓
Pipeline pauses (waiting for 2 approvals)
  ↓
Approval 1: Release Manager approves
Approval 2: Security Lead approves
  ↓
All pre-deployment checks pass
  ↓
Services deployed to production cluster
  ↓
Post-deployment security audit
  ↓
Monitoring and alerting active
```

---

## 📊 PHASE 8: Monitoring & Maintenance

### **Step 8.1: Daily Monitoring**

```bash
# Check pipeline status
az pipelines runs list --org https://dev.azure.com/YOUR_ORG --project YOUR_PROJECT

# Check Kubernetes health
kubectl get nodes -A
kubectl get pods -n three-tier-app

# Check application logs
kubectl logs -f deployment/user-service -n three-tier-app
kubectl logs -f deployment/order-service -n three-tier-app
kubectl logs -f deployment/payment-service -n three-tier-app
```

### **Step 8.2: Weekly Reviews**

```
Security Checklist:
☐ Review Snyk dashboard for new vulnerabilities
☐ Check SonarQube for code quality trends
☐ Review failed pipeline runs (if any)
☐ Check Azure activity logs for unusual activity
☐ Verify all deployments successful
☐ Monitor application error rates
```

### **Step 8.3: Monthly Maintenance**

```
Tasks:
☐ Update base Docker images
☐ Update Maven dependencies
☐ Review and rotate secrets in Key Vault
☐ Check SSL certificate expiration dates
☐ Run security assessment
☐ Review RBAC assignments
☐ Archive old pipeline artifacts
☐ Update documentation
```

---

## 🐛 PHASE 9: Troubleshooting

### **Pipeline Failures**

**Stage 1: Initialize - Secret Found**

```
Error: Secret detected in git history
Solution:
1. Identify file with secret
2. Remove from code
3. Use git-secrets to clean history
4. Or: Use git filter-branch to remove
5. Force push (requires permissions)
```

**Stage 2: Build Fails - Dependency Issue**

```
Error: Maven cannot find dependency
Solution:
1. Check internet connectivity
2. Verify proxy settings if behind firewall
3. Clear Maven cache: mvn clean
4. Check pom.xml for typos
5. Try: mvn dependency:tree
```

**Stage 3: SonarQube - Quality Gate Failed**

```
Error: Coverage below 80%
Solution:
1. View SonarQube dashboard
2. Add unit tests for uncovered code
3. Rerun pipeline
4. Verify coverage improved

Error: Vulnerability found
Solution:
1. Review vulnerability details
2. Fix code issue or update library
3. Rerun pipeline
```

**Stage 4: Snyk - Vulnerability Found**

```
Error: CRITICAL vulnerability detected
Solution:
1. Check Snyk dashboard for details
2. Upgrade vulnerable dependency
3. Run: snyk test --dry-run
4. Verify fix
5. Commit and push
6. Pipeline auto-reruns
```

**Stage 6: Docker Build - Image too Large**

```
Error: Image exceeds 500MB
Solution:
1. Use multi-stage Dockerfile
2. Remove unnecessary files
3. Use .dockerignore
4. Minimize base image
5. Rebuild: docker build --no-cache
```

**Stage 7: Kubernetes Deploy - Image Pull Failed**

```
Error: ImagePullBackOff
Solution:
1. Verify ACR credentials
2. Verify image exists in ACR
3. Check image name/tag spelling
4. Verify network connectivity
5. Check: kubectl describe pod [pod-name]
```

**Stage 8: Staging Approval - No Approval Button**

```
Error: Approval button not appearing
Solution:
1. Check environment approvers configured
2. Verify you have approval permissions
3. Refresh Azure DevOps browser
4. Check pipeline status is paused
5. Contact Azure DevOps admin
```

### **Container Issues**

**Health Check Failing**

```bash
# Check pod status
kubectl get pods -n three-tier-app

# Check logs
kubectl logs [pod-name] -n three-tier-app

# Check events
kubectl describe pod [pod-name] -n three-tier-app

# Test health endpoint manually
kubectl port-forward [pod-name] 8080:8080
curl http://localhost:8080/actuator/health
```

**Service Not Accessible**

```bash
# Check service
kubectl get svc -n three-tier-app

# Check endpoints
kubectl get endpoints -n three-tier-app

# Check network policies
kubectl get networkpolicies -n three-tier-app

# Test connectivity
kubectl exec -it [pod-name] -- curl http://order-service:8082
```

### **Security Scanning Issues**

**SonarQube Connection Timeout**

```bash
# Check SonarQube running
docker ps | grep sonarqube

# Check network connectivity
telnet sonarqube.example.com 9000

# Verify token valid
curl -u $SONAR_TOKEN: https://sonarqube.example.com/api/user/current
```

**Snyk Authentication Failed**

```bash
# Verify token
echo $SNYK_TOKEN

# Test Snyk CLI
snyk auth $SNYK_TOKEN
snyk test --debug
```

---

## ✅ Validation Checklist

### **Before Going to Production**

```
Infrastructure:
☐ All three AKS clusters created (dev, staging, prod)
☐ MySQL databases created for each environment
☐ Application Gateway deployed
☐ Load Balancer deployed
☐ SSL certificates installed
☐ Key Vault configured with secrets

Pipeline:
☐ azure-pipelines.yml committed to repo
☐ All stages executing successfully
☐ SonarQube connected and scanning
☐ Snyk connected and scanning
☐ Unit tests passing with ≥80% coverage
☐ Container images built and pushed to ACR
☐ Dev deployment successful

Security:
☐ RBAC policies applied
☐ Network policies applied
☐ Managed Identities configured
☐ Azure Key Vault configured
☐ Secrets not hardcoded anywhere
☐ All vulnerabilities remediated
☐ No CRITICAL/HIGH unresolved issues

Approvals:
☐ Release managers assigned
☐ Security leads assigned
☐ Approval workflows configured
☐ Notification channels setup (email/Slack)

Monitoring:
☐ Application logs flowing
☐ Prometheus metrics exposed
☐ Kubernetes events monitored
☐ Alerts configured
☐ Runbooks documented
☐ On-call rotation established
```

---

## 📞 Support & Resources

### **If Something Goes Wrong**

```
1. Check logs first:
   - Pipeline logs (Azure DevOps)
   - Container logs (kubectl logs)
   - SonarQube logs
   - Snyk logs
   
2. Search documentation:
   - README.md (this repo)
   - AZURE_PIPELINE_STAGES_EXPLAINED.md
   - SONARQUBE_SETUP_GUIDE.md
   - SNYK_INTEGRATION_GUIDE.md
   
3. Common issues:
   - See PHASE 9: Troubleshooting (above)
   
4. Get help:
   - Azure DevOps support
   - SonarQube community
   - Snyk support
   - GitHub issues
```

### **Documentation Reference**

```
Pipeline Overview:
  → AZURE_PIPELINE_STAGES_EXPLAINED.md

Security Details:
  → DEVSECOPS_POLICIES.md
  
SonarQube:
  → SONARQUBE_SETUP_GUIDE.md
  
Snyk:
  → SNYK_INTEGRATION_GUIDE.md
  
RBAC:
  → rbac/azure-service-principals.sh
  → k8s/rbac-network-policies.yaml
  
Terraform:
  → AZURE_DEPLOYMENT_GUIDE.md
```

---

## 🎓 Learning Path

```
Week 1: Setup
  Day 1-2: Azure DevOps & Service Connections
  Day 3: SonarQube & Snyk setup
  Day 4: Create first pipeline run
  Day 5: Monitor and troubleshoot

Week 2: Understanding
  Day 1: Read pipeline stages explanation
  Day 2: Review SonarQube results
  Day 3: Analyze Snyk findings
  Day 4: Study RBAC configuration
  Day 5: Practice approvals/deployments

Week 3: Optimization
  Day 1: Improve test coverage
  Day 2: Fix security vulnerabilities
  Day 3: Optimize pipeline performance
  Day 4: Configure notifications
  Day 5: Create runbooks

Week 4: Advanced
  Day 1: Setup Slack integration
  Day 2: Configure advanced metrics
  Day 3: Implement advanced RBAC
  Day 4: Create custom quality gates
  Day 5: Plan disaster recovery
```

---

## 🎉 Completion Checklist

After following this guide:

```
Phase 1: Azure DevOps Setup
  ☐ Project created
  ☐ Repo linked
  ☐ Service connections configured
  ☐ Variable groups created

Phase 2: SonarQube Setup
  ☐ SonarQube deployed
  ☐ Project created
  ☐ Token generated
  ☐ Quality gate configured

Phase 3: Snyk Setup
  ☐ Account created
  ☐ Token generated
  ☐ Repo connected (optional)

Phase 4: RBAC Setup
  ☐ Service principals created
  ☐ Kubernetes RBAC applied
  ☐ Azure DevOps RBAC configured
  ☐ Approvals configured

Phase 5: Pipeline Created
  ☐ YAML file added
  ☐ Pipeline created in Azure DevOps
  ☐ Triggers configured

Phase 6: Testing Complete
  ☐ First test run successful
  ☐ All stages executing
  ☐ Results reviewed

Phase 7: Deployments Working
  ☐ Dev auto-deploys
  ☐ Staging approvals work
  ☐ Production approvals work

Phase 8: Monitoring Active
  ☐ Logs flowing
  ☐ Metrics collected
  ☐ Alerts configured

Phase 9: Troubleshooting Ready
  ☐ Know how to debug
  ☐ Have runbooks
  ☐ Know support contacts

YOU ARE READY FOR PRODUCTION! ✅
```

---

## 🚀 Next Steps

1. **Start with Phase 1:** Set up Azure DevOps
2. **Follow Phases 2-4:** Configure security tools
3. **Complete Phase 5:** Create pipeline
4. **Test in Phase 6:** Run first build
5. **Deploy in Phase 7:** Use approval workflows
6. **Monitor in Phase 8:** Watch it work
7. **Reference Phase 9:** When issues arise

**Estimated time to full setup:** 3-4 hours  
**Estimated time for first production deployment:** 6-8 hours (including testing)

---

**Questions?** See related documentation files or contact your security/DevOps team.

**Last Updated:** April 2026  
**Status:** Production Ready
