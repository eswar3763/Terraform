# User Service Helm Chart

User Service is a Spring Boot microservice that handles user management in the 3-tier application.

## Chart Details

- **Chart Version**: 1.0.0
- **Application Version**: 1.0.0
- **Type**: application
- **Namespace**: three-tier-app

## Prerequisites

- Kubernetes 1.24+
- Helm 3.10+
- Azure Container Registry (ACR) credentials configured
- PostgreSQL database accessible from the cluster

## Installation

### 1. Add Helm Repository (if using a Helm repo)

```bash
helm repo add three-tier https://github.com/eswar3763/Terraform
helm repo update
```

### 2. Install the Chart

```bash
# Development environment
helm install user-service helm-charts/user-service \
  -n three-tier-app \
  -f helm-charts/user-service/values-dev.yaml

# Staging environment
helm install user-service helm-charts/user-service \
  -n three-tier-app \
  -f helm-charts/user-service/values-staging.yaml

# Production environment
helm install user-service helm-charts/user-service \
  -n three-tier-app \
  -f helm-charts/user-service/values-prod.yaml
```

### 3. Upgrade the Chart

```bash
helm upgrade user-service helm-charts/user-service \
  -n three-tier-app \
  -f helm-charts/user-service/values-prod.yaml
```

### 4. Uninstall the Chart

```bash
helm uninstall user-service -n three-tier-app
```

## Configuration

### Default Values

All configuration values are in `values.yaml`. Key sections:

- **Replication**: Number of pod replicas
- **Image**: Container image configuration
- **Resources**: CPU and memory limits/requests
- **Autoscaling**: HPA configuration
- **Security**: Pod and container security contexts
- **Health Checks**: Liveness and readiness probes
- **Database**: PostgreSQL connection settings
- **Logging**: Log level and format

### Environment-Specific Values

- `values-dev.yaml`: Development environment (1 replica, debug logging)
- `values-staging.yaml`: Staging environment (2 replicas, info logging)
- `values-prod.yaml`: Production environment (3 replicas, warn logging, HA config)

### Override Values

```bash
# Override specific values during installation
helm install user-service helm-charts/user-service \
  -n three-tier-app \
  --set image.tag=1.1.0 \
  --set replicaCount=5
```

## Values Reference

### Image Configuration

```yaml
image:
  registry: "acrname.azurecr.io"     # ACR registry URL
  repository: "user-service"          # Image repository
  tag: "1.0.0"                        # Image tag
  pullPolicy: IfNotPresent            # Pull policy
```

### Resource Limits

```yaml
resources:
  limits:
    cpu: 500m                         # Maximum CPU
    memory: 512Mi                     # Maximum memory
  requests:
    cpu: 250m                         # Requested CPU
    memory: 256Mi                     # Requested memory
```

### Autoscaling

```yaml
autoscaling:
  enabled: true                       # Enable HPA
  minReplicas: 2                      # Minimum pods
  maxReplicas: 5                      # Maximum pods
  targetCPUUtilizationPercentage: 70  # CPU threshold
  targetMemoryUtilizationPercentage: 80  # Memory threshold
```

### Database Configuration

```yaml
database:
  host: postgres-service              # Database host
  port: 5432                          # Database port
  name: three_tier_db                 # Database name
  username: postgres                  # Database user
  passwordSecret: postgres-secret     # Secret containing password
  passwordKey: password               # Key in secret
```

## Helm Templates

### deployment.yaml
Kubernetes Deployment resource that manages pod replicas with:
- Container spec with image, ports, and environment variables
- Security contexts for pod and container
- Health checks (liveness and readiness probes)
- Resource requests and limits
- Volume mounts for temporary storage
- Pod anti-affinity for distribution

### service.yaml
Kubernetes Service resource that:
- Exposes pods on port 8080
- Uses ClusterIP by default (can be changed to LoadBalancer)
- Routes traffic to pods using label selectors

### configmap.yaml
ConfigMap containing:
- Spring Boot application.yaml configuration
- Database connection settings
- Logging configuration
- Actuator/metrics configuration

### hpa.yaml
HorizontalPodAutoscaler that:
- Scales pods based on CPU and memory metrics
- Defines min/max replica bounds
- Includes scaling policies for smooth scaling

### serviceaccount.yaml
ServiceAccount for pod identity and RBAC.

### _helpers.tpl
Helm template helpers providing:
- Chart name and version
- Full name generation
- Label generation (common, selector)
- Service account name resolution

### NOTES.txt
Post-installation instructions displayed to users.

## Deployment Workflow

### Development

```bash
# 1. Build and push image to ACR
docker build -t acrname.azurecr.io/user-service:dev .
docker push acrname.azurecr.io/user-service:dev

# 2. Update dev values
sed -i 's/tag:.*/tag: "dev"/' helm-charts/user-service/values-dev.yaml

# 3. Install/Upgrade chart
helm upgrade --install user-service helm-charts/user-service \
  -n three-tier-app \
  -f helm-charts/user-service/values-dev.yaml

# 4. Verify deployment
kubectl rollout status deployment/user-service -n three-tier-app
kubectl logs -n three-tier-app -l app.kubernetes.io/name=user-service -f
```

