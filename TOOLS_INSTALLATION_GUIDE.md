# Tools Installation Guide

## Complete Installation Guide for DevSecOps Pipeline

This guide covers installing all required tools for the DevSecOps pipeline on macOS.

---

## 📋 Prerequisites

- macOS 10.15+ (Catalina or later)
- Administrator access
- Internet connection (4+ Mbps recommended)
- ~20GB free disk space
- Terminal/Command line familiarity

---

## 1️⃣ Install Homebrew (Package Manager)

**Homebrew** is a package manager that simplifies installing tools on macOS.

### Installation Steps:

```bash
# 1. Open Terminal
# 2. Copy and paste this command:
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 3. If using Apple Silicon (M1/M2), add to PATH:
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# 4. Verify installation:
brew --version
# Output should show: Homebrew <version>
```

### Troubleshooting:
- **Error: "xcode-select: error: tool requires Xcode"**
  ```bash
  xcode-select --install
  ```

- **Error: "Permission denied"**
  ```bash
  sudo chown -R $(whoami) /usr/local/bin
  ```

---

## 2️⃣ Install Docker Desktop

**Docker Desktop** is essential for containerization and running services locally.

### Option A: Using Homebrew (Recommended)

```bash
# 1. Install Docker Desktop
brew install --cask docker

# 2. Open Docker Desktop from Applications
open /Applications/Docker.app

# 3. Complete the setup wizard
#    - Allow Docker to access your system
#    - Provide your password when prompted

# 4. Wait for Docker to fully start (check menu bar for Docker icon)

# 5. Verify installation:
docker --version
# Output: Docker version 20.10+ or higher

docker run hello-world
# Output: "Hello from Docker!"
```

### Option B: Manual Installation

