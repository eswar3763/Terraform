# Payment Service Helm Chart

Payment Service is a Spring Boot microservice that handles payment processing in the 3-tier application.

## Quick Start

```bash
helm install payment-service helm-charts/payment-service \
  -n three-tier-app \
  -f helm-charts/payment-service/values-prod.yaml
```

## Upgrade

```bash
helm upgrade payment-service helm-charts/payment-service \
  -n three-tier-app \
  -f helm-charts/payment-service/values-prod.yaml
```

## Configuration

See `values.yaml` for all available configuration options.

## Troubleshooting

```bash
kubectl logs -n three-tier-app -l app.kubernetes.io/name=payment-service -f
kubectl rollout status deployment/payment-service -n three-tier-app
```

## Related Charts

- [User Service](../user-service/README.md)
- [Order Service](../order-service/README.md)
