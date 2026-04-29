# Helm Charts for 3-Tier Microservices Application

This directory contains Helm charts for the 3-tier Java microservices application running on Azure Kubernetes Service (AKS).

## Overview

Helm charts provide:
- **Templating**: Reusable Kubernetes manifests with configurable values
- **Package Management**: Versioned application releases
- **Environment Support**: Dev, Staging, and Production configurations
- **Dependency Management**: Clear service dependencies
- **Rollback Capability**: Easy version rollbacks

## Charts Included

### 1. user-service

User management microservice for the 3-tier application.

**Location**: `./user-service/`

**Key Features**:
- Spring Boot REST API
- PostgreSQL database integration
- Horizontal Pod Autoscaling (HPA)
- Health checks (liveness & readiness probes)
- Prometheus metrics export
- Security contexts and RBAC

**Quick Install**:

```bash
# Development
helm install user-service ./user-service \
  -n three-tier-app \
  -f ./user-service/values-dev.yaml

# Production
helm install user-service ./user-service \
  -n three-tier-app \
  -f ./user-service/values-prod.yaml
```

**Configuration Files**:
- `Chart.yaml` - Chart metadata and versioning
- `values.yaml` - Default configuration
- `values-dev.yaml` - Development environment overrides
- `values-staging.yaml` - Staging environment overrides
- `values-prod.yaml` - Production environment overrides
- `templates/` - Kubernetes manifest templates
- `README.md` - Detailed documentation

### 2. order-service

Order processing microservice for the 3-tier application.

**Location**: `./order-service/`

**Similar to user-service** with:
- Order processing business logic
- Same infrastructure patterns
- Identical deployment strategy
- Compatible with user-service

### 3. payment-service

Payment handling microservice for the 3-tier application.

**Location**: `./payment-service/`

**Similar to user-service and order-service** with:
- Payment processing business logic
- PCI DSS compliance requirements (if applicable)
- Same deployment patterns

## Directory Structure

```
helm-charts/
├── user-service/
│   ├── Chart.yaml              # Metadata
│   ├── values.yaml             # Default values
│   ├── values-dev.yaml         # Dev environment
│   ├── values-staging.yaml     # Staging environment
│   ├── values-prod.yaml        # Production environment
│   ├── templates/
│   │   ├── deployment.yaml     # Kubernetes Deployment
│   │   ├── service.yaml        # Kubernetes Service
│   │   ├── configmap.yaml      # Configuration
│   │   ├── hpa.yaml            # Horizontal Pod Autoscaler
│   │   ├── serviceaccount.yaml # Service Account
│   │   ├── _helpers.tpl        # Template helpers
│   │   ├── NOTES.txt           # Post-install notes
│   │   └── README.md           # Chart documentation
│   └── README.md               # Detailed guide
├── order-service/              # Similar structure
├── payment-service/            # Similar structure
└── README.md                   # This file
```

## Common Values

All charts support the following common configuration values:

### Image Configuration

```yaml
image:
  registry: "acrname.azurecr.io"
  repository: "user-service"
  tag: "1.0.0"
  pullPolicy: IfNotPresent

imagePullSecrets:
  - name: acr-secret
```

### Service Configuration

```yaml
service:
  type: ClusterIP
  port: 8080
  targetPort: 8080
```

### Resource Management

```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```

### Autoscaling

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70
```

### Health Checks

```yaml
livenessProbe:
  httpGet:
    path: /actuator/health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /actuator/health/ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
```

### Database Configuration

```yaml
database:
  host: postgres-service
  port: 5432
  name: three_tier_db
  username: postgres
  passwordSecret: postgres-secret
  passwordKey: password
```

## Environment-Specific Values

### Development (values-dev.yaml)

```yaml
replicaCount: 1                    # Single replica
image.tag: "1.0.0-dev"            # Dev image tag
autoscaling.enabled: false         # No auto-scaling
resources.limits.memory: "256Mi"  # Lower memory
logging.level: "DEBUG"             # Debug logging
```

### Staging (values-staging.yaml)

```yaml
replicaCount: 2                    # 2 replicas
image.tag: "1.0.0-staging"        # Staging image tag
autoscaling.enabled: true          # Auto-scaling enabled
autoscaling.minReplicas: 2         # Min 2 replicas
autoscaling.maxReplicas: 3         # Max 3 replicas
logging.level: "INFO"              # Info logging
```

### Production (values-prod.yaml)

```yaml
replicaCount: 3                    # 3+ replicas
image.tag: "1.0.0"                # Release image tag
autoscaling.enabled: true          # Auto-scaling enabled
autoscaling.minReplicas: 3         # Min 3 replicas
autoscaling.maxReplicas: 10        # Max 10 replicas
resources.limits.memory: "1024Mi"  # Higher memory
logging.level: "WARN"              # Warn logging
ingress.enabled: true              # Enable ingress
podDisruptionBudget.minAvailable: 2 # HA configuration
```

## Installation

### Prerequisites

```bash
# Verify Helm is installed
helm version                       # v3.10+

# Verify kubectl connectivity
kubectl cluster-info               # Should connect to AKS

# Create namespace
kubectl create namespace three-tier-app
```

### Quick Start

```bash
# Install all services for development
helm install user-service ./user-service \
  -n three-tier-app \
  -f ./user-service/values-dev.yaml

helm install order-service ./order-service \
  -n three-tier-app \
  -f ./order-service/values-dev.yaml

helm install payment-service ./payment-service \
  -n three-tier-app \
  -f ./payment-service/values-dev.yaml

