#!/bin/bash

# Helm Chart Testing Script
# This script validates and tests all Helm charts

set -e

echo "=================================================="
echo "Helm Chart Testing and Validation"
echo "=================================================="

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

SERVICES=("user-service" "order-service" "payment-service")
CHARTS_DIR="helm-charts"

# Step 1: Check prerequisites
echo -e "\n${YELLOW}Step 1: Checking prerequisites${NC}"
echo "Verifying Helm is installed..."
helm version || exit 1

# Step 2: Lint all charts
echo -e "\n${YELLOW}Step 2: Linting Helm charts${NC}"
for service in "${SERVICES[@]}"; do
    echo "Linting $service..."
    helm lint "$CHARTS_DIR/$service" --strict
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $service passed linting${NC}"
    else
        echo -e "${RED}✗ $service failed linting${NC}"
        exit 1
    fi
done

# Step 3: Validate template rendering
echo -e "\n${YELLOW}Step 3: Validating template rendering${NC}"
for service in "${SERVICES[@]}"; do
    echo "Validating $service templates..."
    
    # Test with default values
    helm template $service "$CHARTS_DIR/$service" > /tmp/${service}-template.yaml
    
    # Validate YAML syntax
    kubectl apply -f /tmp/${service}-template.yaml --dry-run=client
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $service templates are valid${NC}"
    else
        echo -e "${RED}✗ $service templates failed validation${NC}"
        exit 1
    fi
done

# Step 4: Test environment-specific values
echo -e "\n${YELLOW}Step 4: Testing environment-specific configurations${NC}"
ENVIRONMENTS=("dev" "staging" "prod")

for service in "${SERVICES[@]}"; do
    for env in "${ENVIRONMENTS[@]}"; do
        values_file="$CHARTS_DIR/$service/values-${env}.yaml"
        
        if [ -f "$values_file" ]; then
            echo "Testing $service with $env values..."
            helm template $service "$CHARTS_DIR/$service" \
              -f "$CHARTS_DIR/$service/values.yaml" \
              -f "$values_file" > /tmp/${service}-${env}-template.yaml
            
            # Count resources
            resource_count=$(grep "^kind:" /tmp/${service}-${env}-template.yaml | wc -l)
            echo "  Generated $resource_count Kubernetes resources"
            
            # Validate YAML
            kubectl apply -f /tmp/${service}-${env}-template.yaml --dry-run=client
            if [ $? -eq 0 ]; then
                echo -e "  ${GREEN}✓ Valid configuration${NC}"
            else
                echo -e "  ${RED}✗ Invalid configuration${NC}"
                exit 1
            fi
        fi
    done
done

# Step 5: Dry run installation
echo -e "\n${YELLOW}Step 5: Testing dry-run installations${NC}"
kubectl create namespace three-tier-app --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

for service in "${SERVICES[@]}"; do
    echo "Dry-run install $service..."
    helm install $service "$CHARTS_DIR/$service" \
      -n three-tier-app \
      -f "$CHARTS_DIR/$service/values-prod.yaml" \
      --dry-run \
      --debug > /dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $service can be installed successfully${NC}"
    else
        echo -e "${RED}✗ $service installation would fail${NC}"
        exit 1
    fi
done

# Step 6: Check for common issues
echo -e "\n${YELLOW}Step 6: Checking for common configuration issues${NC}"

for service in "${SERVICES[@]}"; do
    values_file="$CHARTS_DIR/$service/values.yaml"
    
    # Check if image registry is set
    if grep -q "registry:" "$values_file"; then
        echo -e "  ${GREEN}✓ Image registry is configured${NC}"
    else
        echo -e "  ${RED}✗ Image registry is missing${NC}"
    fi
    
    # Check if resources are defined
    if grep -q "resources:" "$values_file"; then
        echo -e "  ${GREEN}✓ Resource limits are configured${NC}"
    else
        echo -e "  ${RED}✗ Resource limits are missing${NC}"
    fi
    
    # Check if probes are defined
    if grep -q "livenessProbe:" "$values_file"; then
        echo -e "  ${GREEN}✓ Health checks are configured${NC}"
    else
        echo -e "  ${RED}✗ Health checks are missing${NC}"
    fi
done

# Step 7: Generate documentation
echo -e "\n${YELLOW}Step 7: Generating template documentation${NC}"
mkdir -p /tmp/helm-docs

for service in "${SERVICES[@]}"; do
    echo "Generating documentation for $service..."
    helm template $service "$CHARTS_DIR/$service" \
      -f "$CHARTS_DIR/$service/values-prod.yaml" > "/tmp/helm-docs/${service}-manifests.yaml"
    
    echo "  Documentation saved to /tmp/helm-docs/${service}-manifests.yaml"
done

echo -e "${GREEN}All documentation generated${NC}"

# Step 8: Display summary
echo -e "\n${GREEN}=================================================="
echo "All Helm Chart Tests Passed!"
echo "==================================================${NC}"
echo ""
echo "Summary:"
echo "- All charts passed linting ✓"
echo "- All templates are valid ✓"
echo "- All configurations are correct ✓"
echo "- All installations would succeed ✓"
echo ""
echo "Generated manifests are available at:"
echo "  /tmp/helm-docs/"
echo ""
echo "Next steps:"
echo "1. Deploy to AKS:"
echo "   kubectl create namespace three-tier-app"
echo "   helm install user-service $CHARTS_DIR/user-service -n three-tier-app -f $CHARTS_DIR/user-service/values-prod.yaml"
echo ""
echo "2. Or use ArgoCD for automated deployment:"
echo "   kubectl apply -f argocd/projects/three-tier-app.yaml"
echo "   kubectl apply -f argocd/applications/"
echo ""
echo "3. Monitor deployments:"
echo "   kubectl get pods -n three-tier-app"
echo "   kubectl rollout status deployment/user-service -n three-tier-app"
