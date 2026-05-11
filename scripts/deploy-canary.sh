#!/bin/bash
# scripts/deploy-canary.sh
# Deploy service with canary deployment strategy

set -e

SERVICE=${1:-user-service}
VERSION=${2:-latest}
ENVIRONMENT=${3:-prod}
NAMESPACE="three-tier-app"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
  echo -e "${RED}❌ $1${NC}"
}

# Validate inputs
if [ -z "$SERVICE" ] || [ -z "$VERSION" ]; then
  log_error "Usage: $0 <service> <version> [environment]"
  log_info "Example: $0 user-service 1.1.0 prod"
  exit 1
fi

log_info "Starting canary deployment"
log_info "Service: $SERVICE"
log_info "Version: $VERSION"
log_info "Environment: $ENVIRONMENT"

# Step 1: Verify prerequisites
log_info "Verifying prerequisites..."

# Check if service exists
if ! kubectl get deployment $SERVICE -n $NAMESPACE &>/dev/null; then
  log_error "Deployment $SERVICE not found in namespace $NAMESPACE"
  exit 1
fi

# Check if Flagger is installed
if ! kubectl get crd canaries.flagger.app &>/dev/null; then
  log_error "Flagger CRD not found. Please install Flagger first:"
  log_info "helm repo add flagger https://flagger.app"
  log_info "helm upgrade -i flagger flagger/flagger -n kube-system"
  exit 1
fi

log_success "Prerequisites verified"

# Step 2: Update image tag in values
log_info "Updating Helm values with new image tag..."
VALUES_FILE="helm-charts/$SERVICE/values-$ENVIRONMENT.yaml"

if [ ! -f "$VALUES_FILE" ]; then
  log_error "Values file not found: $VALUES_FILE"
  exit 1
fi

# Backup original values
cp "$VALUES_FILE" "$VALUES_FILE.backup"

# Update image tag
sed -i "s/tag: .*/tag: \"$VERSION\"/" "$VALUES_FILE"

log_success "Updated image tag to $VERSION"

# Step 3: Commit changes
log_info "Committing changes to Git..."
git add "$VALUES_FILE"
git commit -m "Canary deploy: $SERVICE v$VERSION to $ENVIRONMENT" || \
  log_warning "No changes to commit"

git push origin main
log_success "Changes pushed to Git"

# Step 4: Wait for pipeline
log_info "Waiting for Azure Pipeline to build and push image..."
sleep 10

# Step 5: Verify canary resource exists
log_info "Waiting for Canary resource to be created..."
for i in {1..30}; do
  if kubectl get canary $SERVICE -n $NAMESPACE &>/dev/null; then
    log_success "Canary resource found"
    break
  fi
  if [ $i -eq 30 ]; then
    log_error "Timeout waiting for Canary resource"
    exit 1
  fi
  sleep 2
done

# Step 6: Monitor canary progress
log_info "Monitoring canary deployment progress..."
log_info "Press Ctrl+C to stop monitoring"
echo ""

kubectl get canary $SERVICE -n $NAMESPACE -w

# Step 7: Get final status
log_info "Checking final canary status..."
echo ""
kubectl describe canary $SERVICE -n $NAMESPACE | grep -A 20 "Status:"

# Verify success
CANARY_STATUS=$(kubectl get canary $SERVICE -n $NAMESPACE -o jsonpath='{.status.phase}')

if [ "$CANARY_STATUS" == "Succeeded" ]; then
  log_success "Canary deployment completed successfully!"
  log_success "$SERVICE v$VERSION is now running in production"
  echo ""
  log_info "Canary timeline:"
  kubectl get canary $SERVICE -n $NAMESPACE -o jsonpath='{.status.conditions[*].message}' | tr ',' '\n'
elif [ "$CANARY_STATUS" == "Failed" ]; then
  log_error "Canary deployment failed!"
  log_warning "Rolling back to previous version..."
  
  # Restore previous values
  cp "$VALUES_FILE.backup" "$VALUES_FILE"
  git add "$VALUES_FILE"
  git commit -m "Canary rollback: $SERVICE failed deployment"
  git push origin main
  
  exit 1
else
  log_warning "Canary deployment status: $CANARY_STATUS"
  log_info "Use 'kubectl describe canary $SERVICE -n $NAMESPACE' for details"
fi

# Cleanup backup
rm -f "$VALUES_FILE.backup"

log_success "Deployment complete!"
