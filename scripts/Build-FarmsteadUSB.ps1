#Requires -Version 5.1
<##
.SYNOPSIS
    Wrapper for .working USB builder.
.DESCRIPTION
    Allows running from repo root:
      .\scripts\Build-FarmstackUSB.ps1
#>

[CmdletBinding()]
param(
    [string]$UbuntuVersion = '24.04.1',
    [string]$IsoPath,
    [switch]$SkipChecksum,
    [string]$RequiredDriveLetter,
    [int]$DownloadTimeoutSec = 1800,
    [int]$DownloadRetries = 3
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$Target = Join-Path $RepoRoot '.working\scripts\Build-FarmstackUSB.ps1'

if (-not (Test-Path $Target)) {
    throw "Target script not found: $Target"
}

& $Target @PSBoundParameters
