<#
.SYNOPSIS
    Common utility functions shared across PowerShell scripts.

.DESCRIPTION
    This module provides common utility functions used by multiple PowerShell scripts
    in the Cloud Native LGTM Stack project. It includes functions for output formatting,
    command testing, and other shared functionality.

.NOTES
    This is a utility module meant to be imported by other PowerShell scripts.
    Functions provided:
    - Write-ColorOutput: Outputs colored text messages
    - Test-Command: Tests if a command is available
#>

function Write-ColorOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [ValidateSet("Red", "Green", "Yellow", "Blue", "White")]
        [string]$ForegroundColor = "White"
    )
    # save the current color
    $fc = $host.UI.RawUI.ForegroundColor

    # set the new color
    $host.UI.RawUI.ForegroundColor = $ForegroundColor

    Write-Output $Message

    # restore the original color
    $host.UI.RawUI.ForegroundColor = $fc
}

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