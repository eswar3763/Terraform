#!/bin/bash

################################################################################
# Helm & ArgoCD Integration Test Script
# Purpose: Test integration between Helm charts and ArgoCD
# Usage: ./helm-argocd-integration.sh [test|monitor|rollback|cleanup]
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
APPS=("user-service" "order-service" "payment-service")
TEST_TIMEOUT=300

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
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
    fi
    
    if ! command -v helm &> /dev/null; then
        log_error "helm is not installed"
    fi
    
    if ! command -v argocd &> /dev/null; then
        log_warn "argocd CLI not found - some tests will be skipped"
    fi
    
    log_success "Prerequisites check complete"
}

# Test Helm installations
test_helm_installations() {
    log_info "Testing Helm installations in ${NAMESPACE}..."
    
    for app in "${APPS[@]}"; do
        log_info "Testing ${app}..."
        
        # Check if release exists
        if helm list -n ${NAMESPACE} | grep -q ${app}; then
            STATUS=$(helm list -n ${NAMESPACE} | grep ${app} | awk '{print $8}')
            log_success "${app} is deployed (Status: ${STATUS})"
        else
            log_warn "${app} is not deployed via Helm"
        fi
    done
}

# Test pod health
test_pod_health() {
    log_info "Testing pod health in ${NAMESPACE}..."
    
    # Create namespace if it doesn't exist
    kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    
    for app in "${APPS[@]}"; do
        log_info "Checking health of ${app}..."
        
        POD_COUNT=$(kubectl get pods -n ${NAMESPACE} \
            -l "app.kubernetes.io/name=${app}" \
            --field-selector=status.phase=Running 2>/dev/null | wc -l)
        
        if [ $POD_COUNT -gt 1 ]; then
            log_success "${app} has $(($POD_COUNT - 1)) running pods"
        else
            log_warn "${app} has no running pods"
        fi
    done
}

# Test service connectivity
test_service_connectivity() {
    log_info "Testing service connectivity in ${NAMESPACE}..."
    
    # Get all services
    SERVICES=$(kubectl get svc -n ${NAMESPACE} -o name 2>/dev/null | cut -d/ -f2)
    
    if [ -z "$SERVICES" ]; then
        log_warn "No services found in ${NAMESPACE}"
        return
    fi
    
    for svc in $SERVICES; do
        log_info "Testing service ${svc}..."
        
        # Check if service has endpoints
        ENDPOINTS=$(kubectl get endpoints ${svc} -n ${NAMESPACE} -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
        
        if [ -n "$ENDPOINTS" ]; then
            log_success "${svc} has endpoints: ${ENDPOINTS}"
        else
            log_warn "${svc} has no endpoints"
        fi
    done
}

# Test ArgoCD applications
test_argocd_apps() {
    log_info "Testing ArgoCD applications..."
    
    if ! command -v argocd &> /dev/null; then
        log_warn "argocd CLI not available, skipping ArgoCD tests"
        return
    fi
    
    for app in "${APPS[@]}"; do
        log_info "Checking ArgoCD app: ${app}..."
        
        if argocd app get ${app} &>/dev/null; then
            SYNC_STATUS=$(argocd app get ${app} --refresh 2>/dev/null | grep "Sync Status" | awk '{print $3}')
            HEALTH=$(argocd app get ${app} | grep "Health Status" | awk '{print $3}')
            
            log_success "${app} - Sync: ${SYNC_STATUS}, Health: ${HEALTH}"
        else
            log_warn "${app} not found in ArgoCD"
        fi
    done
}

# Monitor deployments
monitor_deployments() {
    log_info "Monitoring deployments..."
    
    log_info "Watching deployments (Ctrl+C to stop)..."
    kubectl rollout status deployment --all-namespaces -w 2>/dev/null || true
}

# Check deployment replicas
check_replicas() {
    log_info "Checking deployment replicas..."
    
    for app in "${APPS[@]}"; do
        DEPLOYMENT="${app}"
        
        if kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} &>/dev/null; then
            DESIRED=$(kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.spec.replicas}')
            READY=$(kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.status.readyReplicas}')
            
            if [ "$DESIRED" == "$READY" ]; then
                log_success "${DEPLOYMENT}: ${READY}/${DESIRED} replicas ready"
            else
                log_warn "${DEPLOYMENT}: ${READY}/${DESIRED} replicas ready"
            fi
        else
            log_warn "Deployment ${DEPLOYMENT} not found"
        fi
    done
}

