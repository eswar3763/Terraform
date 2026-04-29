# ArgoCD Configuration and Setup

This directory contains all ArgoCD configurations for the 3-tier microservices application using GitOps principles.

## Directory Structure

```
argocd/
├── applications/              # ArgoCD Application manifests
│   ├── user-service.yaml
│   ├── order-service.yaml
│   └── payment-service.yaml
├── projects/                  # ArgoCD AppProject for RBAC
│   └── three-tier-app.yaml
├── repositories/              # Git repository credentials
│   └── github-repo.yaml
├── scripts/                   # Installation and testing scripts
│   ├── install-argocd.sh     # ArgoCD installation
│   └── test-helm-charts.sh   # Helm chart testing
└── README.md                  # This file
```

## Quick Start

### 1. Install ArgoCD

```bash
# Make script executable
chmod +x argocd/scripts/install-argocd.sh

# Run installation script
./argocd/scripts/install-argocd.sh

# You will be prompted to choose authentication method:
# - HTTPS with Personal Access Token
# - SSH with private key
```

The script will:
- ✅ Create the `argocd` namespace
- ✅ Install ArgoCD from upstream manifests
- ✅ Wait for all pods to be ready
- ✅ Retrieve the initial admin password
- ✅ Create the AppProject for RBAC
- ✅ Configure Git repository access
- ✅ Create all Application manifests
- ✅ Expose the ArgoCD UI

### 2. Access ArgoCD UI

**Option A: Port Forward (Testing)**

```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Access: https://localhost:8080
```

**Option B: LoadBalancer (Production)**

```bash
kubectl get svc -n argocd argocd-server
# Access via external IP
```

**Login Credentials**

```
Username: admin
Password: [From installation script output]
```

Change password after first login:

```bash
argocd login localhost:8080 --username admin --password <password>
argocd account update-password --current-password <password> --new-password <new-password>
```

### 3. Verify Applications

```bash
# Check application status
argocd app list

# Detailed status
argocd app get user-service
argocd app get order-service
argocd app get payment-service

# Watch sync progress
argocd app watch user-service
```

## Configuration Details

### Applications

Each Application manifest defines:

- **Source**: Git repository path to Helm chart
- **Destination**: Target cluster and namespace
- **Helm Values**: Environment-specific configurations
- **Sync Policy**: Auto-sync and pruning settings
- **RBAC Project**: Access control via AppProject

#### user-service.yaml

```yaml
source:
  path: helm-charts/user-service
  helm:
    valueFiles:
      - values.yaml
      - values-prod.yaml
```

Syncs the user-service Helm chart with production values.

#### order-service.yaml

Similar to user-service but for order processing.

#### payment-service.yaml

Similar to user-service but for payment handling.

### AppProject (RBAC)

`projects/three-tier-app.yaml` defines:

**Roles:**

1. **developers** - Can view and sync applications
2. **admins** - Full access to all resources
3. **cicd** - Can sync applications (for CI/CD pipelines)

**Source Repositories:**

```yaml
sourceRepos:
  - 'https://github.com/eswar3763/Terraform.git'
```

**Destinations:**

```yaml
destinations:
  - namespace: 'three-tier-app'
    server: 'https://kubernetes.default.svc'
```

### Git Repository

`repositories/github-repo.yaml` contains credentials for Git access.

**Two methods:**

1. **HTTPS** (with Personal Access Token)
2. **SSH** (with private key, recommended)

## Installation Scripts

### install-argocd.sh

Complete installation script that:

1. Verifies prerequisites (kubectl, Helm)
2. Creates argocd namespace
3. Installs ArgoCD from official manifests
4. Waits for all pods to be ready
5. Retrieves initial admin password
6. Creates AppProject for RBAC
7. Sets up Git repository access (HTTPS or SSH)
8. Creates all Application manifests
9. Exposes ArgoCD UI (LoadBalancer option)
10. Displays login credentials and next steps

**Usage:**

```bash
chmod +x argocd/scripts/install-argocd.sh
./argocd/scripts/install-argocd.sh
```

### test-helm-charts.sh

Comprehensive testing script that:

1. Lints all Helm charts
2. Validates template rendering
3. Tests environment-specific values
4. Performs dry-run installations
5. Checks for common configuration issues
6. Generates documentation

**Usage:**

```bash
chmod +x argocd/scripts/test-helm-charts.sh
./argocd/scripts/test-helm-charts.sh
```

## GitOps Workflow

### Deployment Flow

```
Git Repository                 # Single source of truth
         │
         │ (Webhook/Poll)
         ▼
   ArgoCD Server               # Monitors Git
         │
         │ (Fetch & Render)
         ▼
  Helm Templates Rendered
         │
         │ (Compare & Sync)
         ▼
  Kubernetes Cluster           # Auto-synced
```

### Deploy New Version

```bash
# 1. Update image tag in values-prod.yaml
sed -i 's/tag:.*/tag: "1.1.0"/' helm-charts/user-service/values-prod.yaml

# 2. Commit and push
git add helm-charts/user-service/values-prod.yaml
git commit -m "Update user-service to v1.1.0"
git push origin main

# 3. ArgoCD automatically syncs (if auto-sync enabled)
# Or manually sync:
argocd app sync user-service --prune --wait

# 4. Monitor rollout
kubectl rollout status deployment/user-service -n three-tier-app -w
```

### Rollback Version

