# Cloud Native LTGM Stack Installation Script
# This script deploys Loki, Tempo, Grafana, and Minio on Kubernetes using Helm

param(
    [string]$Namespace = $env:NAMESPACE ?? "default",
    [string]$ReleasePrefix = $env:RELEASE_PREFIX ?? "ltgm",
    [string]$HelmTimeout = $env:HELM_TIMEOUT ?? "10m"
)

# Import Helm utilities
$scriptPath = Join-Path $PSScriptRoot "helm-utils.ps1"
. $scriptPath

# Function to write colored output
function Write-ColorOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [ValidateSet("Red", "Green", "Yellow", "Blue", "White")]
        [string]$ForegroundColor = "White"
    )
    Write-Host $Message -ForegroundColor $ForegroundColor
}

# Function to check if command exists
function Test-Command {
    param([string]$Command)
    try {
        $null = Get-Command $Command -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

Write-ColorOutput "🚀 Starting Cloud Native LGTM Stack Installation" "Green"
Write-Host "Namespace: $Namespace"
Write-Host "Release Prefix: $ReleasePrefix"
Write-Host "Helm Timeout: $HelmTimeout"
Write-Host ""

# Check prerequisites
Write-ColorOutput "🔍 Checking prerequisites..." "Yellow"

# Detect and configure Helm (local or containerized)
if (-not (Detect-Helm)) {
    Write-ColorOutput "❌ Neither Helm nor Docker is available" "Red"
    Write-ColorOutput "💡 Please install either:" "Yellow"
    Write-ColorOutput "  Option 1: Install Helm locally" "Blue"
    Write-ColorOutput "  Option 2: Install Docker (for containerized Helm)" "Blue"
    exit 1
}

# Show Helm configuration
Show-HelmInfo

# Prepare containerized Helm if needed
if (-not (Initialize-ContainerizedHelm)) {
    exit 1
}

if (-not (Test-Command "kubectl")) {
    Write-ColorOutput "❌ kubectl is not installed. Please install kubectl first." "Red"
    exit 1
}

# Check if kubectl can connect to cluster
try {
    kubectl cluster-info 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Cannot connect to cluster"
    }
}
catch {
    Write-ColorOutput "❌ Cannot connect to Kubernetes cluster. Please check your kubeconfig." "Red"
    exit 1
}

Write-ColorOutput "✅ Prerequisites check passed" "Green"
Write-Host ""

# Add Helm repositories
Write-ColorOutput "📦 Adding Helm repositories..." "Yellow"
if (-not (Add-HelmRepo "grafana" "https://grafana.github.io/helm-charts")) { exit 1 }
if (-not (Add-HelmRepo "minio" "https://charts.min.io/")) { exit 1 }
if (-not (Add-HelmRepo "prometheus-community" "https://prometheus-community.github.io/helm-charts")) { exit 1 }
Update-HelmRepo

Write-ColorOutput "✅ Helm repositories configured" "Green"
Write-Host ""

# Create namespace if it doesn't exist
Write-ColorOutput "🏗️  Creating namespace if needed..." "Yellow"
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -
Write-ColorOutput "✅ Namespace $Namespace ready" "Green"
Write-Host ""

# Get project root for values files
$projectRoot = Split-Path $PSScriptRoot -Parent

# Deploy Minio first (storage backend)
Write-ColorOutput "🪣 Deploying Minio..." "Yellow"
$minioValuesPath = Join-Path $projectRoot "values/minio-values.yaml"
if (-not (Install-HelmRelease "${ReleasePrefix}-minio" "minio/minio" $Namespace "--values" $minioValuesPath "--wait" "--timeout=$HelmTimeout")) {
    exit 1
}

Write-ColorOutput "✅ Minio deployed successfully" "Green"
Write-Host ""

# Wait for Minio to be ready
Write-ColorOutput "⏳ Waiting for Minio to be ready..." "Yellow"
kubectl wait --for=condition=ready pod -l "release=${ReleasePrefix}-minio" -n $Namespace --timeout=300s

Write-ColorOutput "✅ Minio is ready" "Green"
Write-Host ""

# Deploy Loki
Write-ColorOutput "📊 Deploying Loki..." "Yellow"
$lokiValuesPath = Join-Path $projectRoot "values/loki-distributed-values.yaml"
if (-not (Install-HelmRelease "${ReleasePrefix}-loki" "grafana/loki-distributed" $Namespace "--values" $lokiValuesPath "--wait" "--timeout=$HelmTimeout")) {
    exit 1
}

Write-ColorOutput "✅ Loki deployed successfully" "Green"
Write-Host ""

# Deploy Tempo
Write-ColorOutput "🔍 Deploying Tempo..." "Yellow"
$tempoValuesPath = Join-Path $projectRoot "values/tempo-distributed-values.yaml"
if (-not (Install-HelmRelease "${ReleasePrefix}-tempo" "grafana/tempo-distributed" $Namespace "--values" $tempoValuesPath "--wait" "--timeout=$HelmTimeout")) {
    exit 1
}

Write-ColorOutput "✅ Tempo deployed successfully" "Green"
Write-Host ""

# Deploy Mimir
Write-ColorOutput "📊 Deploying Mimir..." "Yellow"
$mimirValuesPath = Join-Path $projectRoot "values/mimir-distributed-values.yaml"
if (-not (Install-HelmRelease "${ReleasePrefix}-mimir" "grafana/mimir-distributed" $Namespace "--values" $mimirValuesPath "--wait" "--timeout=$HelmTimeout")) {
    exit 1
}

Write-ColorOutput "✅ Mimir deployed successfully" "Green"
Write-Host ""

# Deploy Grafana
Write-ColorOutput "📈 Deploying Grafana..." "Yellow"
$grafanaValuesPath = Join-Path $projectRoot "values/grafana-values.yaml"
if (-not (Install-HelmRelease "${ReleasePrefix}-grafana" "grafana/grafana" $Namespace "--values" $grafanaValuesPath "--wait" "--timeout=$HelmTimeout")) {
    exit 1
}

Write-ColorOutput "✅ Grafana deployed successfully" "Green"
Write-Host ""

# Deploy custom Grafana dashboards
Write-ColorOutput "📊 Deploying custom Grafana dashboards..." "Yellow"
$dashboardsConfigPath = Join-Path $projectRoot "values/kubernetes-dashboards-configmap.yaml"

try {
    kubectl apply -f $dashboardsConfigPath -n $Namespace
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ Custom dashboards ConfigMap deployed successfully" "Green"
    }
    else {
        Write-ColorOutput "❌ Failed to deploy custom dashboards ConfigMap" "Red"
        exit 1
    }
}
catch {
    Write-ColorOutput "❌ Failed to deploy custom dashboards ConfigMap" "Red"
    exit 1
}

