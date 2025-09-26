<#
.SYNOPSIS
    Containerized Helm wrapper for environments without local Helm installation.

.DESCRIPTION
    This script runs Helm commands inside a Docker container, eliminating the need
    to install Helm locally. It automatically mounts your kubeconfig and project
    files, and handles network configuration for different environments (local, CI).

.PARAMETER TestConnection
    Tests connectivity to the Kubernetes cluster.

.PARAMETER PullImages
    Pre-pulls required container images.

.PARAMETER Kubectl
    Runs kubectl commands in container instead of Helm.

.PARAMETER KubectlArgs
    Arguments to pass to kubectl when using -Kubectl.

.PARAMETER HelmArgs
    Helm commands and arguments to execute in the container.

.EXAMPLE
    ./Helm-Container.ps1 version
    Shows the Helm version from the container.

.EXAMPLE
    ./Helm-Container.ps1 repo add grafana https://grafana.github.io/helm-charts
    Adds a Helm repository using the containerized Helm.

.EXAMPLE
    ./Helm-Container.ps1 -TestConnection
    Tests connectivity to the Kubernetes cluster.

.EXAMPLE
    ./Helm-Container.ps1 -Kubectl -KubectlArgs get,nodes
    Runs kubectl command in container to get cluster nodes.

.NOTES
    Requires:
    - Docker installed and running
    - Valid kubeconfig file
    - Access to Docker Hub for container images
    
    The script automatically detects CI environments and adjusts network settings.
#>

param(
    [switch]$TestConnection,
    [switch]$PullImages,
    [switch]$Kubectl,
    [string[]]$KubectlArgs,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$HelmArgs
)

# Import common utilities
$commonUtilsPath = Join-Path $PSScriptRoot "Common-Utils.ps1"
. $commonUtilsPath

# Configuration
$HELM_IMAGE = "alpine/helm:3.13.2"
$KUBECTL_IMAGE = "alpine/kubectl:1.34.1"

function Test-Docker {
    try {
        $null = Get-Command docker -ErrorAction Stop
        docker info 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
        else {
            Write-ColorOutput "❌ Docker is not running" "Red"
            Write-ColorOutput "💡 Please start Docker to use containerized Helm" "Yellow"
            return $false
        }
    }
    catch {
        Write-ColorOutput "❌ Docker is not installed or not in PATH" "Red"
        Write-ColorOutput "💡 Please install Docker to use containerized Helm" "Yellow"
        return $false
    }
}

function Get-KubeconfigPath {
    if ($env:KUBECONFIG) {
        return $env:KUBECONFIG
    }
    # Check Linux/Unix path first
    elseif (Test-Path "$env:HOME/.kube/config") {
        return "$env:HOME/.kube/config"
    }
    # Check Windows path as fallback
    elseif ($env:USERPROFILE -and (Test-Path "$env:USERPROFILE\.kube\config")) {
        return "$env:USERPROFILE\.kube\config"
    }
    else {
        Write-ColorOutput "❌ No kubeconfig found"
        Write-ColorOutput "💡 Please ensure kubectl is configured"
        throw "No kubeconfig found"
    }
}

