import Link from "next/link";
import { Github, Twitter } from "lucide-react";

export function Footer() {
  return (
    <footer className="border-t bg-neutral-950 py-12 text-neutral-400">
      <div className="container px-4 md:px-6">
        <div className="grid gap-8 md:grid-cols-2 lg:grid-cols-4">
          <div className="space-y-4">
            <h3 className="text-lg font-bold text-white">DisplayDeck</h3>
            <p className="text-sm">
              The open-source digital signage platform for developers.
            </p>
            <div className="flex space-x-4">
              <Link href="https://github.com/Japsterr/DisplayDeck" target="_blank" className="hover:text-white">
                <Github className="h-5 w-5" />
              </Link>
              <Link href="#" className="hover:text-white">
                <Twitter className="h-5 w-5" />
              </Link>
            </div>
          </div>
          <div>
            <h4 className="mb-4 text-sm font-semibold text-white uppercase tracking-wider">Product</h4>
            <ul className="space-y-2 text-sm">
              <li><Link href="/features" className="hover:text-white">Features</Link></li>
              <li><Link href="/integrations" className="hover:text-white">Integrations</Link></li>
              <li><Link href="/pricing" className="hover:text-white">Pricing</Link></li>
              <li><Link href="/changelog" className="hover:text-white">Changelog</Link></li>
            </ul>
          </div>
          <div>
            <h4 className="mb-4 text-sm font-semibold text-white uppercase tracking-wider">Resources</h4>
            <ul className="space-y-2 text-sm">
              <li><Link href="/docs" className="hover:text-white">Documentation</Link></li>
              <li><Link href="http://localhost:8080" target="_blank" className="hover:text-white">API Reference</Link></li>
              <li><Link href="https://github.com/Japsterr/DisplayDeck/discussions" target="_blank" className="hover:text-white">Community</Link></li>
            </ul>
          </div>
          <div>
            <h4 className="mb-4 text-sm font-semibold text-white uppercase tracking-wider">Legal</h4>
            <ul className="space-y-2 text-sm">
              <li><Link href="/privacy" className="hover:text-white">Privacy Policy</Link></li>
              <li><Link href="/terms" className="hover:text-white">Terms of Service</Link></li>
            </ul>
          </div>
        </div>
        <div className="mt-12 border-t border-neutral-800 pt-8 text-center text-sm">
          <p>&copy; {new Date().getFullYear()} DisplayDeck. All rights reserved.</p>
        </div>
      </div>
    </footer>
  );
}