1. Download from [Docker Official Website](https://www.docker.com/products/docker-desktop/)
2. Open `Docker.dmg`
3. Drag Docker icon to Applications folder
4. Open Applications → Docker.app
5. Follow setup wizard

### Post-Installation:

```bash
# Enable Docker to start on login (optional)
# System Preferences → General → "Start Docker Desktop when you log in"

# Test with a simple container
docker run --rm -it ubuntu bash
# Type 'exit' to exit

# Check Docker resources
docker version
docker info
```

### Troubleshooting:
- **Docker daemon won't start**: Restart Docker Desktop
- **Permission denied**: Add user to docker group:
  ```bash
  sudo usermod -a -G docker $(whoami)
  # Restart your terminal
  ```
- **Resource issues**: Docker → Preferences → Resources (increase CPU/Memory)

---

## 3️⃣ Install Azure CLI

**Azure CLI** is needed to manage Azure resources from the command line.

### Installation:

```bash
# 1. Install Azure CLI using Homebrew
brew install azure-cli

# 2. Verify installation:
az --version
# Output: azure-cli <version>

# 3. Login to Azure
az login
# Browser window opens → Sign in with your Azure account

# 4. Select your subscription:
az account set --subscription "<subscription-id>"

# 5. Verify you're logged in:
az account show
# Output shows your subscription details
```

### Troubleshooting:
- **Command not found**: Restart terminal after installation
- **Login fails**: Clear Azure credentials:
  ```bash
  az logout
  rm -rf ~/.azure
  az login
  ```

---

## 4️⃣ Install kubectl (Kubernetes CLI)

**kubectl** manages Kubernetes clusters (AKS).

### Installation:

```bash
# 1. Install kubectl using Homebrew
brew install kubectl

# 2. Verify installation:
kubectl version --client
# Output: version.Info{...}

# 3. Get AKS cluster credentials
az aks get-credentials \
  --resource-group <your-resource-group> \
  --name <your-aks-cluster-name>

# 4. Verify connection to cluster:
kubectl cluster-info
# Output shows cluster IP and API server

# 5. List nodes in cluster:
kubectl get nodes
# Output shows your AKS nodes

# 6. List pods:
kubectl get pods --all-namespaces
```

### Useful kubectl Aliases:

```bash
# Add to ~/.zprofile for quick access:
cat >> ~/.zprofile << 'EOF'

# Kubernetes aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgd='kubectl get deployments'
alias kdp='kubectl describe pod'
EOF

# Reload profile:
source ~/.zprofile
```

### Troubleshooting:
- **Cannot connect to cluster**: Update kubeconfig:
  ```bash
  az aks get-credentials --resource-group <rg> --name <cluster> --overwrite-existing
  ```

---

## 5️⃣ Install Git (Version Control)

**Git** is used for source code management.

### Installation:

```bash
# 1. Install Git using Homebrew
brew install git

# 2. Verify installation:
git --version
# Output: git version 2.35+

# 3. Configure Git with your details
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# 4. Configure SSH (optional but recommended)
# Generate SSH key:
ssh-keygen -t ed25519 -C "your.email@example.com"

# Add to SSH agent:
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Copy public key for GitHub:
cat ~/.ssh/id_ed25519.pub
# Add this to GitHub Settings → SSH keys

# 5. Test Git connection:
ssh -T git@github.com
# Output: Hi <username>! You've successfully authenticated.
```

### Troubleshooting:
- **SSH key issues**: Ensure correct permissions:
  ```bash
  chmod 700 ~/.ssh
  chmod 600 ~/.ssh/id_ed25519
  ```

---

## 6️⃣ Install Maven

**Maven** is the build tool for Java microservices.

### Installation:

```bash
# 1. Install Maven using Homebrew
brew install maven

# 2. Verify installation:
mvn --version
# Output: Apache Maven 3.8+

# 3. Configure Maven settings (optional)
# Edit ~/.m2/settings.xml for custom repositories

# 4. Test Maven build
cd /path/to/your/java/project
mvn clean compile
```

### Troubleshooting:
- **Maven not found**: Restart terminal
- **Build fails**: Update Maven:
  ```bash
  brew upgrade maven
  ```

---

## 7️⃣ Install Node.js (For Frontend/Tools)

**Node.js** is needed for some tools and the React frontend.

### Installation:

```bash
# 1. Install Node.js using Homebrew
brew install node

# 2. Verify installation:
node --version
# Output: v16.0.0 or higher
npm --version
# Output: npm version

# 3. Update npm to latest:
npm install -g npm@latest

# 4. Verify again:
npm --version
```

### Troubleshooting:
- **Permission denied when installing global packages**:
  ```bash
  mkdir ~/.npm-global
  npm config set prefix '~/.npm-global'
  echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.zprofile
  source ~/.zprofile
  ```

---

## 8️⃣ Install SonarQube Scanner (Optional - For Local Testing)

**SonarScanner** scans code locally before pushing to SonarQube server.

### Installation:

```bash
# 1. Install using Homebrew
brew install sonar-scanner

# 2. Verify installation:
sonar-scanner --version
# Output: SonarScanner version

# 3. Configure SonarQube connection (edit config file):
nano /usr/local/Cellar/sonar-scanner/4.x.x/libexec/conf/sonar-scanner.properties

# Add:
sonar.host.url=http://localhost:9000
sonar.login=<your-sonar-token>

# 4. Test with sample project:
sonar-scanner -Dsonar.projectKey=test -Dsonar.sources=.
```

---

## 9️⃣ Install Snyk CLI (Optional - For Vulnerability Scanning)

**Snyk CLI** scans for vulnerabilities locally.

### Installation:

```bash
# 1. Install Snyk using npm (requires Node.js)
npm install -g snyk

# 2. Verify installation:
snyk --version
# Output: Snyk version

# 3. Authenticate with Snyk:
snyk auth
# Browser opens → Get your auth token → Paste in terminal

# 4. Test Snyk with a project:
snyk test

# 5. Generate reports:
snyk test --json > snyk-report.json
```

---

## 🔟 Install Docker Compose

**Docker Compose** orchestrates multi-container Docker applications.

### Installation:

```bash
# 1. Install Docker Compose (comes with Docker Desktop)
# If not installed:
brew install docker-compose

# 2. Verify installation:
docker-compose --version
# Output: Docker Compose version 1.29+

# 3. Test with a sample compose file:
cat > docker-compose-test.yml << 'EOF'
version: '3'
services:
  web:
    image: nginx
    ports:
      - "8080:80"
EOF

# 4. Start services:
docker-compose -f docker-compose-test.yml up -d

# 5. Verify:
docker-compose ps
# Output shows running containers

# 6. Stop services:
docker-compose -f docker-compose-test.yml down
```

---

## 1️⃣1️⃣ Install Visual Studio Code (Recommended IDE)

**VS Code** is the recommended editor for this project.

### Installation:

```bash
# 1. Install VS Code using Homebrew
brew install --cask visual-studio-code

# 2. Open VS Code:
code .

# 3. Install recommended extensions:
# - Docker (Microsoft)
# - Kubernetes (Microsoft)
# - Azure Tools (Microsoft)
# - Git Graph (mhutchie)
# - SonarLint (SonarSource)
# - Maven for Java (Microsoft)

# 4. Configure VS Code settings:
# Code → Preferences → Settings
# Recommended: Enable format on save, set Python formatter, etc.
```

---

## 1️⃣2️⃣ Install JDK (Java Development Kit)

**JDK** is required to build and run Java services.

### Installation:

```bash
# 1. Install JDK using Homebrew
brew install openjdk@11
# Or for newer version:
brew install openjdk@17

# 2. Create symlink (some tools need this):
sudo ln -sfn /opt/homebrew/opt/openjdk@11/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-11.jdk

# 3. Verify installation:
java -version
# Output: Java version 11.x or 17.x

javac -version
# Output: Compiler version

# 4. Set JAVA_HOME (add to ~/.zprofile):
echo 'export JAVA_HOME=$(/usr/libexec/java_home)' >> ~/.zprofile
source ~/.zprofile

# 5. Verify JAVA_HOME:
echo $JAVA_HOME
```

---

## Installation Verification Checklist

Run this script to verify all tools are installed:

```bash
#!/bin/bash

echo "=== DevSecOps Tools Installation Verification ==="
echo ""

tools=(
    "docker:Docker"
    "docker-compose:Docker Compose"
    "kubectl:Kubernetes CLI"
    "az:Azure CLI"
    "git:Git"
    "mvn:Maven"
    "node:Node.js"
    "npm:npm"
    "java:Java"
    "javac:Java Compiler"
)

for tool in "${tools[@]}"; do
    cmd="${tool%:*}"
    name="${tool#*:}"
    if command -v $cmd &> /dev/null; then
        version=$($cmd --version 2>&1 | head -1)
        echo "✅ $name: $version"
    else
        echo "❌ $name: NOT INSTALLED"
    fi
done

echo ""
echo "=== Azure Authentication ==="
az account show 2>/dev/null && echo "✅ Azure CLI logged in" || echo "❌ Azure CLI not logged in"

echo ""
echo "=== Kubernetes Cluster ==="
kubectl cluster-info 2>/dev/null && echo "✅ Connected to cluster" || echo "⚠️  No cluster configured"

echo ""
echo "=== Docker ==="
docker ps 2>/dev/null && echo "✅ Docker running" || echo "❌ Docker not running"

echo ""
echo "=== Installation Verification Complete ==="
```

Save as `verify-tools.sh` and run:
```bash
chmod +x verify-tools.sh
./verify-tools.sh
```

---

## Recommended Installation Order

```
1. Homebrew (prerequisite for others)
   ↓
2. Docker Desktop (foundation)
   ↓
3. Git (version control)
   ↓
4. Azure CLI (infrastructure management)
   ↓
5. JDK (Java development)
   ↓
6. Maven (build tool)
   ↓
7. kubectl (Kubernetes management)
   ↓
8. Node.js (frontend/tools)
   ↓
9. Docker Compose (local testing)
   ↓
10. Optional: SonarScanner, Snyk, VS Code
```

---

## Quick Installation Script

If you want to install everything at once, save this as `install-all.sh`:

```bash
#!/bin/bash

echo "Installing all DevSecOps tools..."

# Homebrew
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Update Homebrew
brew update

# Install tools
echo "Installing tools..."
brew install docker azure-cli kubectl git maven node@18 openjdk@17 docker-compose

# Install Node.js tools globally
npm install -g snyk

# Configure Git
echo "Configuring Git (you'll need to enter your details)..."
read -p "Enter your name: " name
read -p "Enter your email: " email
git config --global user.name "$name"
git config --global user.email "$email"

# Verify installations
echo ""
echo "=== Verification ==="
docker --version
az --version
kubectl version --client
git --version
mvn --version
node --version
npm --version
java -version

echo ""
echo "✅ Installation complete!"
echo "⚠️  Please open Docker Desktop to complete setup"
echo "⚠️  Run 'az login' to authenticate with Azure"
```

Run with:
```bash
chmod +x install-all.sh
./install-all.sh
```

---

## Updating Tools

```bash
# Update Homebrew and all packages
brew update
brew upgrade

# Update specific tools
brew upgrade docker
brew upgrade azure-cli
brew upgrade kubectl
brew upgrade maven

# Update Node.js packages
npm install -g npm@latest
npm install -g snyk@latest

# Update Docker Desktop
# Settings → Check for Updates
```

---

## Storage and Performance Optimization

### Free up Docker space:
```bash
# Remove unused images, containers, volumes
docker system prune -a

# Remove dangling volumes
docker volume prune
```

### Increase Docker resources:
```bash
# Docker → Preferences → Resources
# Recommended: 
# CPU: 4+ cores
# Memory: 8+ GB
# Disk: 50+ GB
```

### Clean up old Homebrew packages:
```bash
brew cleanup
```

---

## Troubleshooting Common Issues

### Docker won't start:
```bash
# Restart Docker daemon
pkill Docker
open /Applications/Docker.app

# Or reset Docker:
# Docker → Preferences → Reset → Reset Docker to factory defaults
```

### Terminal commands not found after installation:
```bash
# Reload terminal configuration
source ~/.zprofile

# Or restart your terminal completely
```

### Permission issues:
```bash
# Fix Homebrew permissions
sudo chown -R $(whoami) /usr/local/bin

# Fix Docker permissions
sudo usermod -a -G docker $(whoami)
```

### Azure CLI authentication issues:
```bash
# Clear cached credentials
az logout
rm -rf ~/.azure

# Login again
az login
```

### Kubernetes connection issues:
```bash
# Update kubeconfig
az aks get-credentials --resource-group <rg> --name <cluster> --overwrite-existing

# Verify connection
kubectl cluster-info

# Check current context
kubectl config current-context
```

---

## System Requirements Check

```bash
# Check macOS version
sw_vers

# Check available disk space
df -h

# Check CPU cores
sysctl -n hw.ncpu

# Check total memory
sysctl -n hw.memsize | awk '{print $1 / (1024^3) " GB"}'

# Check internet connectivity
ping -c 1 8.8.8.8
```

Recommended minimums:
- macOS: 10.15 Catalina or later
- Disk: 20 GB free
- RAM: 8 GB minimum, 16 GB recommended
- CPU: 4 cores minimum, 8 recommended
- Internet: 4+ Mbps

---

## Additional Resources

### Official Documentation:
- [Docker Desktop](https://docs.docker.com/desktop/install/mac-install/)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-macos)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/)
- [Maven](https://maven.apache.org/download.cgi)
- [Git](https://git-scm.com/download/mac)
- [Homebrew](https://brew.sh/)

### Tutorials:
- Docker: https://docs.docker.com/get-started/
- Kubernetes: https://kubernetes.io/docs/tutorials/
- Azure: https://learn.microsoft.com/en-us/azure/
- Maven: https://maven.apache.org/guides/

### Community Support:
- Stack Overflow (tag with tool name)
- GitHub Issues
- Official forums
- Community Slack channels

---

## Next Steps After Installation

1. ✅ Verify all tools are installed
2. ✅ Configure Azure authentication (`az login`)
3. ✅ Setup Kubernetes cluster connection (`az aks get-credentials`)
4. ✅ Clone your GitHub repository
5. ✅ Follow [DEVSECOPS_COMPLETE_SETUP_GUIDE.md](DEVSECOPS_COMPLETE_SETUP_GUIDE.md)

---

**Installation Complete!** 🎉

You're now ready to deploy the DevSecOps pipeline.

**Start here:** [DEVSECOPS_COMPLETE_SETUP_GUIDE.md](DEVSECOPS_COMPLETE_SETUP_GUIDE.md)
