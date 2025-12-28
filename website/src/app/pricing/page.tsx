import { Navbar } from "@/components/landing/Navbar";
import { Footer } from "@/components/landing/Footer";
import { Check } from "lucide-react";
import { Button } from "@/components/ui/button";
import Link from "next/link";

export default function PricingPage() {
  return (
    <div className="flex min-h-screen flex-col bg-background">
      <Navbar />
      <main className="flex-1 pt-24 pb-16">
        <div className="container px-4 md:px-6">
          <div className="flex flex-col items-center justify-center space-y-4 text-center mb-16">
            <h1 className="text-4xl font-bold tracking-tighter sm:text-6xl bg-clip-text text-transparent bg-gradient-to-r from-white to-neutral-500">
              Simple, transparent pricing
            </h1>
            <p className="max-w-[900px] text-muted-foreground md:text-xl/relaxed">
              Start for free, scale as you grow. Open source is always free to self-host.
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-8 max-w-6xl mx-auto">
            {/* Free Tier */}
            <div className="rounded-xl border border-neutral-800 bg-neutral-900/50 p-8 flex flex-col">
              <h3 className="text-xl font-bold text-white mb-2">Self-Hosted</h3>
              <div className="text-3xl font-bold text-white mb-6">$0<span className="text-sm font-normal text-muted-foreground">/mo</span></div>
              <p className="text-muted-foreground mb-6 flex-1">
                Run DisplayDeck on your own infrastructure. Full access to the source code.
              </p>
              <ul className="space-y-3 mb-8">
                <li className="flex items-center text-sm"><Check className="h-4 w-4 text-green-500 mr-2" /> Unlimited Displays</li>
                <li className="flex items-center text-sm"><Check className="h-4 w-4 text-green-500 mr-2" /> Unlimited Users</li>
                <li className="flex items-center text-sm"><Check className="h-4 w-4 text-green-500 mr-2" /> Community Support</li>
                <li className="flex items-center text-sm"><Check className="h-4 w-4 text-green-500 mr-2" /> Docker Deployment</li>
              </ul>
              <Link href="https://github.com/Japsterr/DisplayDeck" target="_blank">
                <Button variant="outline" className="w-full">View on GitHub</Button>
              </Link>
            </div>

            {/* Cloud Starter */}
            <div className="rounded-xl border border-primary/50 bg-neutral-900/80 p-8 flex flex-col relative overflow-hidden">
              <div className="absolute top-0 right-0 bg-primary text-white text-xs font-bold px-3 py-1 rounded-bl-xl">POPULAR</div>
              <h3 className="text-xl font-bold text-white mb-2">Cloud Starter</h3>
              <div className="text-3xl font-bold text-white mb-6">$15<span className="text-sm font-normal text-muted-foreground">/screen/mo</span></div>
              <p className="text-muted-foreground mb-6 flex-1">
                We host it for you. Perfect for small businesses and startups.
              </p>
              <ul className="space-y-3 mb-8">
                <li className="flex items-center text-sm"><Check className="h-4 w-4 text-green-500 mr-2" /> Up to 10 Displays</li>
                <li className="flex items-center text-sm"><Check className="h-4 w-4 text-green-500 mr-2" /> 99.9% Uptime SLA</li>
                <li className="flex items-center text-sm"><Check className="h-4 w-4 text-green-500 mr-2" /> Automatic Updates</li>
                <li className="flex items-center text-sm"><Check className="h-4 w-4 text-green-500 mr-2" /> Email Support</li>
              </ul>
              <Link href="/register">
                <Button className="w-full">Start Free Trial</Button>
              </Link>
            </div>

            {/* Enterprise */}
            <div className="rounded-xl border border-neutral-800 bg-neutral-900/50 p-8 flex flex-col">
              <h3 className="text-xl font-bold text-white mb-2">Enterprise</h3>
              <div className="text-3xl font-bold text-white mb-6">Custom</div>
              <p className="text-muted-foreground mb-6 flex-1">
                For large scale deployments and custom requirements.
              </p>
              <ul className="space-y-3 mb-8">
                <li className="flex items-center text-sm"><Check className="h-4 w-4 text-green-500 mr-2" /> Volume Discounts</li>
                <li className="flex items-center text-sm"><Check className="h-4 w-4 text-green-500 mr-2" /> Dedicated Support</li>
                <li className="flex items-center text-sm"><Check className="h-4 w-4 text-green-500 mr-2" /> Custom Integrations</li>
                <li className="flex items-center text-sm"><Check className="h-4 w-4 text-green-500 mr-2" /> SSO / SAML</li>
              </ul>
              <Button variant="outline" className="w-full">Contact Sales</Button>
            </div>
          </div>
        </div>
      </main>
      <Footer />
    </div>
  );
}