# Test pod logs
test_pod_logs() {
    log_info "Checking pod logs for errors..."
    
    for app in "${APPS[@]}"; do
        log_info "Checking logs for ${app}..."
        
        PODS=$(kubectl get pods -n ${NAMESPACE} \
            -l "app.kubernetes.io/name=${app}" \
            -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
        
        for pod in $PODS; do
            ERROR_COUNT=$(kubectl logs -n ${NAMESPACE} ${pod} 2>/dev/null | \
                grep -i "error\|exception\|failed" | wc -l)
            
            if [ $ERROR_COUNT -gt 0 ]; then
                log_warn "${pod}: Found ${ERROR_COUNT} error lines in logs"
            else
                log_success "${pod}: No errors found in logs"
            fi
        done
    done
}

# Test resource usage
test_resource_usage() {
    log_info "Checking resource usage..."
    
    log_info "Pod resource usage:"
    kubectl top pods -n ${NAMESPACE} 2>/dev/null || log_warn "Metrics not available (ensure Metrics Server is installed)"
    
    log_info "Node resource usage:"
    kubectl top nodes 2>/dev/null || true
}

# Rollback deployment
rollback_deployment() {
    log_info "Rolling back deployments..."
    
    for app in "${APPS[@]}"; do
        if kubectl get deployment ${app} -n ${NAMESPACE} &>/dev/null; then
            log_info "Rolling back ${app}..."
            kubectl rollout undo deployment/${app} -n ${NAMESPACE}
            kubectl rollout status deployment/${app} -n ${NAMESPACE}
            log_success "${app} rolled back"
        fi
    done
}

# Cleanup test resources
cleanup() {
    log_info "Cleaning up test resources..."
    
    read -p "Are you sure you want to delete the test namespace? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_info "Cleanup cancelled"
        return
    fi
    
    kubectl delete namespace ${NAMESPACE}
    log_success "Test namespace deleted"
}

# Run all tests
run_all_tests() {
    log_info "Running all integration tests..."
    
    check_prerequisites
    test_helm_installations
    test_pod_health
    test_service_connectivity
    test_argocd_apps
    check_replicas
    test_pod_logs
    test_resource_usage
    
    log_success "All tests completed!"
}

# Generate test report
generate_report() {
    log_info "Generating test report..."
    
    REPORT_FILE="/tmp/helm-argocd-test-report-$(date +%s).txt"
    
    {
        echo "Helm & ArgoCD Integration Test Report"
        echo "Generated: $(date)"
        echo ""
        echo "=== Helm Releases ==="
        helm list -n ${NAMESPACE} 2>/dev/null || echo "No releases found"
        echo ""
        echo "=== Deployments ==="
        kubectl get deployments -n ${NAMESPACE} 2>/dev/null || echo "No deployments found"
        echo ""
        echo "=== Pods ==="
        kubectl get pods -n ${NAMESPACE} 2>/dev/null || echo "No pods found"
        echo ""
        echo "=== Services ==="
        kubectl get svc -n ${NAMESPACE} 2>/dev/null || echo "No services found"
        echo ""
        echo "=== Events ==="
        kubectl get events -n ${NAMESPACE} --sort-by='.lastTimestamp' 2>/dev/null | tail -20 || echo "No events found"
    } > "${REPORT_FILE}"
    
    log_success "Report generated: ${REPORT_FILE}"
    cat "${REPORT_FILE}"
}

# Usage
usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  test          - Run all integration tests"
    echo "  helm          - Test Helm installations"
    echo "  pods          - Test pod health"
    echo "  services      - Test service connectivity"
    echo "  argocd        - Test ArgoCD applications"
    echo "  replicas      - Check deployment replicas"
    echo "  logs          - Check pod logs"
    echo "  resources     - Check resource usage"
    echo "  monitor       - Monitor deployments"
    echo "  report        - Generate test report"
    echo "  rollback      - Rollback deployments"
    echo "  cleanup       - Delete test namespace"
    echo ""
}

# Main
main() {
    case "${1:-test}" in
        test)
            run_all_tests
            ;;
        helm)
            check_prerequisites
            test_helm_installations
            ;;
        pods)
            check_prerequisites
            test_pod_health
            ;;
        services)
            check_prerequisites
            test_service_connectivity
            ;;
        argocd)
            check_prerequisites
            test_argocd_apps
            ;;
        replicas)
            check_prerequisites
            check_replicas
            ;;
        logs)
            check_prerequisites
            test_pod_logs
            ;;
        resources)
            check_prerequisites
            test_resource_usage
            ;;
        monitor)
            check_prerequisites
            monitor_deployments
            ;;
        report)
            generate_report
            ;;
        rollback)
            rollback_deployment
            ;;
        cleanup)
            cleanup
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
