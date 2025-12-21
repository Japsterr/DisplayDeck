<div align="center">

	<img src="docs/assets/displaydeck-logo.png" alt="DisplayDeck" width="420" />

</div>

# DisplayDeck API

Backend API for DisplayDeck, a digital signage SaaS. Linux-first, Dockerized stack: PostgreSQL + MinIO + Delphi WebBroker server, with Swagger UI.

## Stack

- Language: Delphi (Object Pascal)
- Server: Delphi WebBroker + Indy (Linux console app)
- DB: PostgreSQL (Docker)
- Object storage: MinIO (S3-compatible, Docker)
- Auth: JWT (HS256)
- Docs: OpenAPI 3.0 at `docs/openapi.yaml` served by Swagger UI container

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

## Out-of-the-box deployment

If you prefer to run without building locally, use the production compose override and a prebuilt image:

1) Copy `.env.example` to `.env` and set a strong `JWT_SECRET`.
2) Use `docker-compose.prod.yml` (references a prebuilt image):

```powershell
docker compose --env-file .env -f docker-compose.prod.yml up -d
```

Note: Until you publish the image to a registry, you can still run locally by building it:

```powershell
docker compose build server
docker compose up -d server
```

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

Testing:
- Use `tests\media-upload-download.ps1` to confirm round-trip; script now validates the `Orientation` field.

Edge cases:
- Missing orientation in client update calls defaults to existing value.
- Invalid orientation strings are coerced server-side to `Landscape` if unsupported (future hard validation may return 400).

---

Made with Delphi. Contributions welcome via PR.
