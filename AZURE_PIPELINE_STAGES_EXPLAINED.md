# Azure DevSecOps Pipeline - Complete Stage Explanation

## 📋 Table of Contents

1. Pipeline Overview
2. Stage 1: Initialize & Pre-Build Security Checks
3. Stage 2: Build & Compile
4. Stage 3: Code Quality Analysis (SonarQube + SonarLint)
5. Stage 4: Security Scanning (Snyk + OWASP)
6. Stage 5: Unit & Integration Tests
7. Stage 6: Build & Push Docker Images
8. Stage 7-9: Deploy to Environments
9. Stage 10: Compliance Reporting
10. RBAC & Environment Controls

---

## 🎯 Pipeline Overview

```
Your Code → Git Push → Azure Pipeline Trigger
    ↓
[Stage 1] Initialize & Security Pre-Checks
    ↓
[Stage 2] Build & Compile (Maven)
    ↓
[Stage 3] Code Quality (SonarQube + SonarLint)
    ↓
[Stage 4] Security Scanning (Snyk + OWASP + Trivy)
    ↓
[Stage 5] Testing (Unit + Integration)
    ↓
[Stage 6] Build & Push Docker Images
    ↓
[Stage 7] Deploy to Dev
    ↓
[Stage 8] Deploy to Staging (Requires Approval)
    ↓
[Stage 9] Deploy to Production (Requires Multiple Approvals)
    ↓
[Stage 10] Compliance & Audit Reporting
```

**Total Pipeline Time:** ~45-60 minutes  
**Failure Point:** Pipeline stops at first failure, logs provide detailed debugging

---

## 🔐 **STAGE 1: Initialize & Pre-Build Security Checks**

### **Purpose**
Verify code integrity, scan for secrets, and detect malicious patterns BEFORE compilation.

### **What Happens**

#### **Step 1.1: Git Commit Verification**
```bash
git log --oneline -n 5
```
- **Why:** Ensures all commits are properly logged
- **Risk Mitigated:** Detects unauthorized changes, commit tampering
- **What to Look For:** Clean commit history, all changes documented

#### **Step 1.2: SBOM (Software Bill of Materials) Creation**
```bash
mkdir -p sbom/
```
- **Why:** Required for compliance (SOC 2, ISO 27001, FedRAMP)
- **What It Does:** Creates directory for artifact tracking
- **Output:** Later populated with all dependencies and versions

#### **Step 1.3: Dependency Check (OWASP)**
```bash
dependency-check --scan .
```
- **Why:** Detects known vulnerable libraries BEFORE build
- **Vulnerabilities Detected:**
  - Log4j (CVE-2021-44228) ✓
  - Spring Core vulnerabilities ✓
  - Serialization exploits ✓
- **Action:** Fails build if HIGH/CRITICAL found

#### **Step 1.4: Secret Scanning (git-secrets)**
```bash
git secrets --scan
```
- **Why:** Prevents accidental commit of credentials
- **Secrets Detected:**
  - AWS Access Keys (`AKIA...`)
  - Azure Connection Strings
  - Database passwords
  - API keys
- **Action:** Blocks commit if secrets found

#### **Step 1.5: Code Pattern Scanning**
```bash
grep -r "password.*=" --include="*.java"
```
- **Why:** Detects hardcoded sensitive data
- **Patterns Detected:**
  - `password="..."`
  - `SECRET=...`
  - Database connection strings
  - API credentials
- **False Positives:** Configuration examples may flag
- **Action:** Manual review required for exceptions

### **Success Criteria**
✅ Git history clean  
✅ No secrets detected  
✅ No hardcoded credentials  
✅ SBOM directory created  

### **Failure Scenarios**
❌ Secret detected → Pipeline stops → Commit must be reverted  
❌ Hardcoded password → Manual exception or code fix  
❌ Git history issues → May indicate branch safety problems  

---

## 🔨 **STAGE 2: Build & Compile**

