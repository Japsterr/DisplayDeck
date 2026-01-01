import { Navbar } from "@/components/landing/Navbar";
import { Footer } from "@/components/landing/Footer";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Book, LifeBuoy, Wrench } from "lucide-react";

export default function DocsPage() {
  return (
    <div className="flex min-h-screen flex-col bg-background">
      <Navbar />
      <main className="flex-1 pt-24 pb-16">
        <div className="container px-4 md:px-6 max-w-5xl mx-auto">
          <div className="flex flex-col items-center justify-center space-y-4 text-center mb-16">
            <h1 className="text-4xl font-bold tracking-tighter sm:text-6xl bg-clip-text text-transparent bg-gradient-to-r from-white to-neutral-500">
              Help Center
            </h1>
            <p className="max-w-[900px] text-muted-foreground md:text-xl/relaxed">
              Quick answers, setup guidance, and best practices for running great signage.
            </p>
          </div>

          <div className="grid gap-6 md:grid-cols-3 mb-14">
            <div className="rounded-xl border border-neutral-800 bg-neutral-900/50 p-6 hover:bg-neutral-900/80 transition-colors">
              <Book className="h-10 w-10 text-primary mb-4" />
              <h3 className="text-xl font-bold text-white mb-2">Getting Started</h3>
              <p className="text-neutral-400 mb-4">
                Connect a screen, publish your first menu, and go live in minutes.
              </p>
              <Link href="#getting-started">
                <Button variant="outline" className="w-full">View Steps</Button>
              </Link>
            </div>

            <div className="rounded-xl border border-neutral-800 bg-neutral-900/50 p-6 hover:bg-neutral-900/80 transition-colors">
              <Wrench className="h-10 w-10 text-primary mb-4" />
              <h3 className="text-xl font-bold text-white mb-2">Troubleshooting</h3>
              <p className="text-neutral-400 mb-4">
                Fix common issues like offline screens, missing media, and playback problems.
              </p>
              <Link href="#troubleshooting">
                <Button variant="outline" className="w-full">See Fixes</Button>
              </Link>
            </div>

            <div className="rounded-xl border border-neutral-800 bg-neutral-900/50 p-6 hover:bg-neutral-900/80 transition-colors">
              <LifeBuoy className="h-10 w-10 text-primary mb-4" />
              <h3 className="text-xl font-bold text-white mb-2">Support</h3>
              <p className="text-neutral-400 mb-4">
                Need a hand? Reach out and we’ll help you get it working.
              </p>
              <Link href="/register">
                <Button variant="outline" className="w-full">Contact Us</Button>
              </Link>
            </div>
          </div>

          <div className="space-y-10">
            <section id="getting-started" className="rounded-xl border border-neutral-800 bg-neutral-900/40 p-6">
              <h2 className="text-2xl font-bold text-white">Getting Started</h2>
              <ol className="list-decimal pl-5 mt-4 space-y-2 text-neutral-300">
                <li>Install the player on your device (Android TV, tablet, or a small PC).</li>
                <li>Create your menu in the Menu Designer and add your photos/prices.</li>
                <li>Assign the menu or campaign to your screen and publish.</li>
              </ol>
              <p className="mt-4 text-sm text-neutral-400">
                Tip: Start with a template and refine it once you see it on the screen.
              </p>
            </section>

            <section id="troubleshooting" className="rounded-xl border border-neutral-800 bg-neutral-900/40 p-6">
              <h2 className="text-2xl font-bold text-white">Troubleshooting</h2>
              <ul className="list-disc pl-5 mt-4 space-y-2 text-neutral-300">
                <li><span className="font-semibold text-white">Screen is blank:</span> check the device has internet and the display is assigned content.</li>
                <li><span className="font-semibold text-white">Media not showing:</span> re-upload the file and confirm it’s used in the menu/campaign.</li>
                <li><span className="font-semibold text-white">Updates not appearing:</span> publish again, then restart the player device.</li>
              </ul>
            </section>

            <section id="advanced" className="rounded-xl border border-neutral-800 bg-neutral-900/40 p-6">
              <h2 className="text-2xl font-bold text-white">Advanced (Optional)</h2>
              <p className="mt-4 text-neutral-300">
                Running many branches or need dynamic lists? The Pro plan supports advanced layouts and live list updates.
              </p>
            </section>
          </div>
        </div>
      </main>
      <Footer />
    </div>
  );
}
