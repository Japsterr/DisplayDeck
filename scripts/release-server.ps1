param(
  [string]$Version
)
$ErrorActionPreference = 'Stop'

# Determine version
if (-not $Version -and (Test-Path -Path "$PSScriptRoot\..\VERSION")) {
  $Version = (Get-Content "$PSScriptRoot\..\VERSION" -Raw).Trim()
}
if (-not $Version) {
  Write-Error "No version specified and VERSION file missing. Provide -Version X.Y.Z or create VERSION file."
}

# Paths
$repoRoot = Resolve-Path "$PSScriptRoot\.."
Set-Location $repoRoot

# 1) Build Linux binary
Write-Host "[1/4] Building Linux server binary..." -ForegroundColor Cyan
cmd /c build_linux.bat

# 2) Build Docker image
$image = "ghcr.io/japsterr/displaydeck-server:$Version"
Write-Host "[2/4] Building Docker image: $image" -ForegroundColor Cyan
docker build -f Dockerfile.server -t $image .

# 3) Tag as latest as well
$latest = "ghcr.io/japsterr/displaydeck-server:latest"
Write-Host "[3/4] Tagging also as: $latest" -ForegroundColor Cyan
try { docker image rm $latest | Out-Null } catch {}
docker tag $image $latest

# 4) Push both tags
Write-Host "[4/4] Pushing $image and $latest to GHCR" -ForegroundColor Cyan
docker push $image
docker push $latest

Write-Host "Release complete: $image" -ForegroundColor Green
