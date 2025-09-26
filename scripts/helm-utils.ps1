# Helm Utilities - Detect and use Helm (local or containerized)
# FOR: Internal use by install/uninstall scripts
# USAGE: . .\helm-utils.ps1

# Script-scoped variable to track Helm mode
$script:HELM_MODE = ""

# Function to write colored output
function Write-ColorOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    Write-Output $Message
}

# Function to detect Helm availability
function Test-Helm {
    # Check for Helm first
    try {
        $helmVersion = helm version --short 2>$null
        if ($LASTEXITCODE -eq 0) {
            $script:HELM_MODE = "local"
            Write-ColorOutput "✅ Helm found locally: $helmVersion"
            return $true
        }
    }
    catch {
        # Helm not found locally - continue to check Docker
        Write-ColorOutput "⚠️  Helm not found locally, checking for Docker..."
    }

    # Check for Docker
    try {
        docker info 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $script:HELM_MODE = "container"
            Write-ColorOutput "🐳 Docker detected, will use containerized Helm"
            return $true
        }
    }
    catch {
        # Docker not found - continue to final check
        Write-ColorOutput "⚠️  Docker not found, checking if available..."
    }

    $script:HELM_MODE = "none"
    Write-ColorOutput "❌ Neither Helm nor Docker found"
    Write-ColorOutput "💡 Please install either Helm or Docker to continue"
    return $false
}

# Function to run Helm command (local or containerized)
function Invoke-Helm {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    switch ($script:HELM_MODE) {
        "local" {
            Write-ColorOutput "🔧 Running local Helm: helm $($Arguments -join ' ')"
            $result = & helm @Arguments
            return $result
        }
        "container" {
            Write-ColorOutput "🐳 Running containerized Helm: $($Arguments -join ' ')"
            $scriptPath = Join-Path $PSScriptRoot "helm-container.ps1"
            $result = & $scriptPath @Arguments
            return $result
        }
        default {
            Write-ColorOutput "❌ Helm mode not detected. Run Test-Helm first."
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
                Write-ColorOutput "✅ Added Helm repository: $RepoName"
                return $true
            }
        }
        catch {
            # Continue to retry logic - this is expected
            Write-ColorOutput "⚠️  Repository add failed, will retry..."
        }

        $retryCount++
        Write-ColorOutput "⚠️  Retry $retryCount/$maxRetries for repository: $RepoName"
        Start-Sleep -Seconds 2
    }

    Write-ColorOutput "❌ Failed to add repository after $maxRetries attempts: $RepoName"
    return $false
}

# Function to update Helm repositories
function Update-HelmRepo {
    Write-ColorOutput "📦 Updating Helm repositories..."
    try {
        Invoke-Helm "repo", "update"
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Helm repositories updated"
            return $true
        }
    }
    catch {
        Write-ColorOutput "⚠️  Failed to update repositories, continuing anyway..."
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
        [Parameter(Mandatory = $false)]
        [bool]$DryRun = $false,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$AdditionalArgs
    )

    if ($DryRun) {
        Write-ColorOutput "🔍 Dry-run: Validating Helm release: $ReleaseName"
        
        $helmArgs = @("upgrade", "--install", $ReleaseName, $Chart, "--namespace", $Namespace, "--dry-run=server", "--debug") + $AdditionalArgs
        
        try {
            Invoke-Helm @helmArgs
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "✅ Dry-run validation successful: $ReleaseName"
                return $true
            }
            else {
                Write-ColorOutput "❌ Dry-run validation failed: $ReleaseName"
                return $false
            }
        }
        catch {
            Write-ColorOutput "❌ Dry-run validation failed: $ReleaseName"
            return $false
        }
    }
    else {
        Write-ColorOutput "🚀 Installing/upgrading Helm release: $ReleaseName"

        $helmArgs = @("upgrade", "--install", $ReleaseName, $Chart, "--namespace", $Namespace) + $AdditionalArgs

        try {
            Invoke-Helm @helmArgs
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "✅ Successfully deployed: $ReleaseName"
                return $true
            }
            else {
                Write-ColorOutput "❌ Failed to deploy: $ReleaseName"
                return $false
            }
        }
        catch {
            Write-ColorOutput "❌ Failed to deploy: $ReleaseName"
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
            Write-ColorOutput "🗑️  Uninstalling Helm release: $ReleaseName"
            Invoke-Helm "uninstall", $ReleaseName, "-n", $Namespace
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "✅ Successfully uninstalled: $ReleaseName"
                return $true
            }
            else {
                Write-ColorOutput "❌ Failed to uninstall: $ReleaseName"
                return $false
            }
        }
    }
    catch {
        Write-ColorOutput "⚠️  Helm release not found, skipping: $ReleaseName"
        return $true
    }
}

# Function to prepare containerized Helm (pull images if needed)
function Initialize-ContainerizedHelm {
    if ($script:HELM_MODE -eq "container") {
        Write-ColorOutput "📦 Preparing containerized Helm environment..."
        $scriptPath = Join-Path $PSScriptRoot "helm-container.ps1"
        try {
            & $scriptPath --pull-images
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "✅ Containerized Helm ready"
                return $true
            }
            else {
                Write-ColorOutput "❌ Failed to prepare containerized Helm"
                return $false
            }
        }
        catch {
            Write-ColorOutput "❌ Failed to prepare containerized Helm"
            return $false
        }
    }
    return $true
}

# Function to show Helm mode information
function Show-HelmInfo {
    Write-ColorOutput "🔍 Helm Configuration:"
    switch ($script:HELM_MODE) {
        "local" {
            Write-ColorOutput "  Mode: Local Helm installation"
            try {
                $version = Invoke-Helm "version", "--short"
                Write-Output "  $version"
            }
            catch {
                Write-Output "  Version information unavailable"
            }
        }
        "container" {
            Write-ColorOutput "  Mode: Containerized Helm"
            Write-ColorOutput "  Image: $HELM_IMAGE"
            Write-ColorOutput "  Note: Requires Docker to be running"
        }
        default {
            Write-ColorOutput "  Mode: Not detected"
        }
    }
    Write-Output ""
}