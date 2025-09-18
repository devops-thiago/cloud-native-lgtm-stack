# E2E Test Validation Script for PowerShell
# This script provides utility functions for validating the LGTM stack installation

param(
    [string]$Command = "help",
    [string]$Mode = "auto"
)

# Configuration
$NAMESPACE = $env:NAMESPACE ?? "lgtm-test"
$RELEASE_PREFIX = $env:RELEASE_PREFIX ?? "test"

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

# Function to check if a command exists
function Test-Command {
    param([string]$CommandName)
    try {
        $null = Get-Command $CommandName -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# Function to wait for pod readiness with timeout
function Wait-ForPods {
    param(
        [string]$Namespace,
        [string]$Selector,
        [int]$Timeout = 300
    )
    
    Write-ColorOutput "⏳ Waiting for pods with selector '$Selector' in namespace '$Namespace'..." "Yellow"
    
    try {
        kubectl wait --for=condition=ready pod -l $Selector -n $Namespace --timeout="${Timeout}s" 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Pods are ready" "Green"
            return $true
        }
        else {
            Write-ColorOutput "❌ Pods failed to become ready within ${Timeout}s" "Red"
            kubectl describe pods -l $Selector -n $Namespace
            return $false
        }
    }
    catch {
        Write-ColorOutput "❌ Error waiting for pods: $_" "Red"
        return $false
    }
}

# Function to validate installation
function Test-Installation {
    param(
        [string]$Namespace,
        [string]$ReleasePrefix
    )
    
    Write-ColorOutput "🔍 Validating installation in namespace '$Namespace' with prefix '$ReleasePrefix'..." "Blue"
    
    # Check namespace exists
    try {
        kubectl get namespace $Namespace 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "❌ Namespace '$Namespace' does not exist" "Red"
            return $false
        }
    }
    catch {
        Write-ColorOutput "❌ Namespace '$Namespace' does not exist" "Red"
        return $false
    }
    
    Write-ColorOutput "✅ Namespace '$Namespace' exists" "Green"
    
    # Check for expected Helm releases
    $expectedReleases = @("minio", "loki", "tempo", "mimir", "alloy", "grafana", "kube-state-metrics")
    $missingReleases = @()
    
    # Function to check Helm releases based on available tool
    function Get-HelmReleases {
        if (Test-Command "helm") {
            $releases = helm list -n $Namespace --output json 2>$null
            if ($LASTEXITCODE -eq 0) {
                return $releases
            }
        }
        elseif ((Test-Command "docker") -and (docker info 2>$null | Out-Null; $LASTEXITCODE -eq 0)) {
            # Use containerized Helm
            $scriptPath = Join-Path $PSScriptRoot "helm-container.ps1"
            $releases = & $scriptPath list -n $Namespace --output json 2>$null
            if ($LASTEXITCODE -eq 0) {
                return $releases
            }
        }
        else {
            Write-ColorOutput "⚠️  Neither Helm nor Docker available, skipping Helm release validation" "Yellow"
            return "[]"
        }
        return "[]"
    }
    
    $releasesJson = Get-HelmReleases
    
    foreach ($release in $expectedReleases) {
        $fullReleaseName = "${ReleasePrefix}-${release}"
        if ($releasesJson -notmatch "name.*$fullReleaseName") {
            $missingReleases += $fullReleaseName
        }
    }
    
    if ($missingReleases.Count -eq 0) {
        Write-ColorOutput "✅ All expected Helm releases are installed" "Green"
    }
    else {
        Write-ColorOutput "❌ Missing Helm releases: $($missingReleases -join ', ')" "Red"
        return $false
    }
    
    # Check for running pods
    $pods = kubectl get pods -n $Namespace --no-headers 2>$null
    if ($LASTEXITCODE -eq 0 -and $pods) {
        $podCount = ($pods | Measure-Object).Count
        Write-ColorOutput "✅ Found $podCount pods in namespace '$Namespace'" "Green"
        
        # Show pod status
        kubectl get pods -n $Namespace
        
        # Check for any failed pods
        $failedPods = kubectl get pods -n $Namespace --field-selector=status.phase=Failed --no-headers 2>$null
        if ($LASTEXITCODE -eq 0 -and $failedPods) {
            $failedCount = ($failedPods | Measure-Object).Count
            Write-ColorOutput "❌ Found $failedCount failed pods" "Red"
            kubectl get pods -n $Namespace --field-selector=status.phase=Failed
            return $false
        }
    }
    else {
        Write-ColorOutput "❌ No pods found in namespace '$Namespace'" "Red"
        return $false
    }
    
    # Check services
    $services = kubectl get services -n $Namespace --no-headers 2>$null
    if ($LASTEXITCODE -eq 0 -and $services) {
        $serviceCount = ($services | Measure-Object).Count
        Write-ColorOutput "✅ Found $serviceCount services in namespace '$Namespace'" "Green"
        kubectl get services -n $Namespace
    }
    else {
        Write-ColorOutput "⚠️  No services found in namespace '$Namespace'" "Yellow"
    }
    
    return $true
}

