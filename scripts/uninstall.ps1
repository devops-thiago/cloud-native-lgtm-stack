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
        [string]$Message
    )
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

Write-ColorOutput "🗑️  Starting Cloud Native LGTM Stack Uninstallation"
Write-Output "Namespace: $Namespace"
Write-Output "Release Prefix: $ReleasePrefix"
Write-Output ""

# Check prerequisites
Write-ColorOutput "🔍 Checking prerequisites..."

# Detect and configure Helm (local or containerized)
if (-not (Test-Helm)) {
    Write-ColorOutput "⚠️  Neither Helm nor Docker available, will skip Helm releases"
}
else {
    Show-HelmInfo
    Initialize-ContainerizedHelm | Out-Null  # Don't fail uninstall if this fails
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

# Function to uninstall helm release (using utilities)
function Remove-HelmRelease {
    param(
        [string]$ReleaseName,
        [string]$ComponentName
    )

    if ($script:HELM_MODE -ne "none") {
        Write-ColorOutput "🗑️  Uninstalling $ComponentName..."
        Uninstall-HelmRelease $ReleaseName $Namespace
    }
    else {
        Write-ColorOutput "⚠️  Helm not available, skipping $ComponentName uninstall"
    }
    Write-Output ""
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
Write-ColorOutput "🧹 Cleaning up custom node-exporter DaemonSet..."
$projectRoot = Split-Path $PSScriptRoot -Parent
$nodeExporterDaemonSetPath = Join-Path $projectRoot "values/node-exporter-docker-desktop-daemonset.yaml"
kubectl delete -f $nodeExporterDaemonSetPath --ignore-not-found=true 2>$null
Write-ColorOutput "✅ Custom node-exporter cleaned up"
Write-Output ""

# Clean up PVCs if they exist
Write-ColorOutput "🧹 Cleaning up Persistent Volume Claims..."

try {
    $pvcList = kubectl get pvc -n $Namespace --no-headers 2>$null | Where-Object {
        $_ -match "$ReleasePrefix"
    } | ForEach-Object { ($_ -split '\s+')[0] }

    if ($pvcList) {
        Write-Output "Found PVCs to clean up:"
        $pvcList | ForEach-Object { Write-Output "  $_" }
        Write-Output ""

        $confirmation = Read-Host "Do you want to delete these PVCs? This will permanently delete all data! [y/N]"
        if ($confirmation -match '^[Yy]$') {
            $pvcList | ForEach-Object {
                if ($_) {
                    Write-Output "Deleting PVC: $_"
                    try {
                        kubectl delete pvc $_ -n $Namespace --ignore-not-found=true 2>$null
                        if ($LASTEXITCODE -ne 0) {
                            Write-Output "  Warning: Could not delete PVC $_"
                        }
                    }
                    catch {
                        Write-Output "  Warning: Could not delete PVC $_"
                    }
                }
            }
            Write-ColorOutput "✅ PVC deletion completed"
        }
        else {
            Write-ColorOutput "⚠️  PVCs left intact"
        }
    }
    else {
        Write-Output "No PVCs found to clean up"
    }
}
catch {
    Write-Output "No PVCs found to clean up"
}
Write-Output ""

# Check for remaining resources
Write-ColorOutput "🔍 Checking for remaining resources..."

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
    Write-ColorOutput "⚠️  Some resources may still be terminating:"
    Write-Output "  Pods: $remainingPods"
    Write-Output "  Services: $remainingServices"
    Write-Output "  Secrets: $remainingSecrets"
    Write-Output ""
    Write-Output "You can check the status with:"
    Write-Output "  kubectl get all -n $Namespace"
}
else {
    Write-ColorOutput "✅ No remaining LTGM resources found"
}
Write-Output ""

# Option to delete namespace
if ($Namespace -ne "default" -and $Namespace -ne "kube-system") {
    $confirmation = Read-Host "Do you want to delete the namespace '$Namespace'? [y/N]"
    if ($confirmation -match '^[Yy]$') {
        kubectl delete namespace $Namespace 2>$null
        Write-ColorOutput "✅ Namespace '$Namespace' deleted"
    }
    else {
        Write-ColorOutput "⚠️  Namespace '$Namespace' left intact"
    }
}
else {
    Write-ColorOutput "ℹ️  Namespace '$Namespace' is a system namespace and won't be deleted"
}
Write-Output ""

Write-ColorOutput "🎉 LGTM Stack uninstallation completed!"
Write-Output ""
Write-ColorOutput "📋 Cleanup Summary:"
Write-Output "  ✅ Alloy uninstalled"
Write-Output "  ✅ Grafana uninstalled"
Write-Output "  ✅ Mimir uninstalled"
Write-Output "  ✅ Tempo uninstalled"
Write-Output "  ✅ Loki uninstalled"
Write-Output "  ✅ Node Exporter uninstalled"
Write-Output "  ✅ Kube-state-metrics uninstalled"
Write-Output "  ✅ Minio uninstalled"
Write-Output "  ✅ Custom dashboard ConfigMaps removed"
Write-Output ""
Write-ColorOutput "🛠️  Manual cleanup (if needed):"
Write-Output "  # Remove any remaining resources"
Write-Output "  kubectl get all -n $Namespace"
Write-Output "  kubectl delete <resource-type> <resource-name> -n $Namespace"
Write-Output ""
Write-Output "  # Remove storage classes (if custom ones were created)"
Write-Output "  kubectl get storageclass"
Write-Output ""

Write-ColorOutput "✅ Uninstallation completed successfully!"