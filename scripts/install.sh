#!/bin/bash

# Cloud Native LTGM Stack Installation Script

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

while [[ $# -gt 0 ]]; do
  case $1 in
    --kubeconfig)
      export KUBECONFIG="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --release-prefix)
      RELEASE_PREFIX="$2"
      shift 2
      ;;
    --helm-timeout)
      HELM_TIMEOUT="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --kubeconfig PATH      Path to kubeconfig file"
      echo "  --namespace NAMESPACE  Target namespace (default: default)"
      echo "  --release-prefix PREFIX Helm release prefix (default: ltgm)"
      echo "  --helm-timeout TIMEOUT Helm timeout (default: 10m)"
      echo "  --dry-run              Run in dry-run mode"
      echo "  --help                 Show this help"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

NAMESPACE=${NAMESPACE:-default}
RELEASE_PREFIX=${RELEASE_PREFIX:-ltgm}
HELM_TIMEOUT=${HELM_TIMEOUT:-10m}
DRY_RUN=${DRY_RUN:-false}

if [ "$DRY_RUN" = "true" ]; then
    echo -e "${GREEN}🚀 Starting Cloud Native LGTM Stack Installation (DRY-RUN MODE)${NC}"
    echo -e "${YELLOW}⚠️  This is a dry-run - validating with server but making no changes${NC}"
else
    echo -e "${GREEN}🚀 Starting Cloud Native LGTM Stack Installation${NC}"
fi
echo "Namespace: $NAMESPACE"
echo "Release Prefix: $RELEASE_PREFIX"
echo "Helm Timeout: $HELM_TIMEOUT"
echo "Dry Run: $DRY_RUN"
echo ""

source "$(dirname "${BASH_SOURCE[0]}")/helm-utils.sh"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}
echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"
if ! detect_helm; then
    echo -e "${RED}❌ Neither Helm nor Docker is available${NC}"
    echo -e "${YELLOW}💡 Please install either:${NC}"
    echo -e "${BLUE}  Option 1: Install Helm locally${NC}"
    echo -e "${BLUE}  Option 2: Install Docker (for containerized Helm)${NC}"
    exit 1
fi

show_helm_info
if ! prepare_containerized_helm; then
    exit 1
fi

if ! command_exists kubectl; then
    echo -e "${RED}❌ kubectl is not installed. Please install kubectl first.${NC}"
    exit 1
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster. Please check your kubeconfig.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"
echo ""

echo -e "${YELLOW}📦 Adding Helm repositories...${NC}"
helm_repo_add grafana https://grafana.github.io/helm-charts
helm_repo_add minio https://charts.min.io/
helm_repo_add prometheus-community https://prometheus-community.github.io/helm-charts
helm_repo_update

echo -e "${GREEN}✅ Helm repositories configured${NC}"
echo ""

echo -e "${YELLOW}🏗️  Creating namespace if needed...${NC}"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✅ Namespace $NAMESPACE ready${NC}"
echo ""

echo -e "${YELLOW}🪣 Deploying Minio...${NC}"
helm_install_upgrade "${RELEASE_PREFIX}-minio" "minio/minio" "$NAMESPACE" \
    --values ../values/minio-values.yaml \
    --wait --timeout="$HELM_TIMEOUT"

echo -e "${GREEN}✅ Minio deployed successfully${NC}"
echo ""

echo -e "${YELLOW}📊 Deploying Loki...${NC}"
helm_install_upgrade "${RELEASE_PREFIX}-loki" "grafana/loki-distributed" "$NAMESPACE" \
    --values ../values/loki-distributed-values.yaml \
    --wait --timeout="$HELM_TIMEOUT"

echo -e "${GREEN}✅ Loki deployed successfully${NC}"
echo ""

echo -e "${YELLOW}🔍 Deploying Tempo...${NC}"
helm_install_upgrade "${RELEASE_PREFIX}-tempo" "grafana/tempo-distributed" "$NAMESPACE" \
    --values ../values/tempo-distributed-values.yaml \
    --wait --timeout="$HELM_TIMEOUT"

echo -e "${GREEN}✅ Tempo deployed successfully${NC}"
echo ""

echo -e "${YELLOW}📊 Deploying Mimir...${NC}"
helm_install_upgrade "${RELEASE_PREFIX}-mimir" "grafana/mimir-distributed" "$NAMESPACE" \
    --values ../values/mimir-distributed-values.yaml \
    --wait --timeout="$HELM_TIMEOUT"

echo -e "${GREEN}✅ Mimir deployed successfully${NC}"
echo ""

