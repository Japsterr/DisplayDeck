<div align="center">

	<img src="docs/assets/displaydeck-logo.png" alt="DisplayDeck" width="420" />

</div>

# DisplayDeck API

Backend API for DisplayDeck, a digital signage SaaS. Linux-first, Dockerized stack: PostgreSQL + MinIO + Delphi WebBroker server, with Swagger UI.

## Stack

- **Backend**:
  - Language: Delphi (Object Pascal)
  - Server: Delphi WebBroker + Indy (Linux console app)
  - DB: PostgreSQL (Docker)
  - Object storage: MinIO (S3-compatible, Docker)
  - Auth: JWT (HS256)
  - Docs: OpenAPI 3.0 at `docs/openapi.yaml` served by Swagger UI container
- **Frontend (Website/Dashboard)**:
  - Framework: Next.js 16 (React 19)
  - UI: Tailwind CSS, Shadcn UI
  - Drag & Drop: @hello-pangea/dnd

## Quick start (local)

Prereqs: Docker Desktop, Git. For building the server binary, Delphi with Linux toolchain.

If you don’t have the Linux toolchain set up locally anymore, you can use the included Dockerized PAServer instead (see `paserver/README.md`).

1) Clone and enter

```powershell
git clone https://github.com/Japsterr/DisplayDeck.git
cd DisplayDeck
```

2) Build the Linux server binary (from Windows IDE or the provided script)

```powershell
c:\DisplayDeck\build_linux.bat
```

Alternative (no local Linux toolchain): Dockerized PAServer

- Put `PAServer-Linux-64.tar.gz` into `paserver/` and start PAServer:

```powershell
docker compose down -v
docker compose up -d --build paserver
```

- Configure RAD Studio to connect to PAServer at `127.0.0.1:49999` (password `displaydeck`) and build the Linux64 target.
- Ensure the output binary exists at `Server/Linux/DisplayDeck.WebBroker`.

3) Bring up the stack (DB, MinIO, server, Swagger UI)

```powershell
# optional: copy .env.example to .env and adjust
Copy-Item .env.example .env -Force
# pin the server image version (defaults to latest if unset)
$env:SERVER_TAG = '0.1.7'
docker compose --env-file .env up -d postgres minio server swagger-ui
```

From a completely fresh slate (no containers/volumes):

```powershell
docker compose down -v
docker compose up -d --build
```

- API base: http://localhost:2001
- Swagger UI: http://localhost:8080

Run tests (optional):

```powershell
tests\pairing-tests.ps1
```

## Environment

Server reads configuration from env vars (see `.env.example`):

- DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
- MINIO_ENDPOINT, MINIO_ACCESS_KEY, MINIO_SECRET_KEY, MINIO_REGION, MINIO_PUBLIC_ENDPOINT
- JWT_SECRET (required)
- SERVER_DEBUG (default "false"; gates debug endpoints)
- SIGV4_DEBUG (default "false"; prints SigV4 canonical request when true)
- SERVER_TAG (image tag used by compose; defaults to `latest` if unset)
- APP_VERSION (optional; surfaced in dashboard as "UI build")

The compose file `docker-compose.yml` sets sane defaults. Override via environment or an `.env` file.
Key overrides:

- `SERVER_TAG` controls the server image tag used.
- `MINIO_PUBLIC_ENDPOINT` controls the hostname used in pre-signed URLs (default `http://localhost:9000`).
- `SIGV4_DEBUG` toggles extra SigV4 logging.

## Try a local copy (prebuilt 0.1.7)

Use the prebuilt image to test media upload/download quickly:

```powershell
cd C:\DisplayDeck
Copy-Item .env.example .env -Force
$env:SERVER_TAG = '0.1.7'
docker compose --env-file .env pull server
docker compose --env-file .env up -d postgres minio server swagger-ui
cd tests
./media-upload-download.ps1
```

Expected result: the script reports PUT/GET 200 and `Media upload/download SUCCESS`.

## Base URL + Auth

- **Base URL**: The server supports both root-level and `/api` prefixed routes.
  - Local: `http://localhost:2001` or `http://localhost:2001/api`
  - Production: `http://api.displaydeck.co.za` or `http://api.displaydeck.co.za/api`
- **Authentication**:
  - All protected endpoints require a JWT.
  - Header: `Authorization: Bearer <token>`

