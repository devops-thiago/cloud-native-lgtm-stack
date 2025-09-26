# Helm Utilities - Detect and use Helm (local or containerized)
# FOR: Internal use by install/uninstall scripts
# USAGE: . .\helm-utils.ps1

# Global variable to track Helm mode
$Global:HELM_MODE = ""

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

# Function to detect Helm availability
function Detect-Helm {
    try {
        $helmVersion = helm version --short 2>$null
        if ($LASTEXITCODE -eq 0) {
            $Global:HELM_MODE = "local"
            Write-ColorOutput "✅ Helm found locally: $helmVersion" "Green"
            return $true
        }
    }
    catch {
        # Helm not found locally
    }

    # Check for Docker
    try {
        docker info 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $Global:HELM_MODE = "container"
            Write-ColorOutput "⚠️  Helm not found locally, using containerized Helm" "Yellow"
            Write-ColorOutput "🐳 Docker detected, will use containerized Helm" "Blue"
            return $true
        }
    }
    catch {
        # Docker not found
    }

    $Global:HELM_MODE = "none"
    Write-ColorOutput "❌ Neither Helm nor Docker found" "Red"
    Write-ColorOutput "💡 Please install either Helm or Docker to continue" "Yellow"
    return $false
}

# Function to run Helm command (local or containerized)
function Invoke-Helm {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    switch ($Global:HELM_MODE) {
        "local" {
            Write-ColorOutput "🔧 Running local Helm: helm $($Arguments -join ' ')" "Blue"
            $result = & helm @Arguments
            return $result
        }
        "container" {
            Write-ColorOutput "🐳 Running containerized Helm: $($Arguments -join ' ')" "Blue"
            $scriptPath = Join-Path $PSScriptRoot "helm-container.ps1"
            $result = & $scriptPath @Arguments
            return $result
        }
        default {
            Write-ColorOutput "❌ Helm mode not detected. Run Detect-Helm first." "Red"
            throw "Helm mode not detected"
        }
    }
}

# Function to add Helm repositories with retry logic
function Add-HelmRepo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoName,
        [Parameter(Mandatory = $true)]
        [string]$RepoUrl
    )

    $maxRetries = 3
    $retryCount = 0

    while ($retryCount -lt $maxRetries) {
        try {
            Invoke-Helm "repo", "add", $RepoName, $RepoUrl
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "✅ Added Helm repository: $RepoName" "Green"
                return $true
            }
        }
        catch {
            # Continue to retry logic
        }

        $retryCount++
        Write-ColorOutput "⚠️  Retry $retryCount/$maxRetries for repository: $RepoName" "Yellow"
        Start-Sleep -Seconds 2
    }

    Write-ColorOutput "❌ Failed to add repository after $maxRetries attempts: $RepoName" "Red"
    return $false
}

# Function to update Helm repositories
function Update-HelmRepo {
    Write-ColorOutput "📦 Updating Helm repositories..." "Yellow"
    try {
        Invoke-Helm "repo", "update"
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Helm repositories updated" "Green"
            return $true
        }
    }
    catch {
        Write-ColorOutput "⚠️  Failed to update repositories, continuing anyway..." "Yellow"
        return $true  # Don't fail the installation for this
    }
    return $true
}

# Function to install/upgrade Helm release
function Install-HelmRelease {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReleaseName,
        [Parameter(Mandatory = $true)]
        [string]$Chart,
        [Parameter(Mandatory = $true)]
        [string]$Namespace,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$AdditionalArgs
    )

    if ($Global:DryRun) {
        Write-ColorOutput "🔍 Dry-run: Validating Helm release: $ReleaseName" "Blue"
        
        $args = @("upgrade", "--install", $ReleaseName, $Chart, "--namespace", $Namespace, "--dry-run=server", "--debug") + $AdditionalArgs
        
        try {
            Invoke-Helm @args
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "✅ Dry-run validation successful: $ReleaseName" "Green"
                return $true
            }
            else {
                Write-ColorOutput "❌ Dry-run validation failed: $ReleaseName" "Red"
                return $false
            }
        }
        catch {
            Write-ColorOutput "❌ Dry-run validation failed: $ReleaseName" "Red"
            return $false
        }
    }
    else {
        Write-ColorOutput "🚀 Installing/upgrading Helm release: $ReleaseName" "Blue"

        $args = @("upgrade", "--install", $ReleaseName, $Chart, "--namespace", $Namespace) + $AdditionalArgs

        try {
            Invoke-Helm @args
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "✅ Successfully deployed: $ReleaseName" "Green"
                return $true
            }
            else {
                Write-ColorOutput "❌ Failed to deploy: $ReleaseName" "Red"
                return $false
            }
        }
        catch {
            Write-ColorOutput "❌ Failed to deploy: $ReleaseName" "Red"
            return $false
        }
    }
}

# Function to uninstall Helm release
function Uninstall-HelmRelease {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReleaseName,
        [Parameter(Mandatory = $true)]
        [string]$Namespace
    )

    # Check if release exists
    try {
        Invoke-Helm "status", $ReleaseName, "-n", $Namespace 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "🗑️  Uninstalling Helm release: $ReleaseName" "Yellow"
            Invoke-Helm "uninstall", $ReleaseName, "-n", $Namespace
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "✅ Successfully uninstalled: $ReleaseName" "Green"
                return $true
            }
            else {
                Write-ColorOutput "❌ Failed to uninstall: $ReleaseName" "Red"
                return $false
            }
        }
    }
    catch {
        Write-ColorOutput "⚠️  Helm release not found, skipping: $ReleaseName" "Yellow"
        return $true
    }
}

# Function to prepare containerized Helm (pull images if needed)
function Initialize-ContainerizedHelm {
    if ($Global:HELM_MODE -eq "container") {
        Write-ColorOutput "📦 Preparing containerized Helm environment..." "Yellow"
        $scriptPath = Join-Path $PSScriptRoot "helm-container.ps1"
        try {
            & $scriptPath --pull-images
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "✅ Containerized Helm ready" "Green"
                return $true
            }
            else {
                Write-ColorOutput "❌ Failed to prepare containerized Helm" "Red"
                return $false
            }
        }
        catch {
            Write-ColorOutput "❌ Failed to prepare containerized Helm" "Red"
            return $false
        }
    }
    return $true
}

# Function to show Helm mode information
function Show-HelmInfo {
    Write-ColorOutput "🔍 Helm Configuration:" "Blue"
    switch ($Global:HELM_MODE) {
        "local" {
            Write-ColorOutput "  Mode: Local Helm installation" "Green"
            try {
                $version = Invoke-Helm "version", "--short"
                Write-Host "  $version"
            }
            catch {
                Write-Host "  Version information unavailable"
            }
        }
        "container" {
            Write-ColorOutput "  Mode: Containerized Helm" "Blue"
            Write-ColorOutput "  Image: $HELM_IMAGE" "Blue"
            Write-ColorOutput "  Note: Requires Docker to be running" "Yellow"
        }
        default {
            Write-ColorOutput "  Mode: Not detected" "Red"
        }
    }
    Write-Host ""
}