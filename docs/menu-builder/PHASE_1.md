# Menu Builder — Phase 1 (Implemented)

Date: 2025-12-29

Phase 1 goal: introduce **dynamic menu boards** as first-class content (not rendered images), editable from the dashboard and playable on displays.

## What Phase 1 adds

- Database tables for menus, sections, and items:
  - `Menus`
  - `MenuSections`
  - `MenuItems`
- Campaign items can now reference **either**:
  - a media file (`ItemType=media`, `MediaFileId` set)
  - a menu (`ItemType=menu`, `MenuId` set)
- A public, token-based endpoint for display rendering:
  - `GET /public/menus/{Token}` (no auth)

## Database changes

- Fresh installs: schema is updated in `schema.sql`.
- Existing databases: apply migration `migrations/2025-12-29_add_menus.sql`.

Important constraint:
- `CampaignItems` enforces a one-of relationship:
  - `(ItemType='media' AND MediaFileID IS NOT NULL AND MenuID IS NULL)`
  - `(ItemType='menu' AND MenuID IS NOT NULL AND MediaFileID IS NULL)`

## API endpoints (Phase 1)

All endpoints are under the `/api` base in production (via Nginx), but the server also tolerates missing `/api` prefix.

### Authenticated (dashboard)

Menus
- `GET /organizations/{OrganizationId}/menus`
- `POST /organizations/{OrganizationId}/menus`
- `GET /menus/{Id}`
- `PUT /menus/{Id}`
- `DELETE /menus/{Id}`

Menu sections
- `GET /menus/{MenuId}/sections`
- `POST /menus/{MenuId}/sections`
- `PUT /menu-sections/{Id}`
- `DELETE /menu-sections/{Id}`

Menu items
- `GET /menu-sections/{MenuSectionId}/items`
- `POST /menu-sections/{MenuSectionId}/items`
- `PUT /menu-items/{Id}`
- `DELETE /menu-items/{Id}`

Campaign items (updated)
- `GET /campaigns/{CampaignId}/items`
- `POST /campaigns/{CampaignId}/items`
- `GET /campaign-items/{Id}`
- `PUT /campaign-items/{Id}`
- `DELETE /campaign-items/{Id}`

### Public (display)

- `GET /public/menus/{Token}`
  - Returns a single menu including sections and items.
  - Intended for polling by players/displays.

## Website UI (Phase 1)

Dashboard
- `/dashboard/menus` — list + create menus
- `/dashboard/menus/{id}` — menu editor (sections/items + JSON theme config)
- `/dashboard/campaigns/{id}` — campaign editor now supports adding menus to playlists

Public display renderer
- `/display/menu/{token}` — renders the menu via `GET /public/menus/{token}` and polls periodically.

## ThemeConfig (Phase 1)

`Menus.ThemeConfig` is stored as JSONB and is intentionally flexible. Current renderer uses the following optional keys:

- `backgroundColor` (default `#0b1220`)
- `textColor` (default `#ffffff`)
- `mutedTextColor` (default `#94a3b8`)
- `accentColor` (default `#22c55e`)

Templates
- `TemplateKey` is stored, but Phase 1 uses a single "classic/simple" rendering approach (future templates planned).
