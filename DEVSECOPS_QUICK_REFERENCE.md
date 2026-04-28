# DevSecOps Pipeline - Quick Reference Cheatsheet

## 📋 At a Glance

```
PIPELINE FLOW:
Git Push → Initialize → Build → Code Analysis → Security Scan → Test
  → Container Build → Deploy Dev (auto) → Deploy Staging (approval)
  → Deploy Production (multi-approval) → Compliance Report

TOOLS:
- Azure Pipelines: Orchestration
- SonarQube: Code quality & SAST
- Snyk: Dependency & container security
- OWASP: Vulnerability database
- Trivy: Container scanning
- Kubernetes RBAC: Access control
- Azure Key Vault: Secrets management
```

---

## 🎯 Quick Setup (30 minutes)

```bash
# 1. Clone repo
git clone [your-repo-url]
cd [repo-directory]

# 2. Copy pipeline file
cp azure-pipelines.yml /path/to/repo/

# 3. Update with your values
sed -i 's/YOUR_ACR/your-acr-name/g' azure-pipelines.yml
sed -i 's/YOUR_SONARQUBE/your-sonarqube-url/g' azure-pipelines.yml

# 4. Commit
git add azure-pipelines.yml
git commit -m "Add DevSecOps pipeline"
git push

# 5. Create in Azure DevOps
# Go to: Pipelines → New → Select repo → Use existing YAML

# 6. Run first build
# Click: Run
```

---

## 🔑 Essential Credentials

```
Store these as secrets in Azure DevOps (Settings → Library → Variable groups):

sonarqube-secrets:
  ├─ sonarAuthToken: [Your SonarQube token]
  └─ SONAR_HOST_URL: https://your-sonarqube-instance

snyk-secrets:
  └─ snykToken: [Your Snyk API token]

azure-credentials:
  ├─ subscriptionId: [Azure subscription ID]
  ├─ clientId: [Service Principal ID]
  ├─ clientSecret: [Service Principal secret]
  └─ tenantId: [Azure tenant ID]
```

---

## 🔐 Service Connections to Create

```
In Azure DevOps → Project Settings → Service connections:

1. Azure Resource Manager
   Name: Azure-Subscription
   Subscription: [Your subscription]

2. Docker Registry
   Name: ACR
   Registry: [Your ACR instance]

3. Kubernetes (for each cluster)
   Name: dev-aks, staging-aks, prod-aks
   Server: [AKS cluster URL]
   Service Account Token: [Generated]
```

---

## 📊 Pipeline Stages Summary

| Stage | Purpose | Time | Action on Fail |
|-------|---------|------|----------------|
| **1. Initialize** | Pre-build security | 5 min | Stop ❌ |
| **2. Build** | Maven compile | 5 min | Stop ❌ |
| **3. Code Quality** | SonarQube analysis | 10 min | Stop ❌ |
| **4. Security Scan** | Snyk + OWASP | 5 min | Stop ❌ |
| **5. Testing** | Unit + Integration | 10 min | Stop ❌ |
| **6. Containers** | Docker build+push | 10 min | Stop ❌ |
| **7. Dev Deploy** | Auto deploy | 5 min | Stop ❌ |
| **8. Staging Deploy** | Manual approval | - | Await approval ⏳ |
| **9. Prod Deploy** | Multi-approval | - | Await approval ⏳ |
| **10. Compliance** | Reports | 5 min | Archive only 📋 |

**Total Time:** ~45-50 min (first run), ~35-40 min (cached)

---

## 🛡️ Security Gates

```
✓ MUST PASS (or pipeline stops):
  ├─ No secrets in code (git-secrets)
  ├─ SonarQube Quality Gate
  ├─ Code Coverage ≥ 80%
  ├─ Snyk: 0 CRITICAL/HIGH vulnerabilities
  ├─ All unit tests pass
  ├─ All integration tests pass
  └─ No CRITICAL Docker vulnerabilities

⏳ REQUIRES APPROVAL (or waits):
  ├─ Staging deployment (1 approver, 24h timeout)
  └─ Production deployment (2 approvers, 48h timeout)

ℹ️ WARNINGS (doesn't block, but tracks):
  ├─ Code smells > 5
  ├─ Duplicated code > 3%
  ├─ Snyk MEDIUM vulnerabilities
  └─ Container warnings (runs as root, no health checks)
```