### **Purpose**
Compile Java code using Maven, verify all dependencies, create executable artifacts.

### **What Happens**

#### **Step 2.1: Java Environment Setup**
```bash
Java 11 Toolchain Installed
```
- **Version:** Java 11 (matches your pom.xml)
- **Why:** Ensures consistent build environment
- **Alternative:** Change `JAVA_VERSION: '11'` to use Java 17, 21, etc.

#### **Step 2.2: Maven Dependency Caching**
```bash
Cache location: ~/.m2/repository
```
- **Why:** Speeds up subsequent builds (30% faster)
- **Benefit:** Reduces Maven Central downloads
- **Cache Key:** `pom.xml` changes invalidate cache

#### **Step 2.3: Maven Clean Package Build**
```bash
mvn clean package -DskipTests -X -e -V
```

| Flag | Meaning | Why |
|------|---------|-----|
| `clean` | Remove old artifacts | Fresh build every time |
| `package` | Compile + create JAR | Produces `target/*.jar` |
| `-DskipTests` | Don't run tests yet | Tests in separate stage |
| `-X` | Verbose debug mode | Detailed troubleshooting |
| `-e` | Show errors | Full error stack traces |
| `-V` | Show version | Logs Java/Maven versions |

#### **Step 2.4: Artifact Verification**
```bash
find . -name "*.jar" -type f
```
- **Output:** Lists all created JAR files
- **Expected:** 3 JARs
  - `user-service-*.jar`
  - `order-service-*.jar`
  - `payment-service-*.jar`

### **Build Artifacts Created**

```
target/
├── user-service-1.0-SNAPSHOT.jar (40 MB)
├── order-service-1.0-SNAPSHOT.jar (42 MB)
├── payment-service-1.0-SNAPSHOT.jar (38 MB)
└── classes/
    ├── com/example/user/**
    ├── com/example/order/**
    └── com/example/payment/**
```

### **Success Criteria**
✅ All 3 services compile successfully  
✅ No compilation errors  
✅ JAR files created  
✅ Dependencies resolved  

### **Failure Scenarios**
❌ Compilation error → Shows exact line and class  
❌ Dependency conflict → Maven shows conflicting versions  
❌ Java version mismatch → Requires Java 11+  
❌ Memory error → Agent needs more RAM (rare in Azure Pipelines)

---

## 📊 **STAGE 3: Code Quality Analysis (SonarQube + SonarLint)**

### **Purpose**
Analyze code for bugs, vulnerabilities, code smells, and maintainability issues.

### **Components**

#### **SonarQube (Server-side Analysis)**
- **Type:** SAST (Static Application Security Testing)
- **Scope:** Full project analysis with historical tracking
- **What It Detects:**
  - Security vulnerabilities (SQL injection, XSS, etc.)
  - Code smells (duplicated code, long methods)
  - Bugs (null pointer exceptions, infinite loops)
  - Maintainability issues (complex code, low testability)

#### **SonarLint (Local Analysis)**
- **Type:** Real-time code inspection
- **Scope:** Detected during IDE + pipeline
- **What It Detects:**
  - Same issues as SonarQube but faster
  - Real-time feedback during development

### **Setup Required**

#### **1. Configure SonarQube Service Connection**

In Azure DevOps:
```
1. Go to: Project Settings → Service connections
2. Click: New service connection
3. Type: SonarQube
4. Fill in:
   - Server URL: https://sonarqube.example.com
   - Token: [Generate in SonarQube]
5. Name: "SonarQube"
```

#### **2. Get SonarQube Authentication Token**

In SonarQube:
```
1. Login to your SonarQube instance
2. Click Profile (top-right) → My Account
3. Security tab → Generate Token
4. Name: "Azure-Pipeline"
5. Copy token and save in Azure DevOps as secret variable
```

### **What Happens in Pipeline**

