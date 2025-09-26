# Containerized Helm Wrapper Script
# FOR: Environments where Helm is not installed locally
# USAGE: .\helm-container.ps1 [helm-commands]
# REQUIRES: Docker installed and running

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

# Configuration
$HELM_IMAGE = "alpine/helm:3.13.2"
$KUBECTL_IMAGE = "alpine/kubectl:1.34.1"

# Function to write colored output
function Write-ColorOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    Write-Output $Message
}

# Function to check if Docker is available
function Test-Docker {
    try {
        $null = Get-Command docker -ErrorAction Stop
        docker info 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
        else {
            Write-ColorOutput "❌ Docker is not running"
            Write-ColorOutput "💡 Please start Docker to use containerized Helm"
            return $false
        }
    }
    catch {
        Write-ColorOutput "❌ Docker is not installed or not in PATH"
        Write-ColorOutput "💡 Please install Docker to use containerized Helm"
        return $false
    }
}

# Function to get kubeconfig path
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

# Function to run Helm in container
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

    Write-ColorOutput "🐳 Running Helm in container: $HELM_IMAGE"

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

    # Detect CI environment and use host networking for kind/localhost access
    $networkArgs = @()
    if ($env:CI -eq "true" -or $env:GITHUB_ACTIONS -eq "true" -or $env:RUNNER_OS) {
        Write-ColorOutput "🔧 CI environment detected, using host networking for KinD access" "Yellow"
        $networkArgs = @("--network=host")
    }
    else {
        $networkArgs = @("--add-host", "kubernetes.docker.internal:host-gateway")
    }

    $dockerArgs = @(
        "run", "--rm", "-it",
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

# Function to run kubectl in container (for verification)
function Invoke-KubectlContainer {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$KubectlArgs
    )

    $kubeconfigPath = Get-KubeconfigPath

    Write-ColorOutput "🐳 Running kubectl in container: $KUBECTL_IMAGE"

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

# Function to test cluster connectivity
function Test-ClusterConnection {
    Write-ColorOutput "🔍 Testing Kubernetes cluster connectivity..."
    try {
        Invoke-KubectlContainer "cluster-info" 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Kubernetes cluster is accessible"
            return $true
        }
        else {
            Write-ColorOutput "❌ Cannot connect to Kubernetes cluster"
            return $false
        }
    }
    catch {
        Write-ColorOutput "❌ Cannot connect to Kubernetes cluster"
        return $false
    }
}

# Function to pull required images
function Get-ContainerImage {
    Write-ColorOutput "📦 Pulling required container images..."

    Write-ColorOutput "Pulling Helm image: $HELM_IMAGE"
    docker pull $HELM_IMAGE

    Write-ColorOutput "Pulling kubectl image: $KUBECTL_IMAGE"
    docker pull $KUBECTL_IMAGE

    Write-ColorOutput "✅ Container images ready"
}

# Function to show help
function Show-Help {
    Write-ColorOutput "🐳 Containerized Helm Wrapper"
    Write-Output ""
    Write-ColorOutput "Usage:"
    Write-Output "  .\helm-container.ps1 [helm-command] [args...]"
    Write-Output ""
    Write-ColorOutput "Examples:"
    Write-Output "  .\helm-container.ps1 version"
    Write-Output "  .\helm-container.ps1 repo add grafana https://grafana.github.io/helm-charts"
    Write-Output "  .\helm-container.ps1 install my-app ./chart"
    Write-Output ""
    Write-ColorOutput "Special commands:"
    Write-Output "  .\helm-container.ps1 --test-connection    # Test cluster connectivity"
    Write-Output "  .\helm-container.ps1 --pull-images        # Pre-pull container images"
    Write-Output "  .\helm-container.ps1 --kubectl [args...]  # Run kubectl in container"
}

# Main execution
function Main {
    # Check prerequisites
    if (-not (Test-Docker)) {
        exit 1
    }

    # If no arguments provided, show help
    if ($Arguments.Count -eq 0) {
        Show-Help
        exit 0
    }

    # Handle special commands
    switch ($Arguments[0]) {
        "--test-connection" {
            if (Test-ClusterConnection) {
                exit 0
            }
            else {
                exit 1
            }
        }
        "--pull-images" {
            Get-ContainerImage
            exit 0
        }
        "--kubectl" {
            $kubectlArgs = $Arguments[1..($Arguments.Count - 1)]
            Invoke-KubectlContainer @kubectlArgs
            exit $LASTEXITCODE
        }
        { $_ -in "--help", "-h" } {
            Show-Help
            exit 0
        }
        default {
            # Test cluster connection first
            if (-not (Test-ClusterConnection)) {
                Write-ColorOutput "❌ Cluster connectivity test failed"
                Write-ColorOutput "💡 Please check your kubeconfig and cluster status"
                exit 1
            }

            # Run Helm command in container
            Invoke-HelmContainer @Arguments
            exit $LASTEXITCODE
        }
    }
}

# Execute main function
Main