# Cloud Native LTGM Stack Uninstallation Script
# This script removes Loki, Tempo, Grafana, and Minio from Kubernetes

param(
    [string]$Namespace = $env:NAMESPACE ?? "default",
    [string]$ReleasePrefix = $env:RELEASE_PREFIX ?? "ltgm"
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

Write-ColorOutput "🗑️  Starting Cloud Native LGTM Stack Uninstallation" "Yellow"
Write-Host "Namespace: $Namespace"
Write-Host "Release Prefix: $ReleasePrefix"
Write-Host ""

# Check prerequisites
Write-ColorOutput "🔍 Checking prerequisites..." "Yellow"

# Detect and configure Helm (local or containerized)
if (-not (Detect-Helm)) {
    Write-ColorOutput "⚠️  Neither Helm nor Docker available, will skip Helm releases" "Yellow"
}
else {
    Show-HelmInfo
    Initialize-ContainerizedHelm | Out-Null  # Don't fail uninstall if this fails
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

# Function to uninstall helm release (using utilities)
function Remove-HelmRelease {
    param(
        [string]$ReleaseName,
        [string]$ComponentName
    )

    if ($Global:HELM_MODE -ne "none") {
        Write-ColorOutput "🗑️  Uninstalling $ComponentName..." "Yellow"
        Uninstall-HelmRelease $ReleaseName $Namespace
    }
    else {
        Write-ColorOutput "⚠️  Helm not available, skipping $ComponentName uninstall" "Yellow"
    }
    Write-Host ""
}

# Uninstall components in reverse order
Remove-HelmRelease "${ReleasePrefix}-alloy" "Alloy"
Remove-HelmRelease "${ReleasePrefix}-grafana" "Grafana"
Remove-HelmRelease "${ReleasePrefix}-mimir" "Mimir"
Remove-HelmRelease "${ReleasePrefix}-tempo" "Tempo"
Remove-HelmRelease "${ReleasePrefix}-loki" "Loki"
Remove-HelmRelease "${ReleasePrefix}-kube-state-metrics" "Kube-state-metrics"
Remove-HelmRelease "${ReleasePrefix}-node-exporter" "Node Exporter (Helm)"
Remove-HelmRelease "${ReleasePrefix}-minio" "Minio"

# Clean up custom node-exporter DaemonSet if it exists
Write-ColorOutput "🧹 Cleaning up custom node-exporter DaemonSet..." "Yellow"
$projectRoot = Split-Path $PSScriptRoot -Parent
$nodeExporterDaemonSetPath = Join-Path $projectRoot "values/node-exporter-docker-desktop-daemonset.yaml"
kubectl delete -f $nodeExporterDaemonSetPath --ignore-not-found=true 2>$null
Write-ColorOutput "✅ Custom node-exporter cleaned up" "Green"
Write-Host ""

# Clean up PVCs if they exist
Write-ColorOutput "🧹 Cleaning up Persistent Volume Claims..." "Yellow"

try {
    $pvcList = kubectl get pvc -n $Namespace --no-headers 2>$null | Where-Object {
        $_ -match "$ReleasePrefix"
    } | ForEach-Object { ($_ -split '\s+')[0] }

    if ($pvcList) {
        Write-Host "Found PVCs to clean up:"
        $pvcList | ForEach-Object { Write-Host "  $_" }
        Write-Host ""

        $confirmation = Read-Host "Do you want to delete these PVCs? This will permanently delete all data! [y/N]"
        if ($confirmation -match '^[Yy]$') {
            $pvcList | ForEach-Object {
                kubectl delete pvc $_ -n $Namespace 2>$null
            }
            Write-ColorOutput "✅ PVCs deleted" "Green"
        }
        else {
            Write-ColorOutput "⚠️  PVCs left intact" "Yellow"
        }
    }
    else {
        Write-Host "No PVCs found to clean up"
    }
}
catch {
    Write-Host "No PVCs found to clean up"
}
Write-Host ""

# Check for remaining resources
Write-ColorOutput "🔍 Checking for remaining resources..." "Yellow"

try {
    $remainingPods = (kubectl get pods -n $Namespace --no-headers 2>$null | Where-Object {
        $_ -match "($ReleasePrefix|loki|tempo|mimir|grafana|minio|alloy)"
    }).Count

    $remainingServices = (kubectl get svc -n $Namespace --no-headers 2>$null | Where-Object {
        $_ -match "($ReleasePrefix|loki|tempo|mimir|grafana|minio|alloy)"
    }).Count

    $remainingSecrets = (kubectl get secrets -n $Namespace --no-headers 2>$null | Where-Object {
        $_ -match "($ReleasePrefix|loki|tempo|mimir|grafana|minio|alloy)"
    }).Count
}
catch {
    $remainingPods = 0
    $remainingServices = 0
    $remainingSecrets = 0
}

if ($remainingPods -gt 0 -or $remainingServices -gt 0 -or $remainingSecrets -gt 0) {
    Write-ColorOutput "⚠️  Some resources may still be terminating:" "Yellow"
    Write-Host "  Pods: $remainingPods"
    Write-Host "  Services: $remainingServices"
    Write-Host "  Secrets: $remainingSecrets"
    Write-Host ""
    Write-Host "You can check the status with:"
    Write-Host "  kubectl get all -n $Namespace"
}
else {
    Write-ColorOutput "✅ No remaining LTGM resources found" "Green"
}
Write-Host ""

# Option to delete namespace
if ($Namespace -ne "default" -and $Namespace -ne "kube-system") {
    $confirmation = Read-Host "Do you want to delete the namespace '$Namespace'? [y/N]"
    if ($confirmation -match '^[Yy]$') {
        kubectl delete namespace $Namespace 2>$null
        Write-ColorOutput "✅ Namespace '$Namespace' deleted" "Green"
    }
    else {
        Write-ColorOutput "⚠️  Namespace '$Namespace' left intact" "Yellow"
    }
}
else {
    Write-ColorOutput "ℹ️  Namespace '$Namespace' is a system namespace and won't be deleted" "Yellow"
}
Write-Host ""

Write-ColorOutput "🎉 LGTM Stack uninstallation completed!" "Green"
Write-Host ""
Write-ColorOutput "📋 Cleanup Summary:" "Yellow"
Write-Host "  ✅ Alloy uninstalled"
Write-Host "  ✅ Grafana uninstalled"
Write-Host "  ✅ Mimir uninstalled"
Write-Host "  ✅ Tempo uninstalled"
Write-Host "  ✅ Loki uninstalled"
Write-Host "  ✅ Node Exporter uninstalled"
Write-Host "  ✅ Kube-state-metrics uninstalled"
Write-Host "  ✅ Minio uninstalled"
Write-Host ""
Write-ColorOutput "🛠️  Manual cleanup (if needed):" "Yellow"
Write-Host "  # Remove any remaining resources"
Write-Host "  kubectl get all -n $Namespace"
Write-Host "  kubectl delete <resource-type> <resource-name> -n $Namespace"
Write-Host ""
Write-Host "  # Remove storage classes (if custom ones were created)"
Write-Host "  kubectl get storageclass"
Write-Host ""

Write-ColorOutput "✅ Uninstallation completed successfully!" "Green"