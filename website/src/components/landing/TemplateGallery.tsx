import Link from "next/link";
import { Button } from "@/components/ui/button";

const templates = [
  {
    name: "Classic Menu",
    desc: "A clean, high-contrast menu board for fast readability.",
  },
  {
    name: "Image-Forward",
    desc: "Showcase high-res product photos while keeping prices prominent.",
  },
  {
    name: "Announcements",
    desc: "Perfect for specials, promos, and time-based messaging.",
  },
];

export function TemplateGallery() {
  return (
    <section id="templates" className="py-24 w-full relative overflow-hidden">
      <div className="container mx-auto px-4 md:px-6">
        <div className="flex flex-col items-center justify-center space-y-4 text-center mb-12">
          <h2 className="text-3xl font-bold tracking-tighter sm:text-5xl text-white">Template Gallery</h2>
          <p className="max-w-[900px] text-neutral-400 md:text-xl/relaxed">
            Start with a proven layout and make it yours in minutes.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-6xl mx-auto">
          {templates.map((t) => (
            <div key={t.name} className="group relative p-6 rounded-2xl bg-neutral-900/50 border border-white/5">
              <div className="h-40 rounded-xl bg-gradient-to-br from-indigo-500/15 to-purple-500/15 border border-white/5" />
              <h3 className="text-white font-semibold mt-5">{t.name}</h3>
              <p className="text-sm text-neutral-400 leading-relaxed mt-2">{t.desc}</p>
            </div>
          ))}
        </div>

        <div className="flex justify-center mt-10">
          <Link href="/register">
            <Button size="lg" variant="outline" className="h-12 px-8 rounded-full font-semibold">
              Get Started Now
            </Button>
          </Link>
        </div>
      </div>
    </section>
  );
}