echo -e "${YELLOW}📈 Deploying Grafana...${NC}"
helm_install_upgrade "${RELEASE_PREFIX}-grafana" "grafana/grafana" "$NAMESPACE" \
    --values ../values/grafana-values.yaml \
    --wait --timeout="$HELM_TIMEOUT"

echo -e "${GREEN}✅ Grafana deployed successfully${NC}"
echo ""

echo -e "${YELLOW}📊 Deploying custom Grafana dashboards...${NC}"
if [ "$DRY_RUN" = "true" ]; then
    echo -e "${BLUE}🔍 Dry-run: Validating dashboard ConfigMap...${NC}"
    if kubectl apply -f ../values/kubernetes-dashboards-configmap.yaml -n "$NAMESPACE" --dry-run=server; then
        echo -e "${GREEN}✅ Dashboard ConfigMap validation successful${NC}"
    else
        echo -e "${RED}❌ Dashboard ConfigMap validation failed${NC}"
        exit 1
    fi
else
    if kubectl apply -f ../values/kubernetes-dashboards-configmap.yaml -n "$NAMESPACE"; then
        echo -e "${GREEN}✅ Custom dashboards ConfigMap deployed successfully${NC}"
    else
        echo -e "${RED}❌ Failed to deploy custom dashboards ConfigMap${NC}"
        exit 1
    fi

    echo -e "${YELLOW}⏳ Waiting for dashboard sidecar to process dashboards...${NC}"
    sleep 10

    echo -e "${GREEN}✅ Custom dashboards configured successfully${NC}"
fi
echo ""

echo -e "${YELLOW}🤖 Deploying Alloy (Grafana Agent)...${NC}"
helm_install_upgrade "${RELEASE_PREFIX}-alloy" "grafana/alloy" "$NAMESPACE" \
    --values ../values/alloy-values.yaml \
    --wait --timeout="$HELM_TIMEOUT"

echo -e "${GREEN}✅ Alloy deployed successfully${NC}"
echo ""

echo -e "${YELLOW}📊 Deploying kube-state-metrics...${NC}"
helm_install_upgrade "${RELEASE_PREFIX}-kube-state-metrics" "prometheus-community/kube-state-metrics" "$NAMESPACE" \
    --values ../values/kube-state-metrics-values.yaml \
    --wait --timeout="$HELM_TIMEOUT"

echo -e "${GREEN}✅ Kube-state-metrics deployed successfully${NC}"
echo ""

echo -e "${YELLOW}📊 Deploying node-exporter...${NC}"
if kubectl get nodes -o jsonpath='{.items[0].metadata.name}' | grep -q docker-desktop; then
    echo -e "${YELLOW}🐳 Docker Desktop detected - using custom DaemonSet (mount propagation compatibility)${NC}"
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${BLUE}🔍 Dry-run: Validating node-exporter DaemonSet...${NC}"
        if kubectl apply -f ../values/node-exporter-docker-desktop-daemonset.yaml --dry-run=server; then
            echo -e "${GREEN}✅ Node-exporter DaemonSet validation successful${NC}"
        else
            echo -e "${RED}❌ Node-exporter DaemonSet validation failed${NC}"
            exit 1
        fi
    else
        kubectl apply -f ../values/node-exporter-docker-desktop-daemonset.yaml
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=node-exporter -n "$NAMESPACE" --timeout=120s
    fi
else
    echo -e "${YELLOW}⚙️  Standard Kubernetes detected - using Helm chart${NC}"
    helm_install_upgrade "${RELEASE_PREFIX}-node-exporter" "prometheus-community/prometheus-node-exporter" "$NAMESPACE" \
        --values ../values/node-exporter-values.yaml \
        --wait --timeout="$HELM_TIMEOUT"
fi

echo -e "${GREEN}✅ Node-exporter deployed successfully${NC}"
echo ""

# Display access information
echo -e "${GREEN}🎉 LGTM Stack deployed successfully!${NC}"
echo ""
echo -e "${YELLOW}📋 Access Information:${NC}"
echo ""

# Get Grafana NodePort
GRAFANA_NODEPORT=$(kubectl get svc "${RELEASE_PREFIX}-grafana" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
echo -e "${GREEN}Grafana:${NC}"
echo "  URL: http://localhost:$GRAFANA_NODEPORT (if using port-forward)"
echo "  Username: admin"
echo "  Password: admin123"
echo ""

# Get Minio Console NodePort
MINIO_CONSOLE_NODEPORT=$(kubectl get svc "${RELEASE_PREFIX}-minio-console" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
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