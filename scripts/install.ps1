# Cloud Native LTGM Stack Installation Script
# This script deploys Loki, Tempo, Grafana, and Minio on Kubernetes using Helm

param(
    [string]$Namespace = $env:NAMESPACE ?? "default",
    [string]$ReleasePrefix = $env:RELEASE_PREFIX ?? "ltgm",
    [string]$HelmTimeout = $env:HELM_TIMEOUT ?? "10m",
    [switch]$DryRun
)

# Import Helm utilities
$scriptPath = Join-Path $PSScriptRoot "helm-utils.ps1"
. $scriptPath

# Pass dry-run flag to helm utilities via parameter

# Function to write colored output
function Write-ColorOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    # Use Write-Output for better compatibility
    Write-Output $Message
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

if ($DryRun) {
    Write-ColorOutput "🚀 Starting Cloud Native LGTM Stack Installation (DRY-RUN MODE)"
    Write-ColorOutput "⚠️  This is a dry-run - validating with server but making no changes"
}
else {
    Write-ColorOutput "🚀 Starting Cloud Native LGTM Stack Installation"
}
Write-Output "Namespace: $Namespace"
Write-Output "Release Prefix: $ReleasePrefix"
Write-Output "Helm Timeout: $HelmTimeout"
Write-Output "Dry Run: $DryRun"
Write-Output ""

# Check prerequisites
Write-ColorOutput "🔍 Checking prerequisites..."

# Detect and configure Helm (local or containerized)
if (-not (Test-Helm)) {
    Write-ColorOutput "❌ Neither Helm nor Docker is available"
    Write-ColorOutput "💡 Please install either:"
    Write-ColorOutput "  Option 1: Install Helm locally"
    Write-ColorOutput "  Option 2: Install Docker (for containerized Helm)"
    exit 1
}

# Show Helm configuration
Show-HelmInfo

# Prepare containerized Helm if needed
if (-not (Initialize-ContainerizedHelm)) {
    exit 1
}

if (-not (Test-Command "kubectl")) {
    Write-ColorOutput "❌ kubectl is not installed. Please install kubectl first."
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
    Write-ColorOutput "❌ Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
}

Write-ColorOutput "✅ Prerequisites check passed"
Write-Output ""

# Add Helm repositories
Write-ColorOutput "📦 Adding Helm repositories..."
if (-not (Add-HelmRepo "grafana" "https://grafana.github.io/helm-charts")) { exit 1 }
if (-not (Add-HelmRepo "minio" "https://charts.min.io/")) { exit 1 }
if (-not (Add-HelmRepo "prometheus-community" "https://prometheus-community.github.io/helm-charts")) { exit 1 }
Update-HelmRepo

Write-ColorOutput "✅ Helm repositories configured"
Write-Output ""

# Create namespace if it doesn't exist
Write-ColorOutput "🏗️  Creating namespace if needed..."
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -
Write-ColorOutput "✅ Namespace $Namespace ready"
Write-Output ""

# Get project root for values files
$projectRoot = Split-Path $PSScriptRoot -Parent

# Deploy Minio first (storage backend)
Write-ColorOutput "🪣 Deploying Minio..."
$minioValuesPath = Join-Path $projectRoot "values/minio-values.yaml"
if (-not (Install-HelmRelease "${ReleasePrefix}-minio" "minio/minio" $Namespace -DryRun $DryRun "--values" $minioValuesPath "--wait" "--timeout=$HelmTimeout")) {
    exit 1
}

Write-ColorOutput "✅ Minio deployed successfully"
Write-Output ""


# Deploy Loki
Write-ColorOutput "📊 Deploying Loki..."
$lokiValuesPath = Join-Path $projectRoot "values/loki-distributed-values.yaml"
if (-not (Install-HelmRelease "${ReleasePrefix}-loki" "grafana/loki-distributed" $Namespace -DryRun $DryRun "--values" $lokiValuesPath "--wait" "--timeout=$HelmTimeout")) {
    exit 1
}

Write-ColorOutput "✅ Loki deployed successfully"
Write-Output ""

