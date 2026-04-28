#!/bin/bash

# Quick Setup Script for Each Environment
# Use this for faster environment-specific setup after Terraform is deployed
# Usage: ./quick-setup-env.sh dev|staging|prod

set -e

ENV=${1:-dev}
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Validate environment
if [[ ! " dev staging prod " =~ " $ENV " ]]; then
    print_error "Invalid environment: $ENV"
    echo "Valid options: dev, staging, prod"
    exit 1
fi

print_header "Quick Setup for $ENV Environment"

# Get resource group and cluster names
RG="rg-3tier-app-$ENV"
CLUSTER="aks-3tier-$ENV"
MYSQL_SERVER="mysql-3tier-$ENV"

print_info "Resource Group: $RG"
print_info "Cluster: $CLUSTER"
print_info "MySQL Server: $MYSQL_SERVER"

# Step 1: Configure kubectl
print_header "Step 1: Configuring kubectl"
print_info "Getting AKS credentials..."
az aks get-credentials --resource-group "$RG" --name "$CLUSTER" --overwrite-existing
print_success "kubectl configured"

# Step 2: Install NGINX Ingress (if not already installed)
print_header "Step 2: Installing NGINX Ingress"
if kubectl get ns ingress-nginx &> /dev/null; then
    print_info "NGINX Ingress already installed"
else
    print_info "Installing NGINX Ingress..."
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    helm install nginx-ingress ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.type=LoadBalancer \
        --wait
    print_success "NGINX Ingress installed"
fi

# Step 3: Create namespace and configuration
print_header "Step 3: Setting up Kubernetes Namespace"
print_info "Applying namespace and configuration..."
kubectl apply -f "$SCRIPT_DIR/examples/3-tier-architecture/namespace-and-config.yaml"
print_success "Namespace configured"

# Step 4: Update ConfigMaps with database info
print_header "Step 4: Updating ConfigMaps"
print_info "Getting Terraform outputs..."
cd "$SCRIPT_DIR/environments/$ENV"
MYSQL_FQDN=$(terraform output -raw mysql_server_fqdn)
ACR_SERVER=$(terraform output -raw acr_login_server)

print_info "MySQL Server: $MYSQL_FQDN"
print_info "ACR Server: $ACR_SERVER"

kubectl set env configmap/app-config \
    -n three-tier-app \
    MYSQL_HOST="$MYSQL_FQDN" \
    MYSQL_DATABASE="appdb" \
    MYSQL_USER="azureuser" \
    ACR_LOGIN_SERVER="$ACR_SERVER" \
    --record

print_success "ConfigMaps updated"

# Step 5: Create ACR secret
print_header "Step 5: Creating ACR Secret"
print_info "Getting ACR credentials..."
ACR_USERNAME=$(terraform output -raw acr_admin_username)
ACR_PASSWORD=$(terraform output -raw acr_admin_password)

kubectl create secret docker-registry acr-secret \
    --docker-server="$ACR_SERVER" \
    --docker-username="$ACR_USERNAME" \
    --docker-password="$ACR_PASSWORD" \
    -n three-tier-app \
    --dry-run=client \
    -o yaml | kubectl apply -f -

print_success "ACR secret created"

# Step 6: Deploy applications
print_header "Step 6: Deploying Applications"
print_info "Deploying Spring Boot services..."
kubectl apply -f "$SCRIPT_DIR/examples/3-tier-architecture/spring-boot-services.yaml"

print_info "Deploying React frontend..."
kubectl apply -f "$SCRIPT_DIR/examples/3-tier-architecture/react-frontend.yaml"

print_success "Applications deployed"

# Step 7: Wait for deployments
print_header "Step 7: Waiting for Deployments to Be Ready"
kubectl rollout status deployment/user-service -n three-tier-app --timeout=5m
kubectl rollout status deployment/order-service -n three-tier-app --timeout=5m
kubectl rollout status deployment/payment-service -n three-tier-app --timeout=5m
kubectl rollout status deployment/react-frontend -n three-tier-app --timeout=5m

print_success "All deployments ready"

# Step 8: Display status
print_header "Deployment Status"
print_info "Pods:"
kubectl get pods -n three-tier-app

print_info "Services:"
kubectl get svc -n three-tier-app

print_info "Ingress:"
kubectl get ingress -n three-tier-app

# Step 9: Get access information
print_header "Access Information"

INGRESS_IP=$(kubectl get ingress -n three-tier-app -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
print_info "Frontend URL: http://$INGRESS_IP"

print_info "Kubernetes Services:"
echo "  User Service: user-service.three-tier-app.svc.cluster.local:8081"
echo "  Order Service: order-service.three-tier-app.svc.cluster.local:8082"
echo "  Payment Service: payment-service.three-tier-app.svc.cluster.local:8083"

print_header "Setup Complete!"
print_success "Your $ENV environment is ready"

print_info "Quick test commands:"
echo "  # Port forward to services"
echo "  kubectl port-forward svc/user-service 8081:8081 -n three-tier-app &"
echo "  kubectl port-forward svc/react-frontend 3000:80 -n three-tier-app &"
echo ""
echo "  # Test API"
echo "  curl http://localhost:8081/actuator/health"
echo "  open http://localhost:3000"
echo ""
echo "  # View logs"
echo "  kubectl logs -n three-tier-app -l app=user-service -f"
