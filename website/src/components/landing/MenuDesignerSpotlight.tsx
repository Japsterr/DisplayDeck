"use client";

import Image from "next/image";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { ArrowRight, Sparkles, Layers, Wand2, Eye } from "lucide-react";

const builderFeatures = [
  {
    icon: <Layers className="h-5 w-5" />,
    title: "Drag & Drop Editor",
    description: "Intuitive canvas where you can place and resize elements freely.",
  },
  {
    icon: <Wand2 className="h-5 w-5" />,
    title: "Smart Templates",
    description: "Start with pro-designed templates for QSR, fine dining, or retail.",
  },
  {
    icon: <Eye className="h-5 w-5" />,
    title: "Live Preview",
    description: "See exactly how your content will look on the actual display.",
  },
];

export function MenuDesignerSpotlight() {
  return (
    <section className="relative py-32 overflow-hidden">
      {/* Background */}
      <div className="absolute inset-0 bg-gradient-to-b from-slate-950 to-slate-900" />
      
      {/* Accent Gradient */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[1000px] h-[600px] bg-gradient-to-r from-purple-600/10 via-cyan-600/10 to-pink-600/10 rounded-full blur-[100px]" />

      <div className="container relative mx-auto px-4 md:px-6">
        <div className="grid lg:grid-cols-2 gap-16 items-center">
          {/* Left - Preview Image */}
          <div className="relative order-2 lg:order-1">
            {/* Glow */}
            <div className="absolute -inset-4 bg-gradient-to-r from-cyan-500/20 via-purple-500/20 to-pink-500/20 rounded-3xl blur-2xl opacity-50" />
            
            {/* Browser Frame */}
            <div className="relative bg-slate-900 rounded-2xl p-3 border border-white/10 shadow-2xl">
              {/* Top Bar */}
              <div className="flex items-center gap-2 mb-3 px-2">
                <div className="flex gap-1.5">
                  <div className="w-3 h-3 rounded-full bg-red-500/80" />
                  <div className="w-3 h-3 rounded-full bg-yellow-500/80" />
                  <div className="w-3 h-3 rounded-full bg-green-500/80" />
                </div>
                <div className="flex-1 flex justify-center">
                  <div className="px-4 py-1 rounded-full bg-white/5 text-xs text-slate-500 font-mono">
                    displaydeck.co.za/dashboard/menus/designer
                  </div>
                </div>
              </div>

              {/* Screenshot */}
              <div className="relative aspect-[16/10] rounded-lg overflow-hidden bg-slate-800">
                <Image
                  src="/landing/home_menu_example.jpg"
                  alt="Menu Designer Interface"
                  fill
                  className="object-cover"
                />
                {/* Overlay gradient */}
                <div className="absolute inset-0 bg-gradient-to-t from-slate-900/30 to-transparent" />
              </div>
            </div>

            {/* Floating Elements */}
            <div className="absolute -top-4 -right-4 bg-gradient-to-br from-purple-600 to-pink-600 rounded-xl p-3 shadow-lg shadow-purple-500/25">
              <Sparkles className="h-6 w-6 text-white" />
            </div>
          </div>

          {/* Right - Content */}
          <div className="space-y-8 order-1 lg:order-2">
            <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white/5 border border-white/10">
              <Wand2 className="h-4 w-4 text-purple-400" />
              <span className="text-sm font-medium text-white/90">Visual Menu Builder</span>
            </div>

            <h2 className="text-4xl md:text-5xl font-bold text-white leading-tight">
              Design Like a Pro.{" "}
              <span className="bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent">
                Deploy in Seconds.
              </span>
            </h2>

            <p className="text-xl text-slate-400 leading-relaxed">
              Why hire a graphic designer for every price change? Our built-in Menu Designer 
              lets you create stunning layouts using a simple drag-and-drop interface.
            </p>

            <div className="space-y-4">
              {builderFeatures.map((feature, i) => (
                <div key={i} className="flex items-start gap-4 p-4 rounded-xl bg-white/5 border border-white/5 hover:border-white/10 transition-colors">
                  <div className="flex items-center justify-center w-10 h-10 rounded-lg bg-gradient-to-br from-purple-500/20 to-pink-500/20 text-purple-400">
                    {feature.icon}
                  </div>
                  <div>
                    <h3 className="font-semibold text-white mb-1">{feature.title}</h3>
                    <p className="text-sm text-slate-400">{feature.description}</p>
                  </div>
                </div>
              ))}
            </div>

            <Link href="/register">
              <Button
                size="lg"
                className="h-14 px-8 text-base rounded-xl bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white font-semibold shadow-lg shadow-purple-500/25 transition-all hover:shadow-purple-500/40 hover:scale-[1.02]"
              >
                Try the Designer Free
                <ArrowRight className="ml-2 h-5 w-5" />
              </Button>
            </Link>
          </div>
        </div>
      </div>
    </section>
  );
}
