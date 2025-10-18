param([string]$BaseUrl='http://localhost:2001')
$uniq = Get-Date -Format 'yyyyMMddHHmmssfff'
$email = "camp+$uniq@acme.test"
$pwd = 'P@ssw0rd!'
$reg = Invoke-RestMethod -Method Post -Uri "$BaseUrl/auth/register" -Body (@{ Email=$email; Password=$pwd; OrganizationName=$uniq } | ConvertTo-Json) -ContentType 'application/json' -UseBasicParsing
$t = [string]$reg.Token; $t = $t -replace "\s", ''
$orgId = $reg.User.OrganizationId
$hdrs = @{ 'X-Auth-Token' = $t }
$camp = Invoke-RestMethod -Method Post -Uri "$BaseUrl/organizations/$orgId/campaigns?access_token=$t" -Body (@{ Name='Welcome'; Orientation='Landscape' } | ConvertTo-Json) -ContentType 'application/json' -Headers $hdrs -UseBasicParsing
Write-Host "Created campaign Id=$($camp.Id)" -ForegroundColor Yellow
$cg = Invoke-RestMethod -Uri "$BaseUrl/campaigns/$($camp.Id)" -UseBasicParsing
$cg | ConvertTo-Json -Depth 6