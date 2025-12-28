import { Navbar } from "@/components/landing/Navbar";
import { Footer } from "@/components/landing/Footer";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Book, Code, Terminal } from "lucide-react";

export default function DocsPage() {
  return (
    <div className="flex min-h-screen flex-col bg-background">
      <Navbar />
      <main className="flex-1 pt-24 pb-16">
        <div className="container px-4 md:px-6 max-w-5xl mx-auto">
          <div className="flex flex-col items-center justify-center space-y-4 text-center mb-16">
            <h1 className="text-4xl font-bold tracking-tighter sm:text-6xl bg-clip-text text-transparent bg-gradient-to-r from-white to-neutral-500">
              Documentation
            </h1>
            <p className="max-w-[900px] text-muted-foreground md:text-xl/relaxed">
              Everything you need to build with DisplayDeck.
            </p>
          </div>

          <div className="grid gap-6 md:grid-cols-3">
            <div className="rounded-xl border border-neutral-800 bg-neutral-900/50 p-6 hover:bg-neutral-900/80 transition-colors">
              <Book className="h-10 w-10 text-primary mb-4" />
              <h3 className="text-xl font-bold text-white mb-2">User Guide</h3>
              <p className="text-neutral-400 mb-4">
                Learn how to manage screens, create playlists, and schedule campaigns.
              </p>
              <Button variant="outline" className="w-full">Read Guide</Button>
            </div>

            <div className="rounded-xl border border-neutral-800 bg-neutral-900/50 p-6 hover:bg-neutral-900/80 transition-colors">
              <Code className="h-10 w-10 text-primary mb-4" />
              <h3 className="text-xl font-bold text-white mb-2">API Reference</h3>
              <p className="text-neutral-400 mb-4">
                Complete reference for the DisplayDeck REST API.
              </p>
              <Link href="http://localhost:8080" target="_blank">
                <Button variant="outline" className="w-full">View API Docs</Button>
              </Link>
            </div>

            <div className="rounded-xl border border-neutral-800 bg-neutral-900/50 p-6 hover:bg-neutral-900/80 transition-colors">
              <Terminal className="h-10 w-10 text-primary mb-4" />
              <h3 className="text-xl font-bold text-white mb-2">Self Hosting</h3>
              <p className="text-neutral-400 mb-4">
                Instructions for deploying DisplayDeck on your own infrastructure.
              </p>
              <Button variant="outline" className="w-full">Deployment Guide</Button>
            </div>
          </div>
        </div>
      </main>
      <Footer />
    </div>
  );
}
