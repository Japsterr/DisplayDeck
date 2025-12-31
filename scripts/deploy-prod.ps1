param(
  [switch]$WithTunnel,
  [switch]$RunMigrations
)

$ErrorActionPreference = 'Stop'

if (!(Test-Path -Path '.env')) {
  Write-Host "Missing .env in repo root. Copy .env.example to .env and set required values." -ForegroundColor Yellow
}

$composeFiles = @('-f', 'docker-compose.prod.yml')

# By default, bring up the Cloudflare tunnel on prod when a token is configured.
$tunnelToken = $env:TUNNEL_TOKEN
if (-not $tunnelToken -and (Test-Path -Path '.env')) {
  try {
    $tunnelToken = (Get-Content .env | Where-Object { $_ -match '^\s*TUNNEL_TOKEN\s*=' } | Select-Object -First 1)
  } catch {
    $tunnelToken = $null
  }
}

if ($WithTunnel -or ($tunnelToken -and ($tunnelToken -notmatch '^\s*TUNNEL_TOKEN\s*=\s*$'))) {
  $composeFiles += @('-f', 'docker-compose.tunnel.yml')
}

Write-Host "Rebuilding and restarting containers..." -ForegroundColor Cyan
& docker compose --env-file .env @composeFiles up -d --build

if ($RunMigrations) {
  Write-Host "Running DB migrations..." -ForegroundColor Cyan
  & docker compose --env-file .env @composeFiles --profile migrate up --abort-on-container-exit db-migrate
}

Write-Host "Done. If you still see old UI, hard-refresh the browser and verify the Menu Editor shows 'UI build: ...' under Template." -ForegroundColor Green
