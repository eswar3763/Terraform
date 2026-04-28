# DevSecOps Policies & Azure Security Best Practices

## 📋 Table of Contents

1. DevSecOps Principles
2. Security Gates & Policies
3. Azure Security Best Practices
4. Compliance & Auditing
5. Incident Response
6. Secure Development Practices

---

## 🎯 **DevSecOps Principles**

### **Core Concept**
"Security is everyone's responsibility, integrated into every step of development and deployment."

```
Traditional Approach:
Development → Testing → Operations → (Security Review?) ❌

DevSecOps Approach:
Dev → (Security) → Test → (Security) → Deploy → (Security) → Monitor ✓
```

### **The 5 Pillars of DevSecOps**

```
1. CULTURE
   ├─ Security mindset in development teams
   ├─ Developers trained on secure coding
   └─ Shared responsibility model

2. PROCESSES
   ├─ Security gates in CI/CD pipeline
   ├─ Automated compliance checking
   └─ Regular security audits

3. TECHNOLOGY
   ├─ SAST (SonarQube) - Static analysis
   ├─ Dependency scanning (Snyk, OWASP)
   ├─ DAST (Dynamic testing)
   └─ Container scanning (Trivy)

4. GOVERNANCE
   ├─ RBAC (Role-based access control)
   ├─ Policy enforcement
   ├─ Audit logging
   └─ Compliance (SOC 2, ISO 27001)

5. OPERATIONS
   ├─ Continuous monitoring
   ├─ Incident response
   ├─ Vulnerability management
   └─ Security updates
```

---

## 🚨 **Security Gates & Policies**

### **Gate 1: Pre-Commit (Developer Machine)**

**Policy:** *Secure code before pushing*

```bash
# Local checks before git push
1. Run SonarLint IDE plugin
2. Run Snyk test locally
3. Check for hardcoded secrets (git-secrets)
4. Run unit tests locally
```

**Enforcement:**
```bash
# Install pre-commit hooks
git config core.hooksPath ./git-hooks
chmod +x git-hooks/*

# Hooks check:
- Secrets scanning
- Code formatting
- Linting
```

**Failure Action:** ❌ Commit blocked until fixed

---

### **Gate 2: Stage 1 - Initialization**

**Policy:** *Detect threats early*

**Checks:**
```
✓ Git commit verification
✓ Secret scanning (git-secrets)
✓ Code pattern detection (hardcoded credentials)
✓ SBOM creation
```

**Rules:**
```
IF (secret_detected):
  FAIL pipeline immediately
  ALERT security team
  REQUIRE commit reverted

IF (malicious_pattern_found):
  WARN developer
  REQUIRE manual review
  
IF (dependency_vulnerability):
  FAIL pipeline
  REQUIRE fix before proceeding
```

**Failure Action:** ❌ Pipeline stops → Email notification

---

### **Gate 3: Stage 3 - Code Quality**

**Policy:** *Maintain code quality standards*

**SonarQube Quality Gate Rules:**

```
Rule 1: Code Coverage
  Target: ≥ 80%
  Action: FAIL if < 80%
  Reasoning: Untested code = security risk

Rule 2: Critical Bugs
  Target: = 0
  Action: FAIL if > 0
  Reasoning: Bugs can be exploited

Rule 3: Vulnerabilities
  Target: = 0
  Action: FAIL if found
  Reasoning: Known vulnerabilities must be fixed

Rule 4: Security Hotspots
  Target: All reviewed
  Action: FAIL if unreviewed
  Reasoning: Potential security issues need assessment

Rule 5: Code Smells
  Target: ≤ 5 new issues
  Action: WARN if > 5 new
  Reasoning: Complex code harder to secure
```

**Failure Action:** ❌ Code review required, fix and retest

---

### **Gate 4: Stage 4 - Security Scanning**

**Policy:** *No known vulnerabilities*

**Snyk Rules:**

```
Rule 1: CRITICAL Severity
  Threshold: 0
  Action: BLOCK pipeline
  Timeline: Fix within 24 hours
  Escalation: Security + Development leads

Rule 2: HIGH Severity
  Threshold: 0 (for prod), 5 (for dev)
  Action: BLOCK prod deployment
  Timeline: Fix within 7 days
  Escalation: Development lead approval required

Rule 3: MEDIUM Severity
  Threshold: 20 (for dev)
  Action: LOG + TRACK
  Timeline: Fix within 30 days
  Escalation: Plan in sprint backlog
```

**OWASP Dependency Check:**

```
Rule 1: HIGH/CRITICAL CVE
  Action: BLOCK deployment
  Requirement: Update dependency to patched version

Rule 2: Manual Review Required
  Action: FAIL with detailed findings
  Requirement: Security architect sign-off
```