---

## 🧪 Running the Pipeline

```
Method 1: Manual Trigger
  1. Pipelines → Runs
  2. Click: Run pipeline
  3. Branch: main (or your branch)
  4. Click: Run

Method 2: On Git Push
  Automatic (triggers on push to main/develop)

Method 3: Scheduled
  Daily nightly scans (optional, set in YAML)
```

---

## 📈 Monitoring Pipeline

```bash
# View pipeline status
az pipelines runs list --project three-tier-app

# View specific run
az pipelines runs show --id [RUN_ID] --project three-tier-app

# Get detailed logs
az pipelines runs log --id [RUN_ID] --path [STAGE] --project three-tier-app
```

**Or in Azure DevOps UI:**
```
Pipelines → Runs → [Select run] → See each stage
```

---

## 🔍 Accessing Results

```
SonarQube:
  URL: http://localhost:9000
  Project: three-tier-app
  Metrics: Coverage, Bugs, Vulnerabilities

Snyk:
  URL: https://app.snyk.io/
  Organization: three-tier-app
  Metrics: Dependencies, Code issues, Containers

Azure DevOps:
  Pipeline: Pipelines → Runs → [Run]
  Tests: Tests tab
  Coverage: Code coverage tab
  Artifacts: Published artifacts
```

---

## 🚀 Deployment Approvals

### **Staging Deployment**

```
1. Pipeline pauses at Stage 8
2. Azure DevOps sends approval email
3. DevOps lead logs in:
   Pipelines → Runs → [Run ID] → Approvals
4. Click: Approve (or Reject)
5. Pre-deployment checks run
6. Services deployed to staging cluster
7. Post-deployment validation
```

### **Production Deployment**

```
Only available from main branch!

1. Pipeline reaches Stage 9
2. Checks: if branch != main → Skip
3. If main: Pauses for approvals
4. Email sent to:
   - Release Manager
   - Security Lead
5. Both must approve within 48 hours
6. If approved: Production deployment
7. Post-deployment security audit
```

---

## 🐛 Debugging Failed Stages

```
Stage 1 Failed: Initialize
  → Check logs for secrets
  → Verify git-secrets configured
  → Run: git secrets --scan

Stage 2 Failed: Build
  → Check Maven logs
  → Verify Java version correct
  → Run: mvn clean package -X

Stage 3 Failed: Code Quality
  → Check SonarQube dashboard
  → Verify quality gate settings
  → Add tests to improve coverage

Stage 4 Failed: Security Scan
  → Check Snyk dashboard for CVEs
  → Update vulnerable dependencies
  → Run: snyk test --dry-run

Stage 5 Failed: Testing
  → Check test logs in pipeline
  → Run tests locally: mvn test
  → Fix failing tests

Stage 6 Failed: Containers
  → Check Docker build logs
  → Verify Dockerfile syntax
  → Check ACR credentials
  → Run: docker build -f Dockerfile.springboot .

Stage 7+ Failed: Deployment
  → Check kubectl logs
  → Verify image exists in ACR
  → Check cluster connectivity
  → Run: kubectl describe pod [pod-name]

Stage 8/9 Failed: Approval
  → Check approval settings
  → Verify approvers assigned
  → Check email notifications
```

---

## 🔐 RBAC Quick Reference

```
Kubernetes Roles (in three-tier-app namespace):

Developer (dev-team-sa):
  ✓ Get, list, watch deployments
  ✓ Create, update, patch deployments
  ✓ Read logs, exec into pods
  ✗ Cannot delete anything
  ✗ Cannot access secrets

Pipeline (pipeline-deployer-sa):
  ✓ Full control of deployments
  ✓ Create/update/delete services
  ✓ Create/update/patch secrets
  ✓ Scale deployments
  ✗ Cannot access cluster admin

Monitoring (monitoring-sa):
  ✓ Get, list, watch all resources
  ✓ Read metrics and events
  ✗ Cannot modify anything
  ✗ Cannot delete anything
```

