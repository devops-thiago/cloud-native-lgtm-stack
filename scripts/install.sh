#!/bin/bash

# Cloud Native LTGM Stack Installation Script
# This script deploys Loki, Tempo, Grafana, and Minio on Kubernetes using Helm

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE=${NAMESPACE:-default}
RELEASE_PREFIX=${RELEASE_PREFIX:-ltgm}
HELM_TIMEOUT=${HELM_TIMEOUT:-10m}

echo -e "${GREEN}🚀 Starting Cloud Native LGTM Stack Installation${NC}"
echo "Namespace: $NAMESPACE"
echo "Release Prefix: $RELEASE_PREFIX"
echo "Helm Timeout: $HELM_TIMEOUT"
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
    echo -e "${RED}❌ Neither Helm nor Docker is available${NC}"
    echo -e "${YELLOW}💡 Please install either:${NC}"
    echo -e "${BLUE}  Option 1: Install Helm locally${NC}"
    echo -e "${BLUE}  Option 2: Install Docker (for containerized Helm)${NC}"
    exit 1
fi

# Show Helm configuration
show_helm_info

# Prepare containerized Helm if needed
if ! prepare_containerized_helm; then
    exit 1
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

# Add Helm repositories
echo -e "${YELLOW}📦 Adding Helm repositories...${NC}"
helm_repo_add grafana https://grafana.github.io/helm-charts
helm_repo_add minio https://charts.min.io/
helm_repo_add prometheus-community https://prometheus-community.github.io/helm-charts
helm_repo_update

echo -e "${GREEN}✅ Helm repositories configured${NC}"
echo ""

# Create namespace if it doesn't exist
echo -e "${YELLOW}🏗️  Creating namespace if needed...${NC}"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✅ Namespace $NAMESPACE ready${NC}"
echo ""

# Deploy Minio first (storage backend)
echo -e "${YELLOW}🪣 Deploying Minio...${NC}"
helm_install_upgrade "${RELEASE_PREFIX}-minio" "minio/minio" "$NAMESPACE" \
    --values ../values/minio-values.yaml \
    --wait --timeout=$HELM_TIMEOUT

echo -e "${GREEN}✅ Minio deployed successfully${NC}"
echo ""

# Wait for Minio to be ready
echo -e "${YELLOW}⏳ Waiting for Minio to be ready...${NC}"
kubectl wait --for=condition=ready pod -l release=${RELEASE_PREFIX}-minio -n $NAMESPACE --timeout=300s

echo -e "${GREEN}✅ Minio is ready${NC}"
echo ""

# Deploy Loki
echo -e "${YELLOW}📊 Deploying Loki...${NC}"
helm_install_upgrade "${RELEASE_PREFIX}-loki" "grafana/loki-distributed" "$NAMESPACE" \
    --values ../values/loki-distributed-values.yaml \
    --wait --timeout=$HELM_TIMEOUT

echo -e "${GREEN}✅ Loki deployed successfully${NC}"
echo ""

# Deploy Tempo
echo -e "${YELLOW}🔍 Deploying Tempo...${NC}"
helm_install_upgrade "${RELEASE_PREFIX}-tempo" "grafana/tempo-distributed" "$NAMESPACE" \
    --values ../values/tempo-distributed-values.yaml \
    --wait --timeout=$HELM_TIMEOUT

echo -e "${GREEN}✅ Tempo deployed successfully${NC}"
echo ""

# Deploy Mimir
echo -e "${YELLOW}📊 Deploying Mimir...${NC}"
helm_install_upgrade "${RELEASE_PREFIX}-mimir" "grafana/mimir-distributed" "$NAMESPACE" \
    --values ../values/mimir-distributed-values.yaml \
    --wait --timeout=$HELM_TIMEOUT

echo -e "${GREEN}✅ Mimir deployed successfully${NC}"
echo ""

# Deploy Grafana
echo -e "${YELLOW}📈 Deploying Grafana...${NC}"
helm_install_upgrade "${RELEASE_PREFIX}-grafana" "grafana/grafana" "$NAMESPACE" \
    --values ../values/grafana-values.yaml \
    --wait --timeout=$HELM_TIMEOUT

echo -e "${GREEN}✅ Grafana deployed successfully${NC}"
echo ""

# Deploy custom Grafana dashboards
echo -e "${YELLOW}📊 Deploying custom Grafana dashboards...${NC}"
if kubectl apply -f ../values/kubernetes-dashboards-configmap.yaml -n $NAMESPACE; then
    echo -e "${GREEN}✅ Custom dashboards ConfigMap deployed successfully${NC}"
else
    echo -e "${RED}❌ Failed to deploy custom dashboards ConfigMap${NC}"
    exit 1
