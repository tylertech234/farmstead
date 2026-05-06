#Requires -Version 5.1
<##
.SYNOPSIS
    Wrapper for .working service configurator.
.DESCRIPTION
    Allows running service configuration from repo root:
      .\scripts\Configure-FarmsteadServices.ps1
    It forwards all arguments to the legacy service configurator in .working.
#>

[CmdletBinding()]
param(
    [switch]$NonInteractive,
    [ValidateSet('x86_64', 'arm64')]
    [string]$TargetArchitecture
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$Target = Join-Path $RepoRoot '.working\scripts\Configure-MeetstackServices.ps1'

if (-not (Test-Path $Target)) {
    throw "Target script not found: $Target"
}

& $Target @PSBoundParameters
