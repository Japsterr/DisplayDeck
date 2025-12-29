"use client";

import { useEffect, useMemo, useState } from "react";
import { useParams } from "next/navigation";

type ThemeConfig = Record<string, unknown>;

interface PublicMenuItem {
  Id: number;
  Name: string;
  Description: string | null;
  PriceCents: number | null;
  IsAvailable: boolean;
  DisplayOrder: number;
}

interface PublicMenuSection {
  Id: number;
  Name: string;
  DisplayOrder: number;
  Items: PublicMenuItem[];
}

interface PublicMenu {
  Id: number;
  Name: string;
  Orientation: string;
  TemplateKey: string;
  ThemeConfig?: ThemeConfig;
  Sections: PublicMenuSection[];
}

function getApiUrl() {
  return process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";
}

function formatCurrencyZarFromCents(priceCents: number) {
  try {
    return new Intl.NumberFormat("en-ZA", { style: "currency", currency: "ZAR" }).format(priceCents / 100);
  } catch {
    return `R ${(priceCents / 100).toFixed(2)}`;
  }
}

function getThemeString(theme: ThemeConfig | undefined, key: string, fallback: string) {
  const val = theme?.[key];
  return typeof val === "string" && val.trim() ? val : fallback;
}

export default function DisplayMenuPage() {
  const params = useParams();
  const token = params.token as string;

  const [menu, setMenu] = useState<PublicMenu | null>(null);
  const [error, setError] = useState<string>("");
  const [loading, setLoading] = useState(true);

  const apiUrl = useMemo(() => getApiUrl(), []);

  const fetchMenu = async () => {
    try {
      setError("");
      const res = await fetch(`${apiUrl}/public/menus/${token}`, { cache: "no-store" });
      if (!res.ok) throw new Error(await res.text());
      const data = (await res.json()) as PublicMenu;
      setMenu(data);
    } catch (e) {
      console.error(e);
      setError("Failed to load menu");
      setMenu(null);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchMenu();
    const t = setInterval(fetchMenu, 15_000);
    return () => clearInterval(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  if (loading) {
    return <div className="min-h-screen flex items-center justify-center text-muted-foreground">Loading...</div>;
  }

  if (error || !menu) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <div className="text-lg font-semibold">Menu unavailable</div>
          <div className="text-sm text-muted-foreground">{error || "Not found"}</div>
        </div>
      </div>
    );
  }

  const theme = menu.ThemeConfig || {};
  const bg = getThemeString(theme, "backgroundColor", "#0b0f19");
  const text = getThemeString(theme, "textColor", "#ffffff");
  const muted = getThemeString(theme, "mutedTextColor", "#cbd5e1");
  const accent = getThemeString(theme, "accentColor", "#22c55e");

  const orientation = (menu.Orientation || "Landscape").toLowerCase();
  const sectionCols = orientation === "portrait" ? "grid-cols-1" : "grid-cols-2";

  const sections = (menu.Sections || []).slice().sort((a, b) => a.DisplayOrder - b.DisplayOrder);

  return (
    <div
      className="min-h-screen"
      style={{ backgroundColor: bg, color: text }}
    >
      <div className="px-10 py-8">
        <div className="flex items-end justify-between gap-6">
          <div>
            <h1 className="text-5xl font-bold tracking-tight">{menu.Name}</h1>
            <div className="mt-2 text-base" style={{ color: muted }}>
              Updated automatically
            </div>
          </div>
          <div className="text-sm" style={{ color: muted }}>
            DisplayDeck
          </div>
        </div>

        <div className={`mt-10 grid ${sectionCols} gap-8`}>
          {sections.map((s) => {
            const items = (s.Items || [])
              .filter((i) => i.IsAvailable !== false)
              .slice()
              .sort((a, b) => a.DisplayOrder - b.DisplayOrder);

            return (
              <div key={s.Id} className="rounded-2xl border border-white/10 p-6">
                <div className="flex items-baseline justify-between gap-4">
                  <h2 className="text-3xl font-semibold">{s.Name}</h2>
                  <div className="h-[2px] flex-1 bg-white/10" />
                </div>

                <div className="mt-5 space-y-4">
                  {items.length === 0 ? (
                    <div className="text-sm" style={{ color: muted }}>
                      No items
                    </div>
                  ) : (
                    items.map((it) => (
                      <div key={it.Id} className="flex items-start justify-between gap-6">
                        <div className="min-w-0">
                          <div className="text-xl font-medium leading-snug">{it.Name}</div>
                          {it.Description ? (
                            <div className="mt-1 text-sm leading-snug" style={{ color: muted }}>
                              {it.Description}
                            </div>
                          ) : null}
                        </div>
                        <div className="shrink-0 text-xl font-semibold" style={{ color: accent }}>
                          {it.PriceCents != null ? formatCurrencyZarFromCents(it.PriceCents) : ""}
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
