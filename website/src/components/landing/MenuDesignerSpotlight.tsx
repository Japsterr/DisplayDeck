import Link from "next/link";
import { Button } from "@/components/ui/button";

export function MenuDesignerSpotlight() {
  return (
    <section className="py-24 w-full relative overflow-hidden">
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_bottom,_var(--tw-gradient-stops))] from-purple-900/10 via-background to-background" />

      <div className="container relative mx-auto px-4 md:px-6">
        <div className="max-w-3xl mx-auto text-center space-y-4">
          <h2 className="text-3xl font-bold tracking-tighter sm:text-5xl text-white">
            Design Like a Pro. Deploy in Seconds.
          </h2>
          <p className="text-neutral-400 md:text-xl/relaxed">
            Why hire a graphic designer for every price change? Our built-in Menu Designer lets you create stunning layouts
            using a simple drag-and-drop interface.
          </p>
        </div>

        <div className="grid gap-6 md:grid-cols-3 max-w-5xl mx-auto mt-12">
          <div className="rounded-2xl bg-neutral-900/50 border border-white/5 p-6">
            <h3 className="text-white font-semibold mb-2">Live Previews</h3>
            <p className="text-sm text-neutral-400 leading-relaxed">
              See exactly what your customers see before you hit Publish.
            </p>
          </div>
          <div className="rounded-2xl bg-neutral-900/50 border border-white/5 p-6">
            <h3 className="text-white font-semibold mb-2">Smart Components</h3>
            <p className="text-sm text-neutral-400 leading-relaxed">
              Add prices, high-res food photos, and scrolling announcements in seconds.
            </p>
          </div>
          <div className="rounded-2xl bg-neutral-900/50 border border-white/5 p-6">
            <h3 className="text-white font-semibold mb-2">Instant Updates</h3>
            <p className="text-sm text-neutral-400 leading-relaxed">
              Changed a price? One click updates every screen in your building.
            </p>
          </div>
        </div>

        <div className="flex justify-center mt-10">
          <Link href="/register">
            <Button size="lg" className="h-12 px-8 rounded-full font-semibold">
              Get Started Now
            </Button>
          </Link>
        </div>
      </div>
    </section>
  );
}
