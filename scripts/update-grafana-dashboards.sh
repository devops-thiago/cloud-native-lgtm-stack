#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}🔄 Updating Grafana with custom Kubernetes dashboards${NC}"

# Deploy the custom dashboards ConfigMap
echo -e "${YELLOW}📊 Deploying custom dashboards ConfigMap...${NC}"
if kubectl apply -f "${PROJECT_ROOT}/values/kubernetes-dashboards-configmap.yaml"; then
    echo -e "${GREEN}✅ Custom dashboards ConfigMap deployed successfully${NC}"
else
    echo -e "${RED}❌ Failed to deploy custom dashboards ConfigMap${NC}"
    exit 1
fi

# Upgrade Grafana with updated values
echo -e "${YELLOW}🔄 Upgrading Grafana deployment...${NC}"
if helm upgrade --install ltgm-grafana grafana/grafana \
    -f "${PROJECT_ROOT}/values/grafana-values.yaml" \
    --namespace default \
    --wait; then
    echo -e "${GREEN}✅ Grafana upgraded successfully${NC}"
else
    echo -e "${RED}❌ Failed to upgrade Grafana${NC}"
    exit 1
fi

# Wait for Grafana to be ready
echo -e "${YELLOW}⏳ Waiting for Grafana pod to be ready...${NC}"
if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana --timeout=120s; then
    echo -e "${GREEN}✅ Grafana pod is ready${NC}"
else
    echo -e "${RED}❌ Grafana pod failed to become ready${NC}"
    exit 1
fi

# Check dashboard sidecar logs
echo -e "${YELLOW}📋 Checking dashboard sidecar logs...${NC}"
kubectl logs -l app.kubernetes.io/name=grafana -c grafana-sc-dashboard --tail=5 | grep -E "(Writing|ERROR|WARNING)" || true

# Get Grafana access information
NODE_PORT=$(kubectl get --namespace default -o jsonpath="{.spec.ports[0].nodePort}" services ltgm-grafana)
NODE_IP=$(kubectl get nodes --namespace default -o jsonpath="{.items[0].status.addresses[0].address}")

echo -e "${GREEN}🎉 Grafana dashboards updated successfully!${NC}"
echo ""
echo -e "${YELLOW}📊 Custom Dashboards Deployed:${NC}"
echo "  • Kubernetes Cluster Overview - LGTM Stack"
echo "  • Kubernetes Pods Overview - LGTM Stack"
echo ""
echo -e "${YELLOW}🌐 Access Grafana at:${NC} http://$NODE_IP:$NODE_PORT"
echo -e "${YELLOW}🔑 Login credentials:${NC} admin / admin123"
echo ""
echo -e "${YELLOW}💡 The custom dashboards use corrected metric queries that work with:${NC}"
echo "  • kube-state-metrics (resource metrics with 'resource' labels)"
echo "  • node-exporter (node system metrics)" 
echo "  • cAdvisor (container metrics with 'pod', 'namespace', 'name' labels)"
echo ""
echo -e "${YELLOW}🔍 Find the new dashboards in the Grafana UI under:${NC}"
echo "  • Dashboards → Browse → Look for 'Kubernetes Cluster Overview - LGTM Stack'"
echo "  • Dashboards → Browse → Look for 'Kubernetes Pods Overview - LGTM Stack'"