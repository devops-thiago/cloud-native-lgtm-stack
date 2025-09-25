#!/bin/bash

# Containerized Helm Wrapper Script
# FOR: Environments where Helm is not installed locally
# USAGE: ./helm-container.sh [helm-commands]
# REQUIRES: Docker installed and running

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HELM_IMAGE="alpine/helm:3.13.2"
KUBECTL_IMAGE="bitnami/kubectl:latest"

# Function to check if Docker is available
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not installed or not in PATH${NC}" >&2
        echo -e "${YELLOW}💡 Please install Docker to use containerized Helm${NC}" >&2
        return 1
    fi

    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not running${NC}" >&2
        echo -e "${YELLOW}💡 Please start Docker to use containerized Helm${NC}" >&2
        return 1
    fi
}

# Function to get kubeconfig path
get_kubeconfig_path() {
    if [ -n "${KUBECONFIG:-}" ]; then
        echo "${KUBECONFIG}"
    elif [ -f "${HOME}/.kube/config" ]; then
        echo "${HOME}/.kube/config"
    else
        echo -e "${RED}❌ No kubeconfig found${NC}" >&2
        echo -e "${YELLOW}💡 Please ensure kubectl is configured${NC}" >&2
        return 1
    fi
}

# Function to run Helm in container
run_helm_container() {
    local kubeconfig_path
    kubeconfig_path=$(get_kubeconfig_path)

    local project_root
    project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

    echo -e "${BLUE}🐳 Running Helm in container: ${HELM_IMAGE}${NC}" >&2

    # Mount kubeconfig and project directory, run helm command
    # Add Docker Desktop network compatibility for kubernetes.docker.internal
    # Use /tmp/kubeconfig to avoid permission issues with /root/.kube/config
    # Mount a persistent Helm cache directory to preserve repository configuration
    local helm_cache_dir="${HOME}/.cache/helm-container"
    mkdir -p "${helm_cache_dir}"

    docker run --rm -it \
        -v "${kubeconfig_path}:/tmp/kubeconfig:ro" \
        -v "${project_root}:/workspace" \
        -v "${helm_cache_dir}:/root/.cache/helm" \
        -v "${helm_cache_dir}:/root/.config/helm" \
        -w /workspace/scripts \
        -e KUBECONFIG=/tmp/kubeconfig \
        --add-host kubernetes.docker.internal:host-gateway \
        "${HELM_IMAGE}" \
        "$@"
}

# Function to run kubectl in container (for verification)
run_kubectl_container() {
    local kubeconfig_path
    kubeconfig_path=$(get_kubeconfig_path)

    echo -e "${BLUE}🐳 Running kubectl in container: ${KUBECTL_IMAGE}${NC}" >&2

    docker run --rm \
        -v "${kubeconfig_path}:/tmp/kubeconfig:ro" \
        -e KUBECONFIG=/tmp/kubeconfig \
        --add-host kubernetes.docker.internal:host-gateway \
        "${KUBECTL_IMAGE}" \
        "$@"
}

# Function to test cluster connectivity
test_cluster_connection() {
    echo -e "${YELLOW}🔍 Testing Kubernetes cluster connectivity...${NC}"
    if run_kubectl_container cluster-info >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Kubernetes cluster is accessible${NC}"
        return 0
    else
        echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}" >&2
        return 1
    fi
}

# Function to pull required images
pull_images() {
    echo -e "${YELLOW}📦 Pulling required container images...${NC}"

    echo -e "${BLUE}Pulling Helm image: ${HELM_IMAGE}${NC}"
    docker pull "${HELM_IMAGE}"

    echo -e "${BLUE}Pulling kubectl image: ${KUBECTL_IMAGE}${NC}"
    docker pull "${KUBECTL_IMAGE}"

    echo -e "${GREEN}✅ Container images ready${NC}"
}

# Main execution
main() {
    # Check prerequisites
    if ! check_docker; then
        exit 1
    fi

    # If no arguments provided, show help
    if [ $# -eq 0 ]; then
        echo -e "${YELLOW}🐳 Containerized Helm Wrapper${NC}"
        echo ""
        echo -e "${BLUE}Usage:${NC}"
        echo "  $0 [helm-command] [args...]"
        echo ""
        echo -e "${BLUE}Examples:${NC}"
        echo "  $0 version"
        echo "  $0 repo add grafana https://grafana.github.io/helm-charts"
        echo "  $0 install my-app ./chart"
        echo ""
        echo -e "${BLUE}Special commands:${NC}"
        echo "  $0 --test-connection    # Test cluster connectivity"
        echo "  $0 --pull-images        # Pre-pull container images"
        echo "  $0 --kubectl [args...]  # Run kubectl in container"
        exit 0
    fi

    # Handle special commands
    case "${1:-}" in
        --test-connection)
            test_cluster_connection
            exit $?
            ;;
        --pull-images)
            pull_images
            exit $?
            ;;
        --kubectl)
            shift
            run_kubectl_container "$@"
            exit $?
            ;;
        --help|-h)
            main  # Show help
            exit 0
            ;;
    esac

    # Test cluster connection first
    if ! test_cluster_connection; then
        echo -e "${RED}❌ Cluster connectivity test failed${NC}" >&2
        echo -e "${YELLOW}💡 Please check your kubeconfig and cluster status${NC}" >&2
        exit 1
    fi

    # Run Helm command in container
    run_helm_container "$@"
}

# Execute main function with all arguments
main "$@"