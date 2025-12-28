import { Navbar } from "@/components/landing/Navbar";
import { Footer } from "@/components/landing/Footer";

export default function ChangelogPage() {
  return (
    <div className="flex min-h-screen flex-col bg-background">
      <Navbar />
      <main className="flex-1 pt-24 pb-16">
        <div className="container px-4 md:px-6 max-w-4xl mx-auto">
          <div className="flex flex-col items-center justify-center space-y-4 text-center mb-16">
            <h1 className="text-4xl font-bold tracking-tighter sm:text-6xl bg-clip-text text-transparent bg-gradient-to-r from-white to-neutral-500">
              Changelog
            </h1>
            <p className="max-w-[900px] text-muted-foreground md:text-xl/relaxed">
              Stay up to date with the latest improvements and fixes.
            </p>
          </div>

          <div className="space-y-12">
            {/* Version 1.0.0 */}
            <div className="relative pl-8 border-l border-neutral-800">
              <div className="absolute -left-1.5 top-1.5 h-3 w-3 rounded-full bg-primary" />
              <div className="mb-2 flex items-center gap-3">
                <h2 className="text-2xl font-bold text-white">v1.0.0</h2>
                <span className="rounded-full bg-neutral-800 px-2.5 py-0.5 text-xs font-medium text-neutral-400">
                  Latest
                </span>
                <span className="text-sm text-muted-foreground">
                  December 21, 2025
                </span>
              </div>
              <div className="prose prose-invert max-w-none">
                <p className="text-neutral-300 mb-4">
                  Initial public release of DisplayDeck.
                </p>
                <ul className="list-disc pl-5 space-y-2 text-neutral-400">
                  <li>Complete device management dashboard</li>
                  <li>Campaign scheduling system</li>
                  <li>Real-time analytics</li>
                  <li>Multi-user support with role-based access control</li>
                  <li>Docker deployment support</li>
                </ul>
              </div>
            </div>

            {/* Beta */}
            <div className="relative pl-8 border-l border-neutral-800">
              <div className="absolute -left-1.5 top-1.5 h-3 w-3 rounded-full bg-neutral-700" />
              <div className="mb-2 flex items-center gap-3">
                <h2 className="text-2xl font-bold text-neutral-400">Beta</h2>
                <span className="text-sm text-muted-foreground">
                  November 10, 2025
                </span>
              </div>
              <div className="prose prose-invert max-w-none">
                <p className="text-neutral-300 mb-4">
                  Private beta release for select partners.
                </p>
                <ul className="list-disc pl-5 space-y-2 text-neutral-400">
                  <li>Basic device pairing</li>
                  <li>Simple image playlist support</li>
                  <li>Offline playback capability</li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </main>
      <Footer />
    </div>
  );
}
