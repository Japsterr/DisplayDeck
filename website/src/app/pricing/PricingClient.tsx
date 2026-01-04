"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { Check } from "lucide-react";

import { Button } from "@/components/ui/button";

type PricingMode = "ZA" | "GLOBAL";

function formatPrice(mode: PricingMode, amount: number) {
  if (mode === "ZA") {
    return `R${amount}`;
  }
  return `$${amount}`;
}

function getDefaultMode(): PricingMode {
  if (typeof window === "undefined") return "GLOBAL";

  const stored = window.localStorage.getItem("dd_pricing_mode");
  if (stored === "ZA" || stored === "GLOBAL") return stored;

  const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
  if (tz === "Africa/Johannesburg") return "ZA";

  return "GLOBAL";
}

export function PricingClient() {
  const [mode, setMode] = useState<PricingMode>("GLOBAL");

  useEffect(() => {
    setMode(getDefaultMode());
  }, []);

  useEffect(() => {
    if (typeof window === "undefined") return;
    window.localStorage.setItem("dd_pricing_mode", mode);
  }, [mode]);

  const pricing = useMemo(() => {
    const isZa = mode === "ZA";

    return {
      currencyLabel: isZa ? "South Africa (ZAR)" : "Global (USD)",
      tiers: {
        starter: {
          title: "Free",
          price: 0,
          unit: "/mo",
          subtitle: "Get started in minutes.",
          description: "Perfect for a small shop testing digital signage. No credit card required.",
          bullets: ["2 active displays", "500MB media storage"],
          ctaLabel: "Get Started Free",
          ctaHref: "/register",
          highlighted: false,
        },
        business: {
          title: "Starter",
          price: isZa ? 150 : 10,
          unit: "/mo",
          subtitle: "For growing stores.",
          description: "More screens and storage for daily updates and promotions.",
          bullets: ["5 active displays", "700MB media storage"],
          ctaLabel: "Start Now",
          ctaHref: "/register",
          highlighted: true,
        },
        pro: {
          title: "Pro",
          price: isZa ? 250 : 16,
          unit: "/mo",
          subtitle: "For multi-display setups.",
          description: "Ideal for larger floors and multiple content zones.",
          bullets: ["10 active displays", "1GB media storage"],
          ctaLabel: "Start Now",
          ctaHref: "/register",
          highlighted: false,
        },
        enterprise: {
          title: "Enterprise",
          price: isZa ? 0 : 0,
          unit: "",
          subtitle: "Unlimited scale.",
          description: "Unlimited displays, 10GB storage, and a custom quote for your rollout.",
          bullets: ["Unlimited displays", "10GB media storage"],
          ctaLabel: "Contact Us",
          ctaHref: "/integrations",
          highlighted: false,
        },
      },
      footerNote: "",
    };
  }, [mode]);

  return (
    <>
      <div className="flex items-center justify-center gap-2 mb-10">
        <div className="inline-flex rounded-full border border-neutral-800 bg-neutral-900/50 p-1">
          <button
            type="button"
            onClick={() => setMode("ZA")}
            className={
              "px-4 py-2 rounded-full text-sm font-semibold transition-colors " +
              (mode === "ZA"
                ? "bg-white text-black"
                : "text-neutral-300 hover:text-white")
            }
            aria-pressed={mode === "ZA"}
          >
            South Africa
          </button>
          <button
            type="button"
            onClick={() => setMode("GLOBAL")}
            className={
              "px-4 py-2 rounded-full text-sm font-semibold transition-colors " +
              (mode === "GLOBAL"
                ? "bg-white text-black"
                : "text-neutral-300 hover:text-white")
            }
            aria-pressed={mode === "GLOBAL"}
          >
            Global
          </button>
        </div>
        <div className="text-xs text-neutral-500 hidden sm:block">{pricing.currencyLabel}</div>
      </div>

      <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-8 max-w-6xl mx-auto">
        {(
          [
            pricing.tiers.starter,
            pricing.tiers.business,
            pricing.tiers.pro,
            pricing.tiers.enterprise,
          ] as const
        ).map((tier) => (
          <div
            key={tier.title}
            className={
              "rounded-xl border p-8 flex flex-col relative overflow-hidden " +
              (tier.highlighted
                ? "border-primary/50 bg-neutral-900/80"
                : "border-neutral-800 bg-neutral-900/50")
            }
          >
            {tier.highlighted ? (
              <div className="absolute top-0 right-0 bg-primary text-white text-xs font-bold px-3 py-1 rounded-bl-xl">
                BEST VALUE
              </div>
            ) : null}

            <h3 className="text-xl font-bold text-white mb-1">{tier.title}</h3>
            <div className="text-sm text-blue-300 font-semibold mb-4">{tier.subtitle}</div>

            <div className="text-3xl font-bold text-white mb-4">
              {tier.title === "Enterprise" ? "Custom" : formatPrice(mode, tier.price)}
              {tier.unit ? (
                <span className="text-sm font-normal text-muted-foreground">
                  {tier.unit}
                </span>
              ) : null}
            </div>

            <p className="text-muted-foreground mb-6 flex-1">{tier.description}</p>

            <ul className="space-y-3 mb-8">
              {tier.bullets.map((b) => (
                <li key={b} className="flex items-center text-sm">
                  <Check className="h-4 w-4 text-green-500 mr-2" />
                  {b}
                </li>
              ))}
            </ul>

            <Link href={tier.ctaHref}>
              <Button
                className="w-full"
                variant={tier.highlighted ? "default" : "outline"}
              >
                {tier.ctaLabel}
              </Button>
            </Link>
          </div>
        ))}
      </div>

      {pricing.footerNote ? (
        <div className="max-w-4xl mx-auto text-center mt-10 text-sm text-neutral-400">
          <p>{pricing.footerNote}</p>
        </div>
      ) : null}
    </>
  );
}