# Deploy Tempo
Write-ColorOutput "🔍 Deploying Tempo..."
$tempoValuesPath = Join-Path $projectRoot "values/tempo-distributed-values.yaml"
if (-not (Install-HelmRelease "${ReleasePrefix}-tempo" "grafana/tempo-distributed" $Namespace -DryRun $DryRun "--values" $tempoValuesPath "--wait" "--timeout=$HelmTimeout")) {
    exit 1
}

Write-ColorOutput "✅ Tempo deployed successfully"
Write-Output ""

# Deploy Mimir
Write-ColorOutput "📊 Deploying Mimir..."
$mimirValuesPath = Join-Path $projectRoot "values/mimir-distributed-values.yaml"
if (-not (Install-HelmRelease "${ReleasePrefix}-mimir" "grafana/mimir-distributed" $Namespace -DryRun $DryRun "--values" $mimirValuesPath "--wait" "--timeout=$HelmTimeout")) {
    exit 1
}

Write-ColorOutput "✅ Mimir deployed successfully"
Write-Output ""

# Deploy Grafana
Write-ColorOutput "📈 Deploying Grafana..."
$grafanaValuesPath = Join-Path $projectRoot "values/grafana-values.yaml"
if (-not (Install-HelmRelease "${ReleasePrefix}-grafana" "grafana/grafana" $Namespace -DryRun $DryRun "--values" $grafanaValuesPath "--wait" "--timeout=$HelmTimeout")) {
    exit 1
}

Write-ColorOutput "✅ Grafana deployed successfully"
Write-Output ""

# Deploy custom Grafana dashboards
Write-ColorOutput "📊 Deploying custom Grafana dashboards..."
$dashboardsConfigPath = Join-Path $projectRoot "values/kubernetes-dashboards-configmap.yaml"

if ($DryRun) {
    Write-ColorOutput "🔍 Dry-run: Validating dashboard ConfigMap..."
    try {
        kubectl apply -f $dashboardsConfigPath -n $Namespace --dry-run=server
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Dashboard ConfigMap validation successful"
        }
        else {
            Write-ColorOutput "❌ Dashboard ConfigMap validation failed"
            exit 1
        }
    }
    catch {
        Write-ColorOutput "❌ Dashboard ConfigMap validation failed"
        exit 1
    }
}
else {
    try {
        kubectl apply -f $dashboardsConfigPath -n $Namespace
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Custom dashboards ConfigMap deployed successfully"
        }
        else {
            Write-ColorOutput "❌ Failed to deploy custom dashboards ConfigMap"
            exit 1
        }
    }
    catch {
        Write-ColorOutput "❌ Failed to deploy custom dashboards ConfigMap"
        exit 1
    }

    # Wait a moment for the sidecar to pick up the dashboards
    Write-ColorOutput "⏳ Waiting for dashboard sidecar to process dashboards..."
    Start-Sleep -Seconds 10

    Write-ColorOutput "✅ Custom dashboards configured successfully"
}
Write-Output ""

# Deploy Alloy (Grafana Agent)
Write-ColorOutput "🤖 Deploying Alloy (Grafana Agent)..."
$alloyValuesPath = Join-Path $projectRoot "values/alloy-values.yaml"
if (-not (Install-HelmRelease "${ReleasePrefix}-alloy" "grafana/alloy" $Namespace -DryRun $DryRun "--values" $alloyValuesPath "--wait" "--timeout=$HelmTimeout")) {
    exit 1
}

Write-ColorOutput "✅ Alloy deployed successfully"
Write-Output ""

# Deploy Kube-state-metrics
Write-ColorOutput "📊 Deploying kube-state-metrics..."
$kubeStateMetricsValuesPath = Join-Path $projectRoot "values/kube-state-metrics-values.yaml"
if (-not (Install-HelmRelease "${ReleasePrefix}-kube-state-metrics" "prometheus-community/kube-state-metrics" $Namespace -DryRun $DryRun "--values" $kubeStateMetricsValuesPath "--wait" "--timeout=$HelmTimeout")) {
    exit 1
}

Write-ColorOutput "✅ Kube-state-metrics deployed successfully"
Write-Output ""

# Deploy Node Exporter with environment detection
Write-ColorOutput "📊 Deploying node-exporter..."

