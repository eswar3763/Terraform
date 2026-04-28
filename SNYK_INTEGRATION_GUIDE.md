# Snyk Integration Guide - Security Vulnerability Scanning

## 📋 Prerequisites

- Snyk account (free at https://snyk.io/)
- Azure DevOps project
- Azure Pipelines running
- Node.js or npm installed (for Snyk CLI)

---

## 🚀 STEP 1: Create Snyk Account & Get API Token

### **Sign Up**

```
1. Visit: https://snyk.io/
2. Click: "Sign Up"
3. Choose: "Sign up with GitHub" or "Sign up with email"
4. Complete profile setup
```

### **Generate API Token**

```
1. After login, click: Account Settings (bottom-left)
2. Click: "API Token" tab
3. Click: "Show" (to reveal token)
4. Copy token (save securely - shown only once)
```

Example token format:
```
12345678-1234-1234-1234-123456789012
```

### **Set Up Organization**

```
1. From dashboard, click: Settings → Organization
2. Set organization name (e.g., "three-tier-app")
3. Note the organization ID (needed for scanning)
```

---

## 🔗 STEP 2: Connect GitHub/GitLab Repository (Optional)

This enables continuous monitoring of your repository.

### **For GitHub:**

```
1. In Snyk: Settings → Integrations → GitHub
2. Click: "Authenticate with GitHub"
3. Grant permissions (Snyk needs repo access)
4. Authorize
5. Select repositories to monitor
```

### **For Azure Repos:**

```
1. In Snyk: Integrations → (no direct integration, use CLI instead)
2. Use Snyk CLI in Azure Pipelines
3. Each pipeline run triggers scan
```

---

## 📦 STEP 3: Add Snyk to Azure Pipelines

### **Store API Token as Secret**

In Azure DevOps:

```
1. Go to: Pipelines → Library
2. Click: Variable groups
3. Create new: "snyk-secrets"
4. Add variable:
   Name: snykToken
   Value: 12345678-1234-1234-1234-123456789012
5. Check: "Keep this value secret"
6. Save
```

### **Link to Pipeline**

Already configured in `azure-pipelines.yml`:

```yaml
variables:
  SNYK_SEVERITY_THRESHOLD: 'high'
  SNYK_FAIL_ON_ISSUES: 'true'

jobs:
  - job: SnykDependencyScan
    steps:
      - script: npm install -g snyk
        displayName: 'Install Snyk CLI'
      
      - script: snyk auth $(snykToken)
        displayName: 'Authenticate Snyk'
        env:
          SNYK_TOKEN: $(snykToken)
```

---

## 🔍 STEP 4: Understanding Snyk Scanning Types

### **Type 1: Dependency Scanning (pom.xml)**

```bash
snyk test
```

**What It Scans:**
- Maven dependencies in `pom.xml`
- Known CVEs (Common Vulnerabilities and Exposures)
- Version conflicts
- License compliance

**Example Output:**
```
✓ Scanning pom.xml

Vulnerabilities found:
  HIGH: Remote Code Execution in org.apache.commons:commons-exec:1.3
    Found in: pom.xml
    Fix: Upgrade to 1.3+ (upgrade available)
    Details: CVE-2021-21341

Recommendations:
  - Upgrade commons-exec to 1.4
  - Review other HIGH/CRITICAL findings
```

### **Type 2: Code Scanning (Source Code)**

```bash
snyk code test
```

**What It Scans:**
- Custom code vulnerabilities
- Unsafe API usage
- SQL injection risks
- Insecure cryptography
- Hard-coded secrets

**Example Output:**
```
Code issues found:

  HIGH: SQL Injection risk
    File: src/main/java/com/example/UserRepository.java:52
    Issue: String concatenation in SQL query
    Fix: Use PreparedStatement instead

  MEDIUM: Weak encryption
    File: src/main/java/com/example/PaymentService.java:89
    Issue: Using MD5 for hashing
    Fix: Use SHA-256 or bcrypt
```

### **Type 3: Container Scanning**

```bash
snyk container test my-image:latest
```

**What It Scans:**
- Base image vulnerabilities
- OS package vulnerabilities
- Application dependencies in container

---

## 📋 STEP 5: Configure Snyk in Pipeline

### **Snyk Test (Dependencies)**

Already in `azure-pipelines.yml`:

```yaml
- script: |
    snyk test \
      --severity-threshold=high \
      --json > $(ARTIFACT_STAGING_DIR)/snyk-dependencies.json \
      || if [ $? -eq 1 ]; then echo "Vulnerabilities found"; fi
  displayName: 'Snyk Dependency Scan'
  continueOnError: true
```

**Key Parameters:**

| Parameter | Value | Meaning |
|-----------|-------|---------|
| `--severity-threshold` | `high` | Fail only on HIGH/CRITICAL |
| `--json` | filename | Output machine-readable format |
| `--file` | `pom.xml` | Specific file to scan (optional) |
| `--org` | org-id | Specific Snyk organization |
| `--fail-on-issues` | - | Exit with error code if issues found |

### **Snyk Code (Source Analysis)**

```yaml
- script: |
    snyk code test \
      --json > $(ARTIFACT_STAGING_DIR)/snyk-code.json \
      || echo "Code scan complete"
  displayName: 'Snyk Code Analysis'
  continueOnError: true
```

### **Snyk Container (Docker Images)**

```yaml
- script: |
    snyk container test $(ACR_REGISTRY_URL)/user-service:latest \
      --severity-threshold=high \
      --json > $(ARTIFACT_STAGING_DIR)/snyk-container-user.json
  displayName: 'Scan User Service Image'
  continueOnError: true
```

---

## 🛡️ STEP 6: Interpret Snyk Results

### **Exit Codes**

```
0 = No vulnerabilities found ✓
1 = Vulnerabilities found (action needed)
2 = Invalid command or error
3 = Errors during execution
```

### **Reading Snyk Report**

Example JSON output:

```json
{
  "vulnerabilities": [
    {
      "id": "SNYK-JAVA-COMMONSIOBEANUTILS-1024820",
      "title": "Unsafe Deserialization",
      "severity": "high",
      "cvssScore": 8.9,
      "package": "commons-beanutils:commons-beanutils",
      "packageManager": "maven",
      "currentVersion": "1.9.3",
      "fixedIn": ["1.9.4"],
      "from": ["pom.xml", "commons-beanutils:commons-beanutils@1.9.3"],
      "remediation": "Upgrade to commons-beanutils 1.9.4 or higher",
      "recommendation": "Upgrade commons-beanutils from 1.9.3 to 1.9.4",
      "references": [
        {
          "title": "NVD",
          "url": "https://nvd.nist.gov/vuln/detail/CVE-2019-10086"
        }
      ]
    }
  ]
}
```

### **Action by Severity**

```
🔴 CRITICAL:
  → Block deployment immediately
  → Fix required before next build
  → Create incident ticket

🟠 HIGH:
  → Block staging/production deployment
  → Fix required (timeline: 7 days)
  → Create ticket with priority

🟡 MEDIUM:
  → Allow with approval
  → Plan fix (timeline: 30 days)
  → Track in backlog

🟢 LOW:
  → Log for reference
  → Fix in next minor release
  → Track in backlog
```

---

## 🔧 Advanced Configuration

### **Exclude Specific Vulnerabilities (if accepted risk)**

Create `.snyk` file in project root:

```yaml
version: v1.25.0
ignore:
  SNYK-JAVA-COMMONS-1234567:
    - '*':
        reason: 'Already patched in runtime'
        expires: '2025-12-31T00:00:00Z'
```

### **Configure Policy**

Create `snyk-policy.json`:

```json
{
  "version": "1.0.0",
  "failThreshold": "high",
  "failOnIssues": true,
  "ignoreExpired": false,
  "failOnUnsecured": true,
  "reportSeverity": "high",
  "severityThreshold": "high",
  "unsecuredSeverityThreshold": "high",
  "severityThresholds": {
    "low": false,
    "medium": false,
    "high": true,
    "critical": true
  }
}
```

### **Integrate with Slack/Email**

In Snyk dashboard:

```
1. Go to: Integrations
2. Choose: Slack or Email
3. Authorize and configure
4. Snyk will send alerts on new vulnerabilities
```

---

## 📊 STEP 7: Monitor Vulnerabilities

### **Snyk Dashboard**

```
1. Go to: https://app.snyk.io/
2. View projects
3. Click "three-tier-app"
4. See:
   - Open issues count
   - Severity distribution
   - Last scanned date
   - Remediation guidance
```

### **Generate Reports**

```
Dashboard → Projects → three-tier-app → Reports
  ├── Summary Report (PDF)
  ├── Detailed Report (PDF)
  └── Export (CSV)
```

---

## 🚨 Handling Vulnerabilities

### **When Snyk Finds CRITICAL Issue**

```
1. Get notification (Slack/Email)
2. Check Snyk dashboard for details
3. Review remediation options
4. Update pom.xml with fixed version
5. Run: snyk test --dry-run (to verify fix)
6. Commit and push
7. Pipeline automatically retests
8. Verify fix applied
```

### **Example: Fixing Log4j Vulnerability**

**Before:**
```xml
<dependency>
  <groupId>org.apache.logging.log4j</groupId>
  <artifactId>log4j-core</artifactId>
  <version>2.14.1</version>  <!-- VULNERABLE -->
</dependency>
```

**Snyk Alert:**
```
CRITICAL: Remote Code Execution in Apache Log4j
CVE-2021-44228 (Log4Shell)
Remediation: Upgrade to 2.17.0 or higher
```

**After:**
```xml
<dependency>
  <groupId>org.apache.logging.log4j</groupId>
  <artifactId>log4j-core</artifactId>
  <version>2.19.0</version>  <!-- FIXED -->
</dependency>
```

---

## 🔐 Security Best Practices

### **1. Enable Automatic Updates**

```
Snyk Settings → Integrations → GitHub (or Azure)
Enable: "Automatically fix vulnerabilities"
```

Snyk will create Pull Requests automatically.

### **2. Set Severity Thresholds**

```
project/settings → Severity threshold: HIGH
→ Only fail pipeline on HIGH/CRITICAL
```

### **3. Review Dependencies Regularly**

```
Create calendar reminder: Weekly
Task: Review Snyk dashboard for new issues
```

### **4. Keep Token Secure**

✅ DO:
```yaml
env:
  SNYK_TOKEN: $(snykToken)  # Secret variable
```

❌ DON'T:
```yaml
snyk auth 12345678-1234-1234-1234-123456789012  # Hardcoded!
```

---

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| "Invalid token" | Regenerate token in Snyk settings |
| "Cannot find pom.xml" | Ensure running from project root directory |
| Timeout | Increase timeout: `--max-wait=600` |
| No vulnerabilities found | Snyk might be offline, check status page |
| Exit code 1 but no output | Check Snyk logs: `snyk test --debug` |
| Rate limit exceeded | Wait 1 hour or upgrade Snyk plan |

---

## 📚 Resources

- **Snyk Docs:** https://docs.snyk.io/
- **Snyk CLI:** https://docs.snyk.io/snyk-cli/
- **Maven Integration:** https://docs.snyk.io/scan-application-code/snyk-code/getting-started-with-snyk-code/
- **Container Scanning:** https://docs.snyk.io/scan-containers/
- **Azure DevOps Integration:** https://docs.snyk.io/integrations/ci-cd-integrations/azure-pipelines

---

## 🎯 Next Steps

1. Create Snyk account
2. Generate API token
3. Add token to Azure DevOps secrets
4. Run first scan: `git push origin develop`
5. Monitor: Check Snyk dashboard
6. Fix vulnerabilities as found
7. Integrate with Slack for alerts

---

**Related Guides:**
- [SonarQube Integration](SONARQUBE_SETUP_GUIDE.md)
- [DevSecOps Policies](DEVSECOPS_POLICIES.md)
- [Pipeline Stages Explained](AZURE_PIPELINE_STAGES_EXPLAINED.md)
