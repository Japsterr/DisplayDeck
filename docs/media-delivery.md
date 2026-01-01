# Media delivery notes (practical)

This document explains how DisplayDeck delivers media reliably across browsers, public display pages, and Android players.

## 1) Presigned upload URLs (browser PUT)

Flow:

1. Dashboard calls `POST /media-files/upload-url`
2. Server returns a presigned PUT URL (`UploadUrl`)
3. Browser performs `PUT <UploadUrl>` with the raw file bytes

Production note:

- Presigned URLs are **host/header-sensitive** (SigV4).
- Do **not** rewrite the host in the presigned URL after you receive it.

If you’re serving everything on one domain (recommended), Nginx proxies MinIO under:

- `/minio/...`

That makes browser uploads and downloads much less brittle.

## 2) Signed download URLs (private media)

Flow:

1. Dashboard calls `GET /media-files/{id}/download-url`
2. Server returns a presigned GET URL (`DownloadUrl`)

This avoids making MinIO buckets public.

## 3) Public menus: same-origin proxy for images

Public menus are rendered at:

- `/display/menu/{token}`

Menus can reference uploaded media using a lightweight convention:

- `media:<id>`

When rendering public menus, the website resolves `media:<id>` to:

- `/public-media/menus/{token}/media-files/{id}`

That route:

- Calls `GET /public/menus/{token}/media-files/{id}/download-url`
- Fetches the object via the signed URL
- Streams it back from the website domain with a short cache (`Cache-Control: public, max-age=60`)

Why this exists:

- Older Android WebViews often fail in weird ways with cross-origin image/video resources.
- Same-origin delivery avoids CORS/CSP/certificate/DNS quirks.
- It also avoids clients accidentally breaking signatures by rewriting hosts.

## Troubleshooting checklist

- Upload fails (PUT): check Nginx `/minio/` CORS headers and ensure the presigned URL host isn’t rewritten.
- Download fails (403 signature): verify `MINIO_PUBLIC_ENDPOINT` is set to the public hostname used by clients.
- Public menu images missing: verify the menu’s `ThemeConfig`/item image fields contain `media:<id>` values and the website has access to the API via `INTERNAL_API_BASE_URL` (or default `http://nginx/api`).
