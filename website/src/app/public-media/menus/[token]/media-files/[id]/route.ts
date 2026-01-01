import { NextResponse } from "next/server";

function getInternalApiBase(): string {
  // In Docker (prod), the website container can reach nginx by its service name.
  // Nginx proxies `/api/*` to the Delphi server.
  return process.env.INTERNAL_API_BASE_URL || "http://nginx/api";
}

export async function GET(
  _request: Request,
  context: { params: Promise<{ token: string; id: string }> }
) {
  const { token, id } = await context.params;

  const apiBase = getInternalApiBase();
  const metaRes = await fetch(
    `${apiBase}/public/menus/${encodeURIComponent(token)}/media-files/${encodeURIComponent(id)}/download-url`,
    { cache: "no-store" }
  );

  if (!metaRes.ok) {
    return new NextResponse("Not found", { status: 404 });
  }

  let downloadUrl = "";
  try {
    const data = (await metaRes.json()) as { DownloadUrl?: string };
    downloadUrl = (data?.DownloadUrl || "").trim();
  } catch {
    return new NextResponse("Not found", { status: 404 });
  }

  if (!downloadUrl) {
    return new NextResponse("Not found", { status: 404 });
  }

  const upstream = await fetch(downloadUrl, { cache: "no-store" });
  if (!upstream.ok || !upstream.body) {
    return new NextResponse("Not found", { status: 404 });
  }

  const headers = new Headers();
  headers.set(
    "Content-Type",
    upstream.headers.get("content-type") || "application/octet-stream"
  );
  const contentLength = upstream.headers.get("content-length");
  if (contentLength) headers.set("Content-Length", contentLength);

  // Keep this short: signed URLs are time-bound and menus update often.
  headers.set("Cache-Control", "public, max-age=60");

  return new NextResponse(upstream.body, { status: 200, headers });
}
