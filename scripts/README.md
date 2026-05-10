# Helm & ArgoCD Scripts

This directory contains automation scripts for managing Helm charts and ArgoCD deployments.

## Quick Start

### 1. Make scripts executable

```bash
chmod +x scripts/*.sh
```

### 2. Validate Helm charts

```bash
./scripts/helm-setup.sh all
```

### 3. Setup ArgoCD

```bash
export GITHUB_PAT=ghp_xxxxxxxxxxxx
./scripts/argocd-setup.sh complete
```

### 4. Test integration

```bash
./scripts/helm-argocd-integration.sh test
```

## Scripts Overview

### argocd-setup.sh

Installs and configures ArgoCD for GitOps-based deployments.

**Usage:**
```bash
./scripts/argocd-setup.sh [command]
```

**Commands:**
- `install` - Install ArgoCD only
- `configure` - Configure repository access
- `deploy` - Deploy applications
- `credentials` - Get admin credentials
- `portforward` - Setup port forwarding info
- `loadbalancer` - Expose via LoadBalancer
- `complete` - Complete setup (all steps)
- `cleanup` - Remove ArgoCD installation

**Environment Variables:**
- `GITHUB_PAT` - GitHub Personal Access Token (required for configure)

**Examples:**
```bash
# Complete setup
export GITHUB_PAT=ghp_xxxxx...
./scripts/argocd-setup.sh complete

# Just install ArgoCD
./scripts/argocd-setup.sh install

# Configure repository and deploy apps
./scripts/argocd-setup.sh configure
./scripts/argocd-setup.sh deploy
```

### helm-setup.sh

Validates and tests Helm charts before deployment.

**Usage:**
```bash
./scripts/helm-setup.sh [command]
```

**Commands:**
- `validate` - Validate chart structures
- `lint` - Run Helm lint on all charts
- `template` - Generate and test Helm templates
- `test` - Test Helm installations (dry-run)
- `validate-env` - Validate environment-specific values
- `images` - Check image references
- `database` - Validate database configurations
- `info` - Display chart information
- `all` - Run all validations

**Examples:**
```bash
# Validate all charts
./scripts/helm-setup.sh all

# Just lint charts
./scripts/helm-setup.sh lint

# Generate templates
./scripts/helm-setup.sh template

# Display chart info
./scripts/helm-setup.sh info
```

### helm-argocd-integration.sh

Tests the integration between Helm charts and ArgoCD applications.

**Usage:**
```bash
./scripts/helm-argocd-integration.sh [command]
```

**Commands:**
- `test` - Run all integration tests
- `helm` - Test Helm installations
- `pods` - Test pod health
- `services` - Test service connectivity
- `argocd` - Test ArgoCD applications
- `replicas` - Check deployment replicas
- `logs` - Check pod logs
- `resources` - Check resource usage
- `monitor` - Monitor deployments
- `report` - Generate test report
- `rollback` - Rollback deployments
- `cleanup` - Delete test namespace

**Examples:**
```bash
# Run all tests
./scripts/helm-argocd-integration.sh test

# Test pods only
./scripts/helm-argocd-integration.sh pods

# Generate test report
./scripts/helm-argocd-integration.sh report

# Monitor deployments
./scripts/helm-argocd-integration.sh monitor
```

### helm-release-manager.sh

Manages Helm releases, upgrades, and rollbacks.

**Usage:**
```bash
./scripts/helm-release-manager.sh [command] [release] [options]
```

**Commands:**
- `list` - List all Helm releases
- `info [release]` - Get release information
- `values [release]` - Get release values
- `history [release]` - Show release history
- `status [release]` - Get release status
- `install [release] [env]` - Install a release
- `upgrade [release] [env] [version]` - Upgrade a release
- `rollback [release] [rev]` - Rollback a release
- `delete [release]` - Delete a release
- `compare [release] [env]` - Compare values
- `validate` - Validate all releases

**Examples:**
```bash
# List releases
./scripts/helm-release-manager.sh list

# Install user-service in production
./scripts/helm-release-manager.sh install user-service prod

# Upgrade with new image version
./scripts/helm-release-manager.sh upgrade user-service prod 1.1.0

# Rollback to previous version
./scripts/helm-release-manager.sh rollback user-service

# Get status
./scripts/helm-release-manager.sh status user-service

# Compare values
./scripts/helm-release-manager.sh compare user-service prod
```

## Complete Workflow

### Initial Setup

```bash
# 1. Validate all Helm charts
./scripts/helm-setup.sh all

# 2. Install ArgoCD
./scripts/argocd-setup.sh install

# 3. Get initial credentials
./scripts/argocd-setup.sh credentials

# 4. Configure repository
export GITHUB_PAT=ghp_xxxxx...
./scripts/argocd-setup.sh configure

# 5. Deploy applications
./scripts/argocd-setup.sh deploy
```

### Deployment

```bash
# 1. Access ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Open https://localhost:8080 in browser
# Login with admin credentials from step above

# 2. Monitor applications
./scripts/helm-argocd-integration.sh monitor

# 3. Check deployment status
./scripts/helm-release-manager.sh list
./scripts/helm-release-manager.sh status user-service
```

### Update & Upgrade

```bash
# 1. Update Helm values in Git
# Edit helm-charts/user-service/values-prod.yaml
# Update image tag, replicas, etc.

# 2. Commit and push
git add helm-charts/
git commit -m "Update user-service configuration"
git push origin main

# 3. ArgoCD automatically syncs (if auto-sync enabled)
# Monitor sync progress
argocd app watch user-service

# Or manually upgrade via Helm
./scripts/helm-release-manager.sh upgrade user-service prod 1.1.0
```