# Wait a moment for the sidecar to pick up the dashboards
Write-ColorOutput "⏳ Waiting for dashboard sidecar to process dashboards..." "Yellow"
Start-Sleep -Seconds 10

Write-ColorOutput "✅ Custom dashboards configured successfully" "Green"
Write-Host ""

# Deploy Alloy (Grafana Agent)
Write-ColorOutput "🤖 Deploying Alloy (Grafana Agent)..." "Yellow"
$alloyValuesPath = Join-Path $projectRoot "values/alloy-values.yaml"
if (-not (Install-HelmRelease "${ReleasePrefix}-alloy" "grafana/alloy" $Namespace "--values" $alloyValuesPath "--wait" "--timeout=$HelmTimeout")) {
    exit 1
}

Write-ColorOutput "✅ Alloy deployed successfully" "Green"
Write-Host ""

# Deploy Kube-state-metrics
Write-ColorOutput "📊 Deploying kube-state-metrics..." "Yellow"
$kubeStateMetricsValuesPath = Join-Path $projectRoot "values/kube-state-metrics-values.yaml"
if (-not (Install-HelmRelease "${ReleasePrefix}-kube-state-metrics" "prometheus-community/kube-state-metrics" $Namespace "--values" $kubeStateMetricsValuesPath "--wait" "--timeout=$HelmTimeout")) {
    exit 1
}

Write-ColorOutput "✅ Kube-state-metrics deployed successfully" "Green"
Write-Host ""

