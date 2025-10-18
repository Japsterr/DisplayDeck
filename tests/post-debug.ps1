param(
  [string]$BaseUrl = 'http://localhost:2001'
)

# Register and login to get a fresh token
$uniq = Get-Date -Format 'yyyyMMddHHmmssfff'
$email = "curl+$uniq@acme.test"
$reg = Invoke-RestMethod -Method Post -Uri "$BaseUrl/auth/register" -Body (@{ Email=$email; Password='P@ssw0rd!'; OrganizationName=$uniq } | ConvertTo-Json) -ContentType 'application/json' -UseBasicParsing
$login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/auth/login" -Body (@{ Email=$email; Password='P@ssw0rd!' } | ConvertTo-Json) -ContentType 'application/json' -UseBasicParsing
$token = [string]$login.Token; $token = $token -replace "\s", ''
$orgId = $login.User.OrganizationId

Write-Host "TokenLen=$($token.Length) OrgId=$orgId" -ForegroundColor Yellow

# Server-side debug verify
$verify = Invoke-RestMethod -Method Post -Uri "$BaseUrl/auth/debug-verify" -Body (@{ Token = $token } | ConvertTo-Json) -ContentType 'application/json' -UseBasicParsing
Write-Host ("Verify Match={0} ExpectedSigB64[0..15]={1} ActualSigB64[0..15]={2}" -f $verify.Match, $verify.ExpectedSigB64.Substring(0,16), $verify.ActualSigB64.Substring(0,16))

# Debug headers echo
$headers = @{ 'X-Auth-Token' = $token }
$echo = Invoke-RestMethod -UseBasicParsing -Headers $headers -Uri ("$BaseUrl/debug/headers?access_token=" + $token)
Write-Host "Echo: Authorization=[$($echo.Authorization)] X-Auth-Token.len=$(($echo.'X-Auth-Token').Length) Query.len=$(($echo.QueryAccessToken).Length)"

# Try POST create display using curl with header and query token
$bodyJson = '{"Name":"Lobby","Orientation":"Landscape"}'
& curl.exe -v -H ("X-Auth-Token: $token") -H "Content-Type: application/json" -d $bodyJson "$BaseUrl/organizations/$orgId/displays?access_token=$token"