### Troubleshooting

```bash
# Generate test report
./scripts/helm-argocd-integration.sh report

# Test specific component
./scripts/helm-argocd-integration.sh pods
./scripts/helm-argocd-integration.sh services
./scripts/helm-argocd-integration.sh logs

# Check release details
./scripts/helm-release-manager.sh values user-service
./scripts/helm-release-manager.sh history user-service

# Rollback if issues occur
./scripts/helm-release-manager.sh rollback user-service
```

## Prerequisites

### Required Software

- Kubernetes 1.24+ (installed and configured)
- Helm 3.10+
- kubectl 1.24+
- bash 4.0+
- Git

### Optional

- ArgoCD CLI 2.8+ (for advanced operations)
- jq (for JSON parsing)

### Installation

```bash
# macOS (Homebrew)
brew install helm kubectl argocd

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
brew install argocd  # or from releases page
```

## Configuration

### Environment Variables

```bash
# GitHub access token (for ArgoCD repository)
export GITHUB_PAT=ghp_xxxxxxxxxxxx

# ArgoCD admin password (optional, generates random if not set)
export ARGOCD_ADMIN_PASSWORD=mypassword

# Custom namespace (default: three-tier-app)
export NAMESPACE=my-custom-namespace

# Custom Kubernetes context
export KUBECONFIG=/path/to/kubeconfig
kubectl config use-context my-cluster
```

### Kubernetes Namespace

All scripts use `three-tier-app` namespace by default. Customize by setting environment variable:

```bash
export NAMESPACE=my-namespace
```

## File Structure

```
scripts/
├── argocd-setup.sh              # ArgoCD installation and setup
├── helm-setup.sh                # Helm chart validation
├── helm-argocd-integration.sh   # Integration testing
├── helm-release-manager.sh      # Release management
└── README.md                    # This file

helm-charts/
├── user-service/
├── order-service/
└── payment-service/

argocd/
├── applications/                # ArgoCD Application manifests
│   ├── user-service.yaml
│   ├── order-service.yaml
│   └── payment-service.yaml
├── projects/                    # AppProject for RBAC
│   └── three-tier-app.yaml
└── repositories/                # Repository credentials
    └── github-repo.yaml
```

## Common Issues & Troubleshooting

### Issue: "kubectl not found"

```bash
# Install kubectl
brew install kubectl
# or
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

### Issue: "helm not found"

```bash
brew install helm
```

### Issue: ArgoCD password not retrievable

```bash
# Password is deleted after first login. Reset it:
kubectl exec -it -n argocd argocd-server-xxxxx -- argocd account update-password
```

### Issue: Repository connection failed

```bash
# Verify GitHub PAT has correct permissions:
# - repo (full control)
# - admin:public_key (if using SSH)

# Update repository secret
kubectl edit secret -n argocd github-repo
```

### Issue: Pods not starting

```bash
# Check pod events
kubectl describe pod <pod-name> -n three-tier-app

# Check logs
kubectl logs <pod-name> -n three-tier-app

# Check node resources
kubectl top nodes
kubectl describe node <node-name>
```

### Issue: ArgoCD app not syncing

```bash
# Check app status
argocd app get user-service

# Manual sync
argocd app sync user-service

# Force refresh
argocd app get user-service --refresh
```

## Performance Tips

### Optimize Helm Template Rendering

```bash
# Cache Helm dependencies
helm dependency update helm-charts/user-service

# Use --set for overrides instead of multiple -f flags
helm install user-service ./helm-charts/user-service \
  --set image.tag=1.1.0 \
  --set replicas=5
```

### ArgoCD Performance

```bash
# Increase sync frequency
# Edit argocd-cm ConfigMap
kubectl edit configmap argocd-cm -n argocd

# Add/modify:
# application.instanceLabelKey: argocd.argoproj.io/instance
# server.disable.auth: "false"
```

### Kubernetes Metrics

```bash
# Ensure Metrics Server is installed
kubectl get deployment metrics-server -n kube-system

# If not installed:
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

## Security Best Practices

### 1. GitHub Token Security

```bash
# Never commit tokens to Git
echo "GITHUB_PAT=..." >> ~/.bashrc

# Store in environment variable
export GITHUB_PAT=ghp_xxxxx...
```

### 2. SSH-based Repository Access

Instead of PAT, use SSH key in `argocd/repositories/github-repo.yaml`:

```yaml
sshPrivateKey: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  ... your SSH private key ...
  -----END OPENSSH PRIVATE KEY-----
```

### 3. RBAC Configuration

Review `argocd/projects/three-tier-app.yaml` for role definitions:

```yaml
roles:
  - name: developers
    policies: [...]
  - name: admins
    policies: [...]
```

### 4. Network Policies

Ensure network policies are in place:

```bash
kubectl apply -f k8s/rbac-network-policies.yaml
```

## References

- [Helm Documentation](https://helm.sh/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Main Setup Guide](../HELM_ARGOCD_COMPLETE_SETUP_GUIDE.md)

## Support

For issues and questions:
- GitHub Issues: https://github.com/eswar3763/Terraform/issues
- Documentation: https://github.com/eswar3763/Terraform/blob/main/HELM_ARGOCD_COMPLETE_SETUP_GUIDE.md

## Contributing

To improve these scripts:
1. Test thoroughly in your environment
2. Add new features with clear error messages
3. Update documentation
4. Submit pull request

---

**Last Updated**: May 2026  
**Version**: 1.0.0  
**Author**: DevOps Team
