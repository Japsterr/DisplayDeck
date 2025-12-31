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

## Email Verification + Password Reset

### Backend Endpoints

- `POST /auth/resend-verification` `{ "Email": "user@example.com" }`
- `POST /auth/verify-email` `{ "Token": "..." }`
- `POST /auth/forgot-password` `{ "Email": "user@example.com" }`
- `POST /auth/reset-password` `{ "Token": "...", "Password": "newpass" }`

Notes:
- `resend-verification` and `forgot-password` always return 200 to avoid account enumeration.
- Tokens are stored hashed in the DB and are one-time-use.

### Environment Variables

- `PUBLIC_WEB_URL` – base URL used when generating links in emails (e.g. `https://displaydeck.co.za`).
- `AUTH_REQUIRE_EMAIL_VERIFICATION` – when `true`, `/auth/login` returns 403 `email_not_verified` until verified.
- SMTP (optional; if `SMTP_HOST` is blank the server logs the email contents instead of sending):
  - `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM`, `SMTP_SECURE` (`none|starttls|ssl`)
