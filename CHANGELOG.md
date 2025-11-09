# Changelog

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