function Invoke-HelmContainer {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$HelmArgs
    )

    $kubeconfigPath = Get-KubeconfigPath
    $projectRoot = Split-Path $PSScriptRoot -Parent

    # Convert host paths to container paths in Helm arguments
    $convertedArgs = @()
    foreach ($arg in $HelmArgs) {
        if ($arg -match "^$([regex]::Escape($projectRoot))" -and ($arg -match "\.(yaml|yml)$" -or $arg -match "/values/")) {
            # Convert absolute host path to container path
            $containerPath = $arg -replace [regex]::Escape($projectRoot), "/workspace"
            $convertedArgs += $containerPath
            Write-ColorOutput "📁 Converting path: $arg -> $containerPath"
        }
        else {
            $convertedArgs += $arg
        }
    }

    Write-ColorOutput "🐳 Running Helm in container: $HELM_IMAGE" "Blue"

    # Note: Path conversion not needed for current Docker setup

    # Mount kubeconfig and project directory, run helm command
    # Add Docker Desktop network compatibility and persistent Helm cache
    # Use Linux cache path if on Linux, Windows path otherwise
    if ($env:HOME) {
        $helmCacheDir = "$env:HOME/.cache/helm-container"
    } else {
        $helmCacheDir = "$env:USERPROFILE\.cache\helm-container"
    }
    if (-not (Test-Path $helmCacheDir)) {
        New-Item -Path $helmCacheDir -ItemType Directory -Force | Out-Null
    }

    # Detect CI environment for network and TTY settings
    $networkArgs = @()
    $ttyArgs = @("-it")
    if ($env:CI -eq "true" -or $env:GITHUB_ACTIONS -eq "true" -or $env:RUNNER_OS) {
        Write-ColorOutput "🔧 CI environment detected, using host networking for KinD access"
        $networkArgs = @("--network=host")
        $ttyArgs = @()  # No TTY in CI
    }
    else {
        $networkArgs = @("--add-host", "kubernetes.docker.internal:host-gateway")
    }

    $dockerArgs = @(
        "run", "--rm"
    ) + $ttyArgs + @(
        "-v", "${kubeconfigPath}:/tmp/kubeconfig:ro",
        "-v", "${projectRoot}:/workspace",
        "-v", "${helmCacheDir}:/root/.cache/helm",
        "-v", "${helmCacheDir}:/root/.config/helm",
        "-w", "/workspace/scripts",
        "-e", "KUBECONFIG=/tmp/kubeconfig"
    ) + $networkArgs + @($HELM_IMAGE) + $convertedArgs

    & docker @dockerArgs
    $exitCode = $LASTEXITCODE
    return $exitCode
}

function Invoke-KubectlContainer {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$KubectlArgs
    )

    $kubeconfigPath = Get-KubeconfigPath

    Write-ColorOutput "🐳 Running kubectl in container: $KUBECTL_IMAGE" "Blue"

    # Detect CI environment and use host networking for kind/localhost access
    $networkArgs = @()
    if ($env:CI -eq "true" -or $env:GITHUB_ACTIONS -eq "true" -or $env:RUNNER_OS) {
        $networkArgs = @("--network=host")
    }
    else {
        $networkArgs = @("--add-host", "kubernetes.docker.internal:host-gateway")
    }

    $dockerArgs = @(
        "run", "--rm",
        "-v", "${kubeconfigPath}:/tmp/kubeconfig:ro",
        "-e", "KUBECONFIG=/tmp/kubeconfig"
    ) + $networkArgs + @($KUBECTL_IMAGE) + $KubectlArgs

    & docker @dockerArgs
}

function Test-ClusterConnection {
    Write-ColorOutput "🔍 Testing Kubernetes cluster connectivity..." "Yellow"
    try {
        Invoke-KubectlContainer "cluster-info" 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Kubernetes cluster is accessible"
            return $true
        }
        else {
            Write-ColorOutput "❌ Cannot connect to Kubernetes cluster" "Red"
            return $false
        }
    }
    catch {
        Write-ColorOutput "❌ Cannot connect to Kubernetes cluster" "Red"
        return $false
    }
}

function Get-ContainerImage {
    Write-ColorOutput "📦 Pulling required container images..." "Yellow"

    Write-ColorOutput "Pulling Helm image: $HELM_IMAGE" "Blue"
    docker pull $HELM_IMAGE

    Write-ColorOutput "Pulling kubectl image: $KUBECTL_IMAGE" "Blue"
    docker pull $KUBECTL_IMAGE

    Write-ColorOutput "✅ Container images ready" "Green"
}

if (-not (Test-Docker)) { exit 1 }

if ($TestConnection) {
    if (Test-ClusterConnection) { exit 0 } else { exit 1 }
}

if ($PullImages) {
    Get-ContainerImage
    exit 0
}

if ($Kubectl) {
    Invoke-KubectlContainer @KubectlArgs
    exit $LASTEXITCODE
}

# Default: run Helm command if HelmArgs provided
if ($HelmArgs -and $HelmArgs.Count -gt 0) {
    if (-not (Test-ClusterConnection)) {
        Write-ColorOutput "❌ Cluster connectivity test failed"
        Write-ColorOutput "💡 Please check your kubeconfig and cluster status"
        exit 1
    }
    Invoke-HelmContainer @HelmArgs
    exit $LASTEXITCODE
}

# If no parameters provided, show that Get-Help should be used
Write-ColorOutput "💡 Use Get-Help .\Helm-Container.ps1 for usage information"
exit 0
