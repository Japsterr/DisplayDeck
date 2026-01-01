import Link from "next/link";
import { Button } from "@/components/ui/button";

export function ClosingCta() {
  return (
    <section className="py-24 w-full relative overflow-hidden">
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,_var(--tw-gradient-stops))] from-indigo-900/20 via-background to-background" />
      <div className="container relative mx-auto px-4 md:px-6">
        <div className="max-w-3xl mx-auto text-center space-y-5">
          <h2 className="text-3xl font-bold tracking-tighter sm:text-5xl text-white">
            Ready to transform your customer experience?
          </h2>
          <p className="text-neutral-400 md:text-xl/relaxed">
            Join the businesses already using DisplayDeck to drive more sales through better signage.
          </p>
          <div className="flex justify-center">
            <Link href="/register">
              <Button size="lg" className="h-12 px-10 rounded-full font-semibold">
                Create Your Free Account
              </Button>
            </Link>
          </div>
        </div>
      </div>
    </section>
  );
}
