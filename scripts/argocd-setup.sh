#!/bin/bash

################################################################################
# ArgoCD Installation and Setup Script
# Purpose: Install ArgoCD, configure repositories, and setup applications
# Usage: ./argocd-setup.sh [install|configure|deploy|cleanup]
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ARGOCD_VERSION="2.8.3"
ARGOCD_NAMESPACE="argocd"
GITHUB_URL="https://github.com/eswar3763/Terraform.git"
GITHUB_USERNAME="eswar3763"
GITHUB_PAT="${GITHUB_PAT:-}"  # Set via environment variable
ARGOCD_ADMIN_PASSWORD="${ARGOCD_ADMIN_PASSWORD:-}"  # Set via environment variable

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
    fi
    log_success "kubectl found"
    
    if ! command -v helm &> /dev/null; then
        log_error "helm is not installed"
    fi
    log_success "helm found"
    
    if ! command -v argocd &> /dev/null; then
        log_warn "argocd CLI is not installed. Install with: brew install argocd"
    fi
    log_success "Prerequisites check complete"
}

# Install ArgoCD
install_argocd() {
    log_info "Installing ArgoCD v${ARGOCD_VERSION}..."
    
    # Create namespace
    if kubectl get namespace ${ARGOCD_NAMESPACE} &> /dev/null; then
        log_warn "Namespace ${ARGOCD_NAMESPACE} already exists"
    else
        kubectl create namespace ${ARGOCD_NAMESPACE}
        log_success "Created namespace ${ARGOCD_NAMESPACE}"
    fi
    
    # Install ArgoCD
    ARGOCD_INSTALL_URL="https://raw.githubusercontent.com/argoproj/argo-cd/v${ARGOCD_VERSION}/manifests/install.yaml"
    kubectl apply -n ${ARGOCD_NAMESPACE} -f ${ARGOCD_INSTALL_URL}
    log_success "Applied ArgoCD manifests"
    
    # Wait for ArgoCD to be ready
    log_info "Waiting for ArgoCD pods to be ready (this may take 2-3 minutes)..."
    kubectl wait --for=condition=ready pod \
        -l app.kubernetes.io/part-of=argocd \
        -n ${ARGOCD_NAMESPACE} \
        --timeout=300s
    log_success "ArgoCD is ready"
}

# Configure repository access
configure_repository() {
    log_info "Configuring repository access..."
    
    if [ -z "$GITHUB_PAT" ]; then
        log_error "GITHUB_PAT environment variable not set. Please export GITHUB_PAT=<your-token>"
    fi
    
    # Update repository secret with actual credentials
    sed -i.bak "s|<REPLACE_WITH_GITHUB_PAT>|${GITHUB_PAT}|g" \
        argocd/repositories/github-repo.yaml
    
    # Apply repository secret
    kubectl apply -f argocd/repositories/github-repo.yaml
    log_success "Repository configured"
    
    # Verify repository connection
    log_info "Verifying repository connection..."
    sleep 5  # Wait for secret to be processed
    
    # List repositories
    if command -v argocd &> /dev/null; then
        argocd repo list || log_warn "Could not verify repo connection (argocd CLI not configured yet)"
    fi
}

# Create AppProject
create_appproject() {
    log_info "Creating AppProject for three-tier-app..."
    
    kubectl apply -f argocd/projects/three-tier-app.yaml
    log_success "AppProject created"
}

# Deploy applications
deploy_applications() {
    log_info "Deploying ArgoCD Applications..."
    
    # Create namespace for applications
    kubectl create namespace three-tier-app --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply applications
    kubectl apply -f argocd/applications/
    log_success "Applications deployed"
    
    # Wait for applications to be synced (optional)
    log_info "Waiting for applications to sync..."
    sleep 10
}

# Get initial credentials
get_credentials() {
    log_info "Retrieving ArgoCD admin password..."
    
    INITIAL_PASS=$(kubectl -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "")
    
    if [ -z "$INITIAL_PASS" ]; then
        log_warn "Could not retrieve initial password. It may have been changed already."
        return
    fi
    
    log_success "ArgoCD Admin Password: ${INITIAL_PASS}"
    echo "Username: admin"
    echo ""
    log_warn "Change this password immediately after first login!"
}

# Setup port forwarding
setup_portforward() {
    log_info "Setting up port forwarding..."
    
    log_info "ArgoCD UI will be available at: http://localhost:8080"
    log_info "To setup port forwarding, run:"
    echo "  kubectl port-forward -n ${ARGOCD_NAMESPACE} svc/argocd-server 8080:443"
    echo ""
}

# Expose via LoadBalancer
expose_loadbalancer() {
    log_info "Exposing ArgoCD via LoadBalancer..."
    
    kubectl patch svc argocd-server -n ${ARGOCD_NAMESPACE} \
        -p '{"spec": {"type": "LoadBalancer"}}'
    log_success "Service patched to LoadBalancer"
    
    log_info "Waiting for LoadBalancer IP assignment..."
    sleep 10
    
    EXTERNAL_IP=$(kubectl get svc argocd-server -n ${ARGOCD_NAMESPACE} \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -n "$EXTERNAL_IP" ]; then
        log_success "ArgoCD is available at: https://${EXTERNAL_IP}"
    else
        log_warn "LoadBalancer IP not yet assigned. Check with: kubectl get svc -n argocd"
    fi
}

# Cleanup
cleanup() {
    log_info "Cleaning up ArgoCD installation..."
    
    read -p "Are you sure you want to delete ArgoCD? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_info "Cleanup cancelled"
        return
    fi
    
    kubectl delete namespace ${ARGOCD_NAMESPACE}
    log_success "ArgoCD namespace deleted"
}

# Complete setup
complete_setup() {
    log_info "Starting complete ArgoCD setup..."
    check_prerequisites
    install_argocd
    configure_repository
    create_appproject
    deploy_applications
    get_credentials
    setup_portforward
    log_success "ArgoCD setup complete!"
}

# Display usage
usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  install       - Install ArgoCD only"
    echo "  configure     - Configure repository access"
    echo "  deploy        - Deploy applications"
    echo "  credentials   - Get admin credentials"
    echo "  portforward   - Setup port forwarding info"
    echo "  loadbalancer  - Expose via LoadBalancer"
    echo "  complete      - Complete setup (all steps)"
    echo "  cleanup       - Remove ArgoCD installation"
    echo ""
    echo "Environment Variables:"
    echo "  GITHUB_PAT    - GitHub Personal Access Token (required for configure)"
    echo ""
    echo "Examples:"
    echo "  export GITHUB_PAT=ghp_xxxx..."
    echo "  ./argocd-setup.sh complete"
    echo ""
    echo "  ./argocd-setup.sh install"
    echo "  ./argocd-setup.sh configure"
    echo "  ./argocd-setup.sh deploy"
}

# Main
case "${1:-complete}" in
    install)
        check_prerequisites
        install_argocd
        get_credentials
        ;;
    configure)
        configure_repository
        create_appproject
        ;;
    deploy)
        deploy_applications
        ;;
    credentials)
        get_credentials
        ;;
    portforward)
        setup_portforward
        ;;
    loadbalancer)
        expose_loadbalancer
        ;;
    complete)
        complete_setup
        ;;
    cleanup)
        cleanup
        ;;
    *)
        usage
        exit 1
        ;;
esac

log_success "Done!"
