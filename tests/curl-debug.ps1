$BaseUrl = 'http://localhost:2001'
$orgId = 0
if (Test-Path "$PSScriptRoot\last-orgid.txt") { $orgId = Get-Content "$PSScriptRoot\last-orgid.txt" -Raw | ForEach-Object { $_.Trim() } }
if ($orgId -eq 0) { $orgId = 1 }

$token = Get-Content "$PSScriptRoot\last-token.txt" -Raw | ForEach-Object { $_.Trim() }
Write-Host "Token length: $($token.Length)"

$url = "$BaseUrl/organizations/$orgId/displays"
& curl.exe -v -H "X-Auth-Token: $token" "$url"