$ErrorActionPreference = "Stop"

try {
    Write-Host "Testing GET /organizations WITHOUT Auth..."
    $response = Invoke-RestMethod -Uri "http://localhost:80/api/organizations" -Method GET -ErrorAction Stop
    Write-Host "Success!" -ForegroundColor Green
    $response | ConvertTo-Json -Depth 5 | Write-Host
} catch {
    Write-Host "Failed!" -ForegroundColor Red
    Write-Host "Error: $_"
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader $_.Exception.Response.GetResponseStream()
        Write-Host "Body: $($reader.ReadToEnd())"
    }
}