#### **Step 3.1: Prepare SonarQube Scanner**
```yaml
- task: SonarQubePrepare@4
  inputs:
    SonarQube: 'SonarQube'
    projectKey: 'three-tier-app'
    projectVersion: '$(Build.BuildNumber)'
```

- **projectKey:** Unique identifier for your project
- **projectVersion:** Build number (increments each run)
- **Purpose:** Initializes scanner with credentials

#### **Step 3.2: Run Maven with SonarQube**
```bash
mvn clean verify sonar:sonar \
  -Dsonar.projectKey=three-tier-app \
  -Dsonar.host.url=https://sonarqube.example.com \
  -Dsonar.login=$(SONAR_AUTH_TOKEN)
```

- **clean:** Fresh analysis
- **verify:** Compile + tests + static analysis
- **sonar:sonar:** Trigger SonarQube plugin
- **Output:** Sends results to SonarQube server

#### **Step 3.3: Wait for Quality Gate**
```yaml
- task: SonarQubePublish@4
  inputs:
    pollingTimeoutSec: '300'
```

- **What It Does:** Waits up to 5 minutes for SonarQube analysis
- **Quality Gate Rules:**
  - Code Coverage ≥ 80%? ✓
  - Bugs ≤ 0? ✓
  - Security hotspots reviewed? ✓
  - No new code smells? ✓

**Example Quality Gate:**
```
Passed: ✓
- Code Coverage: 85% (target 80%)
- Bugs: 0
- Code Smells: 2 (acceptable)
- Security Hotspots: 0

Failed: ✗
- Code Coverage: 60% (target 80%) — FAIL
- Action: Add more tests
```

#### **Step 3.4: SonarLint Analysis**
```bash
mvn com.sonarsource.sonarlint.core:sonarlint-maven-plugin:analyze
```

- **Fast:** Analyzes only changed code
- **Output:** Local report (not sent to SonarQube)
- **Use:** During development in IDE

### **Metrics Explained**

| Metric | What It Is | Target | Why |
|--------|-----------|--------|-----|
| **Code Coverage** | % of code tested | ≥80% | Critical code must have tests |
| **Bugs** | Logic errors found | 0 | Every bug = potential security risk |
| **Vulnerabilities** | Security issues | 0 | Can be exploited by attackers |
| **Code Smells** | Poor design | ≤5 | Affects maintainability |
| **Duplicated Lines** | Repeated code | <3% | Increases maintenance cost |

### **Success Criteria**
✅ Quality Gate passed  
✅ Code coverage ≥ 80%  
✅ No critical bugs  
✅ No vulnerabilities found  

### **Failure Scenarios**
❌ Quality Gate failed → Review SonarQube dashboard
❌ Low code coverage → Add unit tests
❌ Security hotspot found → Fix and retest

---

## 🔒 **STAGE 4: Security Scanning (Snyk + OWASP)**

### **Purpose**
Scan dependencies and code for known vulnerabilities before containerization.

### **Tool 1: Snyk (Dependency & Code Scanning)**

#### **What Snyk Does**
```
Your Code
    ↓
Snyk CLI reads pom.xml
    ↓
Queries Snyk Vulnerability Database
    ↓
Compares with Known CVEs
    ↓
Reports: Vulnerabilities Found
```

#### **Setup Required**

1. **Create Snyk Account**
   ```
   https://snyk.io/
   Sign up → Create API token
   ```

2. **Add to Azure DevOps Secrets**
   ```
   Settings → Pipelines → Library → Variable groups
   Create: "snyk-secrets"
   Add: snykToken = [your-snyk-token]
   ```

3. **Link to GitHub/GitLab**
   ```
   Snyk Settings → SCM (Source Code Management)
   Connect your repository
   ```

#### **Snyk Test Example**

```bash
snyk test --severity-threshold=high --json > snyk-dependencies.json
```

**Output Example:**
```json
{
  "vulnerabilities": [
    {
      "id": "SNYK-JAVA-SPRING-1234567",
      "severity": "high",
      "title": "Remote Code Execution",
      "from": ["pom.xml", "org.springframework:spring-core@5.1.0"],
      "fix": "Upgrade to 5.3.13"
    }
  ]
}
```

