# SonarQube Integration Guide - Complete Setup

## 📋 Prerequisites

- Azure DevOps project (already set up)
- Azure Pipelines configured
- Docker installed (for SonarQube server setup)
- MySQL or PostgreSQL for SonarQube database

---

## 🚀 OPTION 1: Deploy SonarQube Using Docker (Recommended for Quick Start)

### **Step 1: Prepare Environment**

```bash
# Create data directory
mkdir -p sonarqube-data
mkdir -p sonarqube-logs

# Set permissions
chmod 777 sonarqube-data sonarqube-logs
```

### **Step 2: Start SonarQube with Docker Compose**

Create `sonarqube-docker-compose.yml`:

```yaml
version: '3.8'
services:
  sonarqube:
    image: sonarqube:9.9.3-community
    container_name: sonarqube
    ports:
      - "9000:9000"
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://postgres:5432/sonarqube
      SONAR_JDBC_USERNAME: sonarqube
      SONAR_JDBC_PASSWORD: sonarqube_password_123
      SONAR_ES_BOOTSTRAP_CHECKS_DISABLED: "true"
    volumes:
      - ./sonarqube-data:/opt/sonarqube/data
      - ./sonarqube-extensions:/opt/sonarqube/extensions
      - ./sonarqube-logs:/opt/sonarqube/logs
    depends_on:
      - postgres
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/api/system/health"]
      interval: 30s
      timeout: 10s
      retries: 5

  postgres:
    image: postgres:15-alpine
    container_name: postgres-sonarqube
    environment:
      POSTGRES_USER: sonarqube
      POSTGRES_PASSWORD: sonarqube_password_123
      POSTGRES_DB: sonarqube
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U sonarqube"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres-data:
```

Start services:

```bash
docker-compose -f sonarqube-docker-compose.yml up -d

# Wait for SonarQube to start (2-3 minutes)
docker logs -f sonarqube
```

### **Step 3: Access SonarQube**

```
URL: http://localhost:9000
Default Username: admin
Default Password: admin
```

⚠️ **Change default password immediately:**
```
1. Login with admin/admin
2. Click Admin → My Account
3. Change password
```

---

## 🏢 OPTION 2: Deploy to Azure Container Instances (ACI)

### **Step 1: Create Azure Container Instance**

```bash
# Set variables
RG="rg-3tier-app-dev"
ACI_NAME="sonarqube-aci"
SQL_SERVER="sonarqube-sqlserver"
SQL_ADMIN_USER="sqladmin"
SQL_ADMIN_PASSWORD="ComplexPassword123!"

# Create SQL Server for database
az sql server create \
  --resource-group $RG \
  --name $SQL_SERVER \
  --admin-user $SQL_ADMIN_USER \
  --admin-password $SQL_ADMIN_PASSWORD \
  --location eastus

# Create database
az sql db create \
  --resource-group $RG \
  --server $SQL_SERVER \
  --name sonarqube \
  --edition Standard
```

### **Step 2: Deploy Container**

```bash
az container create \
  --resource-group $RG \
  --name $ACI_NAME \
  --image sonarqube:9.9.3-community \
  --cpu 2 --memory 4 \
  --ports 9000 \
  --environment-variables \
    SONAR_JDBC_URL="jdbc:sqlserver://${SQL_SERVER}.database.windows.net:1433;database=sonarqube;encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;" \
    SONAR_JDBC_USERNAME=$SQL_ADMIN_USER \
    SONAR_JDBC_PASSWORD=$SQL_ADMIN_PASSWORD \
  --restart-policy OnFailure

# Get IP address
az container show \
  --resource-group $RG \
  --name $ACI_NAME \
  --query ipAddress.ip -o tsv
```

Access: `http://<IP_ADDRESS>:9000`

---

## 🔧 STEP 4: Configure SonarQube

### **Generate Authentication Token**