# Verify installations
kubectl get deployments -n three-tier-app
kubectl get services -n three-tier-app
kubectl get pods -n three-tier-app
```

### Production Deployment

```bash
# Install with production values
helm install user-service ./user-service \
  -n three-tier-app \
  -f ./user-service/values-prod.yaml

# Upgrade existing release
helm upgrade user-service ./user-service \
  -n three-tier-app \
  -f ./user-service/values-prod.yaml

# Rollback to previous version
helm rollback user-service -n three-tier-app
```

## Validation

### Lint Charts

```bash
# Check for issues
helm lint ./user-service
helm lint ./order-service
helm lint ./payment-service
```

### Validate Templates

```bash
# Preview rendered manifests
helm template user-service ./user-service \
  -f ./user-service/values-prod.yaml

# Dry-run installation
helm install user-service ./user-service \
  -n three-tier-app \
  -f ./user-service/values-prod.yaml \
  --dry-run --debug
```

### Run Test Script

```bash
# Make script executable
chmod +x ../argocd/scripts/test-helm-charts.sh

# Run comprehensive tests
../argocd/scripts/test-helm-charts.sh
```

## Customization

### Override Values During Installation

```bash
# Override specific values
helm install user-service ./user-service \
  -n three-tier-app \
  -f ./user-service/values-prod.yaml \
  --set image.tag=1.1.0 \
  --set replicaCount=5
```

### Create Custom Values File

```bash
# Create environment-specific values
cat > ./user-service/values-custom.yaml <<EOF
replicaCount: 4
image:
  tag: "1.0.0-custom"
resources:
  limits:
    cpu: 2000m
    memory: 2048Mi
EOF

# Install with custom values
helm install user-service ./user-service \
  -n three-tier-app \
  -f ./user-service/values.yaml \
  -f ./user-service/values-custom.yaml
```

## Integration with ArgoCD

### GitOps Deployment

Helm charts are deployed via ArgoCD for GitOps management:

```yaml
# argocd/applications/user-service.yaml
source:
  path: helm-charts/user-service
  helm:
    valueFiles:
      - values.yaml
      - values-prod.yaml
```

### Sync Applications

```bash
# Sync all applications
argocd app sync user-service

# Auto-sync is enabled by default
# Changes in Git automatically sync to cluster
```

## Monitoring

### View Pod Metrics

```bash
# Check CPU and memory usage
kubectl top pods -n three-tier-app

# Watch metrics
watch kubectl top pods -n three-tier-app
```

### Access Application Metrics

```bash
# Port-forward to service
kubectl port-forward -n three-tier-app svc/user-service 8080:8080

# Prometheus metrics
curl http://localhost:8080/actuator/prometheus
```

### Monitor Deployments

```bash
# Check rollout status
kubectl rollout status deployment/user-service -n three-tier-app

# Watch rollout
kubectl rollout status -w deployment/user-service -n three-tier-app
```

## Troubleshooting

### Check Installation

```bash
# Verify deployments
kubectl get deployments -n three-tier-app

# Describe deployment
kubectl describe deployment user-service -n three-tier-app

# Check pod status
kubectl get pods -n three-tier-app -o wide
```

### View Logs

```bash
# Pod logs
kubectl logs -n three-tier-app -l app.kubernetes.io/name=user-service

# Follow logs
kubectl logs -n three-tier-app -l app.kubernetes.io/name=user-service -f

# View events
kubectl get events -n three-tier-app --sort-by='.lastTimestamp'
```

### Debug Issues

```bash
# Execute shell in pod
kubectl exec -it -n three-tier-app <pod-name> -- /bin/bash

# Check environment variables
kubectl exec -n three-tier-app <pod-name> -- env

# Test database connectivity
kubectl exec -n three-tier-app <pod-name> -- \
  nc -zv postgres-service 5432
```

## Updates and Upgrades

### Update Chart Version

```bash
# Update Chart.yaml
sed -i 's/version:.*/version: 1.1.0/' ./user-service/Chart.yaml

# Upgrade deployed release
helm upgrade user-service ./user-service \
  -n three-tier-app \
  -f ./user-service/values-prod.yaml
```

### Update Application Version

```bash
# Update image tag in values
sed -i 's/tag:.*/tag: "1.1.0"/' ./user-service/values-prod.yaml

# Commit to Git (triggers ArgoCD)
git add helm-charts/user-service/values-prod.yaml
git commit -m "Update user-service to v1.1.0"
git push origin main
```

### Rollback

```bash
# Helm rollback
helm rollback user-service -n three-tier-app

# Git rollback (with ArgoCD)
git revert <commit-hash>
git push origin main
# ArgoCD auto-syncs
```

## Security

### RBAC

Service accounts are created for each service with minimal permissions:

```bash
# Check service account
kubectl get sa -n three-tier-app

# View role bindings
kubectl get rolebindings -n three-tier-app
```

### Pod Security

```yaml
podSecurityContext:
  runAsNonRoot: true     # Run as non-root
  runAsUser: 1000        # Specific user ID
  fsGroup: 1000

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false
```

### Network Policies

Network policies are managed separately but coordinates with these charts.

## References

- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [ArgoCD Integration](../argocd/README.md)
- [Complete Helm & ArgoCD Guide](../HELM_ARGOCD_COMPLETE_SETUP_GUIDE.md)
- [GitHub Repository](https://github.com/eswar3763/Terraform)

## Support

For questions or issues:
- Review individual chart READMEs
- Check the troubleshooting section above
- Consult Helm documentation
- Open GitHub issues

## License

See LICENSE file in the root directory.
