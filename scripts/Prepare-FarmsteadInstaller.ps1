#Requires -Version 5.1
<##
.SYNOPSIS
    Wrapper for .working installer preparation flow.
.DESCRIPTION
    Allows running the deployment prep command from repo root as:
      .\scripts\Prepare-FarmsteadInstaller.ps1
    It forwards all arguments to the legacy installer-preparation script in
    .working.
#>

[CmdletBinding()]
param(
    [string]$ExistingPublicKeyPath,
    [string]$TailscaleAuthKey,
    [switch]$RandomPassword,
    [switch]$ForceRefresh,
    [switch]$SkipServiceConfig,
    [switch]$NonInteractiveServiceConfig,
    [ValidateSet('x86_64', 'arm64')]
    [string]$TargetArchitecture
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$Target = Join-Path $RepoRoot '.working\scripts\Prepare-MeetstackInstaller.ps1'

if (-not (Test-Path $Target)) {
    throw "Target script not found: $Target"
}

& $Target @PSBoundParameters