fi

# Wait a moment for the sidecar to pick up the dashboards
echo -e "${YELLOW}⏳ Waiting for dashboard sidecar to process dashboards...${NC}"
sleep 10

echo -e "${GREEN}✅ Custom dashboards configured successfully${NC}"
echo ""

# Deploy Alloy (Grafana Agent)
echo -e "${YELLOW}🤖 Deploying Alloy (Grafana Agent)...${NC}"
helm_install_upgrade "${RELEASE_PREFIX}-alloy" "grafana/alloy" "$NAMESPACE" \
    --values ../values/alloy-values.yaml \
    --wait --timeout=$HELM_TIMEOUT

echo -e "${GREEN}✅ Alloy deployed successfully${NC}"
echo ""

# Deploy Kube-state-metrics
echo -e "${YELLOW}📊 Deploying kube-state-metrics...${NC}"
helm_install_upgrade "${RELEASE_PREFIX}-kube-state-metrics" "prometheus-community/kube-state-metrics" "$NAMESPACE" \
    --values ../values/kube-state-metrics-values.yaml \
    --wait --timeout=$HELM_TIMEOUT

echo -e "${GREEN}✅ Kube-state-metrics deployed successfully${NC}"
echo ""

# Deploy Node Exporter with environment detection
echo -e "${YELLOW}📊 Deploying node-exporter...${NC}"

# Detect if running on Docker Desktop (mount propagation issues)
if kubectl get nodes -o jsonpath='{.items[0].metadata.name}' | grep -q docker-desktop; then
    echo -e "${YELLOW}🐳 Docker Desktop detected - using custom DaemonSet (mount propagation compatibility)${NC}"
    kubectl apply -f ../values/node-exporter-docker-desktop-daemonset.yaml
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=node-exporter -n $NAMESPACE --timeout=120s
else
    echo -e "${YELLOW}⚙️  Standard Kubernetes detected - using Helm chart${NC}"
    helm_install_upgrade "${RELEASE_PREFIX}-node-exporter" "prometheus-community/prometheus-node-exporter" "$NAMESPACE" \
        --values ../values/node-exporter-values.yaml \
        --wait --timeout=$HELM_TIMEOUT
fi

echo -e "${GREEN}✅ Node-exporter deployed successfully${NC}"
echo ""

# Display access information
echo -e "${GREEN}🎉 LGTM Stack deployed successfully!${NC}"
echo ""
echo -e "${YELLOW}📋 Access Information:${NC}"
echo ""

# Get Grafana NodePort
GRAFANA_NODEPORT=$(kubectl get svc ${RELEASE_PREFIX}-grafana -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
echo -e "${GREEN}Grafana:${NC}"
echo "  URL: http://localhost:$GRAFANA_NODEPORT (if using port-forward)"
echo "  Username: admin"
echo "  Password: admin123"
echo ""

# Get Minio Console NodePort
MINIO_CONSOLE_NODEPORT=$(kubectl get svc ${RELEASE_PREFIX}-minio-console -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
echo -e "${GREEN}Minio Console:${NC}"
if [ "$MINIO_CONSOLE_NODEPORT" != "N/A" ]; then
    echo "  URL: http://localhost:$MINIO_CONSOLE_NODEPORT (if using port-forward)"
else
    echo "  Use port-forward: kubectl port-forward svc/${RELEASE_PREFIX}-minio-console 9001:9001 -n $NAMESPACE"
fi
echo "  Username: admin"
echo "  Password: password123"
echo ""

echo -e "${YELLOW}🛠️  Useful Commands:${NC}"
echo "  # Port-forward Grafana (if NodePort doesn't work)"
echo "  kubectl port-forward svc/${RELEASE_PREFIX}-grafana 3000:80 -n $NAMESPACE"
echo ""
echo "  # Port-forward Minio Console"
echo "  kubectl port-forward svc/${RELEASE_PREFIX}-minio-console 9001:9001 -n $NAMESPACE"
echo ""
echo "  # Check pod status"
echo "  kubectl get pods -n $NAMESPACE"
echo ""
echo "  # View logs"
echo "  kubectl logs -l app.kubernetes.io/name=loki -n $NAMESPACE"
echo "  kubectl logs -l app.kubernetes.io/name=tempo -n $NAMESPACE"
echo "  kubectl logs -l app.kubernetes.io/name=mimir -n $NAMESPACE"
echo "  kubectl logs -l app.kubernetes.io/name=alloy -n $NAMESPACE"
echo "  kubectl logs -l app.kubernetes.io/name=grafana -n $NAMESPACE"
echo ""

echo -e "${GREEN}✅ Installation completed successfully!${NC}"