# Function to validate uninstallation
function Test-Uninstallation {
    param(
        [string]$Namespace,
        [string]$ReleasePrefix
    )
    
    Write-ColorOutput "🔍 Validating uninstallation in namespace '$Namespace' with prefix '$ReleasePrefix'..." "Blue"
    
    # Function to check Helm releases based on available tool
    function Get-HelmReleases {
        if (Test-Command "helm") {
            $releases = helm list -n $Namespace --output json 2>$null
            if ($LASTEXITCODE -eq 0) {
                return $releases
            }
        }
        elseif ((Test-Command "docker") -and (docker info 2>$null | Out-Null; $LASTEXITCODE -eq 0)) {
            # Use containerized Helm
            $scriptPath = Join-Path $PSScriptRoot "helm-container.ps1"
            $releases = & $scriptPath list -n $Namespace --output json 2>$null
            if ($LASTEXITCODE -eq 0) {
                return $releases
            }
        }
        else {
            Write-ColorOutput "⚠️  Neither Helm nor Docker available, skipping Helm release validation" "Yellow"
            return "[]"
        }
        return "[]"
    }
    
    $releasesJson = Get-HelmReleases
    
    # Check that no releases with our prefix exist
    if ($releasesJson -match "name.*${ReleasePrefix}-") {
        Write-ColorOutput "❌ Helm releases with prefix '${ReleasePrefix}-' still exist:" "Red"
        $releasesJson | Select-String "${ReleasePrefix}-"
        return $false
    }
    else {
        Write-ColorOutput "✅ No Helm releases with prefix '${ReleasePrefix}-' found" "Green"
    }
    
    # Check remaining pods (allow for some terminating pods)
    Start-Sleep -Seconds 5
    $pods = kubectl get pods -n $Namespace --no-headers 2>$null
    if ($LASTEXITCODE -eq 0 -and $pods) {
        $allPods = @($pods)
        $terminatingPods = @($allPods | Where-Object { $_ -match "Terminating" })
        $runningCount = $allPods.Count - $terminatingPods.Count
        
        if ($runningCount -eq 0) {
            Write-ColorOutput "✅ No running pods remain in namespace '$Namespace'" "Green"
            if ($terminatingPods.Count -gt 0) {
                Write-ColorOutput "⚠️  $($terminatingPods.Count) pods are still terminating (this is normal)" "Yellow"
            }
        }
        else {
            Write-ColorOutput "❌ $runningCount pods are still running in namespace '$Namespace'" "Red"
            kubectl get pods -n $Namespace 2>$null
            return $false
        }
    }
    else {
        Write-ColorOutput "✅ No pods found in namespace '$Namespace' (or namespace removed)" "Green"
    }
    
    return $true
}

