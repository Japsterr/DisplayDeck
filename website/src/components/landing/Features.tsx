import { ConnectedHub } from "./ConnectedHub";
import {
  Monitor,
  RefreshCw,
  ShieldCheck,
  Globe,
} from "lucide-react";

export function Features() {
  return (
    <section className="py-24 w-full relative overflow-hidden">
      {/* Background Glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[800px] bg-indigo-900/10 rounded-full blur-3xl -z-10" />

      <div className="container mx-auto px-4 md:px-6">
        <div className="flex flex-col items-center justify-center space-y-4 text-center mb-16">
          <h2 className="text-3xl font-bold tracking-tighter sm:text-5xl text-white">
            The problem solved.
          </h2>
          <p className="max-w-[900px] text-neutral-400 md:text-xl/relaxed">
            Professional signage that looks great, stays online, and is easy to manage.
          </p>
        </div>

        {/* Connected Diagram */}
        <ConnectedHub />

        {/* Feature Cards Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mt-16">
          {items.map((item, i) => (
            <div key={i} className="group relative p-6 rounded-2xl bg-neutral-900/50 border border-white/5 hover:border-indigo-500/30 transition-all duration-300 hover:-translate-y-1">
              <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/5 to-purple-500/5 rounded-2xl opacity-0 group-hover:opacity-100 transition-opacity" />
              
              <div className="relative z-10 flex flex-col items-center text-center space-y-4">
                <div className="p-3 rounded-xl bg-neutral-800/50 group-hover:bg-indigo-500/20 transition-colors">
                  {item.icon}
                </div>
                <h3 className="text-lg font-semibold text-white">{item.title}</h3>
                <p className="text-sm text-neutral-400 leading-relaxed">
                  {item.description}
                </p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

const items = [
  {
    title: "Complete Hardware Freedom",
    description: "Stop buying expensive proprietary players. DisplayDeck works with the screens you already have—from Smart TVs to tablets and standard monitors.",
    icon: <Monitor className="h-6 w-6 text-blue-400" />,
  },
  {
    title: "Visual Drag-and-Drop",
    description: "No more messing with flash drives or static images. Use an intuitive canvas to build menus and layouts that fit your brand.",
    icon: <RefreshCw className="h-6 w-6 text-green-400" />,
  },
  {
    title: "Enterprise-Level Reliability",
    description: "Built for 24/7 operation. Whether you have one screen in a cafe or a hundred across a city, your content stays live and secure.",
    icon: <ShieldCheck className="h-6 w-6 text-red-400" />,
  },
  {
    title: "Global Sync & Scheduling",
    description: "Manage your entire network from your phone or laptop. Schedule breakfast menus to switch to lunch automatically—no manual effort required.",
    icon: <Globe className="h-6 w-6 text-purple-400" />,
  },
];