**Trivy Container Scanning:**

```
Rule 1: Base Image Vulnerabilities
  Target: 0 CRITICAL/HIGH
  Action: Use patched base image

Rule 2: Non-root User
  Target: Required
  Action: FAIL if running as root

Rule 3: Health Checks
  Target: Required
  Action: WARN if missing

Rule 4: Resource Limits
  Target: Required
  Action: WARN if not defined
```

**Failure Action:** ❌ Deployment blocked, fix vulnerabilities

---

### **Gate 5: Stage 5 - Testing**

**Policy:** *Proven functionality*

**Unit Test Requirements:**

```
Rule 1: Code Coverage
  Target: ≥ 80%
  Action: FAIL if lower
  Focus: Security-critical code (auth, payment)

Rule 2: Test Execution
  Target: 100% passing
  Action: BLOCK if failures
  Timeout: 15 minutes per service

Rule 3: Security Tests
  Required tests:
  ✓ SQL injection prevention
  ✓ XSS prevention
  ✓ Authentication/Authorization
  ✓ Input validation
```

**Integration Test Requirements:**

```
Rule 1: Service Communication
  Test: Services can reach each other
  Requirement: Database connectivity works

Rule 2: API Security
  Test: Endpoints require authentication
  Test: Authorization enforced
  Test: Rate limiting works

Rule 3: Data Validation
  Test: Invalid input rejected
  Test: SQL injection attempts blocked
```

**Failure Action:** ❌ Fix tests, rerun stage

---

### **Gate 6: Stage 6 - Container Build**

**Policy:** *Secure images*

**Docker Build Rules:**

```
Rule 1: Base Image
  Requirement: Must be officially supported
  Examples: openjdk:11-jdk-slim (✓), scratch (✗)
  Check: Snyk container scan

Rule 2: Non-root User
  Requirement: ADD USER appuser && USER appuser
  Reasoning: Limits container escape damage

Rule 3: No Secrets
  Requirement: No hardcoded credentials
  Check: git-secrets scan Dockerfile

Rule 4: Health Checks
  Requirement: HEALTHCHECK defined
  Example: HEALTHCHECK CMD curl -f http://localhost:8080/health

Rule 5: Minimal Layers
  Requirement: Efficient Dockerfile
  Pattern: RUN && RUN && RUN (combine commands)

Rule 6: Image Scan
  Tool: Snyk container test
  Requirement: No CRITICAL/HIGH vulns
```

**Image Repository Access:**

```
Dev:      All developers can push
Staging:  Only CI/CD pipeline can push
Prod:     Only approved pipeline + manual tag
```

**Failure Action:** ❌ Fix image, rebuild and rescan

---

### **Gate 7: Environment Deployment**

**Policy:** *Controlled rollout*

```
DEV:
  ├─ Auto-deploy on pipeline success
  ├─ No approval needed
  └─ Can deploy at any time

STAGING:
  ├─ Requires 1 approval (DevOps lead)
  ├─ 24-hour approval timeout
  └─ Pre-deployment security checks
      ├─ Network policies verified
      ├─ RBAC assignments checked
      └─ SSL certificates valid

PRODUCTION:
  ├─ Requires 2 approvals:
  │  ├─ Release Manager
  │  └─ Security Lead
  ├─ 48-hour approval timeout
  ├─ Only from main branch
  ├─ Pre-deployment security audit:
  │  ├─ All scanning passed
  │  ├─ Compliance check passed
  │  ├─ Backup verified
  │  └─ Rollback plan documented
  └─ Post-deployment:
     ├─ Health checks passing
     ├─ Security audit
     └─ Monitoring active
```

**Deployment Approval Checklist:**

```
Security Checklist (PROD):
  ☐ All CRITICAL/HIGH vulnerabilities resolved
  ☐ Code coverage ≥ 80%
  ☐ No new security hotspots
  ☐ All tests passing
  ☐ Container images scanned clean
  ☐ RBAC policies configured
  ☐ Network policies active
  ☐ SSL certificates valid
  ☐ Monitoring configured
  ☐ Backup strategy in place
```

---

## 🔒 **Azure Security Best Practices**

### **1. Azure Key Vault - Secret Management**

**Policy:** *Never hardcode secrets*

**Implementation:**

