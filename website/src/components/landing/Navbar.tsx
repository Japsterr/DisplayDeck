import Link from "next/link";
import { Button } from "@/components/ui/button";

export function Navbar() {
  return (
    <nav className="fixed top-0 w-full z-50 border-b border-border/40 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      <div className="container max-w-screen-2xl px-4 md:px-6">
        <div className="flex h-16 items-center justify-between">
          <div className="flex items-center gap-6 min-w-0">
            <Link className="flex items-center gap-2 min-w-0" href="/" aria-label="DisplayDeck">
              <span className="font-semibold tracking-tight truncate text-white">
                DisplayDeck
              </span>
            </Link>

            <nav className="hidden md:flex items-center space-x-6 text-sm font-medium">
              <Link
                className="transition-colors hover:text-foreground/80 text-foreground/60"
                href="/features"
              >
                Product
              </Link>
              <Link
                className="transition-colors hover:text-foreground/80 text-foreground/60"
                href="/pricing"
              >
                Pricing
              </Link>
              <Link
                className="transition-colors hover:text-foreground/80 text-foreground/60"
                href="/download-tv"
              >
                Download TV App
              </Link>
              <Link
                className="transition-colors hover:text-foreground/80 text-foreground/60"
                href="/docs"
              >
                Help
              </Link>
            </nav>
          </div>

          <nav className="flex items-center gap-2 shrink-0">
            <Link href="/login">
              <Button variant="ghost" size="sm">
                Log in
              </Button>
            </Link>
            <Link href="/register">
              <Button size="sm" className="rounded-full px-4">
                Get Started
              </Button>
            </Link>
          </nav>
        </div>
      </div>
    </nav>
  );
}