**Severity Levels:**
- 🔴 **Critical:** Immediate exploit possible
- 🟠 **High:** Likely exploitable
- 🟡 **Medium:** Possible under conditions
- 🟢 **Low:** Minor impact

#### **Snyk Code Analysis**
```bash
snyk code test --json > snyk-code.json
```

Detects:
- SQL Injection vulnerabilities
- Insecure cryptography
- Hard-coded secrets
- Unsafe deserialization

### **Tool 2: OWASP Dependency Check**

#### **What OWASP Does**
```
Analyzes project dependencies
    ↓
Checks against CVE database
    ↓
Generates detailed vulnerability report
```

#### **How It Works**

```bash
dependency-check --project "three-tier-app" \
  --scan . \
  --format XML
```

**Output:** XML report with:
- Library name and version
- Known CVEs
- CVSS score (0-10)
- Remediation advice

#### **Report Example**
```xml
<report>
  <dependency>
    <name>org.springframework:spring-core:5.1.0</name>
    <vulnerabilities>
      <vulnerability>
        <name>CVE-2021-22118</name>
        <cvssScore>7.5</cvssScore>
        <description>Remote Code Execution</description>
        <recommendation>Upgrade to 5.3.13+</recommendation>
      </vulnerability>
    </vulnerabilities>
  </dependency>
</report>
```

### **Tool 3: Trivy Container Scanning**

#### **What Trivy Does**
```
Scans Dockerfile configuration
    ↓
Checks for container image vulnerabilities
    ↓
Verifies security best practices
```

#### **Dockerfile Security Checks**
```bash
trivy config Dockerfile.springboot
```

Detects:
- Running as root (❌ security risk)
- Outdated base image (❌ known vulnerabilities)
- No health checks (❌ monitoring issue)
- Unnecessary privileges (❌ escalation risk)

**Example Finding:**
```
[HIGH] RUN as root user
  Recommendation: Use non-root user
  Fix: Add USER appuser before CMD
```

### **Success Criteria**
✅ No critical vulnerabilities  
✅ All high severity issues have remediation plan  
✅ Dependency versions up to date  
✅ Dockerfile follows security best practices  

### **Failure Scenarios**
❌ Critical CVE found → Can't proceed to deployment
❌ High severity → Requires exception + plan
❌ Unpatched dependency → Update pom.xml and rebuild

---

## ✅ **STAGE 5: Unit & Integration Tests**

### **Purpose**
Verify code logic through automated tests before deployment.

### **Unit Tests**

#### **What Happens**
```bash
mvn test -Dtest=*Test --batch-mode -DfailIfNoTests=true
```

- **Scope:** Individual method testing
- **Examples:**
  - `UserServiceTest.java` → Tests UserService class
  - `OrderControllerTest.java` → Tests API endpoints
  - `PaymentServiceTest.java` → Tests payment logic

#### **Test Example**
```java
@Test
public void testCreateUser() {
  User user = new User("john@example.com", "John", "Doe");
  User savedUser = userService.createUser(user);
  
  assertNotNull(savedUser.getId());
  assertEquals("john@example.com", savedUser.getEmail());
}
```

#### **Code Coverage Report**
```bash
mvn jacoco:report
```

- **Coverage Goal:** ≥80% of code tested
- **Report Location:** `target/site/jacoco/index.html`
- **Shows:** Which lines/methods are tested

**Example Coverage:**
```
UserService.java: 92% ✓ (excellent)
OrderController.java: 75% ⚠️ (needs improvement)
PaymentService.java: 88% ✓ (good)
```

### **Integration Tests**

#### **What Happens**
```bash
# Start MySQL + microservices
docker-compose -f docker-compose.yml up -d
sleep 10

# Run integration tests
mvn verify -Dtest=*IT --batch-mode
```

#### **Integration Test Scope**