1. Login to SonarQube (http://localhost:9000)
2. Click **Admin** (top-right)
3. Go to **Security** → **Users**
4. Find your admin user
5. Click **Generate Token**
   - Name: `azure-pipeline`
   - Validity: 90 days (or forever)
6. **Copy token** (shown only once)

Example token format:
```
squ_c1a2c3d4e5f6a7b8c9d0e1f2a3b4c5d6
```

### **Create Project**

```
1. Click: Projects → Create Project
2. Name: three-tier-app
3. Key: three-tier-app (auto-filled)
4. Set visibility: Public (or Private if preferred)
5. Click: Create
```

### **Configure Quality Gate**

```
1. Go to: Quality Gates (left menu)
2. Click: Create
3. Name: "Three-Tier App Gate"
4. Add conditions:
   - Coverage: ≥ 80%
   - Duplicated Lines Density: ≤ 3%
   - Maintainability Rating: A
   - Reliability Rating: A
   - Security Rating: A
5. Set as default
6. Save
```

---

## 🔗 STEP 5: Configure Azure DevOps Service Connection

### **In Azure DevOps:**

```
1. Go to: Project Settings → Service connections
2. Click: New service connection
3. Search: SonarQube
4. Click: SonarQube
```

### **Fill in Details:**

```
Service Connection Name:    SonarQube
Server URL:                http://localhost:9000
Token:                     squ_c1a2c3d4e5f6a7b8c9d0e1f2a3b4c5d6 (paste from above)
Enable: ✓ Grant access to all pipelines
Save
```

---

## 📝 STEP 6: Add to Pipeline (Already Done in azure-pipelines.yml)

The pipeline already includes:

```yaml
- task: SonarQubePrepare@4
  inputs:
    SonarQube: 'SonarQube'
    scannerMode: 'MSBuild'
    projectKey: 'three-tier-app'
    projectName: 'Three-Tier App'

- script: |
    mvn clean verify sonar:sonar \
      -Dsonar.projectKey=three-tier-app \
      -Dsonar.host.url=http://localhost:9000 \
      -Dsonar.login=$(SONAR_AUTH_TOKEN)
```

---

## 🧪 Testing the Integration

### **Run Manual Pipeline**

```
1. Go to Azure Pipelines
2. Click: Run pipeline
3. Branch: develop (or your branch)
4. Click: Run
```

### **Monitor Progress**

```
1. In pipeline, watch "Code Quality Analysis" stage
2. Click on "SonarQube Analysis Scan" step
3. Should see: "SonarQube analysis complete"
4. Check SonarQube dashboard: http://localhost:9000
```

### **View Results**

Once complete:

```
1. Go to SonarQube Dashboard
2. Click your project: "three-tier-app"
3. See:
   - Code coverage percentage
   - Bugs found
   - Code smells
   - Security hotspots
   - Maintainability rating
```

---

## ⚙️ Advanced Configuration

### **Configure Exclusions**

Create `sonar-project.properties` in project root:

```properties
# Project identification
sonar.projectKey=three-tier-app
sonar.projectName=Three-Tier App
sonar.projectVersion=1.0

# Source files
sonar.sources=src/main/java
sonar.tests=src/test/java

# Exclusions
sonar.exclusions=**/test/**,**/target/**,**/logs/**

# Coverage exclusions
sonar.coverage.exclusions=**/test/**,**/target/**

# Java binaries (for coverage)
sonar.java.binaries=target/classes

# Duplicated code
sonar.cpd.exclusions=**/test/**

# Community plugins (if needed)
sonar.plugins.property=value
```

### **Configure for Maven**

In `pom.xml`, add properties:

```xml
<properties>
    <sonar.projectKey>three-tier-app</sonar.projectKey>
    <sonar.projectName>Three-Tier App</sonar.projectName>
    <sonar.host.url>http://localhost:9000</sonar.host.url>
    <sonar.login>${SONAR_AUTH_TOKEN}</sonar.login>
</properties>
```

### **Custom Rules Plugin**

Install from SonarQube:

```
1. Go to: Administration → Marketplace
2. Search: Plugins
3. Install: Java Rules
4. Install: Security plugin
5. Restart SonarQube (wait 5 min)
```

---

## 📊 Interpreting SonarQube Results

### **Dashboard Overview**

```
Project Health: A (Excellent)

Reliability:    A (No bugs)
Security:       A (No vulnerabilities)
Maintainability: A (Well-designed code)
Coverage:       92% (Very good)
Duplications:   1.2% (Very low)
```

### **Issues Details**

Click issue to see:
- **Bug:** Logic error that will cause failure
- **Vulnerability:** Security issue (SQL injection, XSS, etc.)
- **Code Smell:** Design issue (long method, duplicated code)
- **Severity:** Blocker, Critical, Major, Minor, Info

### **Action Items**

```
Critical Vulnerability Found:
  - Issue: SQL Injection in UserRepository
  - Location: src/main/java/.../UserRepository.java:45
  - Recommendation: Use parameterized queries
  - Status: Open
  - Action: Fix immediately, retest

High Code Smell:
  - Issue: Method too complex (cognitive complexity: 25)
  - Location: OrderService.java:120
  - Recommendation: Refactor to smaller methods
  - Status: Open
  - Action: Plan refactoring
```

---

## 🔒 Security Best Practices

### **Never commit SonarQube token**

✅ DO:
```yaml
# In Azure Pipelines
- script: |
    mvn sonar:sonar -Dsonar.login=$(SONAR_AUTH_TOKEN)
```

❌ DON'T:
```yaml
# Hardcoded token - SECURITY RISK!
- script: |
    mvn sonar:sonar -Dsonar.login=squ_abc123def456
```

### **Protect SonarQube Server**

```
1. Use HTTPS (not HTTP in production)
2. Change default password
3. Use firewall rules (restrict access)
4. Regular backups of PostgreSQL database
5. Monitor access logs
```

---

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| SonarQube connection refused | Check if running: `docker ps \| grep sonarqube` |
| "Invalid token" | Regenerate token in SonarQube admin panel |
| Coverage shows 0% | Add test files to `src/test/java` |
| Quality gate failing | Check gate conditions: Administration → Quality Gates |
| Scanner timeout | Increase timeout: `SONAR_QUALITY_GATE_TIMEOUT: 600` |
| Memory error | Increase JVM: `-Xmx2g` in JAVA_OPTS |

---

## 📚 Resources

- **SonarQube Docs:** https://docs.sonarqube.org/
- **Maven Plugin:** https://docs.sonarqube.org/latest/analyzing-source-code/scanners/sonarscanner-for-maven/
- **Quality Gates:** https://docs.sonarqube.org/latest/user-guide/quality-gates/
- **Azure Integration:** https://docs.microsoft.com/en-us/azure/devops/pipelines/extensions/sonarqube

---

**Next Steps:**
1. Deploy SonarQube (Option 1 or 2)
2. Generate token
3. Create Azure DevOps service connection
4. Run pipeline: `git push origin develop`
5. Monitor: Check SonarQube dashboard
