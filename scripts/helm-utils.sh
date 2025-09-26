#!/bin/bash

# Helm Utilities - Detect and use Helm (local or containerized)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

HELM_MODE=""

detect_helm() {
    if command -v helm >/dev/null 2>&1; then
        HELM_MODE="local"
        echo -e "${GREEN}✅ Helm found locally: $(helm version --short)${NC}"
        return 0
    elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        HELM_MODE="container"
        echo -e "${YELLOW}⚠️  Helm not found locally, using containerized Helm${NC}"
        echo -e "${BLUE}🐳 Docker detected, will use containerized Helm${NC}"
        return 0
    else
        HELM_MODE="none"
        echo -e "${RED}❌ Neither Helm nor Docker found${NC}" >&2
        echo -e "${YELLOW}💡 Please install either Helm or Docker to continue${NC}" >&2
        return 1
    fi
}

run_helm() {
    case "$HELM_MODE" in
        "local")
            echo -e "${BLUE}🔧 Running local Helm: $*${NC}" >&2
            if [ -n "$KUBECONFIG" ]; then
                KUBECONFIG="$KUBECONFIG" helm "$@"
            else
                helm "$@"
            fi
            ;;
        "container")
            echo -e "${BLUE}🐳 Running containerized Helm: $*${NC}" >&2
            if [ -n "$KUBECONFIG" ]; then
                KUBECONFIG="$KUBECONFIG" "$(dirname "${BASH_SOURCE[0]}")/helm-container.sh" "$@"
            else
                "$(dirname "${BASH_SOURCE[0]}")/helm-container.sh" "$@"
            fi
            ;;
        *)
            echo -e "${RED}❌ Helm mode not detected. Run detect_helm() first.${NC}" >&2
            return 1
            ;;
    esac
}

helm_repo_add() {
    local repo_name="$1"
    local repo_url="$2"
    local max_retries=3
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        if run_helm repo add "$repo_name" "$repo_url"; then
            echo -e "${GREEN}✅ Added Helm repository: $repo_name${NC}"
            return 0
        else
            retry_count=$((retry_count + 1))
            echo -e "${YELLOW}⚠️  Retry $retry_count/$max_retries for repository: $repo_name${NC}"
            sleep 2
        fi
    done

    echo -e "${RED}❌ Failed to add repository after $max_retries attempts: $repo_name${NC}" >&2
    return 1
}

helm_repo_update() {
    echo -e "${YELLOW}📦 Updating Helm repositories...${NC}"
    if run_helm repo update; then
        echo -e "${GREEN}✅ Helm repositories updated${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Failed to update repositories, continuing anyway...${NC}" >&2
        return 0
    fi
}

helm_install_upgrade() {
    local release_name="$1"
    local chart="$2"
    local namespace="$3"
    shift 3
    local additional_args=("$@")

    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${BLUE}🔍 Dry-run: Validating Helm release: $release_name${NC}"

        if run_helm upgrade --install "$release_name" "$chart" \
            --namespace "$namespace" \
            --dry-run=server --debug \
            "${additional_args[@]}"; then
            echo -e "${GREEN}✅ Dry-run validation successful: $release_name${NC}"
            return 0
        else
            echo -e "${RED}❌ Dry-run validation failed: $release_name${NC}" >&2
            return 1
        fi
    else
        echo -e "${BLUE}🚀 Installing/upgrading Helm release: $release_name${NC}"

        if run_helm upgrade --install "$release_name" "$chart" \
            --namespace "$namespace" \
            "${additional_args[@]}"; then
            echo -e "${GREEN}✅ Successfully deployed: $release_name${NC}"
            return 0
        else
            echo -e "${RED}❌ Failed to deploy: $release_name${NC}" >&2
            return 1
        fi
    fi
}

helm_uninstall() {
    local release_name="$1"
    local namespace="$2"

    if run_helm status "$release_name" -n "$namespace" >/dev/null 2>&1; then
        echo -e "${YELLOW}🗑️  Uninstalling Helm release: $release_name${NC}"
        if run_helm uninstall "$release_name" -n "$namespace"; then
            echo -e "${GREEN}✅ Successfully uninstalled: $release_name${NC}"
            return 0
        else
            echo -e "${RED}❌ Failed to uninstall: $release_name${NC}" >&2
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  Helm release not found, skipping: $release_name${NC}"
        return 0
    fi
}

prepare_containerized_helm() {
    if [ "$HELM_MODE" = "container" ]; then
        echo -e "${YELLOW}📦 Preparing containerized Helm environment...${NC}"
        if "$(dirname "${BASH_SOURCE[0]}")/helm-container.sh" --pull-images; then
            echo -e "${GREEN}✅ Containerized Helm ready${NC}"
            return 0
        else
            echo -e "${RED}❌ Failed to prepare containerized Helm${NC}" >&2
            return 1
        fi
    fi
}

show_helm_info() {
    echo -e "${BLUE}🔍 Helm Configuration:${NC}"
    case "$HELM_MODE" in
        "local")
            echo -e "${GREEN}  Mode: Local Helm installation${NC}"
            run_helm version --short
            ;;
        "container")
            echo -e "${BLUE}  Mode: Containerized Helm${NC}"
            echo -e "${BLUE}  Image: alpine/helm:3.13.2${NC}"
            echo -e "${YELLOW}  Note: Requires Docker to be running${NC}"
            ;;
        *)
            echo -e "${RED}  Mode: Not detected${NC}"
            ;;
    esac
    echo ""
}