# Update Grafana with custom Kubernetes dashboards

param(
    [string]$Namespace = "default",
    [string]$ReleasePrefix = "ltgm"
)

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

# Script directory and project root
$projectRoot = Split-Path $PSScriptRoot -Parent

Write-ColorOutput "🔄 Updating Grafana with custom Kubernetes dashboards" "Green"

# Deploy the custom dashboards ConfigMap
Write-ColorOutput "📊 Deploying custom dashboards ConfigMap..." "Yellow"
$dashboardsConfigPath = Join-Path $projectRoot "values/kubernetes-dashboards-configmap.yaml"

try {
    kubectl apply -f $dashboardsConfigPath
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

# Upgrade Grafana with updated values
Write-ColorOutput "🔄 Upgrading Grafana deployment..." "Yellow"
$grafanaValuesPath = Join-Path $projectRoot "values/grafana-values.yaml"

try {
    $helmArgs = @(
        "upgrade", "--install", "${ReleasePrefix}-grafana", "grafana/grafana",
        "-f", $grafanaValuesPath,
        "--namespace", $Namespace,
        "--wait"
    )
    
    & helm @helmArgs
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ Grafana upgraded successfully" "Green"
    }
    else {
        Write-ColorOutput "❌ Failed to upgrade Grafana" "Red"
        exit 1
    }
}
catch {
    Write-ColorOutput "❌ Failed to upgrade Grafana" "Red"
    exit 1
}

# Wait for Grafana to be ready
Write-ColorOutput "⏳ Waiting for Grafana pod to be ready..." "Yellow"
try {
    kubectl wait --for=condition=ready pod -l "app.kubernetes.io/name=grafana" --timeout=120s -n $Namespace
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ Grafana pod is ready" "Green"
    }
    else {
        Write-ColorOutput "❌ Grafana pod failed to become ready" "Red"
        exit 1
    }
}
catch {
    Write-ColorOutput "❌ Grafana pod failed to become ready" "Red"
    exit 1
}

# Check dashboard sidecar logs
Write-ColorOutput "📋 Checking dashboard sidecar logs..." "Yellow"
try {
    $logs = kubectl logs -l "app.kubernetes.io/name=grafana" -c "grafana-sc-dashboard" --tail=5 -n $Namespace 2>$null
    if ($logs) {
        $logs | Where-Object { $_ -match "(Writing|ERROR|WARNING)" } | ForEach-Object { Write-Host "  $_" }
    }
}
catch {
    # Ignore log retrieval errors
}

# Get Grafana access information
try {
    $nodePort = kubectl get service "${ReleasePrefix}-grafana" -n $Namespace -o jsonpath='{.spec.ports[0].nodePort}' 2>$null
    $nodeIP = kubectl get nodes -n $Namespace -o jsonpath='{.items[0].status.addresses[0].address}' 2>$null
    
    if (-not $nodeIP) {
        $nodeIP = "localhost"
    }
}
catch {
    $nodePort = "N/A"
    $nodeIP = "localhost"
}

Write-ColorOutput "🎉 Grafana dashboards updated successfully!" "Green"
Write-Host ""
Write-ColorOutput "📊 Custom Dashboards Deployed:" "Yellow"
Write-Host "  • Kubernetes Cluster Overview - LGTM Stack"
Write-Host "  • Kubernetes Pods Overview - LGTM Stack"
Write-Host ""

if ($nodePort -and $nodePort -ne "N/A") {
    Write-ColorOutput "🌐 Access Grafana at: http://${nodeIP}:${nodePort}" "Yellow"
}
else {
    Write-ColorOutput "🌐 Access Grafana using port-forward:" "Yellow"
    Write-Host "  kubectl port-forward svc/${ReleasePrefix}-grafana 3000:80 -n $Namespace"
    Write-Host "  Then visit: http://localhost:3000"
}

Write-ColorOutput "🔑 Login credentials: admin / admin123" "Yellow"
Write-Host ""
Write-ColorOutput "💡 The custom dashboards use corrected metric queries that work with:" "Yellow"
Write-Host "  • kube-state-metrics (resource metrics with 'resource' labels)"
Write-Host "  • node-exporter (node system metrics)"
Write-Host "  • cAdvisor (container metrics with 'pod', 'namespace', 'name' labels)"
Write-Host ""
Write-ColorOutput "🔍 Find the new dashboards in the Grafana UI under:" "Yellow"
Write-Host "  • Dashboards → Browse → Look for 'Kubernetes Cluster Overview - LGTM Stack'"
Write-Host "  • Dashboards → Browse → Look for 'Kubernetes Pods Overview - LGTM Stack'"