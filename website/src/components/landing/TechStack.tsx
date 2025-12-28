import { Database, Server, Code, Container, Smartphone, Wifi } from "lucide-react";

export function TechStack() {
  return (
    <section className="w-full py-12 border-y border-white/5 bg-black/20 backdrop-blur-sm">
      <div className="container px-4 md:px-6">
        <div className="flex flex-wrap justify-center gap-8 md:gap-16 items-center text-neutral-400">
          <div className="flex items-center gap-2 hover:text-white transition-colors">
            <Code className="h-5 w-5" />
            <span className="font-semibold">Next.js</span>
          </div>
          <div className="flex items-center gap-2 hover:text-white transition-colors">
            <Database className="h-5 w-5" />
            <span className="font-semibold">PostgreSQL</span>
          </div>
          <div className="flex items-center gap-2 hover:text-white transition-colors">
            <Container className="h-5 w-5" />
            <span className="font-semibold">Docker</span>
          </div>
          <div className="flex items-center gap-2 hover:text-white transition-colors">
            <Server className="h-5 w-5" />
            <span className="font-semibold">Python</span>
          </div>
          <div className="flex items-center gap-2 hover:text-white transition-colors">
            <Wifi className="h-5 w-5" />
            <span className="font-semibold">IoT</span>
          </div>
          <div className="flex items-center gap-2 hover:text-white transition-colors">
            <Smartphone className="h-5 w-5" />
            <span className="font-semibold">Mobile</span>
          </div>
        </div>
      </div>
    </section>
  );
}
