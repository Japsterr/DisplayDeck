import { Navbar } from "@/components/landing/Navbar";
import { Footer } from "@/components/landing/Footer";
import { PricingClient } from "./PricingClient";

export default function PricingPage() {
  return (
    <div className="flex min-h-screen flex-col bg-background">
      <Navbar />
      <main className="flex-1 pt-24 pb-16">
        <div className="container px-4 md:px-6">
          <div className="flex flex-col items-center justify-center space-y-4 text-center mb-16">
            <h1 className="text-4xl font-bold tracking-tighter sm:text-6xl bg-clip-text text-transparent bg-gradient-to-r from-white to-neutral-500">
              Professional signage for the local shop.
            </h1>
            <p className="max-w-[900px] text-muted-foreground md:text-xl/relaxed">
              Simple monthly pricing that feels like an easy yes—especially compared to reprinting menus.
            </p>
          </div>

          <PricingClient />
        </div>
      </main>
      <Footer />
    </div>
  );
}
