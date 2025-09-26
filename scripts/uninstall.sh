#!/bin/bash

# Cloud Native LTGM Stack Uninstallation Script
# This script removes Loki, Tempo, Grafana, and Minio from Kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE=${NAMESPACE:-default}
RELEASE_PREFIX=${RELEASE_PREFIX:-ltgm}

echo -e "${YELLOW}🗑️  Starting Cloud Native LGTM Stack Uninstallation${NC}"
echo "Namespace: $NAMESPACE"
echo "Release Prefix: $RELEASE_PREFIX"
echo ""

# Import Helm utilities
source "$(dirname "${BASH_SOURCE[0]}")/helm-utils.sh"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"

# Detect and configure Helm (local or containerized)
if ! detect_helm; then
    echo -e "${YELLOW}⚠️  Neither Helm nor Docker available, will skip Helm releases${NC}"
else
    show_helm_info
    prepare_containerized_helm || true  # Don't fail uninstall if this fails
fi

if ! command_exists kubectl; then
    echo -e "${RED}❌ kubectl is not installed. Please install kubectl first.${NC}"
    exit 1
fi

# Check if kubectl can connect to cluster
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster. Please check your kubeconfig.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"
echo ""

# Function to uninstall helm release (using utilities)
uninstall_release() {
    local release_name=$1
    local component_name=$2

    if [ "$HELM_MODE" != "none" ]; then
        echo -e "${YELLOW}🗑️  Uninstalling $component_name...${NC}"
        helm_uninstall "$release_name" "$NAMESPACE"
    else
        echo -e "${YELLOW}⚠️  Helm not available, skipping $component_name uninstall${NC}"
    fi
    echo ""
}

# Uninstall components in reverse order
uninstall_release "${RELEASE_PREFIX}-alloy" "Alloy"
uninstall_release "${RELEASE_PREFIX}-grafana" "Grafana"
uninstall_release "${RELEASE_PREFIX}-mimir" "Mimir"
uninstall_release "${RELEASE_PREFIX}-tempo" "Tempo"
uninstall_release "${RELEASE_PREFIX}-loki" "Loki"
uninstall_release "${RELEASE_PREFIX}-kube-state-metrics" "Kube-state-metrics"
uninstall_release "${RELEASE_PREFIX}-node-exporter" "Node Exporter (Helm)"
uninstall_release "${RELEASE_PREFIX}-minio" "Minio"

# Clean up custom node-exporter DaemonSet if it exists (Docker Desktop)
echo -e "${YELLOW}🧹 Cleaning up custom node-exporter DaemonSet...${NC}"
kubectl delete -f ../values/node-exporter-docker-desktop-daemonset.yaml --ignore-not-found=true
echo -e "${GREEN}✅ Custom node-exporter cleaned up${NC}"
echo ""

# Clean up custom dashboard ConfigMaps
echo -e "${YELLOW}🧹 Cleaning up custom dashboard ConfigMaps...${NC}"
kubectl delete configmap grafana-custom-dashboards -n "$NAMESPACE" --ignore-not-found=true
echo -e "${GREEN}✅ Custom dashboard ConfigMaps cleaned up${NC}"
echo ""

# Clean up PVCs if they exist
echo -e "${YELLOW}🧹 Cleaning up Persistent Volume Claims...${NC}"

PVCs=$(kubectl get pvc -n "$NAMESPACE" | grep -E "(${RELEASE_PREFIX}|loki|tempo|mimir|grafana|minio|alloy)" | awk '{print $1}' | grep -v NAME || echo "")

if [ -n "$PVCs" ]; then
    echo "Found PVCs to clean up:"
    echo "$PVCs"
    echo ""
    read -p "Do you want to delete these PVCs? This will permanently delete all data! [y/N]: " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "$PVCs" | while read -r pvc; do
            if [ -n "$pvc" ]; then
                echo "Deleting PVC: $pvc"
                kubectl delete pvc "$pvc" -n "$NAMESPACE" --ignore-not-found=true || echo "  Warning: Could not delete PVC $pvc"
            fi
        done
        echo -e "${GREEN}✅ PVC deletion completed${NC}"
    else
        echo -e "${YELLOW}⚠️  PVCs left intact${NC}"
    fi
else
    echo "No PVCs found to clean up"
fi
echo ""

# Check for remaining resources
echo -e "${YELLOW}🔍 Checking for remaining resources...${NC}"

REMAINING_PODS=$(kubectl get pods -n "$NAMESPACE" | grep -cE "(${RELEASE_PREFIX}|loki|tempo|mimir|grafana|minio|alloy)" || echo "0")
REMAINING_SERVICES=$(kubectl get svc -n "$NAMESPACE" | grep -cE "(${RELEASE_PREFIX}|loki|tempo|mimir|grafana|minio|alloy)" || echo "0")
REMAINING_SECRETS=$(kubectl get secrets -n "$NAMESPACE" | grep -cE "(${RELEASE_PREFIX}|loki|tempo|mimir|grafana|minio|alloy)" || echo "0")

if [ "$REMAINING_PODS" -gt "0" ] || [ "$REMAINING_SERVICES" -gt "0" ] || [ "$REMAINING_SECRETS" -gt "0" ]; then
    echo -e "${YELLOW}⚠️  Some resources may still be terminating:${NC}"
    echo "  Pods: $REMAINING_PODS"
    echo "  Services: $REMAINING_SERVICES"
    echo "  Secrets: $REMAINING_SECRETS"
    echo ""
    echo "You can check the status with:"
    echo "  kubectl get all -n $NAMESPACE"
else
    echo -e "${GREEN}✅ No remaining LTGM resources found${NC}"
fi
echo ""

# Option to delete namespace
if [ "$NAMESPACE" != "default" ] && [ "$NAMESPACE" != "kube-system" ]; then
    read -p "Do you want to delete the namespace '$NAMESPACE'? [y/N]: " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete namespace "$NAMESPACE"
        echo -e "${GREEN}✅ Namespace '$NAMESPACE' deleted${NC}"
    else
        echo -e "${YELLOW}⚠️  Namespace '$NAMESPACE' left intact${NC}"
    fi
else
    echo -e "${YELLOW}ℹ️  Namespace '$NAMESPACE' is a system namespace and won't be deleted${NC}"
fi
echo ""

echo -e "${GREEN}🎉 LGTM Stack uninstallation completed!${NC}"
echo ""
echo -e "${YELLOW}📋 Cleanup Summary:${NC}"
echo "  ✅ Alloy uninstalled"
echo "  ✅ Grafana uninstalled"
echo "  ✅ Mimir uninstalled"
echo "  ✅ Tempo uninstalled"
echo "  ✅ Loki uninstalled"
echo "  ✅ Node Exporter uninstalled"
echo "  ✅ Kube-state-metrics uninstalled"
echo "  ✅ Minio uninstalled"
echo "  ✅ Custom dashboard ConfigMaps removed"
echo ""
echo -e "${YELLOW}🛠️  Manual cleanup (if needed):${NC}"
echo "  # Remove any remaining resources"
echo "  kubectl get all -n $NAMESPACE"
echo "  kubectl delete <resource-type> <resource-name> -n $NAMESPACE"
echo ""
echo "  # Remove storage classes (if custom ones were created)"
echo "  kubectl get storageclass"
echo ""

echo -e "${GREEN}✅ Uninstallation completed successfully!${NC}"