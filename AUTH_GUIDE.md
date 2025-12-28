# Authentication Guide

## Important: Use `X-Auth-Token` Header

The backend server uses a component (Indy) that has strict handling of the `Authorization` header.
To avoid "Unsupported authorization scheme" errors, please use the `X-Auth-Token` header for authenticated requests instead of `Authorization: Bearer ...`.

### Example (JavaScript/TypeScript)

```typescript
const response = await fetch('/api/organizations', {
  headers: {
    'Content-Type': 'application/json',
    'X-Auth-Token': token // Use this instead of Authorization
  }
});
```

### Example (PowerShell)

```powershell
Invoke-RestMethod -Uri "..." -Headers @{ "X-Auth-Token" = $token }
```

## API Proxying

The Next.js configuration has been updated to proxy `/api` requests to the backend server (`http://server:2001`).
This ensures that API calls work correctly even when accessing the website directly on port 3000.
