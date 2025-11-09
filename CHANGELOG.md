# Changelog

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
