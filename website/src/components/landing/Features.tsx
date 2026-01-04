"use client";

import { Monitor, Palette, Clock, Globe, Shield, Zap, Layers, Smartphone } from "lucide-react";

const features = [
  {
    icon: <Palette className="h-6 w-6" />,
    title: "Visual Menu Designer",
    description: "Drag-and-drop editor with professional templates. No design skills needed.",
    gradient: "from-pink-500 to-rose-500",
  },
  {
    icon: <Monitor className="h-6 w-6" />,
    title: "Any Screen, Anywhere",
    description: "Smart TVs, tablets, monitors, or kiosks. If it has a browser, it works.",
    gradient: "from-cyan-500 to-blue-500",
  },
  {
    icon: <Clock className="h-6 w-6" />,
    title: "Smart Scheduling",
    description: "Breakfast menus become lunch menus automatically. Set it and forget it.",
    gradient: "from-amber-500 to-orange-500",
  },
  {
    icon: <Globe className="h-6 w-6" />,
    title: "Instant Global Sync",
    description: "Update once, see changes everywhere in under 2 seconds.",
    gradient: "from-green-500 to-emerald-500",
  },
  {
    icon: <Shield className="h-6 w-6" />,
    title: "Enterprise Security",
    description: "Role-based access, audit logs, and your data stays on your infrastructure.",
    gradient: "from-purple-500 to-violet-500",
  },
  {
    icon: <Zap className="h-6 w-6" />,
    title: "Blazing Fast",
    description: "Optimized for 24/7 operation. Screens load instantly, every time.",
    gradient: "from-yellow-500 to-amber-500",
  },
  {
    icon: <Layers className="h-6 w-6" />,
    title: "Multi-Zone Layouts",
    description: "Show menus, promotions, and info on the same screen with smart zones.",
    gradient: "from-indigo-500 to-purple-500",
  },
  {
    icon: <Smartphone className="h-6 w-6" />,
    title: "Mobile Management",
    description: "Full control from your phone. Update prices while standing in line.",
    gradient: "from-teal-500 to-cyan-500",
  },
];

export function Features() {
  return (
    <section id="features" className="relative py-32 overflow-hidden">
      {/* Background */}
      <div className="absolute inset-0 bg-gradient-to-b from-slate-950 via-slate-900 to-slate-950" />
      <div className="absolute inset-0 bg-[linear-gradient(to_right,#1a1a2e_1px,transparent_1px),linear-gradient(to_bottom,#1a1a2e_1px,transparent_1px)] bg-[size:4rem_4rem] opacity-30" />
      
      {/* Gradient Orbs */}
      <div className="absolute top-1/4 -left-20 w-96 h-96 bg-cyan-600/10 rounded-full blur-[128px]" />
      <div className="absolute bottom-1/4 -right-20 w-96 h-96 bg-purple-600/10 rounded-full blur-[128px]" />

      <div className="container relative mx-auto px-4 md:px-6">
        {/* Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white/5 border border-white/10 mb-6">
            <span className="text-sm font-medium text-white/90">Packed with Features</span>
          </div>
          <h2 className="text-4xl md:text-5xl font-bold text-white mb-6">
            Everything You Need to{" "}
            <span className="bg-gradient-to-r from-cyan-400 to-purple-400 bg-clip-text text-transparent">
              Own Your Screens
            </span>
          </h2>
          <p className="text-xl text-slate-400 leading-relaxed">
            From small cafés to enterprise deployments, DisplayDeck scales with your business.
          </p>
        </div>

        {/* Feature Grid */}
        <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6">
          {features.map((feature, i) => (
            <div
              key={i}
              className="group relative p-6 rounded-2xl bg-slate-900/50 border border-white/5 hover:border-white/10 transition-all duration-300 hover:-translate-y-1"
            >
              {/* Hover Glow */}
              <div className={`absolute inset-0 bg-gradient-to-br ${feature.gradient} opacity-0 group-hover:opacity-5 rounded-2xl transition-opacity`} />
              
              <div className="relative">
                {/* Icon */}
                <div className={`inline-flex items-center justify-center w-12 h-12 rounded-xl bg-gradient-to-br ${feature.gradient} mb-4`}>
                  <div className="text-white">{feature.icon}</div>
                </div>

                <h3 className="text-lg font-semibold text-white mb-2 group-hover:text-transparent group-hover:bg-gradient-to-r group-hover:from-cyan-400 group-hover:to-purple-400 group-hover:bg-clip-text transition-all">
                  {feature.title}
                </h3>
                <p className="text-sm text-slate-400 leading-relaxed">
                  {feature.description}
                </p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
