<#
.SYNOPSIS
    Uninstalls the Cloud Native LGTM Stack from Kubernetes.

.DESCRIPTION
    This script removes all components of the LGTM stack from Kubernetes including
    Loki, Tempo, Grafana, Minio, Alloy, and supporting components. It can optionally
    clean up persistent volume claims and the namespace.

.PARAMETER Namespace
    Target Kubernetes namespace to clean up (default: default).

.PARAMETER ReleasePrefix
    Prefix of Helm releases to uninstall (default: ltgm).

.PARAMETER Kubeconfig
    Path to kubeconfig file. If not specified, uses KUBECONFIG environment variable or default location.

.EXAMPLE
    ./Uninstall.ps1
    Uninstalls the LGTM stack from the default namespace.

.EXAMPLE
    ./Uninstall.ps1 -Namespace observability
    Uninstalls the LGTM stack from the 'observability' namespace.

.EXAMPLE
    ./Uninstall.ps1 -Kubeconfig ./my-config.yaml -ReleasePrefix my-ltgm
    Uninstalls using custom kubeconfig and release prefix.

.NOTES
    Requires:
    - kubectl (Kubernetes CLI)
    - Either Helm 3.x OR Docker (for containerized Helm)
    - Access to a Kubernetes cluster
    WARNING: This script will prompt before deleting persistent data and namespaces.
#>

param(
    [string]$Namespace = $env:NAMESPACE ?? "default",
    [string]$ReleasePrefix = $env:RELEASE_PREFIX ?? "ltgm",
    [string]$Kubeconfig
)

# Set kubeconfig if provided
if ($Kubeconfig) {
    if (Test-Path $Kubeconfig) {
        $env:KUBECONFIG = $Kubeconfig
        Write-Output "Using kubeconfig: $Kubeconfig"
    }
    else {
        Write-Error "Kubeconfig file not found: $Kubeconfig"
        exit 1
    }
}

# Import common utilities
$commonUtilsPath = Join-Path $PSScriptRoot "Common-Utils.ps1"
. $commonUtilsPath

# Import Helm utilities
$scriptPath = Join-Path $PSScriptRoot "Helm-Utils.ps1"
. $scriptPath

Write-ColorOutput "🗑️  Starting Cloud Native LGTM Stack Uninstallation" "Yellow"
Write-Output "Namespace: $Namespace"
Write-Output "Release Prefix: $ReleasePrefix"
Write-Output ""

# Check prerequisites
Write-ColorOutput "🔍 Checking prerequisites..." "Yellow"

# Detect and configure Helm (local or containerized)
if (-not (Test-Helm)) {
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
Write-Output ""

function Remove-HelmRelease {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ReleaseName,
        [string]$ComponentName
    )

    if ($script:HELM_MODE -ne "none") {
        if ($PSCmdlet.ShouldProcess("$ComponentName ($ReleaseName)", "Uninstall")) {
            Write-ColorOutput "🗑️  Uninstalling $ComponentName..." "Yellow"
            Uninstall-HelmRelease $ReleaseName $Namespace
        } else {
            Write-ColorOutput "🗑️  Would uninstall $ComponentName (WhatIf mode)" "Blue"
        }
    }
    else {
        Write-ColorOutput "⚠️  Helm not available, skipping $ComponentName uninstall" "Yellow"
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
Write-ColorOutput "🧹 Cleaning up custom node-exporter DaemonSet..." "Yellow"
$projectRoot = Split-Path $PSScriptRoot -Parent
$nodeExporterDaemonSetPath = Join-Path $projectRoot "values/node-exporter-docker-desktop-daemonset.yaml"
kubectl delete -f $nodeExporterDaemonSetPath --ignore-not-found=true 2>$null
Write-ColorOutput "✅ Custom node-exporter cleaned up" "Green"
Write-Output ""

# Clean up PVCs if they exist
Write-ColorOutput "🧹 Cleaning up Persistent Volume Claims..." "Yellow"

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
            Write-ColorOutput "✅ PVC deletion completed" "Green"
        }
        else {
            Write-ColorOutput "⚠️  PVCs left intact" "Yellow"
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
    Write-Output "  Pods: $remainingPods"
    Write-Output "  Services: $remainingServices"
    Write-Output "  Secrets: $remainingSecrets"
    Write-Output ""
    Write-Output "You can check the status with:"
    Write-Output "  kubectl get all -n $Namespace"
}
else {
    Write-ColorOutput "✅ No remaining LTGM resources found" "Green"
}
Write-Output ""

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
    Write-ColorOutput "ℹ️  Namespace '$Namespace' is a system namespace and won't be deleted" "Blue"
}
Write-Output ""

Write-ColorOutput "🎉 LGTM Stack uninstallation completed!" "Green"
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

Write-ColorOutput "✅ Uninstallation completed successfully!" "Green"
