#!/bin/bash

################################################################################
# Helm Chart Validation and Testing Script
# Purpose: Validate and test Helm charts before deployment
# Usage: ./helm-setup.sh [validate|lint|template|test|all]
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
HELM_CHARTS_DIR="./helm-charts"
CHARTS=("user-service" "order-service" "payment-service")
TEST_NAMESPACE="helm-test"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v helm &> /dev/null; then
        log_error "helm is not installed"
    fi
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
    fi
    
    log_success "Prerequisites satisfied"
}

# Validate chart structure
validate_charts() {
    log_info "Validating chart structures..."
    
    for chart in "${CHARTS[@]}"; do
        log_info "Validating ${chart}..."
        
        CHART_PATH="${HELM_CHARTS_DIR}/${chart}"
        
        if [ ! -f "${CHART_PATH}/Chart.yaml" ]; then
            log_error "Missing Chart.yaml in ${chart}"
        fi
        
        if [ ! -f "${CHART_PATH}/values.yaml" ]; then
            log_error "Missing values.yaml in ${chart}"
        fi
        
        if [ ! -d "${CHART_PATH}/templates" ]; then
            log_error "Missing templates directory in ${chart}"
        fi
        
        log_success "${chart} structure is valid"
    done
}

# Lint charts
lint_charts() {
    log_info "Linting Helm charts..."
    
    for chart in "${CHARTS[@]}"; do
        log_info "Linting ${chart}..."
        
        if helm lint "${HELM_CHARTS_DIR}/${chart}" -f values.yaml; then
            log_success "${chart} passed lint checks"
        else
            log_error "${chart} failed lint checks"
        fi
    done
}

# Generate templates
generate_templates() {
    log_info "Generating Helm templates..."
    
    for chart in "${CHARTS[@]}"; do
        log_info "Generating templates for ${chart}..."
        
        CHART_PATH="${HELM_CHARTS_DIR}/${chart}"
        OUTPUT_FILE="/tmp/${chart}-manifests.yaml"
        
        helm template "${chart}" "${CHART_PATH}" \
            -f "${CHART_PATH}/values.yaml" \
            -f "${CHART_PATH}/values-prod.yaml" \
            > "${OUTPUT_FILE}"
        
        if [ $? -eq 0 ]; then
            LINE_COUNT=$(wc -l < "${OUTPUT_FILE}")
            log_success "${chart} templates generated (${LINE_COUNT} lines)"
            
            # Basic validation of generated YAML
            if kubectl apply -f "${OUTPUT_FILE}" --dry-run=client &> /dev/null; then
                log_success "${chart} templates are valid Kubernetes manifests"
            else
                log_error "${chart} templates failed Kubernetes validation"
            fi
        else
            log_error "${chart} template generation failed"
        fi
    done
}

# Test installations (dry run)
test_installations() {
    log_info "Testing Helm installations (dry-run)..."
    
    for chart in "${CHARTS[@]}"; do
        log_info "Testing installation of ${chart}..."
        
        CHART_PATH="${HELM_CHARTS_DIR}/${chart}"
        
        if helm install "${chart}-test" "${CHART_PATH}" \
            -n ${TEST_NAMESPACE} \
            -f "${CHART_PATH}/values.yaml" \
            -f "${CHART_PATH}/values-prod.yaml" \
            --dry-run \
            --debug > /tmp/${chart}-install-test.log 2>&1; then
            
            log_success "${chart} installation test passed"
        else
            log_error "${chart} installation test failed (see /tmp/${chart}-install-test.log)"
        fi
    done
}

# Validate environment-specific values
validate_environments() {
    log_info "Validating environment-specific values..."
    
    ENVIRONMENTS=("dev" "staging" "prod")
    
    for chart in "${CHARTS[@]}"; do
        for env in "${ENVIRONMENTS[@]}"; do
            VALUES_FILE="${HELM_CHARTS_DIR}/${chart}/values-${env}.yaml"
            
            if [ -f "${VALUES_FILE}" ]; then
                log_info "Validating values-${env}.yaml for ${chart}..."
                
                if helm template "${chart}" "${HELM_CHARTS_DIR}/${chart}" \
                    -f "${HELM_CHARTS_DIR}/${chart}/values.yaml" \
                    -f "${VALUES_FILE}" > /dev/null; then
                    
                    log_success "values-${env}.yaml for ${chart} is valid"
                else
                    log_error "values-${env}.yaml for ${chart} is invalid"
                fi
            fi
        done
    done
}