# Detect if running on Docker Desktop (mount propagation issues)
$nodeName = kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>$null
if ($nodeName -match "docker-desktop") {
    Write-ColorOutput "🐳 Docker Desktop detected - using custom DaemonSet (mount propagation compatibility)"
    $nodeExporterDaemonSetPath = Join-Path $projectRoot "values/node-exporter-docker-desktop-daemonset.yaml"
    if ($DryRun) {
        Write-ColorOutput "🔍 Dry-run: Validating node-exporter DaemonSet..."
        try {
            kubectl apply -f $nodeExporterDaemonSetPath --dry-run=server
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "✅ Node-exporter DaemonSet validation successful"
            } else {
                Write-ColorOutput "❌ Node-exporter DaemonSet validation failed"
                exit 1
            }
        } catch {
            Write-ColorOutput "❌ Node-exporter DaemonSet validation failed"
            exit 1
        }
    } else {
        kubectl apply -f $nodeExporterDaemonSetPath
        kubectl wait --for=condition=ready pod -l "app.kubernetes.io/name=node-exporter" -n $Namespace --timeout=120s
    }
}
else {
    Write-ColorOutput "⚙️  Standard Kubernetes detected - using Helm chart"
    $nodeExporterValuesPath = Join-Path $projectRoot "values/node-exporter-values.yaml"
    if (-not (Install-HelmRelease "${ReleasePrefix}-node-exporter" "prometheus-community/prometheus-node-exporter" $Namespace -DryRun $DryRun "--values" $nodeExporterValuesPath "--wait" "--timeout=$HelmTimeout")) {
        exit 1
    }
}

Write-ColorOutput "✅ Node-exporter deployed successfully"
Write-Output ""

# Display access information
Write-ColorOutput "🎉 LGTM Stack deployed successfully!"
Write-Output ""
Write-ColorOutput "📋 Access Information:"
Write-Output ""

# Get Grafana NodePort
try {
    $grafanaNodePort = kubectl get svc "${ReleasePrefix}-grafana" -n $Namespace -o jsonpath='{.spec.ports[0].nodePort}' 2>$null
    Write-ColorOutput "Grafana:"
    Write-Output "  URL: http://localhost:$grafanaNodePort (if using port-forward)"
    Write-Output "  Username: admin"
    Write-Output "  Password: admin123"
    Write-Output ""
}
catch {
    Write-ColorOutput "⚠️  Could not retrieve Grafana NodePort"
}

# Get Minio Console NodePort
try {
    $minioConsoleNodePort = kubectl get svc "${ReleasePrefix}-minio-console" -n $Namespace -o jsonpath='{.spec.ports[0].nodePort}' 2>$null
    Write-ColorOutput "Minio Console:"
    if ($minioConsoleNodePort -and $minioConsoleNodePort -ne "") {
        Write-Output "  URL: http://localhost:$minioConsoleNodePort (if using port-forward)"
    }
    else {
        Write-Output "  Use port-forward: kubectl port-forward svc/${ReleasePrefix}-minio-console 9001:9001 -n $Namespace"
    }
    Write-Output "  Username: admin"
    Write-Output "  Password: password123"
    Write-Output ""
}
catch {
    Write-ColorOutput "⚠️  Could not retrieve Minio Console NodePort"
}

Write-ColorOutput "🛠️  Useful Commands:"
Write-Output "  # Port-forward Grafana (if NodePort doesn't work)"
Write-Output "  kubectl port-forward svc/${ReleasePrefix}-grafana 3000:80 -n $Namespace"
Write-Output ""
Write-Output "  # Port-forward Minio Console"
Write-Output "  kubectl port-forward svc/${ReleasePrefix}-minio-console 9001:9001 -n $Namespace"
Write-Output ""
Write-Output "  # Check pod status"
Write-Output "  kubectl get pods -n $Namespace"
Write-Output ""
Write-Output "  # View logs"
Write-Output "  kubectl logs -l app.kubernetes.io/name=loki -n $Namespace"
Write-Output "  kubectl logs -l app.kubernetes.io/name=tempo -n $Namespace"
Write-Output "  kubectl logs -l app.kubernetes.io/name=mimir -n $Namespace"
Write-Output "  kubectl logs -l app.kubernetes.io/name=alloy -n $Namespace"
Write-Output "  kubectl logs -l app.kubernetes.io/name=grafana -n $Namespace"
Write-Output ""

Write-ColorOutput "✅ Installation completed successfully!"
exit 0