## API overview

Key routes (full spec in `docs/openapi.yaml`):

- Health: GET `/health`
- Auth: POST `/auth/register`, POST `/auth/login`
- Orgs: GET/POST `/organizations`, GET `/organizations/{id}`, GET `/organizations/{OrganizationId}/subscription`
- Displays: GET/POST `/organizations/{OrganizationId}/displays`, GET/PUT/DELETE `/displays/{Id}`
- Campaigns: GET/POST `/organizations/{OrganizationId}/campaigns`, GET/PUT/DELETE `/campaigns/{Id}`
- Campaign Items: GET/POST `/campaigns/{CampaignId}/items`, GET/PUT/DELETE `/campaign-items/{Id}`
- Assignments: GET/POST `/displays/{DisplayId}/campaign-assignments`, PUT/DELETE `/campaign-assignments/{Id}`
- Media: POST `/media-files/upload-url`, GET `/media-files/{MediaFileId}/download-url`, GET `/media-files/{Id}`, PUT `/media-files/{Id}`
- Device: POST `/device/provisioning/token`, POST `/device/config`, POST `/device/logs`
- Plans & Roles: GET `/plans`, GET `/roles`
- Playback Logs: POST `/playback-logs`

Timestamps: use `yyyy-MM-ddTHH:mm:ss` (ISO-8601 local) for inputs.

## Swagger UI

Swagger UI is served from the `swagger-ui` container and points to `docs/openapi.yaml`:

- Start it: `docker compose up -d swagger-ui`
- Open: http://localhost:8080

## Production Deployment

### Option A: VPS (Standard)

To deploy on a VPS with your domain (`displaydeck.co.za`):

1.  **DNS Setup**: Point the following A records to your server's IP:
    -   `api.displaydeck.co.za`
    -   `minio.displaydeck.co.za`
    -   `console.displaydeck.co.za`
    -   `docs.displaydeck.co.za`

2.  **Environment**:
    -   Copy `.env.example` to `.env`.
    -   Set a strong `JWT_SECRET`.
    -   Set `MINIO_ACCESS_KEY` and `MINIO_SECRET_KEY` to strong values.
    -   Set `SERVER_TAG` to the desired version (e.g., `latest` or `0.1.7`).

3.  **Run**:
    Use the production compose file which includes an Nginx reverse proxy:

    ```powershell
    docker compose --env-file .env -f docker-compose.prod.yml up -d
    ```

    This will start:
    -   **Nginx** (listening on port 80, routing by hostname)
    -   **Server** (internal port 2001)
    -   **MinIO** (internal ports 9000/9001)
    -   **Postgres** (internal port 5432)
    -   **Swagger UI** (internal port 8080)

4.  **Access**:
    -   API: `http://api.displaydeck.co.za`
    -   MinIO Console: `http://console.displaydeck.co.za`
    -   Docs: `http://docs.displaydeck.co.za`

    *Note: The provided configuration uses HTTP on port 80. For HTTPS, you should configure SSL certificates (e.g., using Certbot) in the `nginx/nginx.conf` file.*

### Option B: Home Hosting (Cloudflare Tunnel)

If you are hosting from a home PC (dynamic IP, no open ports), use **Cloudflare Tunnel**.

