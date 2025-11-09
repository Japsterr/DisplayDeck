Param(
  [string]$BaseUrl = 'http://localhost:2001',
  [string]$FilePath = "$PSScriptRoot/sample-upload.bin"
)

function Ensure-SampleFile {
  param([string]$Path)
  if (-not (Test-Path $Path)) {
    $bytes = New-Object byte[] 1048576 # 1 MB
    (New-Object Random).NextBytes($bytes)
    [IO.File]::WriteAllBytes($Path, $bytes)
  }
}

Write-Host "BaseUrl=$BaseUrl" -ForegroundColor Cyan
Ensure-SampleFile -Path $FilePath
$ContentLength = (Get-Item $FilePath).Length
$ContentType = 'application/octet-stream'

# 1) Register + Login
$uniq = Get-Date -Format 'yyyyMMddHHmmssfff'
$email = "upload+$uniq@acme.test"
$reg = Invoke-RestMethod -Method Post -Uri "$BaseUrl/auth/register" -Body (@{ Email=$email; Password='P@ssw0rd!'; OrganizationName=$uniq } | ConvertTo-Json) -ContentType 'application/json' -UseBasicParsing
$login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/auth/login" -Body (@{ Email=$email; Password='P@ssw0rd!' } | ConvertTo-Json) -ContentType 'application/json' -UseBasicParsing
$token = ([string]$login.Token) -replace "\s",""
$orgId = [int]$login.User.OrganizationId
Write-Host "TokenLen=$($token.Length) OrgId=$orgId" -ForegroundColor Yellow

# 2) Request presigned upload URL
$req = @{ OrganizationId=$orgId; FileName=(Split-Path $FilePath -Leaf); FileType=$ContentType; ContentLength=$ContentLength } | ConvertTo-Json
$upload = Invoke-RestMethod -Method Post -Uri "$BaseUrl/media-files/upload-url" -Body $req -ContentType 'application/json' -Headers @{ 'X-Auth-Token' = $token } -UseBasicParsing
if (-not $upload.Success) { throw "Upload URL error: $($upload.Message)" }
Write-Host "MediaFileId=$($upload.MediaFileId)" -ForegroundColor Green

# 3) PUT the file to MinIO via pre-signed URL
$uploadUrl = [string]$upload.UploadUrl
Write-Host "PUT $uploadUrl" -ForegroundColor Cyan
Invoke-WebRequest -Method Put -Uri $uploadUrl -InFile $FilePath -ContentType $ContentType -UseBasicParsing | Out-Null
Write-Host "Upload complete" -ForegroundColor Green

# 4) Get a download URL and validate
$dl = Invoke-RestMethod -Method Get -Uri "$BaseUrl/media-files/$($upload.MediaFileId)/download-url" -Headers @{ 'X-Auth-Token' = $token } -UseBasicParsing
if (-not $dl.Success) { throw "Download URL error: $($dl.Message)" }
Write-Host "DownloadUrl: $($dl.DownloadUrl)" -ForegroundColor Green

# Optionally fetch a few bytes to verify accessibility
$tmp = Join-Path $env:TEMP ("dl-" + [IO.Path]::GetRandomFileName())
Invoke-WebRequest -Uri $dl.DownloadUrl -OutFile $tmp -UseBasicParsing
Write-Host "Downloaded size: $((Get-Item $tmp).Length) bytes" -ForegroundColor Green
Remove-Item $tmp -Force

Write-Host "Media upload test PASSED" -ForegroundColor Green