### Production Release

```bash
# 1. Tag image with version
docker build -t acrname.azurecr.io/user-service:1.0.0 .
docker push acrname.azurecr.io/user-service:1.0.0

# 2. Update prod values with new version
sed -i 's/tag:.*/tag: "1.0.0"/' helm-charts/user-service/values-prod.yaml

# 3. Commit to Git (triggers ArgoCD)
git add helm-charts/user-service/values-prod.yaml
git commit -m "Release user-service v1.0.0"
git push origin main

# 4. ArgoCD automatically syncs the changes
# Monitor in ArgoCD UI or with CLI:
argocd app sync user-service --prune --wait
```

## Troubleshooting

### Check Chart Syntax

```bash
helm lint helm-charts/user-service
```

### Dry Run to See Generated YAML

```bash
helm template user-service helm-charts/user-service \
  -f helm-charts/user-service/values-prod.yaml
```

### View Deployment Status

```bash
# Check rollout status
kubectl rollout status deployment/user-service -n three-tier-app

# Describe deployment
kubectl describe deployment user-service -n three-tier-app

# View pod status
kubectl get pods -n three-tier-app -l app.kubernetes.io/name=user-service

# Check pod logs
kubectl logs -n three-tier-app <pod-name>

# Execute into pod
kubectl exec -it -n three-tier-app <pod-name> -- /bin/bash
```

### Debug HPA Issues

```bash
# Check HPA status
kubectl get hpa -n three-tier-app

# Describe HPA
kubectl describe hpa user-service -n three-tier-app

# View metrics
kubectl top nodes
kubectl top pods -n three-tier-app
```

### Database Connection Issues

```bash
# Test connectivity from pod
kubectl run debug --image=busybox --rm -it --restart=Never -- \
  nc -zv postgres-service 5432

# Check environment variables in pod
kubectl exec -n three-tier-app <pod-name> -- env | grep DB_

# View logs for connection errors
kubectl logs -n three-tier-app <pod-name> | grep -i "connection\|timeout\|refused"
```

## Integration with ArgoCD

### Create ArgoCD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: user-service
  namespace: argocd
spec:
  project: three-tier-app
  source:
    repoURL: https://github.com/eswar3763/Terraform.git
    targetRevision: main
    path: helm-charts/user-service
    helm:
      valueFiles:
        - values.yaml
        - values-prod.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: three-tier-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### GitOps Workflow

1. Update `values-prod.yaml` in Git
2. Commit and push changes
3. ArgoCD webhook detects change
4. ArgoCD renders templates and compares with cluster
5. ArgoCD syncs changes automatically

## Rollback

### Helm Rollback

```bash
# View release history
helm history user-service -n three-tier-app

# Rollback to previous release
helm rollback user-service -n three-tier-app

# Rollback to specific revision
helm rollback user-service 1 -n three-tier-app
```

### Git-based Rollback (with ArgoCD)

```bash
# Revert recent commit
git revert HEAD
git push origin main

# ArgoCD automatically syncs previous state
argocd app wait user-service
```

## Monitoring

### Prometheus Metrics

The chart enables Prometheus scraping:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/actuator/prometheus"
```

### Custom Metrics

Spring Boot Actuator metrics available at:
- `/actuator/health` - Application health
- `/actuator/metrics` - Application metrics
- `/actuator/prometheus` - Prometheus metrics

### Port Forwarding for Local Access

```bash
kubectl port-forward -n three-tier-app svc/user-service 8080:8080
# Metrics: http://localhost:8080/actuator/metrics
# Prometheus: http://localhost:8080/actuator/prometheus
```

## Security

### Pod Security Context

```yaml
podSecurityContext:
  runAsNonRoot: true         # Run as non-root user
  runAsUser: 1000            # Specific user ID
  fsGroup: 1000              # File system group
```

### Container Security Context

```yaml
securityContext:
  allowPrivilegeEscalation: false    # Prevent privilege escalation
  readOnlyRootFilesystem: false      # (can be true if needed)
  capabilities:
    drop:
      - ALL                          # Drop all Linux capabilities
```

### RBAC

ServiceAccount with minimal permissions:

```bash
# Check RBAC for service account
kubectl get rolebinding,clusterrolebinding -n three-tier-app \
  -o wide | grep user-service
```

## Performance Tuning

### JVM Options (Production)

```yaml
env:
  - name: JAVA_OPTS
    value: "-Xms256m -Xmx512m -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
```

### Connection Pool Tuning

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 20        # Max connections
      minimum-idle: 5              # Min idle connections
      connection-timeout: 30000    # Connection timeout
```

### Request/Response Optimization

```yaml
server:
  compression:
    enabled: true                  # Enable gzip compression
    min-response-size: 1024        # Minimum size to compress
  tomcat:
    threads:
      max: 200                     # Max threads
      min-spare: 10                # Min spare threads
```

## Support

For issues and questions:
- GitHub Issues: https://github.com/eswar3763/Terraform/issues
- Documentation: https://github.com/eswar3763/Terraform/blob/main/HELM_ARGOCD_COMPLETE_SETUP_GUIDE.md

## License

See LICENSE file in the repository.
