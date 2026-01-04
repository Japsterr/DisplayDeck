"use client";

import { useEffect, useMemo, useState } from "react";
import { cn } from "@/lib/utils";

export type HeroSlide = {
  src: string;
  alt: string;
  label?: string;
};

export function HeroSlider({
  slides,
  intervalMs = 5000,
  className,
  fallback,
  onActiveChange,
}: {
  slides: HeroSlide[];
  intervalMs?: number;
  className?: string;
  fallback?: React.ReactNode;
  onActiveChange?: (slide: HeroSlide, index: number) => void;
}) {
  const [active, setActive] = useState(0);
  const [loadedSrcs, setLoadedSrcs] = useState<Record<string, boolean>>({});

  // Preflight images so we can gracefully fallback when assets aren't present.
  useEffect(() => {
    let cancelled = false;

    const run = async () => {
      const checks = await Promise.all(
        slides.map(
          (s) =>
            new Promise<{ src: string; ok: boolean }>((resolve) => {
              const img = new Image();
              img.onload = () => resolve({ src: s.src, ok: true });
              img.onerror = () => resolve({ src: s.src, ok: false });
              img.src = s.src;
            })
        )
      );

      if (cancelled) return;
      const next: Record<string, boolean> = {};
      for (const c of checks) next[c.src] = c.ok;
      setLoadedSrcs(next);
    };

    void run();
    return () => {
      cancelled = true;
    };
  }, [slides]);

  const usableSlides = useMemo(() => slides.filter((s) => loadedSrcs[s.src] !== false), [slides, loadedSrcs]);

  useEffect(() => {
    if (usableSlides.length <= 1) return;
    const t = setInterval(() => {
      setActive((p) => (p + 1) % usableSlides.length);
    }, Math.max(1500, intervalMs));
    return () => clearInterval(t);
  }, [usableSlides.length, intervalMs]);

  useEffect(() => {
    if (active >= usableSlides.length) setActive(0);
  }, [active, usableSlides.length]);

  useEffect(() => {
    if (!onActiveChange) return;
    const slide = usableSlides[active];
    if (!slide) return;
    onActiveChange(slide, active);
  }, [active, onActiveChange, usableSlides]);

  if (usableSlides.length === 0) {
    return <>{fallback ?? null}</>;
  }

  return (
    <div className={cn("relative", className)}>
      <div className="relative aspect-[16/10] sm:aspect-[16/9]">
        {usableSlides.map((s, idx) => {
          const isActive = idx === active;
          return (
            <img
              key={s.src}
              src={s.src}
              alt={s.alt}
              className={cn(
                "absolute inset-0 h-full w-full object-contain transition-opacity duration-500",
                isActive ? "opacity-100" : "opacity-0"
              )}
              loading={idx === 0 ? "eager" : "lazy"}
              draggable={false}
            />
          );
        })}

        {usableSlides.length > 1 ? (
          <div className="absolute bottom-2 right-2 flex items-center gap-2">
            {usableSlides.map((_, idx) => (
              <button
                key={idx}
                type="button"
                aria-label={`Go to slide ${idx + 1}`}
                className={cn(
                  "h-2 w-2 rounded-full transition-colors",
                  idx === active ? "bg-white" : "bg-white/30 hover:bg-white/50"
                )}
                onClick={() => setActive(idx)}
              />
            ))}
          </div>
        ) : null}
      </div>
    </div>
  );
}
