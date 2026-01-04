import Link from "next/link";

import { Button } from "@/components/ui/button";

export default function DownloadTvPage() {
  const externalUrl = (process.env.NEXT_PUBLIC_TV_APK_URL || "").trim();
  const sha256 = (process.env.NEXT_PUBLIC_TV_APK_SHA256 || "").trim();

  // Default: serve from Next's public/ folder (no auth)
  const localPath = "/downloads/displaydeck-tv.apk";
  const downloadUrl = externalUrl || localPath;

  return (
    <main className="min-h-screen bg-black text-white">
      <div className="mx-auto max-w-3xl px-6 py-16">
        <div className="flex items-center justify-between gap-4">
          <h1 className="text-3xl font-semibold tracking-tight">Download DisplayDeck TV App (APK)</h1>
          <Link href="/" className="text-sm text-white/70 hover:text-white">
            Back to home
          </Link>
        </div>

        <div className="mt-8 flex flex-wrap items-center gap-3">
          <Button asChild className="rounded-full px-6">
            <a
              href={downloadUrl}
              download={externalUrl ? undefined : "displaydeck-tv.apk"}
              target={externalUrl ? "_blank" : undefined}
              rel={externalUrl ? "noreferrer" : undefined}
            >
              Download APK
            </a>
          </Button>
        </div>

        {sha256 ? (
          <div className="mt-6 rounded-lg border border-white/10 bg-white/5 p-4">
            <div className="text-sm font-medium">SHA-256</div>
            <div className="mt-1 break-all font-mono text-xs text-white/70">{sha256}</div>
          </div>
        ) : null}
      </div>
    </main>
  );
}
