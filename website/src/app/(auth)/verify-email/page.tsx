"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Suspense, useEffect, useMemo, useState } from "react";

import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

type Status = "idle" | "verifying" | "success" | "error";

export default function VerifyEmailPage() {
  return (
    <Suspense
      fallback={
        <div className="flex min-h-screen items-center justify-center px-4">
          <Card className="w-full max-w-sm">
            <CardHeader>
              <CardTitle className="text-2xl">Verify email</CardTitle>
              <CardDescription>Loading…</CardDescription>
            </CardHeader>
          </Card>
        </div>
      }
    >
      <VerifyEmailInner />
    </Suspense>
  );
}

function VerifyEmailInner() {
  const searchParams = useSearchParams();
  const token = useMemo(() => searchParams.get("token") || "", [searchParams]);

  const [status, setStatus] = useState<Status>("idle");
  const [message, setMessage] = useState<string>("");

  useEffect(() => {
    if (!token) return;

    let cancelled = false;

    async function run() {
      setStatus("verifying");
      setMessage("");

      try {
        const apiUrl =
          process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";

        const res = await fetch(`${apiUrl}/auth/verify-email`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ Token: token }),
        });

        if (!res.ok) {
          const text = await res.text();
          console.error("Verify email failed:", text);
          throw new Error("Verify failed");
        }

        if (cancelled) return;
        setStatus("success");
        setMessage("Email verified. You can now log in.");
      } catch (e) {
        if (cancelled) return;
        setStatus("error");
        setMessage("Could not verify email. The link may be expired.");
      }
    }

    run();

    return () => {
      cancelled = true;
    };
  }, [token]);

  return (
    <div className="flex min-h-screen items-center justify-center px-4">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle className="text-2xl">Verify email</CardTitle>
          <CardDescription>
            {status === "verifying"
              ? "Verifying your email…"
              : "Confirm your email address to continue."}
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-3 text-sm">
          {!token ? (
            <p className="text-destructive">Missing verification token.</p>
          ) : null}
          {message ? (
            <p className={status === "error" ? "text-destructive" : ""}>
              {message}
            </p>
          ) : null}
        </CardContent>
        <CardFooter className="justify-center gap-2">
          <Button asChild variant="secondary">
            <Link href="/login">Go to login</Link>
          </Button>
        </CardFooter>
      </Card>
    </div>
  );
}
