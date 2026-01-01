# DisplayDeck integration status (Dec 28, 2025)

This note summarizes the current “server ↔ OpenAPI ↔ tests ↔ clients” alignment and the remaining integration risks.

## What’s aligned now

- **Single REST server contract**: the Linux WebBroker server in `Server/Linux/WebModuleMain.pas` is the authoritative router.
- **Optional `/api` prefix**: server routing tolerates both `/...` and `/api/...` so the Manager and Mobile client base URLs work consistently.
- **FMX assignment route matches server**: the Mobile app uses `POST /displays/{DisplayId}/campaign-assignments` (the implemented route).
- **OpenAPI spec repaired + reconciled**: `docs/openapi.yaml` is structurally valid again (no accidental nesting/indentation issues) and matches:
  - `API_DOCUMENTATION.md`
  - the PowerShell scripts under `tests/`
  - server behavior for `201` create responses and public `/auth/*` endpoints.
- **XData-era artifacts removed**: the old XData/Sparkle-style server/client prototypes and stale `/tms/xdata` URL references were removed.
- **Production Deployment Prep**: Docker Compose configurations for production with Nginx reverse proxy are being finalized.
- **Website Integration**: Added Next.js frontend (`website/`) to the stack, served via Nginx on `displaydeck.co.za`.
- **CORS + uploads**: Nginx includes CORS headers on `/minio/` so browsers can PUT directly to presigned MinIO URLs.

## Recent Fixes (Dec 28, 2025)

- **Docker Build**: Switched `server` to local build (avoiding GHCR auth issues) and updated `website` to Node 20 (Next.js 15 requirement).
- **Next.js Output**: Enabled `standalone` output in `next.config.ts` for optimized Docker images.
- **React 19 Compatibility**:
  - Issue: `npm ci` failed due to peer dependency conflicts between React 19 and `@hello-pangea/dnd` (which expects React 18).
  - Fix: Updated `website/Dockerfile` to use `npm ci --legacy-peer-deps`.

## Remaining integration risks / inconsistencies

1) **Auth enforcement consistency (medium risk)**
- Server accepts multiple token delivery mechanisms (Bearer, `X-Auth-Token`, and `access_token` query param). This is convenient but increases attack surface and makes “what is protected” harder to reason about.
- Recommendation: pick one canonical mechanism (`Authorization: Bearer`) and deprecate the others (or keep only for device provisioning with strict scope).

2) **Presigned MinIO URL host/signature behavior (medium risk)**
- SigV4 presigned URLs depend on the host/header used during signing.
- If a client “rewrites” `http://minio:9000/...` to `http://localhost:9000/...`, the signature can become invalid.
- **Mitigation**: In production, `MINIO_PUBLIC_ENDPOINT` should be set to the actual domain (e.g., `https://minio.displaydeck.co.za`).

Additional mitigation (recommended for players):

- Public menu pages resolve `media:<id>` references to a same-origin website proxy (`/public-media/...`) to avoid cross-origin quirks on older Android WebViews.

3) **Client configuration drift (low/medium risk)**
- Clients persist base URL/token state locally; this can mask environment issues (e.g., one client points at `/api`, another at root).
- Recommendation: document the expected base URL and the `/api` behavior in one place (README or API docs), and keep client defaults consistent.

4) **Delphi project dependencies vs “legacy removal” (low risk)**
- Project files still reference packages like `sparkle`, `aurelius`, and some TMS UI packages in `DCC_UsePackage` lists.
- These are not the removed XData server stack; they’re dependency declarations for IDE/build.
- Recommendation: only remove these if you’re actively standardizing dependencies; otherwise leave as-is.

5) **Repository hygiene: build artifacts (low risk, but high noise)**
- `.o` object files were previously tracked; they change frequently and create noisy diffs.
- Recommendation: keep artifacts out of git (ignore + remove from index), and rely on source + reproducible builds.

## Suggested next steps (practical)

- [x] Add a short “**Base URL + Auth**” section to the main README.
- [ ] If you want the OpenAPI spec to be a stricter contract, we can:
  - add/verify `security` requirements per-path (not just globally)
  - add response schemas for common error bodies (401/403/404)
  - ensure every path used by tests has an operationId and documented request bodies.