1. **User Service Tests**
   - Create user → Database → Verify saved
   - Get user by ID → Fetch from DB → Verify result
   - Update user → Database → Verify update
   - Find by email → Query → Verify search

2. **Order Service Tests**
   - Create order → Calls User Service → Calls Payment Service
   - Check cascading calls work
   - Verify database consistency

3. **API Endpoint Tests**
   - POST /api/users → HTTP 201
   - GET /api/users/{id} → HTTP 200
   - PUT /api/users/{id} → HTTP 204
   - DELETE /api/users/{id} → HTTP 204

#### **Example Integration Test**
```java
@SpringBootTest
@AutoConfigureMockMvc
public class OrderIntegrationTest {
  
  @Test
  public void testCreateOrderWithUserValidation() {
    // 1. Create user
    User user = userService.createUser(new User(...));
    
    // 2. Create order
    Order order = new Order(user.getId(), 99.99);
    Order savedOrder = orderService.createOrder(order);
    
    // 3. Verify
    assertNotNull(savedOrder.getId());
    assertEquals(OrderStatus.PENDING, savedOrder.getStatus());
  }
}
```

### **Test Results Publishing**

```xml
Target: target/surefire-reports/*.xml
Target: target/failsafe-reports/*.xml
```

**Published to:** Azure DevOps Test Results
**View in:** Pipeline → Tests tab

### **Success Criteria**
✅ All unit tests pass  
✅ All integration tests pass  
✅ Code coverage ≥80%  
✅ No test timeouts  

### **Failure Scenarios**
❌ Test fails → Shows which test failed + stack trace
❌ Low coverage → Add more tests
❌ Timeout → Increase timeout or optimize test

---

## 🐳 **STAGE 6: Build & Push Docker Images**

### **Purpose**
Package applications into container images and scan for vulnerabilities.

### **Step 1: Login to Azure Container Registry (ACR)**
```bash
docker login acr3tierapp.azurecr.io \
  -u [username] \
  -p [password]
```

- **Username:** Created when ACR was set up
- **Password:** Generated ACR access key
- **Purpose:** Authenticate to push images

### **Step 2: Build Docker Images**

#### **Build User Service**
```bash
docker build -t user-service:$(IMAGE_TAG) \
  --build-arg SERVICE_NAME=user-service \
  -f Dockerfile.springboot .
```

**What Happens:**
```
1. Read Dockerfile.springboot
2. Stage 1: Maven builder
   - Copy pom.xml
   - Copy source code
   - Run: mvn clean package
   - Output: target/*.jar
3. Stage 2: OpenJDK runtime
   - Copy JAR from Stage 1
   - Create non-root user
   - Set health check
   - Set entry point
4. Result: ~400MB image
```

#### **Repeat for Order & Payment Services**

### **Step 3: Container Image Scanning (Snyk)**

#### **Before Push - Scan for Vulnerabilities**
```bash
snyk container test acr3tierapp.azurecr.io/user-service:latest
```

**Example Output:**
```
✓ User-Service image scanned
  Critical: 0
  High: 1 (Java library vulnerability)
  Medium: 3
  Low: 5

Recommendation: Upgrade base image to openjdk:11-jdk-slim (latest)
```

#### **Policy Decision**
```
If Critical/High found:
  ✗ Block push (must fix)
  
If Medium found:
  ⚠️ Continue (document issue)
  
If Low/None:
  ✓ Proceed to push
```

### **Step 4: Push to Azure Container Registry (ACR)**

```bash
docker push acr3tierapp.azurecr.io/user-service:$(IMAGE_TAG)
docker push acr3tierapp.azurecr.io/order-service:$(IMAGE_TAG)
docker push acr3tierapp.azurecr.io/payment-service:$(IMAGE_TAG)
```

