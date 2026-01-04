import { Suspense } from "react";
import AuditLogClient from "./AuditLogClient";

export const dynamic = "force-dynamic";

export default function AuditLogPage() {
  return (
    <Suspense
      fallback={<div className="space-y-6"><div className="text-sm text-muted-foreground">Loading…</div></div>}
    >
      <AuditLogClient />
    </Suspense>
  );
}