**Apply RBAC:**
```bash
kubectl apply -f k8s/rbac-network-policies.yaml
```

---

## 📊 Key Metrics to Watch

```
Code Quality (SonarQube):
  Coverage: ≥ 80% (target 90%)
  Bugs: 0 (current: [check dashboard])
  Vulnerabilities: 0 (current: [check dashboard])
  Code Smells: ≤ 5 (current: [check dashboard])

Security (Snyk):
  CRITICAL: 0 (block if > 0)
  HIGH: 0 (block if > 0)
  MEDIUM: ≤ 5 (warn if more)
  LOW: Track (don't block)

Testing:
  Coverage: ≥ 80%
  Pass Rate: 100%
  Execution Time: < 15 min

Deployment Success:
  Dev: 100% (auto-deploy)
  Staging: 100% (on approval)
  Prod: 100% (on approval)
```

---

## 🛠️ Common Commands

```bash
# Test locally before pushing
mvn clean package
mvn test
mvn verify
mvn sonar:sonar
snyk test

# Build Docker images
docker build -f Dockerfile.springboot -t user-service:latest .

# Push to ACR
docker push acr3tierapp.azurecr.io/user-service:latest

# Deploy to Kubernetes
kubectl apply -f k8s/

# Check deployment status
kubectl get deployments -n three-tier-app
kubectl get pods -n three-tier-app
kubectl logs -f deployment/user-service -n three-tier-app

# Scale a deployment
kubectl scale deployment user-service --replicas=3 -n three-tier-app

# Watch resources
kubectl get all -n three-tier-app --watch
```

---

## 📚 Documentation Quick Links

```
COMPLETE GUIDES:
  → DEVSECOPS_COMPLETE_SETUP_GUIDE.md (9 phases, 2-3 hours)
  → AZURE_PIPELINE_STAGES_EXPLAINED.md (detailed stage explanations)

TOOL-SPECIFIC:
  → SONARQUBE_SETUP_GUIDE.md (installation + configuration)
  → SNYK_INTEGRATION_GUIDE.md (setup + usage)
  → DEVSECOPS_POLICIES.md (security policies + best practices)

RBAC & SECURITY:
  → rbac/azure-service-principals.sh (create service principals)
  → k8s/rbac-network-policies.yaml (Kubernetes RBAC + policies)

INFRASTRUCTURE:
  → AZURE_DEPLOYMENT_GUIDE.md (Terraform deployment)
  → DEPLOYMENT_SUMMARY.md (high-level overview)
```

---

## 🎓 Learning Resources

```
SonarQube:
  Docs: https://docs.sonarqube.org/
  Dashboard: http://localhost:9000

Snyk:
  Docs: https://docs.snyk.io/
  Dashboard: https://app.snyk.io/

Azure DevOps:
  Docs: https://learn.microsoft.com/en-us/azure/devops/
  Dashboard: https://dev.azure.com/

Kubernetes:
  Docs: https://kubernetes.io/docs/
  Cheatsheet: https://kubernetes.io/docs/reference/kubectl/cheatsheet/

OWASP:
  Top 10: https://owasp.org/Top10/
  Cheatsheet: https://cheatsheetseries.owasp.org/
```

---

## ✅ Daily Checklist

```
Every day:
  ☐ Check pipeline runs (no failures?)
  ☐ Review Snyk dashboard (new vulnerabilities?)
  ☐ Check SonarQube (coverage stable?)
  ☐ Monitor deployments (all healthy?)
  ☐ Check logs (any errors?)

Weekly:
  ☐ Review all failed runs
  ☐ Update dependencies
  ☐ Check certificate expiry dates
  ☐ Review access logs
  ☐ Security metrics review

Monthly:
  ☐ RBAC review
  ☐ Vulnerability assessment
  ☐ Compliance check
  ☐ Disaster recovery test
  ☐ Update documentation
```