```bash
# Option 1: Git rollback
git revert <commit-hash>
git push origin main
# ArgoCD auto-syncs to previous state

# Option 2: Helm rollback
helm rollback user-service -n three-tier-app
```

## Authentication Methods

### HTTPS with Personal Access Token

1. Generate token: https://github.com/settings/tokens
   - Scope: `repo` (full control of private repositories)
   - Save the token securely

2. Configure in secret:

```yaml
type: git
url: https://github.com/eswar3763/Terraform.git
username: eswar3763
password: ghp_xxxxxxxxxxxxxxxxxxxxxxxxxx
```

### SSH with Private Key

1. Generate SSH key:

```bash
ssh-keygen -t ed25519 -C "argocd@example.com" -f ~/.ssh/github-argocd
```

2. Add public key to GitHub:
   - Settings → SSH and GPG keys → New SSH key
   - Paste `cat ~/.ssh/github-argocd.pub`

3. Configure in secret:

```yaml
type: git
url: git@github.com:eswar3763/Terraform.git
sshPrivateKey: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  [base64-encoded private key]
  -----END OPENSSH PRIVATE KEY-----
```

## Troubleshooting

### Check ArgoCD Status

```bash
# Pods
kubectl get pods -n argocd

# Services
kubectl get svc -n argocd

# Logs
kubectl logs -n argocd deployment/argocd-server
kubectl logs -n argocd deployment/argocd-repo-server
kubectl logs -n argocd deployment/argocd-controller-manager
```

### Check Application Status

```bash
# List apps
argocd app list

# Get detailed status
argocd app get user-service

# Check health
argocd app health user-service

# View last sync operation
argocd app get user-service --refresh
```

### Git Repository Issues

```bash
# Test repository connection
argocd repo list

# Create/update repository
argocd repo add https://github.com/eswar3763/Terraform.git \
  --username eswar3763 \
  --password <token>

# Remove repository
argocd repo rm https://github.com/eswar3763/Terraform.git
```

### Application Sync Issues

```bash
# Manual sync
argocd app sync user-service

# Force sync with prune
argocd app sync user-service --prune

# Wait for sync to complete
argocd app wait user-service

# View sync logs
argocd app logs user-service
```

## Manual Application Creation

If you prefer to create applications manually:

```bash
# Create application
kubectl apply -f argocd/applications/user-service.yaml

# Create AppProject
kubectl apply -f argocd/projects/three-tier-app.yaml

# Create Git secret
kubectl apply -f argocd/repositories/github-repo.yaml
```

## Advanced Configuration

### Enable Webhook for Instant Sync

GitHub webhook for instant synchronization:

1. Get ArgoCD webhook URL:

```bash
kubectl get ingress -n argocd
# Or if using port-forward:
# https://localhost:8080/api/webhook
```

2. Add webhook to GitHub:
   - Repository Settings → Webhooks → Add webhook
   - Payload URL: `https://argocd.example.com/api/webhook`
   - Events: Push events
   - Active: ✓

### Configure RBAC Groups

Connect to Azure AD or another OIDC provider:

```bash
# Update argocd-cm ConfigMap
kubectl edit configmap argocd-cm -n argocd

# Add OIDC config:
# oidc.config: |
#   name: Azure AD
#   issuer: https://login.microsoftonline.com/{tenant-id}/v2.0
#   clientID: {client-id}
```

### Enable Notifications

Slack/Teams notifications on sync events:

```bash
# Install notifications extension
kubectl apply -f https://raw.githubusercontent.com/argoproj-labs/argocd-notifications/release-1.0/manifests/install.yaml

# Configure notification trigger
# Slack webhook in argocd-notifications-cm ConfigMap
```

## Integration with CI/CD

### Azure Pipeline Integration

Update `azure-pipelines.yml`:

```yaml
- stage: UpdateHelmValues
  jobs:
    - job: UpdateAndPush
      steps:
        - script: |
            sed -i 's/tag:.*/tag: "$(Build.BuildId)"/' \
              helm-charts/user-service/values-prod.yaml
            git add helm-charts/*/values-*.yaml
            git commit -m "Update tags to $(Build.BuildId)"
            git push
          displayName: 'Update Helm values and push'

- stage: TriggerArgoSync
  jobs:
    - job: SyncArgoCD
      steps:
        - script: |
            argocd app sync user-service --wait
          displayName: 'Sync ArgoCD applications'
```

## Best Practices

1. **Use SSH for Git access** - More secure than HTTPS tokens
2. **Enable auto-sync** - Keeps cluster in sync with Git
3. **Use separate AppProjects** - For different teams/applications
4. **Implement branch protection** - Prevent direct cluster modifications
5. **Monitor sync status** - Set up alerts for failed syncs
6. **Regular backups** - Backup ArgoCD configuration
7. **Use semver for images** - Clear version tracking
8. **Document changes** - Use meaningful commit messages

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [GitOps Best Practices](https://opengitops.dev/)
- [GitHub Repository](https://github.com/eswar3763/Terraform)
- [Helm & ArgoCD Complete Guide](../HELM_ARGOCD_COMPLETE_SETUP_GUIDE.md)

## Support

For issues or questions:
- Check the troubleshooting section above
- Review ArgoCD logs: `kubectl logs -n argocd`
- GitHub Issues: https://github.com/eswar3763/Terraform/issues
- ArgoCD Slack: https://argoproj.slack.com
