#!/bin/bash

# E2E Test Validation Script
# This script provides utility functions for validating the LGTM stack installation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE=${NAMESPACE:-lgtm-test}
RELEASE_PREFIX=${RELEASE_PREFIX:-test}

# Function to print colored output
log() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for pod readiness with timeout
wait_for_pods() {
    local namespace=$1
    local selector=$2
    local timeout=${3:-300}
    
    log "$YELLOW" "⏳ Waiting for pods with selector '$selector' in namespace '$namespace'..."
    
    if kubectl wait --for=condition=ready pod -l "$selector" -n "$namespace" --timeout="${timeout}s"; then
        log "$GREEN" "✅ Pods are ready"
        return 0
    else
        log "$RED" "❌ Pods failed to become ready within ${timeout}s"
        kubectl describe pods -l "$selector" -n "$namespace"
        return 1
    fi
}

# Function to validate installation
validate_installation() {
    local namespace=$1
    local release_prefix=$2
    
    log "$BLUE" "🔍 Validating installation in namespace '$namespace' with prefix '$release_prefix'..."
    
    # Check namespace exists
    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log "$RED" "❌ Namespace '$namespace' does not exist"
        return 1
    fi
    
    log "$GREEN" "✅ Namespace '$namespace' exists"
    
    # Check for expected Helm releases
    local expected_releases=("minio" "loki" "tempo" "mimir" "alloy" "grafana" "kube-state-metrics")
    local missing_releases=()
    
    # Function to check Helm releases based on available tool
    check_helm_releases() {
        if command_exists helm; then
            helm list -n "$namespace" --output json
        elif command_exists docker && docker info >/dev/null 2>&1; then
            # Use containerized Helm
            "$(dirname "${BASH_SOURCE[0]}")/helm-container.sh" list -n "$namespace" --output json
        else
            log "$YELLOW" "⚠️  Neither Helm nor Docker available, skipping Helm release validation"
            echo "[]"
        fi
    }
    
    local releases_json=$(check_helm_releases)
    
    for release in "${expected_releases[@]}"; do
        local full_release_name="${release_prefix}-${release}"
        if ! echo "$releases_json" | grep -q "\"name\":\"$full_release_name\""; then
            missing_releases+=("$full_release_name")
        fi
    done
    
    if [ ${#missing_releases[@]} -eq 0 ]; then
        log "$GREEN" "✅ All expected Helm releases are installed"
    else
        log "$RED" "❌ Missing Helm releases: ${missing_releases[*]}"
        return 1
    fi
    
    # Check for running pods
    local pod_count=$(kubectl get pods -n "$namespace" --no-headers | wc -l)
    if [ "$pod_count" -gt 0 ]; then
        log "$GREEN" "✅ Found $pod_count pods in namespace '$namespace'"
        
        # Show pod status
        kubectl get pods -n "$namespace"
        
        # Check for any failed pods
        local failed_pods=$(kubectl get pods -n "$namespace" --field-selector=status.phase=Failed --no-headers | wc -l)
        if [ "$failed_pods" -gt 0 ]; then
            log "$RED" "❌ Found $failed_pods failed pods"
            kubectl get pods -n "$namespace" --field-selector=status.phase=Failed
            return 1
        fi
    else
        log "$RED" "❌ No pods found in namespace '$namespace'"
        return 1
    fi
    
    # Check services
    local service_count=$(kubectl get services -n "$namespace" --no-headers | wc -l)
    if [ "$service_count" -gt 0 ]; then
        log "$GREEN" "✅ Found $service_count services in namespace '$namespace'"
        kubectl get services -n "$namespace"
    else
        log "$YELLOW" "⚠️  No services found in namespace '$namespace'"
    fi
    
    return 0
}

# Function to validate uninstallation
validate_uninstallation() {
    local namespace=$1
    local release_prefix=$2
    
    log "$BLUE" "🔍 Validating uninstallation in namespace '$namespace' with prefix '$release_prefix'..."
    
    # Function to check Helm releases based on available tool
    check_helm_releases() {
        if command_exists helm; then
            helm list -n "$namespace" --output json
        elif command_exists docker && docker info >/dev/null 2>&1; then
            # Use containerized Helm
            "$(dirname "${BASH_SOURCE[0]}")/helm-container.sh" list -n "$namespace" --output json
        else
            log "$YELLOW" "⚠️  Neither Helm nor Docker available, skipping Helm release validation"
            echo "[]"
        fi
    }
    
    local releases_json=$(check_helm_releases)
    
    # Check that no releases with our prefix exist
    if echo "$releases_json" | grep -q "\"name\":\"$release_prefix-"; then
        log "$RED" "❌ Helm releases with prefix '$release_prefix-' still exist:"
        echo "$releases_json" | grep "$release_prefix-" || true
        return 1
    else
        log "$GREEN" "✅ No Helm releases with prefix '$release_prefix-' found"
    fi
    
    # Check remaining pods (allow for some terminating pods)
    sleep 5
    local pod_count=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | wc -l || echo "0")
    local terminating_count=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | grep "Terminating" | wc -l || echo "0")
    local running_count=$((pod_count - terminating_count))
    
    if [ "$running_count" -eq 0 ]; then
        log "$GREEN" "✅ No running pods remain in namespace '$namespace'"
        if [ "$terminating_count" -gt 0 ]; then
            log "$YELLOW" "⚠️  $terminating_count pods are still terminating (this is normal)"
        fi
    else
        log "$RED" "❌ $running_count pods are still running in namespace '$namespace'"
        kubectl get pods -n "$namespace" 2>/dev/null || log "$YELLOW" "⚠️  Namespace may have been removed"
        return 1
    fi
    
    return 0
}

