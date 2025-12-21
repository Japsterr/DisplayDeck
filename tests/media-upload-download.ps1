param(
  [string]$BaseUrl = 'http://localhost:2001/api',
  [string]$Email = 'media_tester@example.com',
  [string]$Password = 'VerySecure123!'
)
$ErrorActionPreference = 'Stop'

function Write-Step($msg,[ConsoleColor]$color=[ConsoleColor]::Cyan){
  $orig = $Host.UI.RawUI.ForegroundColor
  $Host.UI.RawUI.ForegroundColor = $color
  Write-Host $msg
  $Host.UI.RawUI.ForegroundColor = $orig
}

try {
  Write-Step 'Auth: login/register' 
  $loginBody = @{ Email=$Email; Password=$Password } | ConvertTo-Json
  try {
    $login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/auth/login" -ContentType 'application/json' -Body $loginBody
  } catch {
    Write-Step ("Login failed, registering user: " + $_.Exception.Message) 'Yellow'
    $regBody = @{ Email=$Email; Password=$Password; OrganizationName='MediaTest Org' } | ConvertTo-Json
    $null = Invoke-RestMethod -Method Post -Uri "$BaseUrl/auth/register" -ContentType 'application/json' -Body $regBody
    $login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/auth/login" -ContentType 'application/json' -Body $loginBody
  }
  $token = $login.Token
  $orgId = $login.User.OrganizationId
  if (-not $token) { throw 'No accessToken in login response' }
  Write-Step ("Token acquired (len=$($token.Length))")

  Write-Step 'Requesting upload-url (Orientation=Landscape)'
  $uploadReq = @{ OrganizationId=$orgId; FileName='test-image.png'; FileType='image/png'; Orientation='Landscape'; ContentLength=95 } | ConvertTo-Json
  $uploadInfo = Invoke-RestMethod -Method Post -Uri "$BaseUrl/media-files/upload-url" -Headers @{ 'X-Auth-Token' = $token } -ContentType 'application/json' -Body $uploadReq
  $mediaId = $uploadInfo.MediaFileId
  $putUrl = $uploadInfo.UploadUrl
  if (-not $putUrl) { throw 'No uploadUrl returned' }
  Write-Step ("mediaId=$mediaId")
  Write-Step ("PUT host=" + ([uri]$putUrl).Host)

  Write-Step 'Preparing 1x1 PNG'
  $pngBytes = [byte[]](137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82,0,0,0,1,0,0,0,1,8,6,0,0,0,31,21,196,137,0,0,0,12,73,68,65,84,8,153,99,96,0,0,0,2,0,1,226,39,53,213,0,0,0,0,73,69,78,68,174,66,96,130)
  $tmpFile = Join-Path $PSScriptRoot 'test-image.png'
  [IO.File]::WriteAllBytes($tmpFile,$pngBytes)

  Write-Step 'PUT to pre-signed URL'
  $putResp = Invoke-WebRequest -Method Put -Uri $putUrl -InFile $tmpFile -ContentType 'image/png' -TimeoutSec 30 -UseBasicParsing
  Write-Step ("PUT status=$($putResp.StatusCode)") 'Green'

  Write-Step 'Requesting download-url'
  $downloadInfo = Invoke-RestMethod -Method Get -Uri "$BaseUrl/media-files/$mediaId/download-url" -Headers @{ 'X-Auth-Token' = $token }
  $getUrl = $downloadInfo.downloadUrl
  if (-not $getUrl) { throw 'No downloadUrl returned' }

  Write-Step 'Verifying media details include Orientation=Landscape'
  $media = Invoke-RestMethod -Method Get -Uri "$BaseUrl/media-files/$mediaId" -Headers @{ 'X-Auth-Token' = $token }
  if ($media.Orientation -ne 'Landscape') { throw "Unexpected Orientation: $($media.Orientation)" }

  Write-Step 'GET object via download-url'
  $getResp = Invoke-WebRequest -Method Get -Uri $getUrl -TimeoutSec 30 -UseBasicParsing
  Write-Step ("GET status=$($getResp.StatusCode) len=$($getResp.Content.Length)") 'Green'

  if ($getResp.StatusCode -eq 200 -and $getResp.Content.Length -gt 0) {
    Write-Step 'Media upload/download SUCCESS' 'Green'
    exit 0
  } else {
    Write-Step 'Media upload/download FAILED' 'Red'
    exit 2
  }
} catch {
  Write-Step ("ERROR: " + $_.Exception.Message) 'Red'
  if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message }
  exit 1
}
