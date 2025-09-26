<#
.SYNOPSIS
    Helm utility functions for detecting and using Helm (local or containerized).

.DESCRIPTION
    This module provides utility functions to detect Helm availability,
    run Helm commands (either locally or in containers), manage repositories,
    and perform Helm operations with automatic environment detection.

.NOTES
    This is a utility module meant to be imported by other PowerShell scripts.
    It provides functions for:
    - Test-Helm: Detects Helm or Docker availability
    - Invoke-Helm: Runs Helm commands (local or containerized)
    - Add-HelmRepo: Adds Helm repositories with retry logic
    - Install-HelmRelease: Installs/upgrades Helm releases
    - Show-HelmInfo: Displays current Helm configuration
#>

# Import common utilities
$commonUtilsPath = Join-Path $PSScriptRoot "Common-Utils.ps1"
. $commonUtilsPath

$script:HELM_MODE = ""

function Test-Helm {
    try {
        $helmVersion = helm version --short 2>$null
        if ($LASTEXITCODE -eq 0) {
            $script:HELM_MODE = "local"
            Write-ColorOutput "✅ Helm found locally: $helmVersion"
            return $true
        }
    }
    catch {
        Write-ColorOutput "⚠️  Helm not found locally, checking for Docker..."
    }
    try {
        docker info 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $script:HELM_MODE = "container"
            Write-ColorOutput "🐳 Docker detected, will use containerized Helm"
            return $true
        }
    }
    catch {
        Write-ColorOutput "⚠️  Docker not found, checking if available..." "Red"
    }

    $script:HELM_MODE = "none"
    Write-ColorOutput "❌ Neither Helm nor Docker found" "Red"
    Write-ColorOutput "💡 Please install either Helm or Docker to continue" "Yellow"
    return $false
}

function Invoke-Helm {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    switch ($script:HELM_MODE) {
        "local" {
            Write-ColorOutput "🔧 Running local Helm: helm $($Arguments -join ' ')" "Blue"
            $result = & helm @Arguments
            return $result
        }
        "container" {
            Write-ColorOutput "🐳 Running containerized Helm: $($Arguments -join ' ')"
            $scriptPath = Join-Path $PSScriptRoot "Helm-Container.ps1"
            & $scriptPath @Arguments | Out-Null
            $global:LASTEXITCODE = $LASTEXITCODE
        }
        default {
            Write-ColorOutput "❌ Helm mode not detected. Run Test-Helm first." "Red"
            throw "Helm mode not detected"
        }
    }
}

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
            # Continue to retry logic - this is expected
            Write-ColorOutput "⚠️  Repository add failed, will retry..."
        }

        $retryCount++
        Write-ColorOutput "⚠️  Retry $retryCount/$maxRetries for repository: $RepoName"
        Start-Sleep -Seconds 2
    }

    Write-ColorOutput "❌ Failed to add repository after $maxRetries attempts: $RepoName" "Red"
    return $false
}

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
        Write-ColorOutput "⚠️  Failed to update repositories, continuing anyway..."
        return $true  # Don't fail the installation for this
    }
    return $true
}

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
        Write-ColorOutput "🚀 Installing/upgrading Helm release: $ReleaseName" "Green"

        $helmArgs = @("upgrade", "--install", $ReleaseName, $Chart, "--namespace", $Namespace) + $AdditionalArgs

        try {
            Invoke-Helm @helmArgs
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

function Initialize-ContainerizedHelm {
    if ($script:HELM_MODE -eq "container") {
        Write-ColorOutput "📦 Preparing containerized Helm environment..." "Yellow"
        $scriptPath = Join-Path $PSScriptRoot "Helm-Container.ps1"
        try {
            & $scriptPath -PullImages
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

function Show-HelmInfo {
    Write-ColorOutput "🔍 Helm Configuration:" "Blue"
    switch ($script:HELM_MODE) {
        "local" {
            Write-ColorOutput "  Mode: Local Helm installation" "Green"
            try {
                $version = Invoke-Helm "version", "--short"
                Write-Output "  $version"
            }
            catch {
                Write-Output "  Version information unavailable"
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
    Write-Output ""
}