1.  **Cloudflare Setup**:
    -   Move your domain's nameservers to Cloudflare (Free).
    -   Go to **Zero Trust > Access > Tunnels**.
    -   Create a new tunnel and get the `TUNNEL_TOKEN`.
  -   In the Public Hostnames tab, if you want to use **only `displaydeck.co.za`**:
    -   `displaydeck.co.za` -> `http://nginx:80`
    -   `www.displaydeck.co.za` -> `http://nginx:80` (optional)

  With this setup, Nginx routes services by path on the same domain:
  - API: `https://displaydeck.co.za/api/...`
  - MinIO API: `https://displaydeck.co.za/minio/...`
  - Swagger UI: `https://displaydeck.co.za/swagger/`

  If you prefer subdomains instead, you can still map:
  - `api.displaydeck.co.za` -> `http://nginx:80`
  - `minio.displaydeck.co.za` -> `http://nginx:80`
  - `console.displaydeck.co.za` -> `http://nginx:80`
  - `docs.displaydeck.co.za` -> `http://nginx:80`

  #### Troubleshooting: Cloudflare Tunnel Error 1033

  Cloudflare **Error 1033** (“Tunnel error / unable to resolve”) almost always means Cloudflare has **no active connector** for the tunnel (cloudflared is stopped, crashed, or has an invalid/expired token).

  On the host machine running DisplayDeck:

  1) Verify the cloudflared container is running

  Linux/macOS:

  ```bash
  docker ps --format "table {{.Names}}\t{{.Status}}" | grep -i tunnel
  ```

  Windows PowerShell:

  ```powershell
  docker ps --format "table {{.Names}}\t{{.Status}}" | Select-String -Pattern tunnel
  ```

  2) Check cloudflared logs for token/auth issues

  ```bash
  docker logs displaydeck-tunnel --tail 200
  ```

  3) Confirm `TUNNEL_TOKEN` is set in your `.env`, then restart the tunnel

  ```bash
  docker compose --env-file .env -f docker-compose.prod.yml -f docker-compose.tunnel.yml up -d tunnel
  ```

  In Cloudflare Zero Trust:

  - Go to **Zero Trust → Networks → Tunnels** and confirm the tunnel shows a healthy/connected connector.
  - If the tunnel token was rotated or the tunnel was deleted/recreated, update `.env` with the new `TUNNEL_TOKEN` and restart.

  #### Troubleshooting: “I don’t see dashboard/UI changes”

  The **website** container is built from the `website/` folder. If you pull new code but don’t rebuild, you will keep serving the old UI (e.g. you’ll only see the "Classic" template).

  Rebuild/restart the stack:

  ```powershell
  # with tunnel
  docker compose --env-file .env -f docker-compose.prod.yml -f docker-compose.tunnel.yml up -d --build

  # without tunnel
  docker compose --env-file .env -f docker-compose.prod.yml up -d --build
  ```

  After deploying, open any menu editor page and confirm it shows `UI build: ...` under the Template selector.

  #### Database migrations (existing DB volumes)

  For existing databases (non-fresh volumes), apply migrations from `migrations/`.

  ```powershell
  docker compose --env-file .env -f docker-compose.prod.yml --profile migrate up --abort-on-container-exit db-migrate
  ```

2.  **Run**:
    Set your token in `.env` (`TUNNEL_TOKEN=...`) and run:

    ```powershell
    docker compose --env-file .env -f docker-compose.prod.yml -f docker-compose.tunnel.yml up -d
    ```

    This starts the stack + the secure tunnel. No port forwarding required.

## Publishing the container image

Because the server binary is compiled with Delphi, the simplest approach is to build and push the image from your dev machine.

### Push to GitHub Container Registry (GHCR)

1) Create a GitHub Personal Access Token with `write:packages`.
2) Login:

```powershell
echo $Env:GITHUB_TOKEN | docker login ghcr.io -u <YOUR_GH_USERNAME> --password-stdin
```

3) Build and tag:

```powershell
docker compose build server
docker tag displaydeck-server:latest ghcr.io/<YOUR_GH_USERNAME>/displaydeck-server:latest
```

4) Push:

```powershell
docker push ghcr.io/<YOUR_GH_USERNAME>/displaydeck-server:latest
```

Update `docker-compose.prod.yml` to point to your image (owner and tag), then deploy with the prod compose file.

Notes about GitHub Actions in this repo:

- The GH runners cannot compile Delphi. Two workflows exist under `.github/workflows/`:
	- `docker-publish.yml` includes a check for the presence of `Server/Linux/DisplayDeck.WebBroker` and skips image publish if missing.
	- `docker-ghcr.yml` builds and pushes on `master`. It now performs the same check and skips if the Linux binary is not present in the repo.
- To have CI publish images automatically, either:
	- Commit the prebuilt `Server/Linux/DisplayDeck.WebBroker` binary (not generally recommended), or
	- Adjust the workflow to download the binary from a Release asset, or
	- Use a self-hosted runner that can build the binary.

### Push to Docker Hub (alternative)

```powershell
docker login
docker tag displaydeck-server:latest <your-dockerhub-username>/displaydeck-server:latest
docker push <your-dockerhub-username>/displaydeck-server:latest
```

## Notes for Delphi/Linux builds

