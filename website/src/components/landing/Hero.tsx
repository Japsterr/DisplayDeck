"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { DashboardPreview } from "./DashboardPreview";
import { HeroSlide, HeroSlider } from "./HeroSlider";

export function Hero() {
  const slides: HeroSlide[] = useMemo(
    () => [
      {
        src: "/landing/slider-1.jpg",
        alt: "Menu template preview",
        label: "Premium menus that look great on any screen",
      },
      {
        src: "/landing/slider-2.jpg",
        alt: "Promotion template preview",
        label: "Promotions that pop — updated in seconds",
      },
      {
        src: "/landing/slider-3.png",
        alt: "Schedule template preview",
        label: "Schedules and playlists that run themselves",
      },
    ],
    []
  );

  const [activeSlide, setActiveSlide] = useState<HeroSlide>(slides[0]);

  return (
    <section className="relative overflow-hidden pt-20 md:pt-24 pb-16">
      {/* Background Effects */}
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-indigo-900/20 via-background to-background" />
      <div className="absolute inset-0 bg-[url('/grid.svg')] bg-center [mask-image:linear-gradient(180deg,white,rgba(255,255,255,0))]" />
      
      <div className="container relative px-4 md:px-6 z-10">
        <div className="grid gap-12 lg:grid-cols-2 lg:gap-8 items-center">
          {/* Slider / Visual */}
          <div className="mx-auto w-full max-w-[800px] lg:max-w-none perspective-1000 lg:order-1">
            <HeroSlider
              className="w-full"
              slides={slides}
              fallback={<DashboardPreview />}
              onActiveChange={(slide) => setActiveSlide(slide)}
            />
          </div>

          <div className="flex flex-col justify-center space-y-8 lg:order-2">
            <div className="space-y-6">
              <h1 className="text-4xl font-bold tracking-tighter sm:text-5xl xl:text-6xl/none text-white">
                {activeSlide?.label || ""}
              </h1>

              <p className="max-w-[650px] text-neutral-300 md:text-xl leading-relaxed">
                The ultimate digital signage suite for businesses. Design beautiful menus, schedule promotions, and manage an unlimited network of displays with zero technical effort.
              </p>
            </div>

            <div className="flex flex-col gap-4 min-[400px]:flex-row">
              <Link href="/register">
                <Button size="lg" className="h-12 px-8 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 text-white border-0 shadow-lg shadow-purple-500/20 rounded-full font-semibold text-base">
                  Get Started Now
                </Button>
              </Link>
              <Link href="/#templates">
                <Button size="lg" variant="outline" className="h-12 px-8 rounded-full font-semibold text-base">
                  View Template Gallery
                </Button>
              </Link>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
