# Helm & ArgoCD Complete Setup Guide for 3-Tier Application

## Table of Contents
1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Helm Overview](#helm-overview)
4. [Helm Chart Structure](#helm-chart-structure)
5. [ArgoCD Overview](#argocd-overview)
6. [ArgoCD Setup](#argocd-setup)
7. [GitOps Workflow](#gitops-workflow)
8. [Helm & ArgoCD Integration](#helm--argocd-integration)
9. [Troubleshooting](#troubleshooting)
10. [Best Practices](#best-practices)

---

## Introduction

**Helm** is a package manager for Kubernetes that simplifies application deployment, configuration, and lifecycle management.

**ArgoCD** is a declarative, GitOps continuous deployment tool that automatically syncs your Git repository state with your Kubernetes cluster.

Together, Helm + ArgoCD provide:
- ✅ **Templating**: Reusable Kubernetes manifests with variables
- ✅ **Version Control**: All infrastructure as code in Git
- ✅ **Automated Deployment**: Self-healing, GitOps-driven updates
- ✅ **Environment Management**: Dev/Staging/Prod with different values
- ✅ **Rollback Capability**: Easy version rollbacks via Git
- ✅ **Multi-Cluster Support**: Deploy to multiple AKS clusters
- ✅ **Audit Trail**: Complete Git history of all changes

---

## Prerequisites

### Required Tools

```bash
# Check installations
helm version          # v3.12+
kubectl version       # 1.28+
argocd version        # 2.8+
git --version         # 2.40+
```

### Installation Commands

```bash
# Install Helm (macOS)
brew install helm

# Install ArgoCD CLI (macOS)
brew install argocd

# Verify installations
helm repo update
argocd version
```

### Azure Resources Required

```bash
# 1. AKS Cluster (already exists from Terraform)
az aks list -o table

# 2. Container Registry (ACR)
az acr list -o table

# 3. Service Principal for ArgoCD
az ad sp create-for-rbac --name sp-argocd --role Contributor \
  --scopes /subscriptions/{subscription-id}

# 4. Git Repository with SSH Key
# GitHub repository for GitOps configuration
```

### Git Repository Structure

```
Terraform/ (your root repo)
├── helm-charts/               # Helm charts directory
│   ├── user-service/
│   ├── order-service/
│   ├── payment-service/
│   └── sonarqube/
├── argocd/                    # ArgoCD configurations
│   ├── applications/
│   ├── projects/
│   └── repositories/
├── k8s/                       # Additional K8s manifests
├── environments/              # Environment-specific values
│   ├── dev/
│   ├── staging/
│   └── prod/
└── azure-pipelines.yml        # CI/CD pipeline
```

---

## Helm Overview

### What is Helm?

Helm is a templating engine that:
1. **Packages Applications**: Bundle Kubernetes manifests + configuration
2. **Manages Dependencies**: Handle service dependencies elegantly
3. **Enables Templating**: Replace hardcoded values with variables
4. **Simplifies Deployment**: One command deploys multiple resources
5. **Manages Versions**: Track application versions and enable rollbacks

### Helm Architecture

```
┌─────────────────────────────────────┐
│   Helm Chart (Your Package)         │
├─────────────────────────────────────┤
│  Chart.yaml       (Metadata)        │
│  values.yaml      (Default values)  │
│  templates/       (K8s manifests)   │
│  README.md        (Documentation)   │
└─────────────────────────────────────┘
            │
            │ helm install
            ▼
┌─────────────────────────────────────┐
│   Rendered Kubernetes Manifests     │
│  (YAML with variables replaced)     │
└─────────────────────────────────────┘
            │
            │ kubectl apply
            ▼
┌─────────────────────────────────────┐
│  Kubernetes Cluster Resources       │
│  (Deployments, Services, etc.)      │
└─────────────────────────────────────┘
```

### Helm Concepts

| Concept | Description |
|---------|-------------|
| **Chart** | Package of Kubernetes manifests + values |
| **Release** | Installed instance of a chart in a cluster |
| **Repository** | Collection of charts (like npm, apt) |
| **Template** | Kubernetes manifest with Helm variables |
| **Values** | Configuration data for a chart |
| **Hooks** | Pre/post install/upgrade actions |

---

## Helm Chart Structure

### Directory Layout for User Service Chart

```
helm-charts/user-service/
├── Chart.yaml                 # Chart metadata
├── values.yaml                # Default configuration
├── values-dev.yaml            # Dev-specific values
├── values-staging.yaml        # Staging-specific values
├── values-prod.yaml           # Production-specific values
├── templates/
│   ├── deployment.yaml        # Kubernetes Deployment
│   ├── service.yaml           # Kubernetes Service
│   ├── configmap.yaml         # ConfigMap for config
│   ├── secret.yaml            # Secret for credentials
│   ├── hpa.yaml               # Horizontal Pod Autoscaler
│   ├── pdb.yaml               # Pod Disruption Budget
│   ├── networkpolicy.yaml     # Network Policy
│   ├── serviceaccount.yaml    # Service Account
│   ├── ingress.yaml           # Ingress (optional)
│   ├── _helpers.tpl           # Template helpers
│   └── NOTES.txt              # Post-install notes
├── charts/                    # Subchart dependencies
└── README.md                  # Chart documentation
```

### Step 1: Create Chart.yaml

```yaml
# helm-charts/user-service/Chart.yaml
apiVersion: v2
name: user-service
description: User Service - 3-Tier Microservices Architecture
type: application
version: 1.0.0                    # Chart version
appVersion: "1.0.0"               # Application version
keywords:
  - user
  - microservices
  - java
home: https://github.com/eswar3763/Terraform
sources:
  - https://github.com/eswar3763/Terraform
maintainers:
  - name: DevOps Team
    email: devops@example.com
dependencies: []                  # If using subcharts
```

### Step 2: Create values.yaml

```yaml
# helm-charts/user-service/values.yaml

# Replica count for scaling
replicaCount: 3

# Image configuration
image:
  registry: "acrname.azurecr.io"
  repository: "user-service"
  tag: "1.0.0"
  pullPolicy: IfNotPresent

# Image pull secrets for private registry
imagePullSecrets:
  - name: acr-secret

# Service configuration
service:
  type: ClusterIP
  port: 8080
  targetPort: 8080
  name: user-service

# Ingress configuration
ingress:
  enabled: false
  className: "nginx"
  annotations: {}
  hosts:
    - host: user-service.example.com
      paths:
        - path: /
          pathType: Prefix
  tls: []

# Resource limits and requests
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

# Autoscaling configuration
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

# Pod security context
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

# Container security context
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL

# Health checks
livenessProbe:
  httpGet:
    path: /actuator/health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /actuator/health/ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3

# Environment variables
env:
  - name: SPRING_PROFILES_ACTIVE
    value: "prod"
  - name: JAVA_OPTS
    value: "-Xms128m -Xmx256m"

# Database configuration (from ConfigMap/Secret)
database:
  host: postgres-service
  port: 5432
  name: three_tier_db
  username: postgres
  passwordSecret: postgres-secret
  passwordKey: password

# Logging configuration
logging:
  level: INFO
  format: json

# Pod Disruption Budget (for HA)
podDisruptionBudget:
  enabled: true
  minAvailable: 1

# Network Policy
networkPolicy:
  enabled: true
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: three-tier-app
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: three-tier-app
      ports:
        - protocol: TCP
          port: 5432

# Service Account
serviceAccount:
  create: true
  name: user-service-sa
  annotations: {}

# Node affinity
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app
                operator: In
                values:
                  - user-service
          topologyKey: kubernetes.io/hostname

# Tolerations for node taints
tolerations: []

# Node selector
nodeSelector: {}

# Labels
labels:
  app: user-service
  version: v1.0.0
  team: platform

# Annotations
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/actuator/prometheus"
```

### Step 3: Create Deployment Template

```yaml
# helm-charts/user-service/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "user-service.fullname" . }}
  namespace: {{ .Release.Namespace | quote }}
  labels:
    {{- include "user-service.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "user-service.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
      labels:
        {{- include "user-service.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "user-service.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ .Values.image.registry }}/{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.targetPort }}
              protocol: TCP
          livenessProbe:
            {{- toYaml .Values.livenessProbe | nindent 12 }}
          readinessProbe:
            {{- toYaml .Values.readinessProbe | nindent 12 }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          env:
            {{- toYaml .Values.env | nindent 12 }}
            - name: DB_HOST
              value: "{{ .Values.database.host }}"
            - name: DB_PORT
              value: "{{ .Values.database.port }}"
            - name: DB_NAME
              value: "{{ .Values.database.name }}"
            - name: DB_USER
              value: "{{ .Values.database.username }}"
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.database.passwordSecret }}
                  key: {{ .Values.database.passwordKey }}
            - name: LOG_LEVEL
              value: "{{ .Values.logging.level }}"
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: cache
              mountPath: /app/cache
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      volumes:
        - name: tmp
          emptyDir: {}
        - name: cache
          emptyDir: {}
```

### Step 4: Create Service Template

```yaml
# helm-charts/user-service/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "user-service.fullname" . }}
  namespace: {{ .Release.Namespace | quote }}
  labels:
    {{- include "user-service.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "user-service.selectorLabels" . | nindent 4 }}
```

### Step 5: Create Helpers Template

```yaml
# helm-charts/user-service/templates/_helpers.tpl
{{/*
Expand the name of the chart.
*/}}
{{- define "user-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "user-service.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "user-service.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "user-service.labels" -}}
helm.sh/chart: {{ include "user-service.chart" . }}
{{ include "user-service.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "user-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "user-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "user-service.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "user-service.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
```

### Step 6: Create ConfigMap Template

```yaml
# helm-charts/user-service/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "user-service.fullname" . }}-config
  namespace: {{ .Release.Namespace | quote }}
  labels:
    {{- include "user-service.labels" . | nindent 4 }}
data:
  application.yaml: |
    spring:
      application:
        name: user-service
      jpa:
        hibernate:
          ddl-auto: validate
        show-sql: false
        properties:
          hibernate:
            dialect: org.hibernate.dialect.PostgreSQL13Dialect
            jdbc:
              batch_size: 20
            order_inserts: true
            order_updates: true
      datasource:
        hikari:
          maximum-pool-size: 20
          minimum-idle: 5
          connection-timeout: 30000
          idle-timeout: 600000
          max-lifetime: 1800000
    logging:
      level:
        root: {{ .Values.logging.level }}
        com.example: DEBUG
      pattern:
        console: "{{ .Values.logging.format }}"
  logback.xml: |
    <?xml version="1.0" encoding="UTF-8"?>
    <configuration>
      <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
          <pattern>%d{ISO8601} %-5p %c{1}:%L - %m%n</pattern>
        </encoder>
      </appender>
      <root level="{{ .Values.logging.level }}">
        <appender-ref ref="STDOUT" />
      </root>
    </configuration>
```

### Step 7: Create HPA Template

```yaml
# helm-charts/user-service/templates/hpa.yaml
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "user-service.fullname" . }}
  namespace: {{ .Release.Namespace | quote }}
  labels:
    {{- include "user-service.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "user-service.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
{{- end }}
```

### Step 8: Create ServiceAccount Template

```yaml
# helm-charts/user-service/templates/serviceaccount.yaml
{{- if .Values.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "user-service.serviceAccountName" . }}
  namespace: {{ .Release.Namespace | quote }}
  labels:
    {{- include "user-service.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
```

### Step 9: Create Environment-Specific Values

```yaml
# helm-charts/user-service/values-prod.yaml
# Production-specific overrides

replicaCount: 5

image:
  tag: "1.0.0"
  pullPolicy: Always

resources:
  limits:
    cpu: 1000m
    memory: 1024Mi
  requests:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 60
  targetMemoryUtilizationPercentage: 75

ingress:
  enabled: true
  className: "azure-application-gateway"
  hosts:
    - host: user-service.prod.example.com
      paths:
        - path: /
          pathType: Prefix

livenessProbe:
  initialDelaySeconds: 60
  periodSeconds: 10
  failureThreshold: 5

readinessProbe:
  initialDelaySeconds: 30
  periodSeconds: 5
  failureThreshold: 5

database:
  host: postgres-prod.database.azure.com
  port: 5432
  name: three_tier_prod
```

### Step 10: Test Helm Chart

```bash
# Dry run to see what will be deployed
helm install user-service helm-charts/user-service \
  -n three-tier-app \
  -f helm-charts/user-service/values-prod.yaml \
  --dry-run \
  --debug

# Validate chart
helm lint helm-charts/user-service

# Show template output
helm template user-service helm-charts/user-service \
  -f helm-charts/user-service/values-prod.yaml

# Install the chart
helm install user-service helm-charts/user-service \
  -n three-tier-app \
  -f helm-charts/user-service/values-prod.yaml

# Upgrade existing release
helm upgrade user-service helm-charts/user-service \
  -n three-tier-app \
  -f helm-charts/user-service/values-prod.yaml

# Rollback to previous version
helm rollback user-service
```

---

## ArgoCD Overview

### What is ArgoCD?

ArgoCD is a GitOps continuous deployment tool that:

1. **Declarative**: Define desired state in Git
2. **Automated**: Syncs Git state with cluster automatically
3. **GitOps**: Git is single source of truth
4. **Self-Healing**: Auto-detects and fixes drift
5. **Auditable**: Complete Git history of changes
6. **Multi-Cluster**: Manage multiple clusters from one ArgoCD

### GitOps Principles

```
┌──────────────────────────────────────────────────────────┐
│                   Git Repository                         │
│  (Helm charts, values, Application manifests)            │
│                                                          │
│  ├── helm-charts/                                        │
│  ├── argocd/applications/                                │
│  └── environments/                                       │
└──────────────────────────────────────────────────────────┘
            │
            │ (Desired State)
            │
            ▼
┌──────────────────────────────────────────────────────────┐
│                     ArgoCD                               │
│  (Monitors Git, compares with cluster)                   │
└──────────────────────────────────────────────────────────┘
            │
            │ (Sync)
            │
            ▼
┌──────────────────────────────────────────────────────────┐
│              Kubernetes Cluster                          │
│  (Actual State - auto-synced with Git)                   │
└──────────────────────────────────────────────────────────┘
```

### ArgoCD Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  ArgoCD Components                       │
├─────────────────────────────────────────────────────────┤
│  API Server          (REST API, Webhook receiver)        │
│  Repo Server         (Git sync, chart rendering)         │
│  Controller          (Sync logic, health monitoring)     │
│  Dex Server          (OIDC auth provider)                │
│  Redis Cache         (Session & cache storage)           │
└─────────────────────────────────────────────────────────┘
         │              │              │
         │              │              │
      Git Repo      Kubernetes    User Browser
```

---

## ArgoCD Setup

### Step 1: Install ArgoCD in AKS Cluster

```bash
# Create argocd namespace
kubectl create namespace argocd

# Install ArgoCD (latest stable)
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/part-of=argocd \
  -n argocd \
  --timeout=300s

# Verify installation
kubectl get all -n argocd
kubectl get svc -n argocd

# Expected output:
# argocd-server               (LoadBalancer or ClusterIP)
# argocd-repo-server          (ClusterIP)
# argocd-controller-manager   (ClusterIP)
# argocd-redis                (ClusterIP)
# argocd-dex-server           (ClusterIP)
```

### Step 2: Access ArgoCD UI

```bash
# Option 1: Port Forward
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Access: https://localhost:8080

# Option 2: Expose via LoadBalancer (Azure)
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Get external IP
kubectl get svc -n argocd argocd-server

# Option 3: Use Application Gateway (Recommended for Production)
# Create Ingress manifest (see below)
```

### Step 3: Get Initial Admin Password

```bash
# Get initial admin password (stored in secret)
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# Login with username: admin and password from above

# Optional: Change password after first login
argocd account update-password \
  --account admin \
  --current-password <old-password> \
  --new-password <new-password>
```

### Step 4: Connect Git Repository

Create a secret for Git repository access:

```yaml
# argocd/repositories/git-repo-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: git-repo-secret
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: https://github.com/eswar3763/Terraform.git
  password: <personal-access-token>
  username: eswar3763
  # For SSH (better security):
  # sshPrivateKey: |
  #   -----BEGIN OPENSSH PRIVATE KEY-----
  #   ... base64-encoded private key ...
  #   -----END OPENSSH PRIVATE KEY-----
  insecure: "false"
  enableLFS: "true"
```

Apply the secret:

```bash
kubectl apply -f argocd/repositories/git-repo-secret.yaml
```

Or use ArgoCD CLI:

```bash
# Login to ArgoCD
argocd login localhost:8080 --username admin --password <password>

# Add Git repository
argocd repo add https://github.com/eswar3763/Terraform.git \
  --username eswar3763 \
  --password <personal-access-token>

# Verify repository connection
argocd repo list
```

### Step 5: Configure Azure Container Registry (ACR) Secret

For pulling private images from ACR:

```bash
# Create Docker config secret
kubectl create secret docker-registry acr-secret \
  --docker-server=acrname.azurecr.io \
  --docker-username=<username> \
  --docker-password=<password> \
  -n three-tier-app

# Patch default service account
kubectl patch serviceaccount default \
  -n three-tier-app \
  -p '{"imagePullSecrets": [{"name": "acr-secret"}]}'
```

### Step 6: Create ArgoCD Application Manifest

```yaml
# argocd/applications/user-service-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: user-service
  namespace: argocd
  # Finalizers ensure cleanup on deletion
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  # Project for RBAC
  project: default
  
  source:
    # Git repository
    repoURL: https://github.com/eswar3763/Terraform.git
    targetRevision: main
    
    # Path to Helm chart
    path: helm-charts/user-service
    
    # Helm specific configuration
    helm:
      # Values files in order of precedence
      valueFiles:
        - values.yaml
        - values-prod.yaml
      
      # Override individual values
      values: |
        image:
          tag: "1.0.0"
      
      # External values from Git
      # parameters:
      #   - name: image.tag
      #     value: "1.0.0"
      
      # Pass --force during Helm install
      force: false
      
      # Install CRDs before applying chart
      crds: Create
      
      # Wait for resources to be healthy
      wait: true
      
      # Number of retries
      retries: 3
  
  destination:
    # Target cluster
    server: https://kubernetes.default.svc
    
    # Target namespace
    namespace: three-tier-app
  
  # Sync policy
  syncPolicy:
    # Auto sync when Git changes
    automated:
      prune: true
      selfHeal: true
      
    # Sync only if allowed
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - RespectIgnoreDifferences=true
    
    # Retry policy for failed syncs
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  
  # Ignore differences (useful for generated fields)
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
  
  # Info URLs
  info:
    - name: Documentation
      value: https://github.com/eswar3763/Terraform/blob/main/HELM_ARGOCD_COMPLETE_SETUP_GUIDE.md
    - name: Issue Tracker
      value: https://github.com/eswar3763/Terraform/issues
```

### Step 7: Create Application for Order Service

```yaml
# argocd/applications/order-service-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: order-service
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/eswar3763/Terraform.git
    targetRevision: main
    path: helm-charts/order-service
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

### Step 8: Create Application for Payment Service

```yaml
# argocd/applications/payment-service-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: payment-service
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/eswar3763/Terraform.git
    targetRevision: main
    path: helm-charts/payment-service
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

### Step 9: Create AppProject for RBAC

```yaml
# argocd/projects/three-tier-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: three-tier-app
  namespace: argocd
spec:
  # Description
  description: 3-Tier Microservices Application
  
  # RBAC roles
  roles:
    # Developer role
    - name: developers
      policies:
        - p, proj:three-tier-app:developers, applications, get, three-tier-app/*, allow
        - p, proj:three-tier-app:developers, applications, sync, three-tier-app/*, allow
      groups:
        - developers@example.com
    
    # Admin role
    - name: admins
      policies:
        - p, proj:three-tier-app:admins, applications, *, three-tier-app/*, allow
        - p, proj:three-tier-app:admins, repositories, *, *, allow
      groups:
        - admins@example.com
    
    # CI/CD role
    - name: cicd
      policies:
        - p, proj:three-tier-app:cicd, applications, sync, three-tier-app/*, allow
  
  # Allowed source repositories
  sourceRepos:
    - 'https://github.com/eswar3763/Terraform.git'
    - 'https://charts.bitnami.com/bitnami'
  
  # Allowed destination clusters and namespaces
  destinations:
    - namespace: 'three-tier-app'
      server: 'https://kubernetes.default.svc'
    - namespace: 'argocd'
      server: 'https://kubernetes.default.svc'
  
  # Cluster resources allowed
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
    - group: ''
      kind: PersistentVolume
  
  # Namespace resources denied
  namespaceResourceBlacklist:
    - group: ''
      kind: ResourceQuota
    - group: ''
      kind: LimitRange
```

### Step 10: Apply All ArgoCD Manifests

```bash
# Create argocd configuration directory
mkdir -p argocd/{applications,projects,repositories}

# Apply repository secret
kubectl apply -f argocd/repositories/git-repo-secret.yaml

# Apply AppProject
kubectl apply -f argocd/projects/three-tier-project.yaml

# Apply Applications
kubectl apply -f argocd/applications/user-service-app.yaml
kubectl apply -f argocd/applications/order-service-app.yaml
kubectl apply -f argocd/applications/payment-service-app.yaml

# Verify applications
argocd app list
argocd app get user-service

# Sync applications manually (if not auto-syncing)
argocd app sync user-service
argocd app sync order-service
argocd app sync payment-service

# Watch sync progress
argocd app watch user-service
```

---

## GitOps Workflow

### Workflow Diagram

```
Developer Push Code
    │
    ▼
GitHub Repository
    │
    ├─ Helm Charts
    ├─ Application Manifests
    └─ ArgoCD Applications
    │
    ▼
Webhook Notification
    │
    ▼
ArgoCD Detects Changes
    │
    ▼
Fetch Latest from Git
    │
    ▼
Render Helm Templates
    │
    ▼
Compare with Cluster (Diff)
    │
    ▼
Auto Sync Enabled?
    ├─ Yes: Auto sync to cluster
    └─ No: Wait for manual approval
    │
    ▼
Monitor Health & Sync Status
    │
    ▼
Update ArgoCD UI & Metrics
```

### Day 1: Deploy New Application

```bash
# 1. Developer creates Helm chart
mkdir helm-charts/new-service
# ... create Chart.yaml, values.yaml, templates/

# 2. Commit to Git
git add helm-charts/new-service/
git commit -m "Add new-service Helm chart"
git push origin main

# 3. Create ArgoCD Application manifest
cat > argocd/applications/new-service-app.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: new-service
  namespace: argocd
spec:
  project: three-tier-app
  source:
    repoURL: https://github.com/eswar3763/Terraform.git
    targetRevision: main
    path: helm-charts/new-service
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: three-tier-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

# 4. Commit and push
git add argocd/applications/new-service-app.yaml
git commit -m "Add ArgoCD application for new-service"
git push origin main

# 5. Apply to ArgoCD
kubectl apply -f argocd/applications/new-service-app.yaml

# 6. Watch deployment
argocd app watch new-service

# 7. Verify in cluster
kubectl get all -n three-tier-app
kubectl get apps -n argocd
```

### Day 2: Update Application Image

```bash
# 1. Developer updates Helm values
cat > helm-charts/user-service/values-prod.yaml <<EOF
image:
  tag: "1.1.0"  # Updated from 1.0.0
EOF

# 2. Commit and push
git add helm-charts/user-service/values-prod.yaml
git commit -m "Update user-service image to v1.1.0"
git push origin main

# 3. ArgoCD detects change (webhook or polling)
# - Automatically syncs if auto-sync enabled
# - Or wait for manual approval

# 4. Monitor deployment
argocd app get user-service

# 5. Watch rollout
kubectl rollout status deployment/user-service -n three-tier-app

# 6. If rollback needed
git revert <commit-hash>
git push origin main
# ArgoCD auto-syncs the previous state
```

### Day 3: Canary Deployment

```bash
# 1. Create canary deployment values
cat > helm-charts/user-service/values-canary.yaml <<EOF
replicaCount: 1
image:
  tag: "1.2.0-rc1"
resources:
  requests:
    memory: "64Mi"
  limits:
    memory: "128Mi"
EOF

# 2. Create canary application
cat > argocd/applications/user-service-canary-app.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: user-service-canary
  namespace: argocd
spec:
  project: three-tier-app
  source:
    repoURL: https://github.com/eswar3763/Terraform.git
    path: helm-charts/user-service
    targetRevision: main
    helm:
      valueFiles:
        - values.yaml
        - values-canary.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: three-tier-app-canary
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

# 3. Deploy canary
kubectl apply -f argocd/applications/user-service-canary-app.yaml

# 4. Test canary version
kubectl exec -it user-service-canary-xxxxx -- /bin/bash

# 5. If successful, promote to production
git mv helm-charts/user-service/values-canary.yaml helm-charts/user-service/values-prod.yaml
git add .
git commit -m "Promote canary version to production"
git push origin main

# 6. Remove canary
kubectl delete -f argocd/applications/user-service-canary-app.yaml
```

---

## Helm & ArgoCD Integration

### Integration Architecture

```
┌─────────────────────────────────────┐
│      Git Repository                 │
│  ├── helm-charts/                   │
│  │   ├── user-service/              │
│  │   ├── order-service/             │
│  │   └── payment-service/           │
│  └── argocd/applications/           │
│      ├── user-service-app.yaml      │
│      ├── order-service-app.yaml     │
│      └── payment-service-app.yaml   │
└─────────────────────────────────────┘
            │
            │ Git webhook
            ▼
┌─────────────────────────────────────┐
│         ArgoCD Server               │
│  ├── Fetch Git changes              │
│  ├── Render Helm templates          │
│  └── Compare with cluster           │
└─────────────────────────────────────┘
            │
            │ kubectl apply
            ▼
┌─────────────────────────────────────┐
│    Kubernetes Cluster               │
│  ├── three-tier-app namespace       │
│  │   ├── user-service pods          │
│  │   ├── order-service pods         │
│  │   └── payment-service pods       │
│  └── argocd namespace               │
│      └── ArgoCD components          │
└─────────────────────────────────────┘
```

### Multi-Environment Setup

```
# Environment structure
environments/
├── dev/
│   ├── helm-values.yaml      # Dev overrides
│   └── argocd-app.yaml
├── staging/
│   ├── helm-values.yaml      # Staging overrides
│   └── argocd-app.yaml
└── prod/
    ├── helm-values.yaml      # Prod overrides
    └── argocd-app.yaml
```

Example environment-specific deployment:

```yaml
# environments/prod/argocd-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: user-service-prod
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/eswar3763/Terraform.git
    path: helm-charts/user-service
    helm:
      valueFiles:
        - values.yaml
        - ../../environments/prod/helm-values.yaml
  destination:
    namespace: three-tier-app-prod
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Azure Pipeline Integration

Update your `azure-pipelines.yml` to work with Helm & ArgoCD:

```yaml
stages:
  # ... existing stages (Build, Test, Security Scan) ...
  
  - stage: BuildContainers
    jobs:
      - job: BuildDockerImages
        steps:
          - task: DockerTaskV2@2
            inputs:
              command: 'build'
              Dockerfile: 'Dockerfile.user-service'
              tags: '$(ACR_URL)/user-service:$(Build.BuildId)'
          
          - task: DockerTaskV2@2
            inputs:
              command: 'push'
              repository: '$(ACR_URL)/user-service'
              tags: '$(Build.BuildId)'
  
  - stage: UpdateHelmValues
    dependsOn: BuildContainers
    jobs:
      - job: UpdateValues
        steps:
          # Update image tag in values-prod.yaml
          - script: |
              sed -i 's/tag:.*/tag: "$(Build.BuildId)"/' \
                helm-charts/user-service/values-prod.yaml
              
              git config user.email "ci@example.com"
              git config user.name "CI Pipeline"
              git add helm-charts/*/values-*.yaml
              git commit -m "Update image tags to $(Build.BuildId)"
              git push
          displayName: 'Update Helm values'
          env:
            GIT_TOKEN: $(GIT_TOKEN)
  
  - stage: TriggerArgoSync
    dependsOn: UpdateHelmValues
    jobs:
      - job: SyncArgoCD
        steps:
          - script: |
              argocd login argocd.example.com \
                --username admin \
                --password $(ARGOCD_PASSWORD) \
                --insecure
              
              argocd app sync user-service \
                --prune \
                --wait
              
              argocd app wait user-service
            displayName: 'Sync ArgoCD applications'
```

---

## Helm Best Practices

### 1. Chart Organization

```bash
# Keep related templates together
templates/
├── deployment.yaml
├── service.yaml
├── configmap.yaml
├── secret.yaml
├── hpa.yaml
├── pdb.yaml
├── networkpolicy.yaml
├── serviceaccount.yaml
├── NOTES.txt
└── _helpers.tpl
```

### 2. Values Management

```yaml
# values.yaml - Base defaults (DO NOT EDIT in production)
replicaCount: 1
resources:
  limits:
    memory: "512Mi"

# values-dev.yaml - Development overrides
replicaCount: 1
resources:
  limits:
    memory: "256Mi"

# values-prod.yaml - Production overrides
replicaCount: 5
resources:
  limits:
    memory: "1024Mi"
```

### 3. Template Naming Conventions

```
_helpers.tpl      # Helper templates
deployment.yaml   # Kubernetes Deployment
service.yaml      # Kubernetes Service
_service.tpl      # Service template helper
```

### 4. Conditional Blocks

```yaml
# Enable features conditionally
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "app.fullname" . }}
spec:
  # ...
{{- end }}
```

### 5. Validation

```bash
# Lint chart for errors
helm lint helm-charts/user-service

# Validate generated manifests
helm template user-service helm-charts/user-service | kubectl apply -f - --dry-run=client

# Check for template errors
helm template user-service helm-charts/user-service --debug
```

---

## ArgoCD Best Practices

### 1. Auto-Sync Strategy

```yaml
syncPolicy:
  automated:
    # Auto-prune resources deleted from Git
    prune: true
    # Auto-fix drift between Git and cluster
    selfHeal: true
  # Sync options
  syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
```

### 2. RBAC with AppProject

```yaml
# Use AppProject for access control
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: three-tier-app
spec:
  roles:
    - name: admins
      policies:
        - p, proj:three-tier-app:admins, applications, *, three-tier-app/*, allow
  sourceRepos:
    - 'https://github.com/eswar3763/Terraform.git'
```

### 3. Monitoring & Alerting

```bash
# Export metrics
kubectl port-forward -n argocd svc/argocd-metrics 8082:8082

# Prometheus scrape config
- job_name: argocd-metrics
  static_configs:
    - targets: ['argocd-metrics.argocd:8082']

# Alert on sync failures
alert: ArgoCDAppSyncFailure
expr: argocd_app_sync_total{phase="Failed"} > 0
for: 5m
annotations:
  summary: "ArgoCD app sync failed"
```

### 4. Multi-Cluster Management

```yaml
# Add additional clusters
apiVersion: v1
kind: Secret
metadata:
  name: eks-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: eks-cluster
  server: https://eks.amazonaws.com
  config: |
    {
      "bearerToken": "...",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "..."
      }
    }
```

### 5. GitOps Webhook

```bash
# Configure GitHub webhook
# GitHub Settings → Webhooks → Add webhook

# Payload URL: https://argocd.example.com/api/webhook
# Events: Push events
# Active: ✓

# This enables automatic sync on Git push
```

---

## Troubleshooting

### Common Issues

#### Issue 1: Application not syncing

```bash
# Check application status
argocd app get user-service

# Check ArgoCD server logs
kubectl logs -n argocd deploy/argocd-server

# Check repo server logs (rendering issue)
kubectl logs -n argocd deploy/argocd-repo-server

# Force refresh
argocd app get user-service --refresh
```

#### Issue 2: Helm template rendering error

```bash
# Debug template rendering
helm template user-service helm-charts/user-service \
  -f helm-charts/user-service/values-prod.yaml \
  --debug

# Common issues:
# - Invalid YAML syntax
# - Missing required values
# - Undefined template variables
```

#### Issue 3: Namespace creation failed

```bash
# Check if namespace exists
kubectl get ns three-tier-app

# Create namespace manually if needed
kubectl create namespace three-tier-app

# Add label for ArgoCD tracking
kubectl label namespace three-tier-app \
  argocd.argoproj.io/managed-by=argocd
```

#### Issue 4: Image pull errors

```bash
# Check if ACR secret exists
kubectl get secret acr-secret -n three-tier-app

# Verify service account has pull secret
kubectl get sa default -n three-tier-app -o yaml

# Recreate secret if needed
kubectl create secret docker-registry acr-secret \
  --docker-server=acrname.azurecr.io \
  --docker-username=<username> \
  --docker-password=<password> \
  -n three-tier-app
```

---

## Best Practices

### 1. Git Repository Organization

```
Terraform/
├── helm-charts/               # All Helm charts
│   ├── user-service/
│   ├── order-service/
│   ├── payment-service/
│   └── README.md
├── argocd/                    # All ArgoCD configs
│   ├── applications/
│   ├── projects/
│   ├── repositories/
│   └── README.md
├── environments/              # Environment values
│   ├── dev/
│   ├── staging/
│   └── prod/
├── k8s/                       # Additional K8s manifests
├── azure-pipelines.yml
└── README.md
```

### 2. Helm Values Hierarchy

1. **Default values** (values.yaml)
2. **Environment values** (values-{env}.yaml)
3. **ArgoCD overrides** (helm.parameters in Application)
4. **CLI overrides** (--values, --set flags)

### 3. Release Strategy

```bash
# Semantic versioning for charts
Chart version: 1.2.3 (MAJOR.MINOR.PATCH)
App version: 1.0.0 (Image tag)

# Tagging in Git
git tag helm-user-service-v1.2.3
git tag app-user-service-v1.0.0
```

### 4. Testing Before Deployment

```bash
# Lint chart
helm lint helm-charts/user-service

# Validate templates
helm template user-service helm-charts/user-service

# Dry run
helm install user-service helm-charts/user-service \
  -n three-tier-app \
  --dry-run

# Install in test namespace
helm install user-service helm-charts/user-service \
  -n test-namespace
```

### 5. Monitoring Deployments

```bash
# Watch ArgoCD application status
watch argocd app get user-service

# Monitor pod rollout
kubectl rollout status deployment/user-service -n three-tier-app

# Check resource usage
kubectl top pods -n three-tier-app

# View recent events
kubectl get events -n three-tier-app --sort-by='.lastTimestamp'
```

---

## Complete Setup Checklist

- [ ] **Helm Charts Created**
  - [ ] user-service chart with all templates
  - [ ] order-service chart with all templates
  - [ ] payment-service chart with all templates
  - [ ] Environment-specific values files

- [ ] **ArgoCD Installed**
  - [ ] ArgoCD deployed in argocd namespace
  - [ ] Initial admin password obtained
  - [ ] Git repository configured

- [ ] **ArgoCD Applications Created**
  - [ ] user-service Application deployed
  - [ ] order-service Application deployed
  - [ ] payment-service Application deployed
  - [ ] AppProject for RBAC configured

- [ ] **Integration Complete**
  - [ ] Azure Pipeline updated to sync Helm values
  - [ ] Webhook configured for Git push notifications
  - [ ] RBAC roles assigned to users/teams

- [ ] **Monitoring Setup**
  - [ ] ArgoCD metrics exported
  - [ ] Prometheus scrape config added
  - [ ] Alerts configured for sync failures

- [ ] **Documentation**
  - [ ] README created for helm-charts/
  - [ ] README created for argocd/
  - [ ] Team trained on GitOps workflow

---

## Next Steps

1. **Create Helm Charts** (Using templates above)
2. **Install ArgoCD** (Using installation commands)
3. **Configure Git Repository** (Push charts & manifests)
4. **Create Applications** (Using Application manifests)
5. **Test Deployments** (Deploy and verify)
6. **Setup Monitoring** (Configure alerts)
7. **Train Team** (Document workflows)

---

## References

- **Helm Documentation**: https://helm.sh/docs/
- **ArgoCD Documentation**: https://argo-cd.readthedocs.io/
- **Kubernetes Documentation**: https://kubernetes.io/docs/
- **GitOps Best Practices**: https://opengitops.dev/
- **Helm Best Practices**: https://helm.sh/docs/chart_best_practices/

---

**Author**: DevOps Team  
**Last Updated**: April 2026  
**Version**: 1.0.0