```hcl
# Store in Key Vault, not code
resource "azurerm_key_vault" "kv" {
  name                = "kv3tierapp-${var.environment}"
  resource_group_name = azurerm_resource_group.env_rg.name
  
  # Access control
  enable_rbac_authorization = true
  
  # Audit trail
  enable_purge_protection = true  # Prod only
  soft_delete_retention_days = 90
}

# Secrets to store:
- MySQL admin password
- API keys (external services)
- JWT signing keys
- Database connection strings
- SSL certificates
```

**Access:**

```bash
# From application (Managed Identity - NO CREDENTIALS!)
az keyvault secret show \
  --vault-name kv3tierapp-prod \
  --name "db-password" \
  --query value -o tsv
```

---

### **2. Managed Identities - No Passwords**

**Policy:** *Use Managed Identities for Azure resources*

```hcl
# Create managed identity
resource "azurerm_user_assigned_identity" "agic" {
  name                = "agic-identity-${var.environment}"
  resource_group_name = azurerm_resource_group.env_rg.name
}

# Assign to resources
resource "azurerm_role_assignment" "agic_contributor" {
  scope              = azurerm_resource_group.env_rg.id
  role_definition_name = "Contributor"
  principal_id       = azurerm_user_assigned_identity.agic.principal_id
}
```

**Benefits:**
- ✅ No credentials to manage
- ✅ Automatic token rotation
- ✅ Audit trail in Azure
- ✅ RBAC-integrated

---

### **3. Network Security**

**Policy:** *Defense in depth*

```hcl
# Kubernetes Network Policies
- Deny all ingress by default
- Allow only required traffic
- Strict pod-to-pod communication

# Application Gateway WAF
- Enable in production
- Set to "Prevention" mode
- Custom rules for your API

# NSG (Network Security Groups)
- Restrict SSH access (bastion only)
- Allow only necessary ports
- Separate ingress/egress rules
```

**Example Network Policy:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

---

### **4. Encryption**

**Policy:** *Encrypt everything*

**At Rest:**
```hcl
# Azure Storage
resource "azurerm_storage_account" "storage" {
  infrastructure_encryption_enabled = true  # Encrypt keys too
  https_traffic_only_enabled         = true
  min_tls_version                    = "TLS1_2"
}

# Azure MySQL
resource "azurerm_mysql_flexible_server" "mysql" {
  ssl_enabled = true
  geo_redundant_backup_enabled = true  # Prod
}
```

**In Transit:**
```
- HTTPS only (no HTTP)
- TLS 1.2+
- Strong cipher suites
- Certificate validation
```

---

### **5. Audit Logging**

**Policy:** *Log everything for compliance*

```hcl
# Enable diagnostics for all resources
resource "azurerm_monitor_diagnostic_setting" "appgw_diag" {
  name                       = "appgw-diagnostics"
  target_resource_id         = azurerm_application_gateway.appgw.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  
  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }
  
  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }
  
  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }
}
```

**What to Log:**
- ✓ All API calls
- ✓ Authentication attempts
- ✓ Authorization decisions
- ✓ Configuration changes
- ✓ Deployment activities
- ✓ Security events

**Retention:**
```
Dev:      30 days
Staging:  90 days
Prod:     1 year (compliance requirement)
```

---

### **6. RBAC - Role-Based Access Control**

**Policy:** *Least privilege access*

```
Developers:
  ✓ Deploy to dev
  ✓ View logs
  ✗ Cannot deploy to prod
  ✗ Cannot modify policies

DevOps/SRE:
  ✓ Deploy to all environments
  ✓ Modify infrastructure
  ✓ Approve deployments
  ✗ Cannot delete resources (protected)

Security Team:
  ✓ Audit everything
  ✓ View all logs
  ✗ Cannot modify (read-only)

Operations:
  ✓ Monitor resources
  ✓ View metrics
  ✗ Cannot deploy or modify
```

**Kubernetes RBAC (per namespace):**

```yaml
# Dev team: can deploy to dev namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: dev-deployer
  namespace: three-tier-app
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
```

---

## 📊 **Compliance & Auditing**

### **Compliance Requirements**

**SOC 2 Type II:**
```
Required Controls:
✓ Access controls (RBAC)
✓ Change management (audit trail)
✓ Encryption (data at rest/transit)
✓ Availability monitoring
✓ Incident response procedures
```

**ISO 27001:**
```
Required Controls:
✓ Information classification
✓ Access control matrix
✓ Cryptographic procedures
✓ Physical/logical security
✓ Audit logging
✓ Incident handling
```

**GDPR (if EU customers):**
```
Required Controls:
✓ Data minimization
✓ Purpose limitation
✓ Consent management
✓ Right to be forgotten
✓ Data breach notification (72 hours)
```

### **Audit Trail**

**What Gets Logged:**