# Deploy Node Exporter with environment detection
Write-ColorOutput "📊 Deploying node-exporter..." "Yellow"

# Detect if running on Docker Desktop (mount propagation issues)
$nodeName = kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>$null
if ($nodeName -match "docker-desktop") {
    Write-ColorOutput "🐳 Docker Desktop detected - using custom DaemonSet (mount propagation compatibility)" "Yellow"
    $nodeExporterDaemonSetPath = Join-Path $projectRoot "values/node-exporter-docker-desktop-daemonset.yaml"
    kubectl apply -f $nodeExporterDaemonSetPath
    kubectl wait --for=condition=ready pod -l "app.kubernetes.io/name=node-exporter" -n $Namespace --timeout=120s
}
else {
    Write-ColorOutput "⚙️  Standard Kubernetes detected - using Helm chart" "Yellow"
    $nodeExporterValuesPath = Join-Path $projectRoot "values/node-exporter-values.yaml"
    if (-not (Install-HelmRelease "${ReleasePrefix}-node-exporter" "prometheus-community/prometheus-node-exporter" $Namespace "--values" $nodeExporterValuesPath "--wait" "--timeout=$HelmTimeout")) {
        exit 1
    }
}

Write-ColorOutput "✅ Node-exporter deployed successfully" "Green"
Write-Host ""

# Display access information
Write-ColorOutput "🎉 LGTM Stack deployed successfully!" "Green"
Write-Host ""
Write-ColorOutput "📋 Access Information:" "Yellow"
Write-Host ""

# Get Grafana NodePort
try {
    $grafanaNodePort = kubectl get svc "${ReleasePrefix}-grafana" -n $Namespace -o jsonpath='{.spec.ports[0].nodePort}' 2>$null
    Write-ColorOutput "Grafana:" "Green"
    Write-Host "  URL: http://localhost:$grafanaNodePort (if using port-forward)"
    Write-Host "  Username: admin"
    Write-Host "  Password: admin123"
    Write-Host ""
}
catch {
    Write-ColorOutput "⚠️  Could not retrieve Grafana NodePort" "Yellow"
}

# Get Minio Console NodePort
try {
    $minioConsoleNodePort = kubectl get svc "${ReleasePrefix}-minio-console" -n $Namespace -o jsonpath='{.spec.ports[0].nodePort}' 2>$null
    Write-ColorOutput "Minio Console:" "Green"
    if ($minioConsoleNodePort -and $minioConsoleNodePort -ne "") {
        Write-Host "  URL: http://localhost:$minioConsoleNodePort (if using port-forward)"
    }
    else {
        Write-Host "  Use port-forward: kubectl port-forward svc/${ReleasePrefix}-minio-console 9001:9001 -n $Namespace"
    }
    Write-Host "  Username: admin"
    Write-Host "  Password: password123"
    Write-Host ""
}
catch {
    Write-ColorOutput "⚠️  Could not retrieve Minio Console NodePort" "Yellow"
}

Write-ColorOutput "🛠️  Useful Commands:" "Yellow"
Write-Host "  # Port-forward Grafana (if NodePort doesn't work)"
Write-Host "  kubectl port-forward svc/${ReleasePrefix}-grafana 3000:80 -n $Namespace"
Write-Host ""
Write-Host "  # Port-forward Minio Console"
Write-Host "  kubectl port-forward svc/${ReleasePrefix}-minio-console 9001:9001 -n $Namespace"
Write-Host ""
Write-Host "  # Check pod status"
Write-Host "  kubectl get pods -n $Namespace"
Write-Host ""
Write-Host "  # View logs"
Write-Host "  kubectl logs -l app.kubernetes.io/name=loki -n $Namespace"
Write-Host "  kubectl logs -l app.kubernetes.io/name=tempo -n $Namespace"
Write-Host "  kubectl logs -l app.kubernetes.io/name=mimir -n $Namespace"
Write-Host "  kubectl logs -l app.kubernetes.io/name=alloy -n $Namespace"
Write-Host "  kubectl logs -l app.kubernetes.io/name=grafana -n $Namespace"
Write-Host ""

Write-ColorOutput "✅ Installation completed successfully!" "Green"