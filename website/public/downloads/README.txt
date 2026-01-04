Place the public TV APK here as:

  displaydeck-tv.apk

This folder is served publicly by Next.js (no authentication required).

Alternative: set NEXT_PUBLIC_TV_APK_URL to an external public URL and the download page will use that instead.

Important (Docker deployments)
  The website container copies /public at image build time.
  If you add/replace the APK after the container has already been built,
  you must either rebuild the website image OR use a volume mount.

  This repo's docker-compose.yml now mounts:
    ./website/public/downloads -> /app/public/downloads (read-only)
  So you can update the APK without rebuilding; just restart the website/nginx containers.