```
Azure Audit Logs:
├─ Who: Azure AD user/service principal
├─ What: Action performed
├─ When: Timestamp
├─ Where: Resource affected
├─ Why: Reason/request ID
└─ Result: Success/Failure

Kubernetes Audit Logs:
├─ API calls
├─ Resource modifications
├─ RBAC decisions
└─ Pod operations

Application Logs:
├─ Authentication attempts
├─ API requests
├─ Database operations
└─ Business transactions
```

**Access to Logs:**

```bash
# View Azure activity logs
az monitor activity-log list \
  --resource-group rg-3tier-app-prod \
  --max-events 100

# View Kubernetes audit logs
kubectl logs -n kube-system apiserver | grep audit

# View application logs
kubectl logs -f deployment/user-service -n three-tier-app
```

---

## 🆘 **Incident Response**

### **Security Incident Response Plan**

**Level 1: Low Severity** (Medium vulnerability found)

```
Timeline: 48 hours
Actions:
1. Security team reviews issue
2. Assign to development team
3. Fix in next sprint
4. Rescan and verify
5. Close ticket
```

**Level 2: Medium Severity** (High vulnerability, exploitable)

```
Timeline: 24 hours
Actions:
1. IMMEDIATE: Disable vulnerable service (if critical)
2. Create emergency hotfix branch
3. Fix and test thoroughly
4. Emergency deployment
5. Post-incident review
```

**Level 3: Critical Severity** (Active exploitation, data breach)

```
Timeline: 1 hour
Actions:
1. IMMEDIATE: Isolate affected systems
2. Notify security team + management
3. Initiate incident response playbook
4. Engage external security firm if needed
5. Preserve forensic evidence
6. Notify users (if data breach)
7. Post-mortem after stabilization
```

### **Example Incident: Log4j Vulnerability (Log4Shell)**

```
Time: 2021-12-10 10:00 UTC
Event: Critical RCE vulnerability in Log4j discovered

Response:
1. [10:05] Security alert sent to team
2. [10:15] Confirm affectation: YES - pom.xml uses 2.14.1
3. [10:30] Create emergency branch: hotfix/log4j-cve
4. [10:45] Upgrade dependency to 2.17.0
5. [11:00] Run full test suite
6. [11:30] Deploy to all environments (emergency)
7. [12:00] Monitor for issues - none detected
8. [14:00] Post-mortem: 
   - Add Snyk to pipeline (DONE - prevents future)
   - Review all dependencies quarterly
   - Set up critical CVE alerts
```

---

## 💻 **Secure Development Practices**

### **Secure Coding Guidelines**

```java
// ❌ INSECURE
String query = "SELECT * FROM users WHERE id = " + userId;
Statement stmt = conn.createStatement();
ResultSet rs = stmt.executeQuery(query);  // SQL Injection!

// ✅ SECURE
String query = "SELECT * FROM users WHERE id = ?";
PreparedStatement pstmt = conn.prepareStatement(query);
pstmt.setInt(1, userId);  // Safely parameterized
ResultSet rs = pstmt.executeQuery();
```

**Secure Coding Checklist:**

```
Input Validation:
  ☐ Validate all inputs (length, type, format)
  ☐ Use whitelist approach (allow known good)
  ☐ Reject unknown inputs
  ☐ Sanitize for output context

Output Encoding:
  ☐ HTML encode for web output
  ☐ JavaScript encode for scripts
  ☐ SQL encode for databases
  ☐ URL encode for URLs

Authentication:
  ☐ Use strong passwords (bcrypt/scrypt)
  ☐ Implement MFA where possible
  ☐ Use JWT with short expiry
  ☐ Never store plaintext passwords

Authorization:
  ☐ Check permissions for every action
  ☐ Use role-based access (RBAC)
  ☐ Principle of least privilege
  ☐ Default deny (not default allow)

Cryptography:
  ☐ Use TLS 1.2+ for transport
  ☐ Use strong algorithms (AES-256, SHA-256)
  ☐ Never implement your own
  ☐ Keep keys secure (Key Vault)

Error Handling:
  ☐ Don't expose system details
  ☐ Log errors securely
  ☐ Use generic error messages
  ☐ Never log passwords/tokens

Secrets Management:
  ☐ Never hardcode credentials
  ☐ Use Key Vault / environment variables
  ☐ Rotate regularly
  ☐ Revoke when compromised
```

### **Code Review Checklist**

