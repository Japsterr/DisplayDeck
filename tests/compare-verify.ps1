param([string]$BaseUrl='http://localhost:2001')
$uniq = Get-Date -Format 'yyyyMMddHHmmssfff'
$email = "cv+$uniq@acme.test"
$password = 'P@ssw0rd!'
$org = $uniq
$reg = Invoke-RestMethod -Method Post -Uri "$BaseUrl/auth/register" -Body (@{ Email=$email; Password=$password; OrganizationName=$org } | ConvertTo-Json) -ContentType 'application/json' -UseBasicParsing
$regToken = [string]$reg.Token; $regToken = $regToken -replace "\s", ''
$login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/auth/login" -Body (@{ Email=$email; Password=$password } | ConvertTo-Json) -ContentType 'application/json' -UseBasicParsing
$loginToken = [string]$login.Token; $loginToken = $loginToken -replace "\s", ''

$regV = Invoke-RestMethod -Method Post -Uri "$BaseUrl/auth/debug-verify" -Body (@{ Token=$regToken } | ConvertTo-Json) -ContentType 'application/json' -UseBasicParsing
$loginV = Invoke-RestMethod -Method Post -Uri "$BaseUrl/auth/debug-verify" -Body (@{ Token=$loginToken } | ConvertTo-Json) -ContentType 'application/json' -UseBasicParsing

Write-Host "Reg Match=$($regV.Match) Login Match=$($loginV.Match)" -ForegroundColor Yellow
Write-Host ("Reg Expected[0..15]={0} Actual[0..15]={1}" -f $regV.ExpectedSigB64.Substring(0,16), $regV.ActualSigB64.Substring(0,16))
Write-Host ("Login Expected[0..15]={0} Actual[0..15]={1}" -f $loginV.ExpectedSigB64.Substring(0,16), $loginV.ActualSigB64.Substring(0,16))
