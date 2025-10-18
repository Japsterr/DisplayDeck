param(
  [string]$BaseUrl = 'http://localhost:2001'
)

$uniq = Get-Date -Format 'yyyyMMddHHmmss'
$email = "dbg+$uniq@acme.test"
$regBody = @{ Email=$email; Password='P@ssw0rd!'; OrganizationName='Dbg' } | ConvertTo-Json
Write-Host "Registering $email"
$reg = Invoke-RestMethod -Method Post -Uri "$BaseUrl/auth/register" -Body $regBody -ContentType 'application/json'
$token = $reg.Token
Write-Host "Token:" -NoNewline; Write-Host " $token" -ForegroundColor Yellow

$dbgBody = @{ Token = $token } | ConvertTo-Json
$dbg = Invoke-RestMethod -Method Post -Uri "$BaseUrl/auth/debug-verify" -Body $dbgBody -ContentType 'application/json'
Write-Host "Debug verify:"; $dbg | Format-List | Out-String | Write-Host

"$token" | Out-File -FilePath (Join-Path $PSScriptRoot 'last-token.txt') -Encoding ascii