```
Security Review:
☐ No hardcoded secrets
☐ No SQL injection vulnerabilities
☐ No XSS vulnerabilities
☐ No insecure deserialization
☐ Proper input validation
☐ Secure random number generation
☐ Proper error handling
☐ RBAC/Authorization checks
☐ No infinite loops/DoS risk
☐ Crypto uses best practices

Quality Review:
☐ Tests present and passing
☐ Code coverage adequate
☐ Documentation updated
☐ No code duplication
☐ Performance acceptable
☐ Follows style guide
```

---

## 📚 **Security Training Requirements**

### **For All Developers**

```
Quarterly Training Topics:
Q1: OWASP Top 10
    - SQL Injection
    - XSS attacks
    - Broken Authentication

Q2: Secure Coding
    - Input validation
    - Output encoding
    - Cryptography basics

Q3: Cloud Security
    - Azure security features
    - IAM/RBAC
    - Data protection

Q4: Compliance & Incidents
    - Compliance requirements
    - Incident response
    - Security assessment
```

### **Certification Programs**

```
Recommended:
- OWASP Certified Secure Developer (OCSD)
- AWS/Azure Security Fundamentals
- CEH (Certified Ethical Hacker) - optional
```

---

## 🔄 **Continuous Security Monitoring**

### **Automated Monitoring (24/7)**

```
Azure Monitor:
├─ Resource health
├─ Performance metrics
├─ Security alerts
└─ Compliance status

Kubernetes Monitoring:
├─ Pod security
├─ Network policy violations
├─ Resource usage
└─ Pod restarts

Application Monitoring:
├─ Error rates
├─ Performance degradation
├─ Security events
└─ Anomalies

Security Tools:
├─ Azure Security Center
├─ Azure Sentinel (SIEM)
├─ Defender for Cloud
└─ Third-party tools (Snyk, Sonarqube)
```

### **Weekly Security Review**

```
Tasks:
☐ Review Azure activity logs for suspicious activity
☐ Check Snyk dashboard for new vulnerabilities
☐ Review SonarQube security hotspots
☐ Analyze failed authentication attempts
☐ Check certificate expiration dates
☐ Review firewall/NSG changes
☐ Scan for exposed secrets
```

### **Monthly Security Audit**

```
Tasks:
☐ RBAC review - are permissions still valid?
☐ Access review - who should have access?
☐ Certificate inventory - what expires soon?
☐ Vulnerability status - any unpatched?
☐ Compliance status - any gaps?
☐ Security metrics - trends?
☐ Incident review - any incidents?
```

### **Quarterly Security Assessment**

```
Tasks:
☐ Vulnerability assessment (pen testing)
☐ Code security review
☐ Architecture review
☐ Disaster recovery test
☐ Security training completion
☐ Policy updates
☐ Compliance checklist
```

---

## ✅ **Security Checklist - Go-Live**

```
Before deploying to Production:

Code Security:
☐ SonarQube Quality Gate passed
☐ Snyk scan: 0 CRITICAL/HIGH
☐ OWASP Dependency Check: passed
☐ Trivy container scan: passed
☐ No hardcoded secrets
☐ Input validation on all endpoints
☐ Authorization checks in place

Infrastructure:
☐ SSL certificates valid
☐ WAF enabled (App Gateway)
☐ Network policies applied
☐ RBAC configured
☐ Key Vault configured
☐ Logging enabled (all resources)
☐ Backups configured

Operations:
☐ Monitoring alerts set up
☐ Runbooks documented
☐ Incident response plan ready
☐ Disaster recovery tested
☐ On-call rotation established
☐ Rollback procedure documented
☐ Health checks configured

Compliance:
☐ Audit logging enabled
☐ Data retention policy set
☐ Encryption enabled
☐ Access controls verified
☐ Compliance scan passed
☐ Pen test passed
☐ Privacy review completed
```

---

## 📞 **Security Contacts & Resources**

```
Internal Contacts:
- Security Lead: [name]@company.com
- DevOps Lead: [name]@company.com
- Compliance Officer: [name]@company.com

External Resources:
- OWASP: https://owasp.org/
- CWE: https://cwe.mitre.org/
- NVD: https://nvd.nist.gov/
- Azure Security: https://azure.microsoft.com/en-us/products/azure-security/

Incident Report:
- Email: security@company.com
- Slack: #security-incidents
- Phone: [emergency number]
```

---

**Last Updated:** April 2026  
**Status:** Active - All policies enforced  
**Next Review:** July 2026

---

**Related Documents:**
- [Azure Pipeline Stages Explained](AZURE_PIPELINE_STAGES_EXPLAINED.md)
- [SonarQube Setup Guide](SONARQUBE_SETUP_GUIDE.md)
- [Snyk Integration Guide](SNYK_INTEGRATION_GUIDE.md)
- [RBAC Configuration](rbac/azure-service-principals.sh)
