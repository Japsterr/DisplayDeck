$ErrorActionPreference = "Stop"

function Test-Endpoint {
    param (
        [string]$Name,
        [string]$Url,
        [string]$Method = "GET",
        [hashtable]$Body = @{},
        [hashtable]$Headers = @{}
    )

    Write-Host "Testing $Name..." -NoNewline
    try {
        $params = @{
            Uri = $Url
            Method = $Method
            ContentType = "application/json"
            ErrorAction = "Stop"
        }
        if ($Body.Count -gt 0) {
            $params.Body = $Body | ConvertTo-Json -Depth 10
        }
        if ($Headers.Count -gt 0) {
            $params.Headers = $Headers
        }

        $response = Invoke-RestMethod @params
        Write-Host " OK" -ForegroundColor Green
        return $response
    } catch {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Host "Error: $_"
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader $_.Exception.Response.GetResponseStream()
            $responseBody = $reader.ReadToEnd()
            Write-Host "Response Body: $responseBody"
        }
        return $null
    }
}

# 1. Health Check
Test-Endpoint -Name "Health Check" -Url "http://localhost:80/api/health"

# 2. Register
$rand = Get-Random
$email = "testuser$rand@example.com"
$password = "password123"
$orgName = "Test Org $rand"

Write-Host "`nRegistering user: $email"
$registerBody = @{
    OrganizationName = $orgName
    Email = $email
    Password = $password
}
$registerResponse = Test-Endpoint -Name "Register" -Url "http://localhost:80/api/auth/register" -Method "POST" -Body $registerBody

# 3. Login
Write-Host "`nLogging in user: $email"
$loginBody = @{
    Email = $email
    Password = $password
}
$loginResponse = Test-Endpoint -Name "Login" -Url "http://localhost:80/api/auth/login" -Method "POST" -Body $loginBody

if ($loginResponse -and $loginResponse.token) {
    $token = $loginResponse.token
    Write-Host "Token received: $($token.Substring(0, 10))..." -ForegroundColor Cyan

    # 4. Get Organization (Protected)
    # Assuming there is an endpoint to get org details or similar. 
    # Based on logs: Endpoints: /health, /organizations, /organizations/{id}
    # Let's try to list organizations (might need admin?) or get current user info if available.
    # Since I don't know the exact protected endpoint for "me", I'll try /organizations which is listed.
    # NOTE: Using X-Auth-Token to avoid Indy "Unsupported authorization scheme" error with Bearer auth.
    
    Test-Endpoint -Name "Get Organizations" -Url "http://localhost:80/api/organizations" -Headers @{ "X-Auth-Token" = $token }
} else {
    Write-Host "Login failed or no token returned." -ForegroundColor Red
}
