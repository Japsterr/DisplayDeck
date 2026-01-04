"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { ArrowRight, Play, Sparkles, Monitor, Smartphone, Tv, Check, ChevronRight } from "lucide-react";

const showcaseImages = [
  { src: "/landing/home_menu_example.jpg", alt: "Restaurant menu display", label: "Restaurant Menu" },
  { src: "/landing/information_display.jpg", alt: "Information display", label: "Info Display" },
  { src: "/landing/business_information.png", alt: "Business information board", label: "Business Info" },
];

const stats = [
  { value: "99.9%", label: "Uptime" },
  { value: "< 2s", label: "Sync Time" },
  { value: "∞", label: "Screens" },
];

export function Hero() {
  const [activeIndex, setActiveIndex] = useState(0);
  const [isHovered, setIsHovered] = useState(false);

  useEffect(() => {
    if (isHovered) return;
    const timer = setInterval(() => {
      setActiveIndex((prev) => (prev + 1) % showcaseImages.length);
    }, 4000);
    return () => clearInterval(timer);
  }, [isHovered]);

  return (
    <section className="relative min-h-screen flex items-center overflow-hidden bg-gradient-to-b from-slate-950 via-slate-900 to-slate-950">
      {/* Animated Background Grid */}
      <div className="absolute inset-0 bg-[linear-gradient(to_right,#1a1a2e_1px,transparent_1px),linear-gradient(to_bottom,#1a1a2e_1px,transparent_1px)] bg-[size:4rem_4rem] [mask-image:radial-gradient(ellipse_60%_50%_at_50%_0%,#000_70%,transparent_110%)]" />
      
      {/* Gradient Orbs */}
      <div className="absolute top-20 left-10 w-96 h-96 bg-purple-600/20 rounded-full blur-[128px] animate-pulse" />
      <div className="absolute bottom-20 right-10 w-96 h-96 bg-cyan-600/20 rounded-full blur-[128px] animate-pulse" />
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-indigo-600/10 rounded-full blur-[128px]" />

      <div className="container relative mx-auto px-4 md:px-6 py-24">
        <div className="grid lg:grid-cols-2 gap-16 items-center">
          {/* Left Content */}
          <div className="space-y-8">
            <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white/5 border border-white/10 backdrop-blur-sm">
              <div className="flex items-center justify-center w-6 h-6 rounded-full bg-gradient-to-r from-green-400 to-emerald-500">
                <Sparkles className="h-3 w-3 text-white" />
              </div>
              <span className="text-sm font-medium text-white/90">Open Source & Self-Hostable</span>
              <ChevronRight className="h-4 w-4 text-white/50" />
            </div>

            <h1 className="text-5xl md:text-7xl font-bold tracking-tight leading-[1.05]">
              <span className="text-white">Digital Signage</span>
              <br />
              <span className="bg-gradient-to-r from-cyan-400 via-purple-400 to-pink-400 bg-clip-text text-transparent">
                Made Simple
              </span>
            </h1>

            <p className="text-xl text-slate-400 max-w-xl leading-relaxed">
              Create beautiful menus, directories, and information displays with our intuitive drag-and-drop builder. 
              Deploy to any screen in seconds.
            </p>

            <div className="flex flex-col sm:flex-row gap-4">
              <Link href="/register">
                <Button
                  size="lg"
                  className="h-14 px-8 text-base rounded-xl bg-gradient-to-r from-cyan-500 to-purple-600 hover:from-cyan-600 hover:to-purple-700 text-white font-semibold shadow-lg shadow-purple-500/25 transition-all hover:shadow-purple-500/40 hover:scale-[1.02]"
                >
                  Get Started Free
                  <ArrowRight className="ml-2 h-5 w-5" />
                </Button>
              </Link>
              <Link href="/swagger/" target="_blank">
                <Button
                  size="lg"
                  variant="outline"
                  className="h-14 px-8 text-base rounded-xl border-white/10 bg-white/5 hover:bg-white/10 text-white font-medium backdrop-blur-sm"
                >
                  <Play className="mr-2 h-5 w-5" />
                  View API Docs
                </Button>
              </Link>
            </div>

            {/* Trust Indicators */}
            <div className="flex flex-wrap items-center gap-x-8 gap-y-4 pt-6">
              {[
                "No credit card required",
                "Unlimited free tier",
                "Self-host option",
              ].map((item, i) => (
                <div key={i} className="flex items-center gap-2 text-sm text-slate-400">
                  <div className="flex items-center justify-center w-5 h-5 rounded-full bg-green-500/20">
                    <Check className="h-3 w-3 text-green-400" />
                  </div>
                  {item}
                </div>
              ))}
            </div>

            {/* Stats */}
            <div className="flex gap-8 pt-8 border-t border-white/10">
              {stats.map((stat, i) => (
                <div key={i} className="text-center">
                  <div className="text-3xl font-bold text-white">{stat.value}</div>
                  <div className="text-sm text-slate-500">{stat.label}</div>
                </div>
              ))}
            </div>
          </div>

          {/* Right Content - Showcase */}
          <div 
            className="relative"
            onMouseEnter={() => setIsHovered(true)}
            onMouseLeave={() => setIsHovered(false)}
          >
            {/* Main Display Frame */}
            <div className="relative">
              {/* Glow Effect */}
              <div className="absolute -inset-4 bg-gradient-to-r from-cyan-500/20 via-purple-500/20 to-pink-500/20 rounded-3xl blur-2xl opacity-60" />
              
              {/* Monitor Frame */}
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
                      displaydeck.co.za/display/preview
                    </div>
                  </div>
                </div>

                {/* Screen Content */}
                <div className="relative aspect-video rounded-lg overflow-hidden bg-black">
                  {showcaseImages.map((img, i) => (
                    <div
                      key={i}
                      className={`absolute inset-0 transition-all duration-700 ${
                        i === activeIndex 
                          ? "opacity-100 scale-100" 
                          : "opacity-0 scale-105"
                      }`}
                    >
                      <Image
                        src={img.src}
                        alt={img.alt}
                        fill
                        className="object-cover"
                        priority={i === 0}
                      />
                      {/* Overlay */}
                      <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent" />
                    </div>
                  ))}
                  
                  {/* Active Label */}
                  <div className="absolute bottom-4 left-4 right-4 flex items-center justify-between">
                    <Badge className="bg-white/10 backdrop-blur-md border-white/20 text-white">
                      {showcaseImages[activeIndex].label}
                    </Badge>
                    <div className="flex gap-1.5">
                      {showcaseImages.map((_, i) => (
                        <button
                          key={i}
                          onClick={() => setActiveIndex(i)}
                          className={`w-2 h-2 rounded-full transition-all ${
                            i === activeIndex 
                              ? "bg-white w-6" 
                              : "bg-white/30 hover:bg-white/50"
                          }`}
                        />
                      ))}
                    </div>
                  </div>
                </div>
              </div>

              {/* Floating Device Icons */}
              <div className="absolute -left-6 top-1/4 bg-slate-800/80 backdrop-blur-sm rounded-xl p-3 border border-white/10 shadow-xl">
                <Monitor className="h-6 w-6 text-cyan-400" />
              </div>
              <div className="absolute -right-6 top-1/2 bg-slate-800/80 backdrop-blur-sm rounded-xl p-3 border border-white/10 shadow-xl">
                <Tv className="h-6 w-6 text-purple-400" />
              </div>
              <div className="absolute -right-4 bottom-8 bg-slate-800/80 backdrop-blur-sm rounded-xl p-3 border border-white/10 shadow-xl">
                <Smartphone className="h-6 w-6 text-pink-400" />
              </div>
            </div>

            {/* Feature Pills */}
            <div className="flex flex-wrap justify-center gap-3 mt-8">
              {["Restaurant Menus", "Mall Directories", "Corporate Info", "HSEQ Boards"].map((feature) => (
                <div 
                  key={feature}
                  className="px-4 py-2 rounded-full bg-white/5 border border-white/10 text-sm text-slate-400 hover:bg-white/10 hover:text-white transition-colors cursor-default"
                >
                  {feature}
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Bottom Fade */}
      <div className="absolute bottom-0 left-0 right-0 h-32 bg-gradient-to-t from-slate-950 to-transparent pointer-events-none" />
    </section>
  );
}
