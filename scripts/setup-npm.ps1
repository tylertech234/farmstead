# Setup Nginx Proxy Manager proxy hosts for all meetstack services
param(
    [string]$NpmUrl = "http://localhost:${env:NPM_ADMIN_PORT}",
    [string]$Email,
    [string]$Password
)

# Load .env defaults for port if not set
if (-not $env:NPM_ADMIN_PORT) { $NpmUrl = "http://localhost:8181" }

Write-Host "=== Setting up Nginx Proxy Manager ===" -ForegroundColor Cyan

if (-not $Email) { $Email = Read-Host "NPM admin email" }
if (-not $Password) {
    $secPw = Read-Host "NPM admin password" -AsSecureString
    $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secPw))
}

# Login
$loginBody = @{identity=$Email; secret=$Password} | ConvertTo-Json -Compress
$loginResp = Invoke-WebRequest -Uri "$NpmUrl/api/tokens" -Method Post -Body $loginBody -ContentType "application/json" -UseBasicParsing -ErrorAction SilentlyContinue
if (-not $loginResp -or $loginResp.StatusCode -ne 200) {
    Write-Host "ERROR: Could not login to NPM. Is it running?" -ForegroundColor Red
    exit 1
}
$token = ($loginResp.Content | ConvertFrom-Json).token
Write-Host "Logged in to NPM" -ForegroundColor Green

# Services to proxy
$services = @(
    @{domain="n8n.localhost"; host="n8n"; port=5678},
    @{domain="chat.localhost"; host="open-webui"; port=8080},
    @{domain="tasks.localhost"; host="vikunja"; port=3456},
    @{domain="wiki.localhost"; host="wikijs"; port=3000},
    @{domain="calendar.localhost"; host="radicale"; port=5232},
    @{domain="whisper.localhost"; host="whisper"; port=9000}
)

foreach ($svc in $services) {
    $body = (@{
        domain_names = @($svc.domain)
        forward_scheme = "http"
        forward_host = $svc.host
        forward_port = $svc.port
        block_exploits = $true
        allow_websocket_upgrade = $true
        access_list_id = 0
        certificate_id = 0
        meta = @{letsencrypt_agree=$false; dns_challenge=$false}
        advanced_config = ""
        locations = @()
        hsts_enabled = $false
        hsts_subdomains = $false
        ssl_forced = $false
        http2_support = $false
    } | ConvertTo-Json -Depth 5 -Compress)

    $r = Invoke-WebRequest -Uri "$NpmUrl/api/nginx/proxy-hosts" -Method Post -Body $body -ContentType "application/json" -Headers @{Authorization="Bearer $token"} -UseBasicParsing -ErrorAction SilentlyContinue
    $resp = $r.Content | ConvertFrom-Json
    if ($resp.id) {
        Write-Host "  OK  $($svc.domain) -> $($svc.host):$($svc.port)" -ForegroundColor Green
    } else {
        Write-Host "  FAIL $($svc.domain): $($resp.error.message)" -ForegroundColor Yellow
    }
}

Write-Host "`nProxy hosts configured. Access services at:" -ForegroundColor Cyan
Write-Host "  NPM Admin:  $NpmUrl"
Write-Host "  n8n:        http://n8n.localhost"
Write-Host "  Open WebUI: http://chat.localhost"
Write-Host "  Vikunja:    http://tasks.localhost"
Write-Host "  Wiki.js:    http://wiki.localhost"
Write-Host "  Radicale:   http://calendar.localhost"
Write-Host "  Whisper:    http://whisper.localhost"