**Image Repository Structure:**
```
ACR: acr3tierapp.azurecr.io
├── user-service
│   ├── latest (latest build)
│   ├── v1.0
│   ├── v1.1
│   └── BUILD_ID-TIMESTAMP
├── order-service
│   ├── latest
│   └── ...
└── payment-service
    ├── latest
    └── ...
```

### **Success Criteria**
✅ All 3 images built successfully  
✅ No critical vulnerabilities in images  
✅ Images pushed to ACR  
✅ Image tags are consistent  

### **Failure Scenarios**
❌ Build fails → Check Dockerfile syntax
❌ Vulnerability found → Upgrade base image or libraries
❌ ACR push fails → Check credentials/network

---

## 🚀 **STAGE 7-9: Deploy to Environments**

### **Dev Environment (Automatic)**

```yaml
- deployment: DeployDevEnvironment
  environment:
    name: 'dev'
    resourceType: 'Kubernetes'
```

**What Happens:**
1. Pull images from ACR
2. Deploy Kubernetes manifests
3. Services start in `three-tier-app` namespace
4. Health checks begin

**Deployment Time:** ~2-5 minutes

### **Staging Environment (Requires Approval)**

```yaml
environment:
  name: 'staging'  # Requires approval from pipeline owner
```

**Process:**
1. Pipeline waits for approval
2. Authorized user approves in Azure DevOps
3. Pre-deployment security checks run
4. Services deployed
5. Post-deployment validation runs

**Approval Gated By:** Azure DevOps → Environments → Staging → Approvers

### **Production Environment (Multiple Approvals Required)**

```yaml
condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
```

**Extra Restrictions:**
1. Only deployable from `main` branch
2. Multiple approvers required
3. Pre-deployment validation
4. Post-deployment security audit

---

## 📊 **STAGE 10: Compliance & Reporting**

### **What Gets Reported**

```
Pipeline Compliance Report
├── Build Status: ✓ Passed
├── Code Quality: ✓ Passed (SonarQube)
├── Security Scan: ✓ Passed (Snyk + OWASP)
├── Tests: ✓ Passed (92% coverage)
├── Deployment Status: ✓ Dev ✓ Staging ✗ Prod (awaiting)
└── Artifacts: 
    ├── Build logs
    ├── Test reports
    ├── Security scan reports
    └── Deployment logs
```

### **Artifact Publishing**

All reports saved to:
```
$(ARTIFACT_STAGING_DIR)/
├── snyk-dependencies.json
├── snyk-code.json
├── trivy-config.json
├── jacoco-report/
└── reports/compliance-report.txt
```

### **Where to Find Reports**

In Azure DevOps:
```
Pipeline → Run Details → Related
  ├── Published artifacts (click to download)
  ├── Test results (tab)
  ├── Code coverage (tab)
  └── Logs (each job)
```

---

## 🔐 **RBAC & Environment Controls**

### **Role-Based Access Control**

#### **Developer Role (Dev only)**
```
Permissions:
✓ Can deploy to dev
✓ Can view logs
✓ Can read all resources
✗ Cannot deploy to staging/prod
✗ Cannot delete resources
```

#### **DevOps/SRE Role (All environments)**
```
Permissions:
✓ Can approve deployments
✓ Can manage all environments
✓ Can modify RBAC policies
✓ Can view audit logs
✗ Cannot delete production data
```

#### **Security Team Role (Read-only audit)**
```
Permissions:
✓ Can view all resources
✓ Can view security scans
✓ Can download reports
✗ Cannot modify anything
✗ Cannot approve deployments
```

### **Environment Approval Rules**

#### **Dev**
```
Auto-deploy on successful build
No approval needed
```

#### **Staging**
```
Requires approval from: DevOps lead OR Release manager
Number of approvers: 1
Timeout: 24 hours
Auto-reject on code changes
```

#### **Production**
```
Requires approval from: Release manager + Security lead
Number of approvers: 2
Timeout: 48 hours
All other approvals must succeed first
Only from main branch
```

---

## 🔄 **Pipeline Flow Summary**

