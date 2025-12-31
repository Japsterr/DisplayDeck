# DisplayDeck REST API Documentation

This document describes the REST endpoints exposed by the DisplayDeck backend.

Base URL: `http://localhost:2001/api`

Content-Type: `application/json`

Authentication: Most endpoints require an auth token.

Supported auth headers:

- Preferred: `Authorization: Bearer <token>`
- Also supported (fallback): `X-Auth-Token: <token>`

Some endpoints may also accept an API key (where enabled) via `X-API-Key: <key>`.

Timestamp format: "yyyy-MM-ddTHH:mm:ss" (ISO 8601).

---

## Health

- `GET /health` → `{ "value": "OK" }`

---

## Auth

- `POST /auth/register`
  - Request: `{ "Email": "...", "Password": "...", "OrganizationName": "..." }`
  - Response: `{ "Success": true, "Token": "...", "User": { ... } }`

- `POST /auth/login`
  - Request: `{ "Email": "...", "Password": "..." }`
  - Response: `{ "Success": true, "Token": "...", "User": { ... } }`

---

## Device Pairing

- `POST /device/provisioning/token`
  - Request: `{ "HardwareId": "unique-device-id" }`
  - Response: 
    ```json
    { 
      "ProvisioningToken": "PROV-...", 
      "ExpiresInSeconds": 600, 
      "QrCodeData": "displaydeck://claim/PROV-...", 
      "Instructions": "Scan this QR code with the DisplayDeck mobile app to pair this display." 
    }
    ```

- `POST /organizations/{OrganizationId}/displays/claim`
  - Request: `{ "ProvisioningToken": "PROV-...", "Name": "New Display", "Orientation": "Landscape" }`
  - Response: `{ "Id": 123, "Name": "New Display", "Orientation": "Landscape" }`

---

## Plans and Roles

- `GET /plans` → Array of plans
- `GET /roles` → `["Owner", "ContentManager", "Viewer"]`

---

## Organizations

- `GET /organizations` → `{ "value": [ { "Id": 1, "Name": "..." }, ... ] }`
- `POST /organizations` → `{ "Id": 1, "Name": "..." }`
- `GET /organizations/{id}` → `{ "Id": 1, "Name": "..." }`
- `GET /organizations/{OrganizationId}/subscription` → Subscription details

---

## Displays

- `GET /organizations/{OrganizationId}/displays` → `{ "value": [ { "Id": 1, "Name": "...", ... }, ... ] }`
- `POST /organizations/{OrganizationId}/displays`
  - Request: `{ "Name": "...", "Orientation": "Landscape" }`
  - Response: `{ "Id": 1, ... }`
- `GET /displays/{Id}`
- `PUT /displays/{Id}`
- `DELETE /displays/{Id}`

---

## Campaigns

- `GET /organizations/{OrganizationId}/campaigns` → `{ "value": [ ... ] }`
- `POST /organizations/{OrganizationId}/campaigns`
- `GET /campaigns/{Id}`
- `PUT /campaigns/{Id}`
- `DELETE /campaigns/{Id}`

---

## Campaign Items

- `GET /campaigns/{CampaignId}/items`
- `POST /campaigns/{CampaignId}/items`
- `GET /campaign-items/{Id}`
- `PUT /campaign-items/{Id}`
- `DELETE /campaign-items/{Id}`

Campaign items now support two types:

- `ItemType: "media"` (default/legacy)
  - Requires `MediaFileId`
  - Requires `MenuId` to be null
- `ItemType: "menu"`
  - Requires `MenuId`
  - Requires `MediaFileId` to be null

The database enforces the one-of constraint.

Example (create media item):
```json
{ "ItemType": "media", "MediaFileId": 123, "DisplayOrder": 0, "Duration": 10 }
```

Example (create menu item):
```json
{ "ItemType": "menu", "MenuId": 55, "DisplayOrder": 0, "Duration": 15 }
```

---

## Menus (Dynamic Menu Boards)

Phase 1 adds structured menu boards (menus → sections → items) and a public token renderer endpoint.

Authenticated endpoints:

- `GET /organizations/{OrganizationId}/menus` → `{ "value": [ ... ] }`
- `POST /organizations/{OrganizationId}/menus`
  - Request: `{ "Name": "Breakfast", "Orientation": "Landscape", "TemplateKey": "simple", "ThemeConfig": { ... } }`
- `GET /menus/{Id}`
- `PUT /menus/{Id}`
- `DELETE /menus/{Id}`

Example: create a menu

```bash
curl -X POST "http://localhost:2001/api/organizations/1/menus" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "Name": "Main Menu",
    "Orientation": "Landscape",
    "TemplateKey": "classic",
    "ThemeConfig": {
      "backgroundColor": "#0b0b0b",
      "textColor": "#ffffff",
      "accentColor": "#22c55e"
    }
  }'
```

Example response (shape)

```json
{
  "Id": 55,
  "OrganizationId": 1,
  "Name": "Main Menu",
  "Orientation": "Landscape",
  "TemplateKey": "classic",
  "PublicToken": "PUB-...",
  "ThemeConfig": {
    "backgroundColor": "#0b0b0b",
    "textColor": "#ffffff",
    "accentColor": "#22c55e"
  }
}
```

Menu sections:

- `GET /menus/{MenuId}/sections` → `{ "value": [ ... ] }`
- `POST /menus/{MenuId}/sections` → creates a section
  - Request: `{ "Name": "Burgers", "DisplayOrder": 0 }`
- `PUT /menu-sections/{Id}`
- `DELETE /menu-sections/{Id}`

Example: create a section

```bash
curl -X POST "http://localhost:2001/api/menus/55/sections" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "Name": "Burgers",
    "DisplayOrder": 1
  }'
```

Menu items:

- `GET /menu-sections/{MenuSectionId}/items` → `{ "value": [ ... ] }`
- `POST /menu-sections/{MenuSectionId}/items`
  - Request: `{ "Name": "Cheeseburger", "Sku": "POS-123", "Description": "...", "ImageUrl": "https://...", "PriceCents": 8999, "IsAvailable": true, "DisplayOrder": 0 }`
- `PUT /menu-items/{Id}`
- `DELETE /menu-items/{Id}`

Notes:

- `Sku` is intended to be the stable identifier used to sync pricing/items with a POS.
- `ImageUrl` is an optional absolute URL shown on public menu templates.
- `PriceCents` is stored as an integer (ZAR cents). Use `null` to indicate “no price”.

Example: create an item

```bash
curl -X POST "http://localhost:2001/api/menu-sections/123/items" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "Name": "Cheese Burger",
    "Sku": "POS-123",
    "Description": "200g beef patty, cheddar, pickles",
    "ImageUrl": "https://cdn.example.com/menu/cheese-burger.jpg",
    "PriceCents": 8999,
    "IsAvailable": true,
    "DisplayOrder": 1
  }'
```

Menu duplicate:

- `POST /menus/{Id}/duplicate` → clones the menu, its sections, and items, and returns the new menu (including a new public token).

Example: duplicate a menu

```bash
curl -X POST "http://localhost:2001/api/menus/55/duplicate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{}'
```

CSV import (dashboard feature):

The dashboard menu editor supports importing items from CSV. The CSV must include a header row.

- Required columns: `Section`, `Name`
- Optional columns: `Sku`, `Description`, `ImageUrl`, `Price` (ZAR, e.g. `89.99`), `PriceCents` (integer), `IsAvailable`, `DisplayOrder`

Public endpoint (no auth):

- `GET /public/menus/{Token}` → menu with its sections + items (for display players)

Example response (shape)

```json
{
  "Menu": { "Id": 55, "Name": "Main Menu", "TemplateKey": "classic", "PublicToken": "PUB-..." },
  "Sections": [
    { "Id": 123, "MenuId": 55, "Name": "Burgers", "DisplayOrder": 1 }
  ],
  "Items": [
    {
      "Id": 999,
      "MenuSectionId": 123,
      "Name": "Cheese Burger",
      "Sku": "POS-123",
      "Description": "200g beef patty, cheddar, pickles",
      "ImageUrl": "https://cdn.example.com/menu/cheese-burger.jpg",
      "PriceCents": 8999,
      "IsAvailable": true,
      "DisplayOrder": 1
    }
  ]
}
```

---

## Display Assignments

- `GET /displays/{DisplayId}/campaign-assignments`
- `POST /displays/{DisplayId}/campaign-assignments`
- `PUT /campaign-assignments/{Id}`
- `DELETE /campaign-assignments/{Id}`
- `POST /displays/{DisplayId}/set-primary`
  - Request: `{ "CampaignId": 123 }`

---

## Media Files

- `GET /organizations/{OrganizationId}/media-files`
- `POST /media-files/upload-url`
  - Request: `{ "OrganizationId": 1, "FileName": "...", "FileType": "...", "Orientation": "Landscape" }`
  - Response: `{ "MediaFileId": 1, "UploadUrl": "...", "StorageKey": "...", "Success": true }`
- `GET /media-files/{Id}/download-url`
- `PUT /media-files/{Id}`
- `DELETE /media-files/{Id}`

---

## Device Configuration (for Displays)

- `POST /device/config`
  - Request: `{ "ProvisioningToken": "..." }`
  - Response: `{ "Success": true, "Device": { ... }, "Campaigns": [ ... ] }`

- `POST /device/logs`
- `POST /playback-logs`

---

## Analytics

- `GET /analytics/plays`
- `GET /analytics/summary/media`
- `GET /analytics/summary/campaigns`
