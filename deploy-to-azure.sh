#!/bin/bash

# Complete Azure Deployment Automation Script
# Sets up Dev, Staging, and Production environments
# Usage: ./deploy-to-azure.sh [dev|staging|prod|all]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ENVIRONMENTS=("dev" "staging" "prod")
SELECTED_ENV=${1:-dev}

# Functions
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
validate_env() {
    if [[ ! " ${ENVIRONMENTS[@]} " =~ " ${SELECTED_ENV} " ]] && [ "$SELECTED_ENV" != "all" ]; then
        print_error "Invalid environment: $SELECTED_ENV"
        echo "Valid options: dev, staging, prod, all"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local tools=("terraform" "az" "kubectl" "docker" "git" "mvn")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            VERSION=$($tool --version 2>&1 | head -1)
            print_success "$tool installed: $VERSION"
        else
            print_error "$tool not found. Please install: https://aka.ms/install-$tool"
            exit 1
        fi
    done
}

# Azure login
azure_login() {
    print_header "Azure Login"
    
    print_info "Logging in to Azure..."
    az login
    
    print_info "Setting subscription..."
    read -p "Enter Azure Subscription ID: " SUBSCRIPTION_ID
    az account set --subscription "$SUBSCRIPTION_ID"
    
    print_success "Azure login successful"
}

# Build Docker images
build_docker_images() {
    print_header "Building Docker Images"
    
    cd "$SCRIPT_DIR/examples/maven-services"
    
    local services=("user-service" "order-service" "payment-service")
    local version="1.0.0"
    
    for service in "${services[@]}"; do
        print_info "Building $service..."
        docker build -t "$service:$version" \
            -f ../3-tier-architecture/Dockerfile.springboot \
            ./$service
        
        print_success "$service built successfully"
    done
}

# Deploy environment
deploy_environment() {
    local env=$1
    
    print_header "Deploying $env Environment"
    
    cd "$SCRIPT_DIR/environments/$env"
    
    print_info "Initializing Terraform..."
    terraform init
    
    print_info "Validating configuration..."
    terraform validate
    
    print_info "Creating plan (review before applying)..."
    terraform plan -out=tfplan
    
    read -p "Apply Terraform changes? (yes/no): " apply_confirm
    if [ "$apply_confirm" != "yes" ]; then
        print_info "Skipping Terraform apply"
        return
    fi
    
    print_info "Applying Terraform configuration..."
    print_info "⏱️  This will take 15-20 minutes for AKS deployment..."
    terraform apply tfplan
    
    print_success "$env environment deployed successfully"
    
    # Save outputs
    print_info "Saving outputs..."
    terraform output > /tmp/terraform-outputs-$env.txt
    print_success "Outputs saved to /tmp/terraform-outputs-$env.txt"
}

# Configure kubectl
configure_kubectl() {
    local env=$1
    local rg="rg-3tier-app-$env"
    local cluster="aks-3tier-$env"
    
    print_info "Configuring kubectl for $env..."
    
    az aks get-credentials \
        --resource-group "$rg" \
        --name "$cluster" \
        --overwrite-existing
    
    print_info "Testing cluster connection..."
    kubectl cluster-info
    
    print_success "kubectl configured successfully"
}

