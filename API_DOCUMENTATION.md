# DisplayDeck REST API Documentation

This document describes the REST endpoints exposed by the DisplayDeck backend.

Base URL: `http://localhost:2001/api`

Content-Type: `application/json`

Authentication: Most endpoints require `Authorization: Bearer <token>` header.

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