# Function to run full test cycle
run_full_test() {
    local test_mode=${1:-"auto"}  # auto, local-helm, containerized-helm
    
    log "$BLUE" "🚀 Starting full e2e test cycle with mode: $test_mode"
    
    # Determine script directory
    local script_dir="$(dirname "${BASH_SOURCE[0]}")"
    
    # Set test environment
    export NAMESPACE="$NAMESPACE"
    export RELEASE_PREFIX="$RELEASE_PREFIX"
    
    log "$YELLOW" "📋 Test Configuration:"
    log "$YELLOW" "  Namespace: $NAMESPACE"
    log "$YELLOW" "  Release Prefix: $RELEASE_PREFIX"
    log "$YELLOW" "  Test Mode: $test_mode"
    echo ""
    
    # Force Helm mode if specified
    if [ "$test_mode" = "containerized-helm" ]; then
        if command_exists helm; then
            log "$YELLOW" "⚠️  Temporarily hiding local Helm to test containerized mode"
            export PATH=$(echo "$PATH" | sed 's|/usr/local/bin||g' | sed 's|::|\:|g' | sed 's|^:||' | sed 's|:$||')
        fi
    fi
    
    # Run installation
    log "$BLUE" "📦 Running installation..."
    if ! "$script_dir/install.sh"; then
        log "$RED" "❌ Installation failed"
        return 1
    fi
    
    # Validate installation
    log "$BLUE" "✅ Installation completed, validating..."
    if ! validate_installation "$NAMESPACE" "$RELEASE_PREFIX"; then
        log "$RED" "❌ Installation validation failed"
        return 1
    fi
    
    # Wait a bit to ensure everything is stable
    sleep 10
    
    # Run uninstallation
    log "$BLUE" "🗑️  Running uninstallation..."
    if ! "$script_dir/uninstall.sh"; then
        log "$RED" "❌ Uninstallation failed"
        return 1
    fi
    
    # Validate uninstallation
    log "$BLUE" "✅ Uninstallation completed, validating..."
    if ! validate_uninstallation "$NAMESPACE" "$RELEASE_PREFIX"; then
        log "$RED" "❌ Uninstallation validation failed"
        return 1
    fi
    
    log "$GREEN" "🎉 Full e2e test cycle completed successfully!"
    return 0
}

# Main function
main() {
    case "${1:-help}" in
        "validate-install")
            validate_installation "$NAMESPACE" "$RELEASE_PREFIX"
            ;;
        "validate-uninstall")
            validate_uninstallation "$NAMESPACE" "$RELEASE_PREFIX"
            ;;
        "full-test")
            run_full_test "${2:-auto}"
            ;;
        "help"|*)
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  validate-install     - Validate that the LGTM stack is properly installed"
            echo "  validate-uninstall   - Validate that the LGTM stack is properly uninstalled"
            echo "  full-test [mode]     - Run complete install/validate/uninstall/validate cycle"
            echo ""
            echo "Full test modes:"
            echo "  auto                 - Use whatever Helm is available (default)"
            echo "  local-helm           - Force use of local Helm"
            echo "  containerized-helm   - Force use of containerized Helm"
            echo ""
            echo "Environment variables:"
            echo "  NAMESPACE            - Kubernetes namespace (default: lgtm-test)"
            echo "  RELEASE_PREFIX       - Helm release prefix (default: test)"
            echo ""
            echo "Examples:"
            echo "  $0 validate-install"
            echo "  $0 full-test containerized-helm"
            echo "  NAMESPACE=my-test $0 validate-install"
            ;;
    esac
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi