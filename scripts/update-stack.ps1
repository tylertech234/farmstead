<#
.SYNOPSIS
    Update the Farmstead Docker Compose stack.

.DESCRIPTION
    Pulls latest images, recreates containers, and prunes old images.

.PARAMETER Gpu
    Include docker-compose.gpu.yml overlay for NVIDIA GPU passthrough.

.PARAMETER DryRun
    Show what would be pulled without making changes.

.EXAMPLE
    .\scripts\update-stack.ps1
    .\scripts\update-stack.ps1 -Gpu
    .\scripts\update-stack.ps1 -DryRun
#>
param(
    [switch]$Gpu,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Push-Location (Split-Path $PSScriptRoot)

try {
    # ── Build compose command ─────────────────────────────────────────────
    $composeFiles = @("-f", "docker-compose.yml")
    if ($Gpu) {
        $composeFiles += @("-f", "docker-compose.gpu.yml")
    }

    Write-Host ""
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host "  Farmstead Update" -ForegroundColor Cyan
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host ""

    # ── Step 1: Pull latest images ────────────────────────────────────────
    Write-Host ">> Pulling latest images..." -ForegroundColor Yellow
    if ($DryRun) {
        Write-Host "  (dry-run) Would pull:" -ForegroundColor DarkGray
        $images = docker compose @composeFiles config --images 2>$null
        $images | Sort-Object | ForEach-Object { Write-Host "  - $_" -ForegroundColor DarkGray }
        Write-Host ""
        Write-Host "Dry run complete. No changes made." -ForegroundColor Green
        return
    }

    docker compose @composeFiles pull
    if ($LASTEXITCODE -ne 0) { throw "Failed to pull images" }
    Write-Host ""

    # ── Step 2: Recreate containers ───────────────────────────────────────
    Write-Host ">> Recreating containers..." -ForegroundColor Yellow
    docker compose @composeFiles up -d
    if ($LASTEXITCODE -ne 0) { throw "Failed to recreate containers" }
    Write-Host ""

    # ── Step 3: Wait for health checks ────────────────────────────────────
    Write-Host ">> Waiting for containers to become healthy..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    docker compose @composeFiles ps
    Write-Host ""

    # ── Step 4: Prune old images ──────────────────────────────────────────
    Write-Host ">> Pruning unused images..." -ForegroundColor Yellow
    docker image prune -f
    Write-Host ""

    # ── Done ──────────────────────────────────────────────────────────────
    Write-Host "===========================================================" -ForegroundColor Green
    Write-Host "  Update complete!" -ForegroundColor Green
    Write-Host "===========================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Run 'docker compose ps' to verify all services are healthy."
}
finally {
    Pop-Location
}
