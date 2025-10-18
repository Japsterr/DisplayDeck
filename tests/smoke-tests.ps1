param(
  [string]$BaseUrl = "http://localhost:2001"
)

function Invoke-JsonPost($url, $obj, $headers=$null) {
  $json = $obj | ConvertTo-Json -Depth 6
  if ($null -ne $headers) {
    return Invoke-RestMethod -Method Post -Uri $url -Body $json -ContentType 'application/json' -Headers $headers -UseBasicParsing
  } else {
    return Invoke-RestMethod -Method Post -Uri $url -Body $json -ContentType 'application/json' -UseBasicParsing
  }
}

function Write-Title($t){ Write-Host "`n=== $t ===" -ForegroundColor Cyan }

$results = @()
function Record($name, $status, $data){
  $results += [pscustomobject]@{ Name=$name; Status=$status; Data=$data }
}

try {
  Write-Title "Health"; $h = Invoke-RestMethod -Uri "$BaseUrl/health" -UseBasicParsing; Record 'health' ($h.value -eq 'OK') $h

  Write-Title "Plans"; $plans = Invoke-RestMethod -Uri "$BaseUrl/plans" -UseBasicParsing; Record 'plans' ($plans.Count -ge 1) $plans
  Write-Title "Roles"; $roles = Invoke-RestMethod -Uri "$BaseUrl/roles" -UseBasicParsing; Record 'roles' ($roles.Count -ge 1) $roles

  Write-Title "Create Organization"; $org = Invoke-JsonPost "$BaseUrl/organizations" @{ Name = 'Acme' }; Record 'org.create' ($org.Id -gt 0) $org
  Write-Title "List Organizations"; $orgs = Invoke-RestMethod -Uri "$BaseUrl/organizations" -UseBasicParsing; Record 'org.list' ($orgs.value.Count -ge 1) $orgs
  Write-Title "Get Organization"; $orgOne = Invoke-RestMethod -Uri "$BaseUrl/organizations/$($org.Id)" -UseBasicParsing; Record 'org.get' ($orgOne.Id -eq $org.Id) $orgOne

  $uniq = Get-Date -Format 'yyyyMMddHHmmssfff'
  $email = "owner+$uniq@acme.test"
  Write-Title "Auth Register"; $reg = Invoke-JsonPost "$BaseUrl/auth/register" @{ Email=$email; Password='P@ssw0rd!'; OrganizationName="Acme-$uniq" }; Record 'auth.register' ($reg.Success -eq $true -and $reg.Token) $reg
  Write-Title "Auth Login"; $login = Invoke-JsonPost "$BaseUrl/auth/login" @{ Email=$email; Password='P@ssw0rd!' }; Record 'auth.login' ($login.Success -eq $true -and $login.Token) $login
  $cleanToken = [string]$login.Token
  # remove any whitespace introduced by PowerShell formatting
  $cleanToken = $cleanToken -replace "\s", ''
  $authHeader = @{ 'X-Auth-Token' = $cleanToken }

  # Diagnostics: echo back what the server sees for headers and query token
  Write-Title "Debug Headers"; 
  $dbg = Invoke-RestMethod -Uri ("$BaseUrl/debug/headers?access_token=" + $cleanToken) -Headers $authHeader -UseBasicParsing
  Record 'debug.headers' ($null -eq $dbg.Authorization -and $null -ne $dbg.'X-Auth-Token' -and $null -ne $dbg.QueryAccessToken) $dbg

  # Use the authenticated user's organization for protected operations
  $orgIdProtected = $login.User.OrganizationId
  Write-Title "Create Display"; $disp = Invoke-JsonPost "$BaseUrl/organizations/$orgIdProtected/displays?access_token=$cleanToken" @{ Name='Lobby'; Orientation='Landscape' } $authHeader; Record 'display.create' ($disp.Id -gt 0) $disp
  Write-Title "List Displays"; $dl = Invoke-RestMethod -Uri "$BaseUrl/organizations/$orgIdProtected/displays?access_token=$cleanToken" -Headers $authHeader -UseBasicParsing; Record 'display.list' ($dl.value.Count -ge 1) $dl
  Write-Title "Get Display"; $dg = Invoke-RestMethod -Uri "$BaseUrl/displays/$($disp.Id)" -UseBasicParsing; Record 'display.get' ($dg.Id -eq $disp.Id) $dg
  Write-Title "Update Display"; $duBody = @{ Id=$disp.Id; Name='Lobby Updated'; Orientation='Portrait' } | ConvertTo-Json -Depth 4; $du = Invoke-RestMethod -Method Put -Uri "$BaseUrl/displays/$($disp.Id)" -Body $duBody -ContentType 'application/json' -UseBasicParsing; Record 'display.update' ($du.Name -eq 'Lobby Updated') $du

  Write-Title "Create Campaign"; $camp = Invoke-JsonPost "$BaseUrl/organizations/$orgIdProtected/campaigns?access_token=$cleanToken" @{ Name='Welcome'; Orientation='Landscape' } $authHeader; Record 'campaign.create' ($camp.Id -gt 0) $camp
  Write-Title "List Campaigns"; $cl = Invoke-RestMethod -Uri "$BaseUrl/organizations/$orgIdProtected/campaigns?access_token=$cleanToken" -Headers $authHeader -UseBasicParsing; Record 'campaign.list' ($cl.value.Count -ge 1) $cl
  Write-Title "Get Campaign"; $cg = Invoke-RestMethod -Uri "$BaseUrl/campaigns/$($camp.Id)" -UseBasicParsing; Record 'campaign.get' ($cg.Id -eq $camp.Id) $cg
  Write-Title "Update Campaign"; $cuBody = @{ Id=$camp.Id; Name='Welcome Updated'; Orientation='Portrait' } | ConvertTo-Json -Depth 4; $cu = Invoke-RestMethod -Method Put -Uri "$BaseUrl/campaigns/$($camp.Id)" -Body $cuBody -ContentType 'application/json' -UseBasicParsing; Record 'campaign.update' ($cu.Name -eq 'Welcome Updated') $cu

  Write-Title "Create Assignment"; $as = Invoke-JsonPost "$BaseUrl/displays/$($disp.Id)/campaign-assignments" @{ CampaignId=$camp.Id; IsPrimary=$true }; Record 'assign.create' ($as.Id -gt 0) $as
  Write-Title "List Assignments"; $al = Invoke-RestMethod -Uri "$BaseUrl/displays/$($disp.Id)/campaign-assignments" -UseBasicParsing; Record 'assign.list' ($al.value.Count -ge 1) $al
  Write-Title "Update Assignment"; $auBody = @{ Id=$as.Id; IsPrimary=$false } | ConvertTo-Json -Depth 4; $au = Invoke-RestMethod -Method Put -Uri "$BaseUrl/campaign-assignments/$($as.Id)" -Body $auBody -ContentType 'application/json' -UseBasicParsing; Record 'assign.update' ($au.IsPrimary -eq $false) $au

  # Media upload/download URLs
  Write-Title "Upload URL"; $up = Invoke-JsonPost "$BaseUrl/media-files/upload-url?access_token=$cleanToken" @{ OrganizationId=$orgIdProtected; FileName='hello.png'; FileType='image/png' } $authHeader; Record 'media.upload-url' ($up.Success -eq $true -and $up.UploadUrl) $up
  Write-Title "Download URL"; $down = Invoke-RestMethod -Uri "$BaseUrl/media-files/$($up.MediaFileId)/download-url" -UseBasicParsing; Record 'media.download-url' ($down.Success -eq $true -and $down.DownloadUrl) $down

  # Device
  Write-Title "Device Logs"; $dlr = Invoke-JsonPost "$BaseUrl/device/logs" @{ DisplayId=$disp.Id; LogType='Info'; Message='Hello'; Timestamp=(Get-Date).ToString('s')+'Z' }; Record 'device.logs' ($dlr.Success -eq $true) $dlr

  # Playback logs (204)
  Write-Title "Playback Logs"; try { Invoke-JsonPost "$BaseUrl/playback-logs" @{ DisplayId=$disp.Id; MediaFileId=$up.MediaFileId; CampaignId=$camp.Id; PlaybackTimestamp=(Get-Date).ToString('s')+'Z' } | Out-Null; Record 'playback.logs' $true $null } catch { Record 'playback.logs' $false $_ }

  # Cleanup operations
  Write-Title "Delete Assignment"; try { Invoke-RestMethod -Method Delete -Uri "$BaseUrl/campaign-assignments/$($as.Id)" -UseBasicParsing | Out-Null; Record 'assign.delete' $true $null } catch { Record 'assign.delete' $false $_ }
  Write-Title "Delete Campaign Item none"; Record 'campaign-item.delete.nop' $true $null
  Write-Title "Delete Campaign"; try { Invoke-RestMethod -Method Delete -Uri "$BaseUrl/campaigns/$($camp.Id)" -UseBasicParsing | Out-Null; Record 'campaign.delete' $true $null } catch { Record 'campaign.delete' $false $_ }
  Write-Title "Delete Display"; try { Invoke-RestMethod -Method Delete -Uri "$BaseUrl/displays/$($disp.Id)" -UseBasicParsing | Out-Null; Record 'display.delete' $true $null } catch { Record 'display.delete' $false $_ }

} catch {
  Write-Host $_ -ForegroundColor Red
}

Write-Host "`nSummary:" -ForegroundColor Yellow
$results | Format-Table -AutoSize

# Exit non-zero if any failed
if ($results | Where-Object { -not $_.Status }) { exit 1 } else { exit 0 }