- This project targets Linux. Ensure your Linux SDK is installed in RAD Studio and `build_linux.bat` works on your machine.
- The server image is Debian-based and already includes required runtime libs (libpq, SSL, krb5, etc.).

## Troubleshooting

### Media delivery: how it works (and why)

There are three distinct ways media may be accessed depending on *who* is consuming it:

- **Dashboard uploads (browser)**: the dashboard calls `POST /media-files/upload-url` to get a presigned PUT URL, then uploads directly to object storage.
- **Authenticated downloads (dashboard)**: the dashboard calls `GET /media-files/{id}/download-url` and uses that signed URL to download/preview.
- **Public menu rendering (players)**: public menu pages avoid embedding raw object-storage URLs in the page.
  Instead, menu image references are resolved to a same-origin proxy route on the website.

Why the proxy for public menus?

- Older Android WebViews and some locked-down networks are fragile with cross-origin fetches.
- Signed URLs are host/header-sensitive (SigV4). If a client “rewrites” hostnames, signatures can break.

See the dedicated notes in docs:

- docs/media-delivery.md

### Production: `/minio/` proxy and CORS

In production, Nginx proxies object storage under the main domain:

- MinIO API via path: `https://displaydeck.co.za/minio/...`

This exists primarily to make **browser PUT uploads** work consistently. The Nginx `/minio/` location adds CORS headers and preserves the `Host` header.

If uploads fail in the browser:

- Confirm the presigned upload URL host matches what the client uses (don’t rewrite it).
- Confirm `MINIO_PUBLIC_ENDPOINT` is set correctly for the public-facing hostname.
- Confirm Nginx `/minio/` is enabled and includes CORS headers.

- **Website Build Errors (React 19)**:
  - The project uses React 19, which may cause peer dependency conflicts with some libraries (like `@hello-pangea/dnd`).
  - The `Dockerfile` for the website uses `npm ci --legacy-peer-deps` to resolve this.
  - If running locally, use `npm install --legacy-peer-deps`.

- 404/preview issues in Media Library after upgrades:
	- If media records exist but the underlying object was never uploaded or has been removed from MinIO, thumbnails and previews may fail.
	- As of 0.1.6, `/media-files/{id}/download-url` is robust against endpoint changes in `StorageURL`, but it cannot recover missing objects.
	- Remedies:
		- Delete the orphan records via UI or `DELETE /media-files/{id}` and re-upload.
		- Re-upload the file to the expected `StorageURL` path in the bucket.
	- Tip: Use `tests\media-upload-download.ps1` to validate presigned PUT/GET end-to-end.

## Orientation (since 0.1.7)

Media files now carry an `Orientation` (`Landscape` or `Portrait`).

Server side:
- Schema: `MediaFiles.Orientation VARCHAR(20) DEFAULT 'Landscape'`.
- Endpoints include `Orientation` in create/upload-url response, list and get JSON.
- `PUT /media-files/{Id}` accepts `Orientation` for metadata updates.

Desktop app behavior:
- Uploads show a confirmation dialog: Yes = Landscape, No = Portrait; default is Landscape.
- Previous bitmap auto-detect logic was removed for broader Delphi compiler compatibility.
- Orientation can be edited after upload in the Media Library via a combo box (Save persists changes).

Upgrades:
- Existing databases: apply `migrations/2025-11-10_add_orientation.sql` or run an `ALTER TABLE` if column missing.
- Fresh installs: `schema.sql` already contains the column.

---

## Menu Builder (since 0.1.9)

Phase 1 adds dynamic menu boards (menus → sections → items) and allows campaigns to include menu items.

Database upgrades:
- Existing databases: apply `migrations/2025-12-29_add_menus.sql`.
- Fresh installs: `schema.sql` already includes menu tables + constraints.

Important note for Docker deployments:
- The Postgres container only runs `schema.sql` on *first* initialization of the data volume.
- For existing volumes, you must run the migration SQL against the running database.

Testing:
- Use `tests\media-upload-download.ps1` to confirm round-trip; script now validates the `Orientation` field.

Edge cases:
- Missing orientation in client update calls defaults to existing value.
- Invalid orientation strings are coerced server-side to `Landscape` if unsupported (future hard validation may return 400).

---

Made with Delphi. Contributions welcome via PR.
