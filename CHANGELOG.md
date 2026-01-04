# Changelog

## 0.2.6 - 2026-01-04

### Android TV Player
- **Campaign Image Display Fix**: Fixed critical bug where campaign images showed a broken image icon instead of the actual image.
  - Root cause: Kotlin raw string literals (`"""`) were rendering literal `\"` escape sequences into HTML attributes, causing the WebView to request malformed URLs like `/%22https://...%22`.
  - Fixed all HTML templates in `loadCoverImageHtml()`, `loadCampaignMessageHtml()`, and `probeThenLoadMedia()`.
- **InfoBoard Support**: Added full support for InfoBoard display type.
  - Mobile app now handles `infoboard` assignment type in heartbeat response.
  - Loads InfoBoard SSR pages via WebView.
- **Version Display**: Simplified version display to show only version name (e.g., `v0.2.6`) without build number in parentheses.

### Server
- **Heartbeat InfoBoard Support**: Heartbeat endpoint now returns `InfoBoardPublicToken` when a display has an InfoBoard assigned.
- **Auto-Cleanup Pairing Codes**: When a device requests a new pairing code, any old unclaimed tokens for the same HardwareId are automatically deleted. This prevents stale "pending" pairing codes from accumulating in the dashboard when devices are reinstalled.

### Website
- **InfoBoard SSR Page**: Created `/display/infoboard-ssr/[token]/page.tsx` for server-side rendered InfoBoard display.
- **Next.js 16 Params Fix**: Fixed both `menu-ssr` and `infoboard-ssr` pages to properly await the `params` Promise (required in Next.js 16+).
- **Display Padding**: Added bottom padding (`pb-6`) to menu and infoboard display pages to prevent content from being cut off at screen edges.
- **Download Link Fix**: Corrected APK download links to point to `/downloads/displaydeck-player.apk`.

## Unreleased

- **Menu Builder (Phase 2 — New Templates)**:
  - Added 4 new professional menu templates:
    - `elegant`: Upscale restaurant / fine dining with serif fonts and dotted price leaders
    - `retro`: Vintage diner / 50s style with neon glow effects
    - `modern`: Clean, contemporary design with generous white space
    - `chalkboard`: Handwritten / artisan cafe style with decorative elements
  - Templates now totaling 9 options for diverse restaurant styles.

- **Information Boards Feature (NEW)**:
  - New display type for non-menu content: mall directories, office building floors, HSEQ posters.
  - Database tables: `InfoBoards`, `InfoBoardSections`, `InfoBoardItems`, `DisplayInfoBoards`.
  - Support for different board types: directory, hseq, notice, custom.
  - Section layouts: list, grid, cards, tiles.
  - Item types: entry, notice, poster, map, QR code, contact info.
  - New dashboard page at `/dashboard/infoboards` with full CRUD.
  - Added "Info Boards" link to sidebar navigation.

- **Display Section Preview Fix**:
  - Display cards now show an iframe preview when the device is displaying a menu.
  - Previously only media files (images/videos) had visual previews.

- **Android App - Configurable URLs**:
  - Replaced hardcoded production URLs with dynamic configuration via SharedPreferences.
  - Added developer SettingsActivity for configuring API and Public URLs.
  - Launch via ADB: `adb shell am start -n co.displaydeck.player/.SettingsActivity`
  - Or pass URLs directly: `--es api_url "http://192.168.x.x:2001/api" --es public_url "http://192.168.x.x:3000"`
  - Functions: `getApiBaseUrl()`, `getPublicBaseUrl()`, `setApiBaseUrl()`, `setPublicBaseUrl()`, `resetToProductionUrls()`.

- **Menu Builder (Phase 2 — QSR Templates)**:
  - Added two new professional templates: `qsr` (Quick Service Restaurant) and `drivethru` for fast-food style displays.
  - QSR template features large product images with price badges, section cards, and grid layouts.
  - Drive-thru template provides numbered items for easy ordering and maximum outdoor legibility.
  - Added 6 new fast-food themed color palettes: Burger Red, Golden Arches, Fried Crispy, Pizza Parlor, Fresh Salad, Coffee Roast.
  - New ThemeConfig options: `priceBadgeColor`, `sectionHeaderColor` for advanced styling.
  - Database enhancements for professional menus:
    - MenuItems: badges, calories, variants (size pricing), combo items, promo flags
    - MenuSections: panel index (multi-screen), per-section colors, layout styles
    - New tables: `MenuPromos` for promotional banners, `MenuCombos` for meal deals
  - Badge system with support for NEW, HOT, SPICY, BESTSELLER, VEGAN, HALAL, and more.
  - Variant pricing for size-based options (Small/Medium/Large).
  - Combo support with included items list.
  - Multi-panel display support for drive-thru configurations.

- **Menu Builder (Phase 2 — Drag-and-Drop & Animations)**:
  - Added drag-and-drop reordering for menu sections using grip handles.
  - Added drag-and-drop reordering for menu items within sections.
  - Visual feedback during drag operations (shadow highlight, ring indicator).
  - Changes automatically persist to the database on drop.
  - Added staggered fade-in animations for sections and items on page load.
  - Added hover effects: scale transform and shadow on menu items.
  - Added image zoom effect on hover for product images.
  - Animation timing uses staggered delays based on section/item index.

- **Provisioning audit / observability**:
  - Added `ProvisioningTokenEvents` table to record token lifecycle and device history.
  - New org endpoints:
    - Token history: `GET /organizations/{orgId}/provisioning-token-events?token=...`
    - Device list + stats: `GET /organizations/{orgId}/provisioning-devices`
    - Device history: `GET /organizations/{orgId}/provisioning-device-events?hardwareId=...`
  - Added explicit unpair action: `POST /organizations/{orgId}/displays/{displayId}/unpair` (records an `unpaired` event tied to HardwareId).

- **Website / Dashboard**:
  - Added Analytics and "Now Playing" dashboard views.
  - Improved public menu rendering for landscape screens.
  - Simplified Android TV APK download page.

- **Android TV player**:
  - Added always-visible version overlay.
  - Improved URL normalization and error surfacing for media.

## 0.2.0 - 2026-01-01

- **Website / Dashboard**:
  - Fixed a public menu crash caused by React hook order violations.
  - Menu editor: improved media picking UX (search + thumbnail grid) for quickly selecting images.
  - Menu editor: detects invalid `ThemeConfig` JSON and offers a reset so logo/background controls can be re-enabled.
- **Media delivery / production reliability**:
  - Public menu rendering no longer relies on raw MinIO URLs in the browser/WebView.
  - Added a same-origin proxy for menu media (`/public-media/...`) that fetches via the API and serves short-cache responses.
  - Nginx proxies `/minio/` with CORS headers to support browser uploads (PUT to presigned URLs).
- **Android player**:
  - Campaign images render via a minimal `object-fit: cover` wrapper (better portrait/fullscreen behavior).
  - Campaign videos play via native Media3/ExoPlayer (more reliable than WebView `<video>` on older devices).
  - Android TV support: Leanback launcher category and boot auto-start receiver.

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