---

## 🎯 Success Metrics

```
Pipeline Reliability:
  Target: 95% success rate
  Current: [Check last 20 runs]

Code Quality:
  Target: Coverage ≥ 80%, 0 bugs
  Current: [Check SonarQube dashboard]

Security:
  Target: 0 CRITICAL/HIGH vulnerabilities
  Current: [Check Snyk dashboard]

Deployment Speed:
  Target: Full pipeline < 50 minutes
  Current: [Check pipeline execution time]

MTTR (Mean Time To Recovery):
  Target: < 30 minutes for failures
  Current: [Track incidents]
```

---

## 🚨 Emergency Procedures

**If Pipeline is Always Failing:**
```
1. Check latest run logs
2. Look for pattern (always same stage?)
3. Run stage manually locally
4. Verify service connections
5. Check variable groups updated
6. Verify SonarQube/Snyk online
7. Contact tool support if stuck
```

**If Production Deployment Stuck:**
```
1. Check approval status
2. Ensure approvers have permissions
3. Check email for approval requests
4. Verify not exceeded timeout
5. Contact release manager
6. If urgent: Manual override (dangerous!)
```

**If Container Won't Start:**
```
1. Check pod logs: kubectl logs [pod]
2. Check pod events: kubectl describe pod [pod]
3. Check image in ACR exists
4. Check resource limits
5. Check health checks
6. Rollback to previous version
```

---

## 📞 Support Matrix

```
Issue Category         | Primary Resource      | Secondary Resource
─────────────────────  | ─────────────────────  | ──────────────────
Pipeline failures      | Azure DevOps logs     | TROUBLESHOOTING section
SonarQube issues       | SONARQUBE_SETUP doc   | SonarQube documentation
Snyk issues            | SNYK_INTEGRATION doc  | Snyk support
Kubernetes errors      | kubectl describe      | K8s documentation
RBAC/Access issues     | k8s RBAC policy file  | Azure DevOps settings
Deployment failures    | Container logs        | Pod events
Network issues         | Network policies      | NSG rules
Secret management      | Key Vault policies    | Azure documentation
```

---

## ⏱️ Typical Timelines

```
First Time Setup: 2-3 hours
  - Configure Azure DevOps: 30 min
  - Setup SonarQube: 30 min
  - Setup Snyk: 15 min
  - Configure RBAC: 30 min
  - Create pipeline: 15 min
  - First run + troubleshooting: 30 min

First Production Deployment: 6-8 hours
  - Dev environment: ready after first run
  - Staging environment: ready after approval
  - Production environment: ready after 2 approvals
  - Testing: 2-3 hours per environment
  - Monitoring: 1-2 hours post-deployment

Ongoing Maintenance: 1-2 hours/week
  - Monitor metrics
  - Fix vulnerabilities
  - Update dependencies
  - Review logs and security events
```

---

## 🎉 Success Indicators

```
✅ Pipeline is "GREEN" (all stages pass)
✅ SonarQube shows Quality Gate: PASSED
✅ Snyk shows: 0 CRITICAL/HIGH vulnerabilities
✅ Code coverage is ≥ 80%
✅ All tests passing
✅ Container images scanned clean
✅ Dev deployment automatic and successful
✅ Staging approvals work smoothly
✅ Production deployment controlled and audited
✅ Monitoring and logging in place
✅ Team trained on processes

YOU'RE PRODUCTION READY! 🚀
```

---

**Last Updated:** April 2026  
**Status:** Active & Maintained  
**Next Review:** June 2026

---

**Pro Tips:**
- Always test changes in feature branch first
- Run pipeline locally before pushing (mvn clean verify)
- Read SonarQube findings, don't just add tests
- Keep security tools updated
- Monitor trends, not just individual metrics
- Document exceptions and approvals
- Practice disaster recovery monthly
