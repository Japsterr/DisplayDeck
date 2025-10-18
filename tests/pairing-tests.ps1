param([string]$BaseUrl = 'http://localhost:2001')

function Invoke-JsonPost($url, $obj, $headers=$null) {
  $json = $obj | ConvertTo-Json -Depth 6
  if ($null -ne $headers) {
    return Invoke-RestMethod -Method Post -Uri $url -Body $json -ContentType 'application/json' -Headers $headers -UseBasicParsing
  } else {
    return Invoke-RestMethod -Method Post -Uri $url -Body $json -ContentType 'application/json' -UseBasicParsing
  }
}

# Register user and get token/org
$uniq = Get-Date -Format 'yyyyMMddHHmmssfff'
$email = "pair+$uniq@acme.test"
$reg = Invoke-JsonPost "$BaseUrl/auth/register" @{ Email=$email; Password='P@ssw0rd!'; OrganizationName=$uniq }
$token = [string]$reg.Token; $token = $token -replace "\s", ''
$orgId = $reg.User.OrganizationId
$headers = @{ 'X-Auth-Token' = $token }

# Device requests provisioning token with hardware id
$prov = Invoke-JsonPost "$BaseUrl/device/provisioning/token" @{ HardwareId = "HW-$uniq" }
if (-not $prov.ProvisioningToken) { throw "Failed to get provisioning token" }

# Account claims device for organization
$claim = Invoke-JsonPost "$BaseUrl/organizations/$orgId/displays/claim?access_token=$token" @{ ProvisioningToken = $prov.ProvisioningToken; Name = 'Kiosk'; Orientation = 'Landscape' } $headers
if (-not $claim.Id) { throw "Failed to claim device" }

# Confirm display appears in list
$list = Invoke-RestMethod -Uri "$BaseUrl/organizations/$orgId/displays?access_token=$token" -Headers $headers -UseBasicParsing
if (-not ($list.value | Where-Object { $_.Id -eq $claim.Id })) { throw "Claimed display not in list" }

Write-Host "Pairing test passed: DisplayId=$($claim.Id)" -ForegroundColor Green
