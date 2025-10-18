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

1) Clone and enter

```powershell
git clone https://github.com/Japsterr/DisplayDeck.git
cd DisplayDeck
```

2) Build the Linux server binary (from Windows IDE or the provided script)

```powershell
c:\DisplayDeck\build_linux.bat
```

3) Bring up the stack (DB, MinIO, server, Swagger UI)

```powershell
docker compose up -d postgres minio server swagger-ui
```

- API base: http://localhost:2001
- Swagger UI: http://localhost:8080

Run tests (optional):

```powershell
.\n+tests\smoke-tests.ps1
tests\pairing-tests.ps1
```

## Environment

Server reads configuration from env vars (see `.env.example`):

- DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
- MINIO_ENDPOINT, MINIO_ACCESS_KEY, MINIO_SECRET_KEY, MINIO_REGION
- JWT_SECRET (required)
- SERVER_DEBUG (default "false"; gates debug endpoints)

The compose file `docker-compose.yml` sets sane defaults. Override via environment or an `.env` file.

## API overview

Key routes (full spec in `docs/openapi.yaml`):

- Health: GET `/health`
- Auth: POST `/auth/register`, POST `/auth/login`
- Orgs: GET/POST `/organizations`, GET `/organizations/{id}`, GET `/organizations/{OrganizationId}/subscription`
- Displays: GET/POST `/organizations/{OrganizationId}/displays`, GET/PUT/DELETE `/displays/{Id}`
- Campaigns: GET/POST `/organizations/{OrganizationId}/campaigns`, GET/PUT/DELETE `/campaigns/{Id}`
- Campaign Items: GET/POST `/campaigns/{CampaignId}/items`, GET/PUT/DELETE `/campaign-items/{Id}`
- Assignments: GET/POST `/displays/{DisplayId}/campaign-assignments`, PUT/DELETE `/campaign-assignments/{Id}`
- Media: POST `/media-files/upload-url`, GET `/media-files/{MediaFileId}/download-url`
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

### Push to Docker Hub (alternative)

```powershell
docker login
docker tag displaydeck-server:latest <your-dockerhub-username>/displaydeck-server:latest
docker push <your-dockerhub-username>/displaydeck-server:latest
```

## Notes for Delphi/Linux builds

- This project targets Linux. Ensure your Linux SDK is installed in RAD Studio and `build_linux.bat` works on your machine.
- The server image is Debian-based and already includes required runtime libs (libpq, SSL, krb5, etc.).

---

Made with Delphi. Contributions welcome via PR.
