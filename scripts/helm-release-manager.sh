#!/bin/bash

################################################################################
# Helm Release Management Script
# Purpose: Manage Helm releases, upgrades, and rollbacks
# Usage: ./helm-release-manager.sh [release] [action] [version]
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
NAMESPACE="three-tier-app"
HELM_CHARTS_DIR="./helm-charts"
ENVIRONMENTS=("dev" "staging" "prod")

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

# Validate release name
validate_release() {
    local release=$1
    if [ -z "$release" ]; then
        log_error "Release name is required"
    fi
}

# List releases
list_releases() {
    log_info "Listing Helm releases in ${NAMESPACE}..."
    helm list -n ${NAMESPACE}
}

# Get release info
get_release_info() {
    local release=$1
    validate_release "$release"
    
    log_info "Getting info for release: ${release}..."
    helm get all -n ${NAMESPACE} ${release}
}

# Get release values
get_release_values() {
    local release=$1
    validate_release "$release"
    
    log_info "Getting values for release: ${release}..."
    helm get values -n ${NAMESPACE} ${release}
}

# Show release history
show_release_history() {
    local release=$1
    validate_release "$release"
    
    log_info "Release history for: ${release}..."
    helm history ${release} -n ${NAMESPACE}
}

# Upgrade release
upgrade_release() {
    local release=$1
    local chart_path="${HELM_CHARTS_DIR}/${release}"
    local environment="${2:-prod}"
    local version="${3:-}"
    
    validate_release "$release"
    
    if [ ! -d "$chart_path" ]; then
        log_error "Chart not found: ${chart_path}"
    fi
    
    log_info "Upgrading release: ${release}"
    log_info "Chart: ${chart_path}"
    log_info "Environment: ${environment}"
    
    # Check if environment-specific values exist
    local values_file="${chart_path}/values-${environment}.yaml"
    if [ ! -f "$values_file" ]; then
        log_error "Values file not found: ${values_file}"
    fi
    
    # Build helm upgrade command
    local helm_cmd="helm upgrade ${release} ${chart_path} \
        -n ${NAMESPACE} \
        -f ${chart_path}/values.yaml \
        -f ${values_file} \
        --wait \
        --timeout 5m"
    
    # Add version override if provided
    if [ -n "$version" ]; then
        helm_cmd="${helm_cmd} --set image.tag=${version}"
        log_info "Setting image tag: ${version}"
    fi
    
    # Show what will be changed
    log_info "Preview of changes:"
    eval "${helm_cmd} --dry-run --debug" 2>/dev/null | head -50 || true
    
    read -p "Proceed with upgrade? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_info "Upgrade cancelled"
        return
    fi
    
    # Execute upgrade
    eval "${helm_cmd}"
    log_success "${release} upgraded successfully"
    
    # Show rollout status
    log_info "Waiting for rollout to complete..."
    kubectl rollout status deployment/${release} -n ${NAMESPACE} --timeout=5m
}

# Install release
install_release() {
    local release=$1
    local chart_path="${HELM_CHARTS_DIR}/${release}"
    local environment="${2:-prod}"
    
    validate_release "$release"
    
    if [ ! -d "$chart_path" ]; then
        log_error "Chart not found: ${chart_path}"
    fi
    
    log_info "Installing release: ${release}"
    log_info "Chart: ${chart_path}"
    log_info "Environment: ${environment}"
    
    # Check if release already exists
    if helm list -n ${NAMESPACE} | grep -q "^${release}"; then
        log_error "Release ${release} already exists. Use 'upgrade' instead."
    fi
    
    local values_file="${chart_path}/values-${environment}.yaml"
    if [ ! -f "$values_file" ]; then
        log_error "Values file not found: ${values_file}"
    fi
    
    helm install ${release} ${chart_path} \
        -n ${NAMESPACE} \
        -f ${chart_path}/values.yaml \
        -f ${values_file} \
        --wait \
        --timeout 5m
    
    log_success "${release} installed successfully"
}

