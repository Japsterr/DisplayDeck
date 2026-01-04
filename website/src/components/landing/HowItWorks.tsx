"use client";

import { Plug, PaintbrushVertical, Rocket, ArrowRight } from "lucide-react";
import Link from "next/link";
import { Button } from "@/components/ui/button";

const steps = [
  {
    number: "01",
    icon: <Plug className="h-8 w-8" />,
    title: "Connect Your Screens",
    description: "Plug any screen into an internet-connected device. Smart TVs, tablets, monitors, or our Android TV app.",
    gradient: "from-cyan-500 to-blue-500",
  },
  {
    number: "02",
    icon: <PaintbrushVertical className="h-8 w-8" />,
    title: "Design Your Content",
    description: "Use our drag-and-drop builder to create stunning menus, directories, or announcements in minutes.",
    gradient: "from-purple-500 to-pink-500",
  },
  {
    number: "03",
    icon: <Rocket className="h-8 w-8" />,
    title: "Go Live Instantly",
    description: "Assign content to your displays and watch it appear in real-time. Updates sync in under 2 seconds.",
    gradient: "from-orange-500 to-red-500",
  },
];

export function HowItWorks() {
  return (
    <section className="relative py-32 overflow-hidden">
      {/* Background */}
      <div className="absolute inset-0 bg-gradient-to-b from-slate-900 to-slate-950" />
      
      {/* Connecting Lines */}
      <div className="absolute top-1/2 left-0 right-0 h-px bg-gradient-to-r from-transparent via-purple-500/30 to-transparent hidden lg:block" />

      <div className="container relative mx-auto px-4 md:px-6">
        {/* Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white/5 border border-white/10 mb-6">
            <span className="text-sm font-medium text-white/90">Simple Setup</span>
          </div>
          <h2 className="text-4xl md:text-5xl font-bold text-white mb-6">
            Three Steps to{" "}
            <span className="bg-gradient-to-r from-cyan-400 to-purple-400 bg-clip-text text-transparent">
              Digital Signage Bliss
            </span>
          </h2>
          <p className="text-xl text-slate-400 leading-relaxed">
            From first login to live displays in under 10 minutes. No IT department required.
          </p>
        </div>

        {/* Steps */}
        <div className="grid md:grid-cols-3 gap-8 lg:gap-12 mb-16">
          {steps.map((step, i) => (
            <div key={i} className="relative group">
              {/* Step Card */}
              <div className="relative p-8 rounded-2xl bg-slate-900/50 border border-white/5 hover:border-white/10 transition-all duration-300 hover:-translate-y-2 h-full">
                {/* Number Badge */}
                <div className="absolute -top-4 -left-4 w-12 h-12 rounded-xl bg-slate-950 border border-white/10 flex items-center justify-center">
                  <span className={`text-sm font-bold bg-gradient-to-r ${step.gradient} bg-clip-text text-transparent`}>
                    {step.number}
                  </span>
                </div>

                {/* Icon */}
                <div className={`inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-gradient-to-br ${step.gradient} mb-6 shadow-lg`}>
                  <div className="text-white">{step.icon}</div>
                </div>

                <h3 className="text-xl font-bold text-white mb-3">{step.title}</h3>
                <p className="text-slate-400 leading-relaxed">{step.description}</p>
              </div>

              {/* Arrow (between cards on desktop) */}
              {i < steps.length - 1 && (
                <div className="hidden lg:block absolute top-1/2 -right-6 transform -translate-y-1/2 z-10">
                  <ArrowRight className="h-6 w-6 text-purple-500/50" />
                </div>
              )}
            </div>
          ))}
        </div>

        {/* CTA */}
        <div className="text-center">
          <Link href="/register">
            <Button
              size="lg"
              className="h-14 px-10 text-base rounded-xl bg-gradient-to-r from-cyan-500 to-purple-600 hover:from-cyan-600 hover:to-purple-700 text-white font-semibold shadow-lg shadow-purple-500/25 transition-all hover:shadow-purple-500/40 hover:scale-[1.02]"
            >
              Start Your Free Trial
              <ArrowRight className="ml-2 h-5 w-5" />
            </Button>
          </Link>
          <p className="mt-4 text-sm text-slate-500">No credit card required • Unlimited screens</p>
        </div>
      </div>
    </section>
  );
}