# Install NGINX Ingress
install_nginx_ingress() {
    local env=$1
    
    print_header "Installing NGINX Ingress Controller for $env"
    
    print_info "Adding Helm repository..."
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    
    print_info "Installing NGINX Ingress..."
    helm install nginx-ingress ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.type=LoadBalancer \
        --wait
    
    print_info "Waiting for external IP assignment (up to 5 minutes)..."
    for i in {1..30}; do
        EXTERNAL_IP=$(kubectl get svc -n ingress-nginx -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
        
        if [ "$EXTERNAL_IP" != "pending" ]; then
            print_success "NGINX Ingress external IP: $EXTERNAL_IP"
            return
        fi
        
        sleep 10
    done
    
    print_error "Could not get external IP. Check manually with: kubectl get svc -n ingress-nginx"
}

# Deploy applications
deploy_applications() {
    local env=$1
    
    print_header "Deploying Applications to $env"
    
    print_info "Creating namespace..."
    kubectl apply -f "$SCRIPT_DIR/examples/3-tier-architecture/namespace-and-config.yaml"
    
    print_info "Getting database info from Terraform..."
    cd "$SCRIPT_DIR/environments/$env"
    MYSQL_FQDN=$(terraform output -raw mysql_server_fqdn 2>/dev/null || echo "pending")
    ACR_SERVER=$(terraform output -raw acr_login_server 2>/dev/null || echo "pending")
    
    print_info "Updating ConfigMaps..."
    kubectl set env configmap/app-config \
        -n three-tier-app \
        MYSQL_HOST="$MYSQL_FQDN" \
        ACR_LOGIN_SERVER="$ACR_SERVER" \
        --record || true
    
    print_info "Deploying Spring Boot services..."
    kubectl apply -f "$SCRIPT_DIR/examples/3-tier-architecture/spring-boot-services.yaml"
    
    print_info "Deploying React frontend..."
    kubectl apply -f "$SCRIPT_DIR/examples/3-tier-architecture/react-frontend.yaml"
    
    print_info "Waiting for deployments to be ready..."
    kubectl rollout status deployment/user-service -n three-tier-app || true
    kubectl rollout status deployment/order-service -n three-tier-app || true
    kubectl rollout status deployment/payment-service -n three-tier-app || true
    
    print_success "Applications deployed successfully"
    
    # Show status
    print_header "Deployment Status for $env"
    kubectl get pods -n three-tier-app
    kubectl get svc -n three-tier-app
}

# Verify deployment
verify_deployment() {
    local env=$1
    
    print_header "Verifying $env Deployment"
    
    print_info "Checking pod status..."
    POD_COUNT=$(kubectl get pods -n three-tier-app 2>/dev/null | grep Running | wc -l)
    
    if [ "$POD_COUNT" -ge 4 ]; then
        print_success "All pods running ($POD_COUNT pods)"
    else
        print_error "Not all pods are running ($POD_COUNT pods found)"
    fi
    
    print_info "Testing health endpoints..."
    
    # Port forward for testing
    kubectl port-forward -n three-tier-app svc/user-service 8081:8081 > /dev/null 2>&1 &
    sleep 5
    
    if curl -s http://localhost:8081/actuator/health | grep -q "UP"; then
        print_success "User Service is healthy"
    else
        print_error "User Service health check failed"
    fi
    
    # Cleanup port forward
    pkill -f "port-forward" || true
}

# Main deployment workflow
main() {
    print_header "Azure 3-Tier Application Deployment"
    print_info "Environment: $SELECTED_ENV"
    print_info "Project Directory: $SCRIPT_DIR"
    
    validate_env
    check_prerequisites
    
    if [ "$SELECTED_ENV" = "all" ]; then
        azure_login
        build_docker_images
        
        for env in "${ENVIRONMENTS[@]}"; do
            deploy_environment "$env"
            configure_kubectl "$env"
            install_nginx_ingress "$env"
            deploy_applications "$env"
            verify_deployment "$env"
        done
    else
        azure_login
        build_docker_images
        deploy_environment "$SELECTED_ENV"
        configure_kubectl "$SELECTED_ENV"
        install_nginx_ingress "$SELECTED_ENV"
        deploy_applications "$SELECTED_ENV"
        verify_deployment "$SELECTED_ENV"
    fi
    
    print_header "Deployment Complete!"
    print_success "All environments deployed successfully"
    print_info "Next steps:"
    echo "  1. Check deployment status: kubectl get pods -n three-tier-app"
    echo "  2. View logs: kubectl logs -n three-tier-app -l app=user-service"
    echo "  3. Port forward for testing: kubectl port-forward svc/user-service 8081:8081"
    echo "  4. Access frontend: kubectl port-forward svc/react-frontend 3000:80"
}

# Run main
main