# Rollback release
rollback_release() {
    local release=$1
    local revision="${2:-}"
    
    validate_release "$release"
    
    # Show history
    log_info "Release history for: ${release}"
    helm history ${release} -n ${NAMESPACE} | head -10
    
    if [ -z "$revision" ]; then
        read -p "Enter revision number to rollback to (0 for previous): " revision
    fi
    
    if [ "$revision" == "0" ]; then
        log_info "Rolling back ${release} to previous version..."
        helm rollback ${release} -n ${NAMESPACE} --wait --timeout 5m
    else
        log_info "Rolling back ${release} to revision ${revision}..."
        helm rollback ${release} ${revision} -n ${NAMESPACE} --wait --timeout 5m
    fi
    
    log_success "${release} rolled back successfully"
    kubectl rollout status deployment/${release} -n ${NAMESPACE}
}

# Delete release
delete_release() {
    local release=$1
    validate_release "$release"
    
    log_warn "This will delete the release: ${release}"
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_info "Deletion cancelled"
        return
    fi
    
    helm uninstall ${release} -n ${NAMESPACE}
    log_success "${release} deleted"
}

# Compare values
compare_values() {
    local release=$1
    local environment="${2:-prod}"
    
    validate_release "$release"
    local chart_path="${HELM_CHARTS_DIR}/${release}"
    
    log_info "Comparing values for ${release}"
    log_info "Current cluster values:"
    helm get values -n ${NAMESPACE} ${release} > /tmp/current-values.yaml
    cat /tmp/current-values.yaml
    
    echo ""
    log_info "File values (${environment}):"
    cat "${chart_path}/values-${environment}.yaml"
    
    echo ""
    log_info "Running diff..."
    diff /tmp/current-values.yaml "${chart_path}/values-${environment}.yaml" || true
}

# Get release status
get_release_status() {
    local release=$1
    validate_release "$release"
    
    log_info "Status for release: ${release}..."
    helm status ${release} -n ${NAMESPACE}
    
    echo ""
    log_info "Deployment status:"
    kubectl rollout status deployment/${release} -n ${NAMESPACE}
    
    echo ""
    log_info "Pod status:"
    kubectl get pods -n ${NAMESPACE} -l "app.kubernetes.io/instance=${release}"
}

# Validate all charts
validate_all() {
    log_info "Validating all charts..."
    
    for release in $(helm list -n ${NAMESPACE} -o json | grep -o '"name":"[^"]*' | cut -d'"' -f4); do
        log_info "Validating ${release}..."
        
        if helm get values -n ${NAMESPACE} ${release} > /dev/null; then
            log_success "${release} is valid"
        else
            log_warn "${release} validation failed"
        fi
    done
}

# Usage
usage() {
    echo "Helm Release Management Script"
    echo ""
    echo "Usage: $0 [command] [release] [options]"
    echo ""
    echo "Commands:"
    echo "  list                     - List all Helm releases"
    echo "  info [release]           - Get release information"
    echo "  values [release]         - Get release values"
    echo "  history [release]        - Show release history"
    echo "  status [release]         - Get release status"
    echo "  install [release] [env]  - Install a release"
    echo "  upgrade [release] [env] [version] - Upgrade a release"
    echo "  rollback [release] [rev] - Rollback a release"
    echo "  delete [release]         - Delete a release"
    echo "  compare [release] [env]  - Compare values"
    echo "  validate                 - Validate all releases"
    echo ""
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 install user-service prod"
    echo "  $0 upgrade user-service prod 1.1.0"
    echo "  $0 rollback user-service"
    echo "  $0 status user-service"
    echo ""
}

# Main
main() {
    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi
    
    case "$1" in
        list)
            list_releases
            ;;
        info)
            get_release_info "$2"
            ;;
        values)
            get_release_values "$2"
            ;;
        history)
            show_release_history "$2"
            ;;
        status)
            get_release_status "$2"
            ;;
        install)
            install_release "$2" "$3"
            ;;
        upgrade)
            upgrade_release "$2" "$3" "$4"
            ;;
        rollback)
            rollback_release "$2" "$3"
            ;;
        delete)
            delete_release "$2"
            ;;
        compare)
            compare_values "$2" "$3"
            ;;
        validate)
            validate_all
            ;;
        *)
            echo "Unknown command: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
