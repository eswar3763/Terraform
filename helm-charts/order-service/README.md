# Order Service Helm Chart

Order Service is a Spring Boot microservice that handles order processing in the 3-tier application.

## Quick Start

```bash
# Development
helm install order-service helm-charts/order-service \
  -n three-tier-app \
  -f helm-charts/order-service/values-dev.yaml

# Production
helm install order-service helm-charts/order-service \
  -n three-tier-app \
  -f helm-charts/order-service/values-prod.yaml
```

## Configuration

- **replicaCount**: Number of pod replicas (default: 2)
- **image.tag**: Container image tag (default: 1.0.0)
- **resources**: CPU/memory limits and requests
- **autoscaling**: HPA settings (minReplicas, maxReplicas, targets)
- **database**: PostgreSQL connection details

## Environment-Specific Values

- `values-dev.yaml`: Development configuration (1 replica, debug logging)
- `values-staging.yaml`: Staging configuration (2 replicas, info logging)
- `values-prod.yaml`: Production configuration (3+ replicas, production settings)

## Upgrade

```bash
helm upgrade order-service helm-charts/order-service \
  -n three-tier-app \
  -f helm-charts/order-service/values-prod.yaml
```

## Troubleshooting

```bash
# Check deployment
kubectl rollout status deployment/order-service -n three-tier-app

# View logs
kubectl logs -n three-tier-app -l app.kubernetes.io/name=order-service -f

# Check pod status
kubectl get pods -n three-tier-app -l app.kubernetes.io/name=order-service

# Describe deployment
kubectl describe deployment order-service -n three-tier-app
```

## Integration with ArgoCD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: order-service
  namespace: argocd
spec:
  project: three-tier-app
  source:
    repoURL: https://github.com/eswar3763/Terraform.git
    path: helm-charts/order-service
    targetRevision: main
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
```

## References

- [User Service Chart](../user-service/README.md)
- [Helm & ArgoCD Setup Guide](../../HELM_ARGOCD_COMPLETE_SETUP_GUIDE.md)
- [GitHub Repository](https://github.com/eswar3763/Terraform)
