# Kubernetes Canary Deployment - Complete Guide
## Progressive Delivery, Zero-Downtime Deployments, and Automated Rollbacks

**Last Updated**: May 2026  
**Version**: 1.0.0

---

## Table of Contents
1. [Canary Deployment Fundamentals](#canary-deployment-fundamentals)
2. [Flagger Setup & Installation](#flagger-setup--installation)
3. [Canary Deployment Implementation](#canary-deployment-implementation)
4. [Monitoring & Metrics](#monitoring--metrics)
5. [Automated Rollback Strategies](#automated-rollback-strategies)
6. [Real-World Production Scenarios](#real-world-production-scenarios)
7. [Interview Q&A](#interview-qa)
8. [Troubleshooting Guide](#troubleshooting-guide)

---

## Canary Deployment Fundamentals

### What is Canary Deployment?

Canary deployment is a risk reduction strategy where you release a new version to a small percentage of users first, monitor its behavior, and gradually increase traffic if it's stable.

```
┌──────────────────────────────────────────────────────────────┐
│                  Canary Deployment Flow                      │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Time 0: Release v1.1.0                                      │
│  └─→ 5% traffic to v1.1.0 (canary)                          │
│  └─→ 95% traffic to v1.0.0 (stable)                         │
│                                                              │
│  Time 5 min: Monitor metrics                                │
│  └─→ Error rate normal ✅                                   │
│  └─→ Latency normal ✅                                      │
│  └─→ Increase to 10% traffic                               │
│                                                              │
│  Time 10 min: Continue monitoring                           │
│  └─→ All metrics green ✅                                   │
│  └─→ Increase to 25% traffic                               │
│                                                              │
│  Time 15 min: Check again                                   │
│  └─→ Performance excellent ✅                              │
│  └─→ Increase to 50% traffic                               │
│                                                              │
│  Time 20 min: Final check                                  │
│  └─→ All systems go ✅                                     │
│  └─→ Route 100% traffic to v1.1.0                         │
│  └─→ v1.0.0 removed                                       │
│                                                              │
│  OR if issues detected at any point:                        │
│  └─→ Revert 100% traffic back to v1.0.0 (instant rollback) │
│  └─→ No user impact (canary already in production)         │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Benefits of Canary Deployment

✅ **Risk Reduction**: Issues only affect small % of users initially  
✅ **Zero-Downtime**: No service interruption during rollout  
✅ **Quick Rollback**: Instant revert if issues detected  
✅ **Real-World Testing**: Test with actual production traffic  
✅ **Metrics-Driven**: Decisions based on observable metrics  
✅ **User-Friendly**: Gradual transition for large user bases  

### Canary vs Blue-Green vs Rolling Update

| Aspect | Canary | Blue-Green | Rolling |
|--------|--------|-----------|---------|
| **Risk** | Very Low (5% start) | Low (parallel envs) | Medium (rolling) |
| **Resource Cost** | Medium (overlapping) | High (2x infra) | Low (sequential) |
| **Rollback Speed** | Instant | Instant | Gradual |
| **Time to Deploy** | 15-30 min | 1-5 min | 5-15 min |
| **Traffic Control** | Fine-grained | Simple on/off | Automatic |
| **Best For** | Critical services | Major releases | Non-critical |
| **Monitoring** | Required | Optional | Optional |

---

## Flagger Setup & Installation

### What is Flagger?

Flagger is an open-source project for automating canary deployments on Kubernetes. It uses service mesh (Istio, Linkerd) or API Gateway (NGINX) to control traffic splitting.

### Installation

```bash
# Step 1: Add Flagger Helm repository
helm repo add flagger https://flagger.app
helm repo update

# Step 2: Install Flagger in kube-system namespace
helm upgrade -i flagger flagger/flagger \
  --namespace kube-system \
  --set prometheus.enabled=true \
  --set prometheus.install=true \
  --set serviceMeshProvider=istio

# Step 3: Install Prometheus (required for metrics)
helm upgrade -i prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.remoteWrite[0].url=http://prometheus:9090

# Step 4: Verify installation
kubectl get pods -n kube-system | grep flagger
kubectl get crd | grep flagger

# Step 5: Create Prometheus ServiceMonitor for Flagger
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: flagger
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: flagger
  endpoints:
    - port: http
      interval: 60s
EOF
```

### Install Istio (for traffic management)

```bash
# Step 1: Download Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.18.0

# Step 2: Install Istio
./bin/istioctl install --set profile=production -y

# Step 3: Enable sidecar injection in namespace
kubectl label namespace three-tier-app istio-injection=enabled

# Step 4: Verify Istio installation
kubectl get pods -n istio-system
kubectl get crd | grep istio
```

---

## Canary Deployment Implementation

### Step 1: Create Flagger Canary Resource

```yaml
# helm-charts/user-service/templates/canary.yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: user-service
  namespace: three-tier-app
spec:
  # Target deployment to canary
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: user-service
  
  # How to identify the service
  service:
    name: user-service
    port: 8080
    targetPort: 8080
  
  # Analysis configuration
  analysis:
    # How often to check metrics
    interval: 5m
    # How long to wait for canary to stabilize
    threshold: 5
    # Max traffic weight for canary
    maxWeight: 50
    # Traffic increment per interval
    stepWeight: 5
    
    # Metric-based analysis
    metrics:
      # Check if error rate increases
      - name: error_rate
        thresholdRange:
          max: 1  # Max 1% error rate
        interval: 1m
      
      # Check if latency increases
      - name: latency
        thresholdRange:
          max: 500  # Max 500ms p99 latency
        interval: 1m
      
      # Check if request success rate is maintained
      - name: request_success_rate
        thresholdRange:
          min: 99  # At least 99% success
        interval: 1m
    
    # Webhooks for custom validation
    webhooks:
      - name: acceptance-test
        url: http://flagger-loadtester/
        timeout: 5s
        metadata:
          type: smoke
          cmd: "curl -sd 'test' http://user-service:8080/health | grep success"
      
      - name: load-test
        url: http://flagger-loadtester/
        timeout: 5s
        metadata:
          type: load
          cmd: "hey -z 1m -q 10 -c 2 http://user-service:8080/"
  
  # Skip canary and go straight to stable
  skipAnalysis: false
  
  # Istio traffic policy
  skipAnalysis: false
  # trafficPolicy:
  #   connectionPool:
  #     tcp:
  #       maxConnections: 100
  #     http:
  #       http1MaxPendingRequests: 100
  #       http2MaxRequests: 1000
  #       maxRequestsPerConnection: 2
  #   outlierDetection:
  #     consecutiveErrors: 5
  #     interval: 30s
  #     baseEjectionTime: 30s
```

### Step 2: Enable Canary in Helm Values

```yaml
# helm-charts/user-service/values.yaml

# Canary deployment settings
canary:
  enabled: true
  analysis:
    interval: 5m
    threshold: 5
    maxWeight: 50
    stepWeight: 5
    
    metrics:
      - name: error_rate
        maxError: 1
      - name: latency
        maxLatency: 500
      - name: success_rate
        minSuccess: 99
    
    webhooks:
      smoke_test: true
      load_test: true
```

### Step 3: Update Deployment for Canary

When Flagger manages canary, your deployment should not have replicas defined:

```yaml
# helm-charts/user-service/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "user-service.fullname" . }}
spec:
  # Don't set replicas - Flagger manages scaling
  {{- if not .Values.canary.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  
  selector:
    matchLabels:
      {{- include "user-service.selectorLabels" . | nindent 6 }}
  
  template:
    metadata:
      labels:
        {{- include "user-service.selectorLabels" . | nindent 8 }}
        {{- if .Values.canary.enabled }}
        app.kubernetes.io/version: {{ .Values.image.tag }}
        {{- end }}
    spec:
      serviceAccountName: {{ include "user-service.serviceAccountName" . }}
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.registry }}/{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
          # ... rest of deployment config
```

### Step 4: Create Virtual Service for Traffic Management

```yaml
# helm-charts/user-service/templates/virtualservice.yaml
{{- if .Values.canary.enabled }}
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: {{ include "user-service.fullname" . }}
  namespace: {{ .Release.Namespace }}
spec:
  hosts:
    - {{ include "user-service.fullname" . }}
    - {{ include "user-service.fullname" . }}.{{ .Release.Namespace }}
    - {{ include "user-service.fullname" . }}.{{ .Release.Namespace }}.svc
    - {{ include "user-service.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local
  http:
    - match:
        - uri:
            prefix: /
      route:
        - destination:
            host: {{ include "user-service.fullname" . }}
            port:
              number: {{ .Values.service.port }}
          weight: 100
      timeout: 30s
      retries:
        attempts: 3
        perTryTimeout: 10s
{{- end }}
```

### Step 5: Create Destination Rule for Circuit Breaking

```yaml
# helm-charts/user-service/templates/destinationrule.yaml
{{- if .Values.canary.enabled }}
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: {{ include "user-service.fullname" . }}
  namespace: {{ .Release.Namespace }}
spec:
  host: {{ include "user-service.fullname" . }}
  
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 100
        http2MaxRequests: 1000
        maxRequestsPerConnection: 2
    
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
      minRequestVolume: 5
      splitExternalLocalOriginErrors: true
  
  subsets:
    - name: canary
      labels:
        istio.io/version: canary
    
    - name: stable
      labels:
        istio.io/version: stable
{{- end }}
```

---

## Monitoring & Metrics

### Prometheus Query Examples for Canary Analysis

```promql
# Error rate (errors per second / total requests per second)
sum(rate(http_request_duration_seconds_count{status=~"5.."}[1m])) 
/ 
sum(rate(http_request_duration_seconds_count[1m]))

# Latency - 99th percentile
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[1m])) by (le))

# Request success rate
sum(rate(http_request_duration_seconds_count{status=~"2.."}[1m]))
/
sum(rate(http_request_duration_seconds_count[1m]))

# Compare canary vs stable
error_rate{pod=~"user-service-canary.*"} vs error_rate{pod=~"user-service-stable.*"}
```

### ServiceMonitor for Application Metrics

```yaml
# helm-charts/user-service/templates/servicemonitor.yaml
{{- if .Values.canary.enabled }}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "user-service.fullname" . }}
  namespace: {{ .Release.Namespace }}
spec:
  selector:
    matchLabels:
      {{- include "user-service.selectorLabels" . | nindent 6 }}
  endpoints:
    - port: http
      path: /actuator/prometheus
      interval: 15s
      scrapeTimeout: 10s
{{- end }}
```

---

## Automated Rollback Strategies

### Strategy 1: Metric-Based Automatic Rollback

Flagger automatically rolls back if metrics exceed thresholds:

```yaml
spec:
  analysis:
    metrics:
      # If error rate > 1%, rollback immediately
      - name: error_rate
        thresholdRange:
          max: 1
        interval: 1m
      
      # If latency p99 > 500ms, rollback immediately
      - name: latency
        thresholdRange:
          max: 500
        interval: 1m
```

When rollback occurs:
1. Flagger sets canary weight to 0%
2. All traffic goes to stable version
3. Flagger marks canary as failed
4. Alert sent to operations team

### Strategy 2: Manual Intervention During Canary

```bash
# Monitor canary status during rollout
kubectl get canaries -n three-tier-app -w
kubectl describe canary user-service -n three-tier-app

# If issues detected, pause canary
kubectl patch canary user-service -n three-tier-app \
  -p '{"spec":{"skipAnalysis":true}}' --type merge

# Manually roll back to previous version
helm rollback user-service -n three-tier-app

# Remove failed canary
kubectl delete canary user-service -n three-tier-app
```

### Strategy 3: Custom Webhook Validation

```yaml
webhooks:
  - name: smoke-tests
    url: http://flagger-loadtester/
    timeout: 5s
    metadata:
      type: smoke
      cmd: |
        curl -X GET http://user-service:8080/actuator/health -H "Accept: application/json" | \
        jq -e '.status == "UP"'
    
  - name: performance-test
    url: http://flagger-loadtester/
    timeout: 30s
    metadata:
      type: load
      cmd: |
        ab -n 1000 -c 10 http://user-service:8080/health
```

---

## Real-World Production Scenarios

### Scenario 1: Deploying New Feature with Canary

**Situation**: Deploy user-service v1.1.0 with new user profile features.

```bash
# Step 1: Update image tag in values-prod.yaml
sed -i 's/tag: "1.0.0"/tag: "1.1.0"/' helm-charts/user-service/values-prod.yaml

# Step 2: Commit changes
git add helm-charts/user-service/values-prod.yaml
git commit -m "Deploy user-service v1.1.0 with canary"
git push origin main

# Step 3: Azure Pipeline rebuilds and pushes image with tag v1.1.0

# Step 4: ArgoCD syncs new deployment, triggers Flagger Canary

# Step 5: Monitor canary progress
kubectl get canaries -n three-tier-app -w
# Watch as weight increases: 5% → 10% → 25% → 50% → 100%

# Step 6: Check metrics in real-time
kubectl logs -n kube-system -l app=flagger -f

# If successful, canary completes and v1.1.0 becomes primary
# If issue detected, automatically rolls back to v1.0.0
```

**Expected Timeline**:
- 0-5 min: Canary at 5% traffic, checking metrics
- 5-10 min: Canary at 10% traffic, all metrics green
- 10-15 min: Canary at 25% traffic, excellent performance
- 15-20 min: Canary at 50% traffic, ready to promote
- 20-25 min: Canary promoted to 100% (fully deployed)

### Scenario 2: Detecting and Rolling Back Bad Deployment

**Situation**: New version increases error rate, should auto-rollback.

```
Canary Progress:
├─ 5% traffic (5 min)
│  └─ Error rate: 0.1% ✅ → Proceed
│
├─ 10% traffic (10 min)
│  └─ Error rate: 0.2% ✅ → Proceed
│
├─ 25% traffic (15 min)
│  └─ Error rate: 2.1% ❌ → EXCEEDS 1% THRESHOLD
│  └─ Flagger detects issue
│  └─ Immediately reverts to 0% canary traffic
│  └─ All traffic back to v1.0.0
│  └─ Marks Canary as FAILED
│  └─ Sends alert to team
│
Result: Deployment rolled back automatically
User Impact: Minimal (only 25% saw errors before rollback)
```

---

## Interview Q&A

### Q1: Explain how canary deployment works and why it's better than rolling updates.

**Answer**:
> "Canary deployment is a progressive delivery strategy where you release a new version to a small percentage of users first (typically 5%), monitor its behavior with real metrics, and gradually increase traffic if everything looks good. This is superior to rolling updates because:
>
> **Risk Reduction**: Issues only affect 5% of users initially, not everyone at once. If a bug is introduced, only a small group sees it before rollback.
>
> **Real-World Testing**: You test with actual production traffic and real users, not synthetic benchmarks. This catches issues that wouldn't appear in staging.
>
> **Quick Rollback**: If metrics indicate problems (error rate spikes, latency increases), Flagger automatically reverts 100% traffic back to the stable version within seconds.
>
> **Zero-Downtime**: No service interruption. Both versions run simultaneously with traffic split between them.
>
> **Metrics-Driven**: The deployment decision is based on observable metrics (error rate < 1%, latency < 500ms, success rate > 99%) not guesswork.
>
> With rolling updates, when a bad version is deployed, it affects all users gradually and takes time to notice and rollback. With canary, we catch issues immediately with minimal user impact.
>
> For critical services, I set canary at 5% for 5 minutes, then 10% for 5 minutes, then 25% for 5 minutes, then 50% for 5 minutes, before promoting to 100%. Total time: ~25 minutes for very careful rollout."

---

### Q2: How would you implement canary deployment in Kubernetes?

**Answer**:
> "Canary deployment in Kubernetes requires two main components: Flagger for automation and Istio/NGINX for traffic splitting. Here's the flow:
>
> **Step 1: Install Prerequisites**
> - Install Flagger (manages canary logic)
> - Install Istio (controls traffic splitting)
> - Install Prometheus (provides metrics)
>
> **Step 2: Create Canary Resource**
> Define a Flagger Canary resource that specifies:
> - Target deployment (user-service)
> - Service to manage (user-service)
> - Analysis rules (check metrics every 5 minutes)
> - Threshold values (error rate < 1%, latency < 500ms)
> - Traffic increment (increase weight 5% every interval)
>
> **Step 3: Configure Metrics**
> Reference Prometheus queries to monitor:
> - Error rate: sum(rate(http_requests_total{status=~'5..'}))
> - Latency: histogram_quantile(0.99, ...)
> - Success rate: requests with 2xx/3xx status
>
> **Step 4: Update Deployment**
> Remove the `replicas` field from deployment - Flagger manages replica count
>
> **Step 5: Deploy New Version**
> Update the image tag in values.yaml, commit to Git
> - ArgoCD detects change
> - Kubernetes updates the deployment
> - Flagger automatically creates a canary
> - Istio splits traffic (5% canary, 95% stable)
>
> **Step 6: Monitor Progress**
> Flagger checks metrics every 5 minutes:
> - All metrics good → increase weight 5%
> - Any metric exceeds threshold → rollback to 0%
>
> The entire process is automated and driven by metrics. When it completes successfully, the canary becomes the new stable version."

---

### Q3: What metrics would you monitor during a canary deployment?

**Answer**:
> "I monitor three primary categories of metrics during canary:
>
> **1. Error Rate**
> - Prometheus query: sum(rate(http_requests_total{status=~'5..'}[1m])) / sum(rate(http_requests_total[1m]))
> - Threshold: Max 1% error rate
> - Why: Immediate indicator of broken code
> - If exceeds 1% → rollback instantly
>
> **2. Latency (P99)**
> - Prometheus query: histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[1m]))
> - Threshold: Max 500ms
> - Why: Indicates performance degradation
> - If exceeds 500ms → rollback (could indicate database issues)
>
> **3. Success Rate**
> - Prometheus query: sum(rate(http_requests_total{status=~'2..|3..'}[1m])) / sum(rate(http_requests_total[1m]))
> - Threshold: Min 99%
> - Why: Catch application-level errors
> - If drops below 99% → rollback
>
> **Optional Secondary Metrics**:
> - Pod restart count (should be 0)
> - Memory usage (should not increase >10%)
> - CPU usage (should not spike)
> - Database connection count (should stay stable)
> - Cache hit rate (should not decrease)
>
> I set these metrics at different weight intervals:
> - At 5% traffic: strict thresholds (error < 0.5%)
> - At 25% traffic: normal thresholds (error < 1%)
> - At 50% traffic: relaxed thresholds (error < 2% for one interval)
>
> I also include custom metrics like:
> - Feature-specific metrics (e.g., login success rate for user-service)
> - Business metrics (revenue, conversion rate)
> - User experience metrics (page load time, transaction completion)"

---

## Troubleshooting Guide

### Issue: Canary Stuck in Progressing State

**Diagnosis**:
```bash
kubectl describe canary user-service -n three-tier-app
# Check status conditions
# Look for: AnalysisFailed or ReconcileFailed
```

**Solutions**:
```bash
# Check if Prometheus is accessible
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Visit http://localhost:9090 and verify metrics exist

# Check if Flagger controller is running
kubectl get pods -n kube-system | grep flagger

# Check Flagger logs
kubectl logs -n kube-system deployment/flagger -f

# Manually trigger analysis
kubectl patch canary user-service -n three-tier-app \
  -p '{"spec":{"skipAnalysis":false}}' --type merge
```

### Issue: Metrics Not Found in Prometheus

**Check if metrics are being scraped**:
```bash
# Query Prometheus API directly
curl http://prometheus:9090/api/v1/query \
  --data-urlencode 'query=http_request_duration_seconds_count' | jq .

# Check ServiceMonitor is created
kubectl get servicemonitor -n three-tier-app

# Check if metrics are being exported by application
kubectl exec user-service-xxxxx -n three-tier-app -- \
  curl http://localhost:8080/actuator/prometheus | grep http_request
```

### Issue: Canary Not Progressing Despite Green Metrics

**Check Flagger status**:
```bash
# Get detailed canary status
kubectl get canary user-service -n three-tier-app -o jsonpath='{.status}'

# Check if minimum request volume threshold is met
# Flagger requires minimum traffic for analysis
# If traffic is too low, canary waits

# Generate load to proceed
kubectl run -it --rm load-generator --image=busybox -- \
  sh -c "while sleep 1; do wget -q -O- http://user-service:8080/health; done"
```

---

## Helm Chart Canary Configuration

Add this to your Helm charts for easy canary enable/disable:

```yaml
# helm-charts/user-service/values-prod.yaml

# Enable canary deployment for production
canary:
  enabled: true
  
  analysis:
    interval: 5m
    threshold: 5
    maxWeight: 50
    stepWeight: 5
    
    metrics:
      - name: error_rate
        thresholdRange:
          max: 1
      
      - name: latency
        thresholdRange:
          max: 500
      
      - name: request_success_rate
        thresholdRange:
          min: 99
    
    webhooks:
      - name: smoke-test
        url: http://flagger-loadtester/
        timeout: 5s
        metadata:
          type: smoke
          cmd: "curl -s http://user-service:8080/health | grep UP"
```

Deploy with canary enabled:

```bash
helm upgrade user-service helm-charts/user-service \
  -f helm-charts/user-service/values-prod.yaml \
  --set canary.enabled=true
```

---

## Complete Canary Deployment Script

```bash
#!/bin/bash
# scripts/deploy-with-canary.sh

set -e

SERVICE=$1
VERSION=$2
ENVIRONMENT=${3:-prod}

if [ -z "$SERVICE" ] || [ -z "$VERSION" ]; then
  echo "Usage: ./deploy-with-canary.sh <service> <version> [environment]"
  exit 1
fi

echo "🚀 Starting canary deployment..."
echo "Service: $SERVICE"
echo "Version: $VERSION"
echo "Environment: $ENVIRONMENT"

# Step 1: Update image tag
echo "📝 Updating image tag..."
sed -i "s/tag: \".*\"/tag: \"$VERSION\"/" helm-charts/$SERVICE/values-$ENVIRONMENT.yaml

# Step 2: Commit changes
git add helm-charts/$SERVICE/values-$ENVIRONMENT.yaml
git commit -m "Deploy $SERVICE v$VERSION with canary to $ENVIRONMENT"
git push origin main

# Step 3: Wait for pipeline
echo "⏳ Waiting for pipeline to complete..."
sleep 60

# Step 4: Monitor canary
echo "📊 Monitoring canary deployment..."
kubectl get canaries -n three-tier-app -w

# Step 5: Get final status
echo "✅ Canary deployment complete!"
kubectl describe canary $SERVICE -n three-tier-app
```

Usage:
```bash
chmod +x scripts/deploy-with-canary.sh
./scripts/deploy-with-canary.sh user-service 1.1.0 prod
```

---

## Summary

Canary deployment is essential for production confidence:
- ✅ Risk reduction with small initial rollout
- ✅ Metrics-driven decision making
- ✅ Automatic rollback on issues
- ✅ Zero-downtime deployments
- ✅ Production validation before full release

Combined with your ArgoCD setup, canary deployments ensure safe, observable, and auditable production releases.

