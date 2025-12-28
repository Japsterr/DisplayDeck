$ErrorActionPreference = "Stop"

# 1. Login to get token
$loginUrl = "http://localhost:80/api/auth/login"
$body = @{
    Email = "testuser@example.com" # Assuming this user exists from previous run, or I'll register a new one if needed.
    Password = "password123"
}

# I'll just register a new user to be safe
$rand = Get-Random
$email = "testuser$rand@example.com"
$registerBody = @{
    OrganizationName = "Test Org $rand"
    Email = $email
    Password = "password123"
}
Write-Host "Registering $email..."
try {
    Invoke-RestMethod -Uri "http://localhost:80/api/auth/register" -Method POST -Body ($registerBody | ConvertTo-Json) -ContentType "application/json" | Out-Null
} catch {
    Write-Host "Register failed (maybe already exists): $_"
}

Write-Host "Logging in..."
try {
    $loginBody = @{ Email = $email; Password = "password123" }
    $resp = Invoke-RestMethod -Uri $loginUrl -Method POST -Body ($loginBody | ConvertTo-Json) -ContentType "application/json"
    $token = $resp.token
    Write-Host "Token: $($token.Substring(0,10))..."
} catch {
    Write-Host "Login failed: $_"
    exit 1
}

# 2. Test with X-Auth-Token
Write-Host "Testing GET /organizations with X-Auth-Token..."
try {
    $headers = @{ "X-Auth-Token" = $token }
    $orgs = Invoke-RestMethod -Uri "http://localhost:80/api/organizations" -Method GET -Headers $headers
    Write-Host "Success!" -ForegroundColor Green
    $orgs | ConvertTo-Json -Depth 5 | Write-Host
} catch {
    Write-Host "Failed!" -ForegroundColor Red
    Write-Host "Error: $_"
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader $_.Exception.Response.GetResponseStream()
        Write-Host "Body: $($reader.ReadToEnd())"
    }
}