# Check image references
check_image_references() {
    log_info "Checking image references..."
    
    for chart in "${CHARTS[@]}"; do
        CHART_PATH="${HELM_CHARTS_DIR}/${chart}"
        
        # Check if values.yaml has image configuration
        if grep -q "image:" "${CHART_PATH}/values.yaml"; then
            log_info "✓ ${chart} has image configuration"
            
            # Extract image details
            REGISTRY=$(grep "registry:" "${CHART_PATH}/values.yaml" | head -1 | awk '{print $2}')
            REPO=$(grep "repository:" "${CHART_PATH}/values.yaml" | head -1 | awk '{print $2}')
            TAG=$(grep "tag:" "${CHART_PATH}/values.yaml" | head -1 | awk '{print $2}')
            
            log_info "  Registry: ${REGISTRY}"
            log_info "  Repository: ${REPO}"
            log_info "  Tag: ${TAG}"
        else
            log_warn "${chart} does not have image configuration"
        fi
    done
}

# Validate database configuration
validate_database_config() {
    log_info "Validating database configuration..."
    
    for chart in "${CHARTS[@]}"; do
        CHART_PATH="${HELM_CHARTS_DIR}/${chart}"
        
        if grep -q "database:" "${CHART_PATH}/values.yaml"; then
            log_info "✓ ${chart} has database configuration"
            
            HOST=$(grep "host:" "${CHART_PATH}/values.yaml" | grep database -A 5 | grep host | head -1 | awk '{print $2}')
            PORT=$(grep "port:" "${CHART_PATH}/values.yaml" | grep database -A 5 | grep port | head -1 | awk '{print $2}')
            
            log_info "  Database: ${HOST}:${PORT}"
        else
            log_warn "${chart} does not have database configuration"
        fi
    done
}

# Display chart information
show_chart_info() {
    log_info "Chart Information Summary:"
    
    for chart in "${CHARTS[@]}"; do
        CHART_PATH="${HELM_CHARTS_DIR}/${chart}"
        
        echo ""
        echo "  📦 ${chart}"
        
        if [ -f "${CHART_PATH}/Chart.yaml" ]; then
            VERSION=$(grep "version:" "${CHART_PATH}/Chart.yaml" | head -1 | awk '{print $2}')
            APP_VERSION=$(grep "appVersion:" "${CHART_PATH}/Chart.yaml" | head -1 | awk '{print $2}')
            DESCRIPTION=$(grep "description:" "${CHART_PATH}/Chart.yaml" | awk -F': ' '{print $2}')
            
            echo "     Version: ${VERSION}"
            echo "     App Version: ${APP_VERSION}"
            echo "     Description: ${DESCRIPTION}"
        fi
        
        # Count templates
        TEMPLATE_COUNT=$(find "${CHART_PATH}/templates" -name "*.yaml" -o -name "*.tpl" | wc -l)
        echo "     Templates: ${TEMPLATE_COUNT}"
    done
}

# Usage information
usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  validate      - Validate chart structures"
    echo "  lint          - Run Helm lint on all charts"
    echo "  template      - Generate and test Helm templates"
    echo "  test          - Test Helm installations (dry-run)"
    echo "  validate-env  - Validate environment-specific values"
    echo "  images        - Check image references"
    echo "  database      - Validate database configurations"
    echo "  info          - Display chart information"
    echo "  all           - Run all validations"
    echo ""
}

# Main
main() {
    case "${1:-all}" in
        validate)
            check_prerequisites
            validate_charts
            ;;
        lint)
            check_prerequisites
            lint_charts
            ;;
        template)
            check_prerequisites
            generate_templates
            ;;
        test)
            check_prerequisites
            test_installations
            ;;
        validate-env)
            check_prerequisites
            validate_environments
            ;;
        images)
            check_image_references
            ;;
        database)
            validate_database_config
            ;;
        info)
            show_chart_info
            ;;
        all)
            check_prerequisites
            validate_charts
            lint_charts
            show_chart_info
            validate_database_config
            check_image_references
            validate_environments
            generate_templates
            log_success "All validations completed successfully!"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