```
┌─────────────────────────────────────────────────────────────┐
│ Developer pushes code to GitHub                              │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ [Stage 1] Initialize & Security Pre-Checks                  │
│  ✓ Git verification                                          │
│  ✓ Secret scanning                                           │
│  ✓ OWASP dependency check                                    │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────┴──────────────┐
         │ Pass?                    │
    ┌────▼────┐              ┌─────▼─────┐
    │   YES   │              │    NO     │
    └────┬────┘              └─────┬─────┘
         │                         │
         │                    [STOP] 🛑
         │                    Email notification
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│ [Stage 2] Build & Compile (Maven)                           │
│  ✓ Java environment setup                                    │
│  ✓ Maven clean package                                       │
│  ✓ 3 JARs created                                            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ [Stage 3] Code Quality (SonarQube)                           │
│  ✓ SonarQube analysis                                        │
│  ✓ Quality gate check                                        │
│  ✓ Code coverage report                                      │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ [Stage 4] Security Scanning                                  │
│  ✓ Snyk dependency scan                                      │
│  ✓ OWASP analysis                                            │
│  ✓ Trivy container scan                                      │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ [Stage 5] Testing                                            │
│  ✓ Unit tests (92% coverage)                                │
│  ✓ Integration tests                                         │
│  ✓ Test reports published                                    │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ [Stage 6] Build & Push Containers                            │
│  ✓ Docker images built                                       │
│  ✓ Security scanned                                          │
│  ✓ Pushed to ACR                                             │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ [Stage 7] Deploy Dev (Automatic)                             │
│  ✓ Kubernetes manifests deployed                             │
│  ✓ Services running                                          │
│  ✓ Health checks passing                                     │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ [Stage 8] Deploy Staging (Requires Approval)                 │
│  ⏳ Waiting for approval...                                   │
│  [APPROVE] [REJECT] buttons in Azure DevOps                  │
└────────────────────┬────────────────────────────────────────┘
                     │
     ┌───────────────┴──────────────┐
     │                              │
[APPROVE ✓]                    [REJECT ✗]
     │                              │
     │                         [Pipeline stops]
     │
     ▼
┌─────────────────────────────────────────────────────────────┐
│ [Stage 9] Deploy Production (Multiple Approvals)             │
│  ⏳ Waiting for 2 approvals...                                │
│  (only if main branch)                                       │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────┴──────────────┐
         │                          │
    [2 APPROVALS]            [REJECTED]
         │                          │
         ▼                     [Pipeline stops]
┌─────────────────────────────────────────────────────────────┐
│ [Stage 10] Compliance Reporting                              │
│  ✓ Generate compliance report                                │
│  ✓ Publish artifacts                                         │
│  ✓ Send notifications                                        │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
   ✓ PIPELINE COMPLETE
   All artifacts published
   Email notification sent
```

---

## 🎯 **Key Takeaways**

1. **Multiple Security Gates:** Each stage validates code before proceeding
2. **Automated Scanning:** SonarQube, Snyk, OWASP all automatic
3. **Progressive Deployment:** Dev auto, Staging manual, Prod multi-approval
4. **Full Audit Trail:** Every action logged and reportable
5. **Compliance Ready:** SOC 2, ISO 27001, FedRAMP compatible

---

## ❓ **Troubleshooting**

| Problem | Solution |
|---------|----------|
| SonarQube connection failed | Check service connection in Azure DevOps |
| Snyk token invalid | Regenerate token in Snyk, update secret |
| Docker push fails | Verify ACR credentials and registry name |
| Tests timeout | Increase timeout value in pipeline YAML |
| Approval not appearing | Check environment approval settings |
| Coverage too low | Add more unit tests to reach 80% |

---

**Next:** See `SNYK_INTEGRATION_GUIDE.md` for detailed Snyk setup  
**Next:** See `SONARQUBE_SETUP_GUIDE.md` for SonarQube installation  
**Next:** See `DEVSECOPS_POLICIES.md` for security policies  
