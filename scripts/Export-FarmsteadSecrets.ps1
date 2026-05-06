#Requires -Version 5.1
<#
.SYNOPSIS
    Export all Farmstead secrets to a secure backup archive.
.DESCRIPTION
    Wrapper for the legacy secret-export script in .working.
#>

param(
    [string]$OutputPath
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir
$Target    = Join-Path $RepoRoot '.working\scripts\Export-MeetstackSecrets.ps1'

& $Target @PSBoundParameters