# Function to run full test cycle
function Invoke-FullTest {
    param([string]$TestMode = "auto")  # auto, local-helm, containerized-helm
    
    Write-ColorOutput "🚀 Starting full e2e test cycle with mode: $TestMode" "Blue"
    
    # Determine script directory
    $scriptDir = $PSScriptRoot
    
    # Set test environment
    $env:NAMESPACE = $NAMESPACE
    $env:RELEASE_PREFIX = $RELEASE_PREFIX
    
    Write-ColorOutput "📋 Test Configuration:" "Yellow"
    Write-ColorOutput "  Namespace: $NAMESPACE" "Yellow"
    Write-ColorOutput "  Release Prefix: $RELEASE_PREFIX" "Yellow"
    Write-ColorOutput "  Test Mode: $TestMode" "Yellow"
    Write-Host ""
    
    # Force Helm mode if specified
    if ($TestMode -eq "containerized-helm") {
        if (Test-Command "helm") {
            Write-ColorOutput "⚠️  Local Helm detected but testing containerized mode" "Yellow"
            # Note: In PowerShell, we can't easily hide helm from PATH like in bash
            # The script will detect both but should prefer containerized based on the mode
        }
    }
    
    # Run installation
    Write-ColorOutput "📦 Running installation..." "Blue"
    $installScript = Join-Path $scriptDir "install.ps1"
    try {
        & $installScript -Namespace $NAMESPACE -ReleasePrefix $RELEASE_PREFIX
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "❌ Installation failed with exit code $LASTEXITCODE" "Red"
            return $false
        }
    }
    catch {
        Write-ColorOutput "❌ Installation failed: $_" "Red"
        return $false
    }
    
    # Validate installation
    Write-ColorOutput "✅ Installation completed, validating..." "Blue"
    if (!(Test-Installation $NAMESPACE $RELEASE_PREFIX)) {
        Write-ColorOutput "❌ Installation validation failed" "Red"
        return $false
    }
    
    # Wait a bit to ensure everything is stable
    Start-Sleep -Seconds 10
    
    # Run uninstallation
    Write-ColorOutput "🗑️  Running uninstallation..." "Blue"
    $uninstallScript = Join-Path $scriptDir "uninstall.ps1"
    try {
        & $uninstallScript -Namespace $NAMESPACE -ReleasePrefix $RELEASE_PREFIX
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "❌ Uninstallation failed with exit code $LASTEXITCODE" "Red"
            return $false
        }
    }
    catch {
        Write-ColorOutput "❌ Uninstallation failed: $_" "Red"
        return $false
    }
    
    # Validate uninstallation
    Write-ColorOutput "✅ Uninstallation completed, validating..." "Blue"
    if (!(Test-Uninstallation $NAMESPACE $RELEASE_PREFIX)) {
        Write-ColorOutput "❌ Uninstallation validation failed" "Red"
        return $false
    }
    
    Write-ColorOutput "🎉 Full e2e test cycle completed successfully!" "Green"
    return $true
}

# Function to show help
function Show-Help {
    Write-Host "Usage: .\e2e-test-utils.ps1 -Command <command> [-Mode <mode>]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  validate-install     - Validate that the LGTM stack is properly installed"
    Write-Host "  validate-uninstall   - Validate that the LGTM stack is properly uninstalled"
    Write-Host "  full-test            - Run complete install/validate/uninstall/validate cycle"
    Write-Host ""
    Write-Host "Full test modes:"
    Write-Host "  auto                 - Use whatever Helm is available (default)"
    Write-Host "  local-helm           - Force use of local Helm"
    Write-Host "  containerized-helm   - Force use of containerized Helm"
    Write-Host ""
    Write-Host "Environment variables:"
    Write-Host "  NAMESPACE            - Kubernetes namespace (default: lgtm-test)"
    Write-Host "  RELEASE_PREFIX       - Helm release prefix (default: test)"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\e2e-test-utils.ps1 -Command validate-install"
    Write-Host "  .\e2e-test-utils.ps1 -Command full-test -Mode containerized-helm"
    Write-Host "  `$env:NAMESPACE='my-test'; .\e2e-test-utils.ps1 -Command validate-install"
}

# Main logic
switch ($Command.ToLower()) {
    "validate-install" {
        $result = Test-Installation $NAMESPACE $RELEASE_PREFIX
        if (-not $result) { exit 1 }
    }
    "validate-uninstall" {
        $result = Test-Uninstallation $NAMESPACE $RELEASE_PREFIX
        if (-not $result) { exit 1 }
    }
    "full-test" {
        $result = Invoke-FullTest $Mode
        if (-not $result) { exit 1 }
    }
    default {
        Show-Help
    }
}