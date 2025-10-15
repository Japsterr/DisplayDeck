# DisplayDeck API

This is the backend API for DisplayDeck, a digital signage SaaS platform.

## Overview

DisplayDeck is a platform for managing and displaying digital content on various screens, such as TVs and customer-facing POS displays. This repository contains the source code for the backend API that powers the entire system.

## Technology Stack

*   **Language:** Delphi (Object Pascal)
*   **API Framework:** TMS XData
*   **Data Access:** FireDAC with PostgreSQL
*   **Database:** PostgreSQL (running in Docker)
*   **Object Storage:** MinIO (S3-compatible, running in Docker)
*   **Deployment Target:** Linux via Docker (as an Apache Module)

## Getting Started

The project is now successfully set up. The Delphi server can connect to the PostgreSQL database running in Docker.

### Prerequisites

*   Embarcadero Delphi (Architect Edition recommended for Linux deployment)
*   Docker Desktop
*   Git for version control

### Development Workflow

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/Japsterr/DisplayDeck.git
    ```
2.  **Navigate to the project directory:**
    ```bash
    cd DisplayDeck
    ```
3.  **Start Backend Services:**
    Use Docker Compose to start the PostgreSQL database.
    ```bash
    docker-compose up -d
    ```

4.  **Run the API Server:**
    The Delphi XData server project is located in the `Server/` directory. Open `Server/DisplayDeck.dproj` in the Delphi IDE, compile, and run the *Win32* Debug build. The server will start and connect to the database on first API request.

### PostgreSQL client libraries

FireDAC requires the native PostgreSQL client (`libpq.dll` and its companion DLLs). The repository includes vendor libraries under `Server/Vendor/PostgreSQL/<arch>/lib/`:

*   **Win32:** Complete PostgreSQL 16.1 client libraries from MSYS2 (11 DLLs including dependencies)
*   **Win64:** PostgreSQL 15 client libraries from official binaries (7 DLLs)

The server automatically detects the architecture and loads the appropriate vendor libraries at runtime.

## API Documentation

- Friendly REST endpoints and request/response shapes are documented in `API_DOCUMENTATION.md`.
- An OpenAPI 2.0 (Swagger) spec reflecting the friendly routes is available in `openapi.json` and uses base URL `http://localhost:2001/tms/xdata`.

### Notes on endpoints

- Health: `GET /health`
- Auth: `POST /auth/register`, `POST /auth/login`
- Organizations: `GET/POST /organizations`, `GET /organizations/{id}`, `GET /organizations/{OrganizationId}/subscription`
- Displays: `GET/POST /organizations/{OrganizationId}/displays`, `GET/PUT/DELETE /displays/{Id}`
- Campaigns: `GET/POST /organizations/{OrganizationId}/campaigns`, `GET/PUT/DELETE /campaigns/{Id}`
- Campaign Items: `GET/POST /campaigns/{CampaignId}/items`, `GET/PUT/DELETE /campaign-items/{Id}`
- Display Assignments: `GET/POST /displays/{DisplayId}/campaign-assignments`, `PUT/DELETE /campaign-assignments/{Id}`
- Media: `POST /media-files/upload-url`, `GET /media-files/{MediaFileId}/download-url`
- Device: `POST /device/config`, `POST /device/logs`
- Plans & Roles: `GET /plans`, `GET /roles`
- Playback Logs: `POST /playback-logs`

Timestamp format: For all TDateTime JSON inputs, use `yyyy-MM-ddTHH:mm:ss` (no timezone suffix).

## Swagger UI (Docker)

You can browse the API using Swagger UI served from Docker:

1. Ensure `docs/openapi.friendly.json` exists (already committed).
2. Start services:

```powershell
docker-compose up -d swagger-ui
```

Then open: http://localhost:8080

## Run the API in Docker (Linux)

This repository now includes a containerized Linux build target for the API. Windows development remains unchanged.

- Pre-requisite: Build the Linux server binary via RAD Studio to `Server/Linux/Release/DisplayDeck`.
- Then run:

```powershell
docker-compose up -d server postgres minio
```

The server will be available on http://localhost:2001/tms/xdata

Environment variables for DB/MinIO can be overridden in `docker-compose.yml`. Defaults match the compose services.
