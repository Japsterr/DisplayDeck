# Changelog

## 0.1.10 - 2025-12-29

- **Deployment (Phase 2)**:
  - Added optional `db-migrate` compose service to apply `migrations/*.sql` and record them in `schema_migrations`.
  - Added `APP_VERSION` wiring so the dashboard can show the UI build version.
  - Added simple prod deploy scripts: `scripts/deploy-prod.ps1` and `scripts/deploy-prod.sh`.

## 0.1.9 - 2025-12-29

- **Menu Builder (Phase 1)**:
  - Added menu tables: `Menus`, `MenuSections`, `MenuItems`.
  - Added public menu rendering endpoint: `GET /public/menus/{token}`.
  - Added dashboard UI for menu CRUD and preview.
- **Campaign Items**:
  - Campaign items now support `ItemType` (`media` | `menu`).
  - `CampaignItems` can reference either `MediaFileId` or `MenuId` (one-of enforced).
- **Database**:
  - Fresh installs updated via `schema.sql`.
  - Existing DB migration: `migrations/2025-12-29_add_menus.sql`.

## 0.1.8 - 2025-12-28

- **Campaign Editor**:
  - Added full playlist management UI.
  - Drag-and-drop reordering of campaign items.
  - Media library sidebar for easy addition of content.
  - Duration editing for each item.
- **Campaign Grid Improvements**:
  - Added "Media Items" count column.
  - Added "Status" column showing active/inactive state and display count.
  - Added "Assign to Displays" dialog for quick activation.
- **Infrastructure**:
  - Updated `website` container to support React 19.
  - Fixed `npm` peer dependency issues in Docker build (`--legacy-peer-deps`).
  - Restarted Nginx to resolve DNS caching issues ("Bad Gateway").

## 0.1.7 - 2025-11-10

- Orientation support for media files end-to-end
  - DB: add `Orientation VARCHAR(20) DEFAULT 'Landscape'` to `MediaFiles`
  - API: include `Orientation` in list/get/create and `upload-url` responses
  - API: update `PUT /media-files/{Id}` to accept and persist `Orientation`
  - OpenAPI + API docs updated with Orientation
  - Desktop app: prompt (Yes=Landscape / No=Portrait) for orientation on upload; orientation editable via combo box in details pane (auto-detect removed for compiler compatibility)
- Migration: `migrations/2025-11-10_add_orientation.sql` for existing databases
- Docs: README examples bumped to `0.1.7`

## 0.1.6 - 2025-11-09

- Fix download-url 400 errors for existing media
  - Robustly parse `StorageURL` by stripping either public or internal MinIO endpoint
  - Handle stale scheme/host to reliably extract bucket/key
  - Return clear 4xx messages for invalid storage paths
- Built and published server image tag `0.1.6` (local)
- Verified with `tests/media-upload-download.ps1` (PUT 200, GET 200)

## 0.1.5 - 2025-11-09

- Fix S3 SigV4 signature for presigned PUT/GET against MinIO
  - Correct lowercase hex signature encoding
  - Sorted canonical query parameters and proper percent-encoding
  - Canonical URI preserves `/` and encodes segments
- Remove duplicate SigV4 unit and standardize presign on `MINIO_PUBLIC_ENDPOINT`
- Add optional debug logging (`SIGV4_DEBUG`) for canonical request and string-to-sign
- Docker Compose improvements
  - `SERVER_TAG` to pin image version
  - `SIGV4_DEBUG` and `MINIO_PUBLIC_ENDPOINT` configurable via `.env`
- Docs: README updated with deploy/test steps; added this changelog
