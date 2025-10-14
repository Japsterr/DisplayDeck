# DisplayDeck REST API Documentation

This document describes the verified friendly REST endpoints exposed by the DisplayDeck backend. These were exercised in live smoke tests and are ready for client integration.

Base URL: http://localhost:2001/tms/xdata

Content-Type: application/json

Authentication: Some endpoints may later require JWT; current smoke tests used open endpoints where available.

Timestamp format: For any TDateTime fields in JSON requests, use "yyyy-MM-ddTHH:mm:ss" (no timezone suffix). Example: "2025-10-14T18:46:30".

---

## Health

- GET /health → { "value": "OK" }

---

## Auth

- POST /auth/register
  - Request: { "Email", "Password", "OrganizationName" }
  - Response: { "Success", "Token", "User", "Message" }

- POST /auth/login
  - Request: { "Email", "Password" }
  - Response: { "Success", "Token", "User" }

---

## Plans and Roles

- GET /plans → array of plans (Free, Starter, Business, ...)
- GET /roles → ["Owner","ContentManager","Viewer"]

---

## Organizations

- GET /organizations → { "value": [ TOrganization, ... ] }
- POST /organizations → TOrganization
- GET /organizations/{id} → TOrganization
- GET /organizations/{OrganizationId}/subscription → subscription details

TOrganization shape (key fields): { Id, Name, CreatedAt, UpdatedAt }

---

## Displays

- GET /organizations/{OrganizationId}/displays → { "value": [ TDisplay, ... ] }
- POST /organizations/{OrganizationId}/displays → TDisplay
  - Required: OrganizationId, Name, Orientation, CurrentStatus, ProvisioningToken
- GET /displays/{Id} → TDisplay
- PUT /displays/{Id} → TDisplay
  - Required fields for update: Id, Name, Orientation, CurrentStatus
- DELETE /displays/{Id} → 204 No Content

TDisplay shape (key fields): { Id, OrganizationId, Name, Orientation, LastSeen, CurrentStatus, ProvisioningToken, CreatedAt, UpdatedAt }

---

## Campaigns

- GET /organizations/{OrganizationId}/campaigns → { "value": [ TCampaign, ... ] }
- POST /organizations/{OrganizationId}/campaigns → TCampaign
  - Required: OrganizationId, Name, Orientation
- GET /campaigns/{Id} → TCampaign
- PUT /campaigns/{Id} → TCampaign (Id, Name, Orientation)
- DELETE /campaigns/{Id} → 204 No Content

TCampaign: { Id, OrganizationId, Name, Orientation, CreatedAt, UpdatedAt }

---

## Campaign Items

- GET /campaigns/{CampaignId}/items → { "value": [ TCampaignItem, ... ] }
- POST /campaigns/{CampaignId}/items → TCampaignItem (CampaignId, MediaFileId, DisplayOrder, Duration)
- GET /campaign-items/{Id} → TCampaignItem
- PUT /campaign-items/{Id} → TCampaignItem (Id, MediaFileId, DisplayOrder, Duration)
- DELETE /campaign-items/{Id} → 204 No Content

TCampaignItem: { Id, CampaignId, MediaFileId, DisplayOrder, Duration }

---

## Display Assignments (Display-Campaigns)

- GET /displays/{DisplayId}/campaign-assignments → { "value": [ TDisplayCampaign, ... ] }
- POST /displays/{DisplayId}/campaign-assignments → TDisplayCampaign (DisplayId, CampaignId, IsPrimary)
- PUT /campaign-assignments/{Id} → TDisplayCampaign (Id, IsPrimary)
- DELETE /campaign-assignments/{Id} → 204 No Content

TDisplayCampaign: { Id, DisplayId, CampaignId, IsPrimary }

---

## Media Files

- POST /media-files/upload-url → { MediaFileId, UploadUrl, StorageKey, Success, Message }
- GET /media-files/{MediaFileId}/download-url → { DownloadUrl, Success, Message }

Note: Upload directly to MinIO using UploadUrl; server records MediaFileId and StorageKey.

---

## Device

- POST /device/config
  - Request: { "ProvisioningToken": "PROV-12345" }
  - Response: { "Success", "Device": TDisplay, "Campaigns": [ TCampaign, ... ], "Message" }

- POST /device/logs
  - Request: { "DisplayId": number, "LogType": string, "Message": string, "Timestamp": "yyyy-MM-ddTHH:mm:ss" }
  - Response: { "Success": true, "Message": "Log received successfully" }

Timestamp guidance: Use "yyyy-MM-ddTHH:mm:ss". Other forms like Z-suffixed ISO or /Date(ms)/ are not accepted by the current TDateTime JSON parser.

---

## Playback Logs

- POST /playback-logs → 204 No Content
  - Request: { "DisplayId": number, "MediaFileId": number, "CampaignId": number, "PlaybackTimestamp": "yyyy-MM-ddTHH:mm:ss" }

---

## Error format

Errors use this envelope:

{ "error": { "code": "...", "message": "..." } }

Common errors: Unauthorized, Forbidden, NotFound, ValidationError, ServerError.

---

## Data model references (from schema)

- Plans: { PlanID, Name, Price, MaxDisplays, MaxCampaigns, MaxMediaStorageGB, IsActive }
- Subscriptions: { SubscriptionID, OrganizationID, PlanID, Status, CurrentPeriodEnd, TrialEndDate, ... }
- MediaFiles: { MediaFileID, OrganizationID, FileName, FileType, StorageURL, ... }
- Displays: { DisplayID, OrganizationID, Name, Orientation, LastSeen, CurrentStatus, ProvisioningToken, ... }
- Campaigns, CampaignItems, DisplayCampaigns, PlaybackLogs as described above.

See `schema.sql` for full table definitions.
