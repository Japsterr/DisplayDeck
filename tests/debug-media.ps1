param(
  [string]$BaseUrl = 'http://localhost:2001',
  [string]$Token
)

if (-not $Token) {
    $Token = Get-Content -Path (Join-Path $PSScriptRoot 'last-token.txt') -ErrorAction SilentlyContinue
}

if (-not $Token) {
    Write-Error "No token provided or found in last-token.txt"
    exit 1
}

$headers = @{ "X-Auth-Token" = $Token }
$body = @{
    OrganizationId = 14
    FileName = "test-image.jpg"
    FileType = "image/jpeg"
    ContentLength = 1024
    Orientation = "Landscape"
} | ConvertTo-Json

Write-Host "Requesting upload URL..."
try {
    $response = Invoke-RestMethod -Method Post -Uri "$BaseUrl/media-files/upload-url" -Headers $headers -Body $body -ContentType "application/json"
    Write-Host "Upload URL Response:"
    $response | Format-List
    
    $uploadUrl = $response.UploadUrl
    Write-Host "Got URL: $uploadUrl"
    
    # Try to upload dummy data to this URL (ignoring CORS since this is PowerShell)
    # This verifies if the URL is reachable and valid from the machine
    Write-Host "Attempting upload to generated URL..."
    $dummyContent = "x" * 1024
    try {
        Invoke-RestMethod -Method Put -Uri $uploadUrl -Body $dummyContent -ContentType "image/jpeg"
        Write-Host "Upload successful!" -ForegroundColor Green
    } catch {
        Write-Error "Upload failed: $_"
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            Write-Host "Response Body: $($reader.ReadToEnd())"
        }
    }

} catch {
    Write-Error "Failed to get upload URL: $_"
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        Write-Host "Response Body: $($reader.ReadToEnd())"
    }
}
