"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useParams } from "next/navigation";

type ThemeConfig = Record<string, unknown>;

const MEDIA_REF_PREFIX = "mediafile:";

function parseMediaRef(raw: string | null | undefined): number | null {
  const s = (raw || "").trim();
  if (!s.toLowerCase().startsWith(MEDIA_REF_PREFIX)) return null;
  const n = parseInt(s.slice(MEDIA_REF_PREFIX.length), 10);
  return Number.isFinite(n) && n > 0 ? n : null;
}

interface PublicMenuItem {
  Id: number;
  Name: string;
  Sku: string | null;
  Description: string | null;
  ImageUrl: string | null;
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

function getThemeStringArray(theme: ThemeConfig | undefined, key: string): string[] {
  const val = theme?.[key];
  if (!Array.isArray(val)) return [];
  return val
    .filter((x) => typeof x === "string")
    .map((x) => (x as string).trim())
    .filter(Boolean);
}

function getThemeStringMap(theme: ThemeConfig | undefined, key: string): Record<string, string> {
  const val = theme?.[key];
  if (!val || typeof val !== "object" || Array.isArray(val)) return {};
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(val as Record<string, unknown>)) {
    if (typeof v === "string" && v.trim()) out[k] = v.trim();
  }
  return out;
}

function getThemeNumber(theme: ThemeConfig | undefined, key: string): number | null {
  const val = theme?.[key];
  if (typeof val === "number" && isFinite(val)) return val;
  if (typeof val === "string" && val.trim()) {
    const n = parseInt(val.trim(), 10);
    return isFinite(n) ? n : null;
  }
  return null;
}

function getTemplateKey(raw: string | undefined): "classic" | "minimal" | "neon" {
  const key = (raw || "classic").toLowerCase();
  if (key === "minimal" || key === "neon" || key === "classic") return key;
  return "classic";
}

function renderClassic(args: {
  menuName: string;
  muted: string;
  accent: string;
  sectionCols: string;
  sections: PublicMenuSection[];
  logoUrl?: string;
  sectionImages?: Record<string, string>;
}) {
  const { menuName, muted, accent, sectionCols, sections, logoUrl, sectionImages } = args;
  return (
    <div className="px-10 py-8">
      <div className="flex items-end justify-between gap-6">
        <div>
          <h1 className="text-5xl font-bold tracking-tight">{menuName}</h1>
          <div className="mt-2 text-base" style={{ color: muted }}>
            Updated automatically
          </div>
        </div>
        <div className="flex items-end gap-4">
          {logoUrl ? <img src={logoUrl} alt="" className="h-10 w-auto object-contain" /> : null}
          <div className="text-sm" style={{ color: muted }}>
            DisplayDeck
          </div>
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
                <div className="flex items-center gap-3 min-w-0">
                  {sectionImages?.[String(s.Id)] ? (
                    <img
                      src={sectionImages[String(s.Id)]}
                      alt=""
                      className="h-16 w-16 rounded-lg object-cover border border-white/10"
                      loading="lazy"
                    />
                  ) : null}
                  <h2 className="text-3xl font-semibold truncate">{s.Name}</h2>
                </div>
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
                        {it.ImageUrl ? (
                          <img
                            src={it.ImageUrl}
                            alt={it.Name}
                            className="mt-2 h-20 w-28 rounded-md object-cover border border-white/10"
                            loading="lazy"
                          />
                        ) : null}
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
  );
}

function renderMinimal(args: {
  menuName: string;
  muted: string;
  accent: string;
  sectionCols: string;
  sections: PublicMenuSection[];
  logoUrl?: string;
  sectionImages?: Record<string, string>;
}) {
  const { menuName, muted, accent, sectionCols, sections, logoUrl, sectionImages } = args;
  return (
    <div className="px-12 py-10">
      <div className="flex items-center justify-between gap-6">
        <div>
          <div className="text-sm tracking-widest uppercase" style={{ color: muted }}>
            Menu
          </div>
          <h1 className="mt-2 text-6xl font-semibold tracking-tight">{menuName}</h1>
        </div>
        <div className="flex items-center gap-4">
          {logoUrl ? <img src={logoUrl} alt="" className="h-10 w-auto object-contain" /> : null}
          <div className="h-10 w-10 rounded-full" style={{ backgroundColor: accent, opacity: 0.85 }} />
        </div>
      </div>

      <div className={`mt-10 grid ${sectionCols} gap-10`}>
        {sections.map((s) => {
          const items = (s.Items || [])
            .filter((i) => i.IsAvailable !== false)
            .slice()
            .sort((a, b) => a.DisplayOrder - b.DisplayOrder);

          return (
            <div key={s.Id}>
              <div className="flex items-center gap-3">
                <div className="h-1 w-10 rounded" style={{ backgroundColor: accent }} />
                {sectionImages?.[String(s.Id)] ? (
                  <img
                    src={sectionImages[String(s.Id)]}
                    alt=""
                    className="h-16 w-16 rounded-lg object-cover"
                    style={{ border: `1px solid ${accent}2A` }}
                    loading="lazy"
                  />
                ) : null}
                <h2 className="text-3xl font-medium">{s.Name}</h2>
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
                        <div className="text-2xl font-medium leading-snug">{it.Name}</div>
                        {it.ImageUrl ? (
                          <img
                            src={it.ImageUrl}
                            alt={it.Name}
                            className="mt-2 h-24 w-32 rounded-md object-cover"
                            style={{ border: `1px solid ${accent}2A` }}
                            loading="lazy"
                          />
                        ) : null}
                        {it.Description ? (
                          <div className="mt-1 text-base leading-snug" style={{ color: muted }}>
                            {it.Description}
                          </div>
                        ) : null}
                      </div>
                      <div className="shrink-0 text-2xl font-semibold" style={{ color: accent }}>
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
  );
}

function renderNeon(args: {
  menuName: string;
  muted: string;
  accent: string;
  sectionCols: string;
  sections: PublicMenuSection[];
  logoUrl?: string;
  sectionImages?: Record<string, string>;
}) {
  const { menuName, muted, accent, sectionCols, sections, logoUrl, sectionImages } = args;

  const glow = `0 0 18px ${accent}55, 0 0 42px ${accent}33`;
  const border = `1px solid ${accent}40`;

  return (
    <div className="px-10 py-8">
      <div className="flex items-end justify-between gap-6">
        <div>
          <div className="text-sm tracking-widest uppercase" style={{ color: muted }}>
            Welcome
          </div>
          <h1 className="mt-2 text-6xl font-bold tracking-tight" style={{ textShadow: glow }}>
            {menuName}
          </h1>
        </div>
        <div className="flex items-end gap-4">
          {logoUrl ? <img src={logoUrl} alt="" className="h-10 w-auto object-contain" /> : null}
          <div className="text-sm" style={{ color: muted }}>
            DisplayDeck
          </div>
        </div>
      </div>

      <div className={`mt-10 grid ${sectionCols} gap-8`}>
        {sections.map((s) => {
          const items = (s.Items || [])
            .filter((i) => i.IsAvailable !== false)
            .slice()
            .sort((a, b) => a.DisplayOrder - b.DisplayOrder);

          return (
            <div
              key={s.Id}
              className="rounded-2xl p-6"
              style={{ border, boxShadow: glow, background: "rgba(0,0,0,0.35)" }}
            >
              <div className="flex items-baseline justify-between gap-4">
                <div className="flex items-center gap-3 min-w-0">
                  {sectionImages?.[String(s.Id)] ? (
                    <img
                      src={sectionImages[String(s.Id)]}
                      alt=""
                      className="h-16 w-16 rounded-lg object-cover"
                      style={{ border, boxShadow: glow }}
                      loading="lazy"
                    />
                  ) : null}
                  <h2 className="text-3xl font-semibold truncate" style={{ color: accent, textShadow: glow }}>
                    {s.Name}
                  </h2>
                </div>
                <div className="h-[2px] flex-1" style={{ backgroundColor: `${accent}2A` }} />
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
                        <div className="text-2xl font-medium leading-snug">{it.Name}</div>
                        {it.ImageUrl ? (
                          <img
                            src={it.ImageUrl}
                            alt={it.Name}
                            className="mt-2 h-24 w-32 rounded-md object-cover"
                            style={{ border, boxShadow: glow }}
                            loading="lazy"
                          />
                        ) : null}
                        {it.Description ? (
                          <div className="mt-1 text-base leading-snug" style={{ color: muted }}>
                            {it.Description}
                          </div>
                        ) : null}
                      </div>
                      <div className="shrink-0 text-2xl font-semibold" style={{ color: accent, textShadow: glow }}>
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
  );
}

export default function DisplayMenuPage() {
  const params = useParams();
  const token = params.token as string;

  const contentRef = useRef<HTMLDivElement | null>(null);
  const [scale, setScale] = useState(1);

  const [menu, setMenu] = useState<PublicMenu | null>(null);
  const [error, setError] = useState<string>("");
  const [loading, setLoading] = useState(true);

  const apiUrl = useMemo(() => getApiUrl(), []);

  const resolveMediaRefs = async (m: PublicMenu): Promise<PublicMenu> => {
    const theme = (m.ThemeConfig || {}) as ThemeConfig;

    const ids = new Set<number>();
    const maybeAdd = (v: unknown) => {
      if (typeof v !== "string") return;
      const id = parseMediaRef(v);
      if (id) ids.add(id);
    };

    // Theme refs
    maybeAdd(theme.logoUrl);
    maybeAdd(theme.backgroundImageUrl);
    const bgList = theme.backgroundImageUrls;
    if (Array.isArray(bgList)) for (const v of bgList) maybeAdd(v);

    const secImages = theme.sectionImages;
    if (secImages && typeof secImages === "object" && !Array.isArray(secImages)) {
      for (const v of Object.values(secImages as Record<string, unknown>)) maybeAdd(v);
    }

    // Item refs
    for (const s of m.Sections || []) {
      for (const it of s.Items || []) maybeAdd(it.ImageUrl);
    }

    if (ids.size === 0) return m;

    const pairs = await Promise.all(
      Array.from(ids).map(async (id) => {
        try {
          const res = await fetch(`${apiUrl}/public/menus/${token}/media-files/${id}/download-url`, { cache: "no-store" });
          if (!res.ok) return [id, ""] as const;
          const data = (await res.json()) as { DownloadUrl?: string };
          return [id, (data?.DownloadUrl || "").trim()] as const;
        } catch {
          return [id, ""] as const;
        }
      })
    );

    const resolved: Record<number, string> = {};
    for (const [id, url] of pairs) if (url) resolved[id] = url;

    const replace = (v: unknown) => {
      if (typeof v !== "string") return v;
      const id = parseMediaRef(v);
      if (!id) return v;
      return resolved[id] || "";
    };

    const nextTheme: ThemeConfig = { ...(theme || {}) };
    nextTheme.logoUrl = replace(nextTheme.logoUrl) as any;
    nextTheme.backgroundImageUrl = replace(nextTheme.backgroundImageUrl) as any;
    if (Array.isArray(nextTheme.backgroundImageUrls)) {
      nextTheme.backgroundImageUrls = (nextTheme.backgroundImageUrls as unknown[]).map(replace) as any;
    }
    if (nextTheme.sectionImages && typeof nextTheme.sectionImages === "object" && !Array.isArray(nextTheme.sectionImages)) {
      const m0 = nextTheme.sectionImages as Record<string, unknown>;
      const out: Record<string, unknown> = {};
      for (const [k, v] of Object.entries(m0)) out[k] = replace(v);
      nextTheme.sectionImages = out as any;
    }

    const nextSections = (m.Sections || []).map((s) => ({
      ...s,
      Items: (s.Items || []).map((it) => ({ ...it, ImageUrl: replace(it.ImageUrl) as any })),
    }));

    return { ...m, ThemeConfig: nextTheme, Sections: nextSections };
  };

  const fetchMenu = async () => {
    try {
      setError("");
      const res = await fetch(`${apiUrl}/public/menus/${token}`, { cache: "no-store" });
      if (!res.ok) throw new Error(await res.text());
      const data = (await res.json()) as PublicMenu;
      const resolved = await resolveMediaRefs(data);
      setMenu(resolved);
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

  useEffect(() => {
    // Ensure the document never scrolls (especially important inside Android WebView).
    const html = document.documentElement;
    const body = document.body;
    const prevHtmlOverflow = html.style.overflow;
    const prevBodyOverflow = body.style.overflow;
    const prevBodyMargin = body.style.margin;
    html.style.overflow = "hidden";
    body.style.overflow = "hidden";
    body.style.margin = "0";
    return () => {
      html.style.overflow = prevHtmlOverflow;
      body.style.overflow = prevBodyOverflow;
      body.style.margin = prevBodyMargin;
    };
  }, []);

  const computed = useMemo(() => {
    if (!menu) {
      return {
        bg: "#0b0f19",
        text: "#ffffff",
        muted: "#cbd5e1",
        accent: "#22c55e",
        logoUrl: "",
        bgImage: "",
        overlayColor: "#000000",
        overlayOpacity: 0.35,
        sectionImages: {} as Record<string, string>,
        sectionCols: "grid-cols-2",
        sections: [] as PublicMenuSection[],
        templateKey: "classic" as const,
      };
    }

    const theme = menu.ThemeConfig || {};
    const bg = getThemeString(theme, "backgroundColor", "#0b0f19");
    const text = getThemeString(theme, "textColor", "#ffffff");
    const muted = getThemeString(theme, "mutedTextColor", "#cbd5e1");
    const accent = getThemeString(theme, "accentColor", "#22c55e");
    const logoUrl = getThemeString(theme, "logoUrl", "");

    const bgImages = getThemeStringArray(theme, "backgroundImageUrls");
    const singleBgImage = getThemeString(theme, "backgroundImageUrl", "");
    const bgImage = bgImages.length ? bgImages[Math.floor(Math.random() * bgImages.length)] : singleBgImage;

    const overlayColor = getThemeString(theme, "backgroundOverlayColor", "#000000");
    const overlayOpacity = getThemeNumber(theme, "backgroundOverlayOpacity") ?? 0.35;
    const sectionImages = getThemeStringMap(theme, "sectionImages");

    const orientation = (menu.Orientation || "Landscape").toLowerCase();
    const themeCols = getThemeNumber(theme, "layoutColumns");
    const resolvedCols = themeCols && [1, 2, 3].includes(themeCols) ? themeCols : orientation === "portrait" ? 1 : 2;
    const sectionCols = resolvedCols === 3 ? "grid-cols-3" : resolvedCols === 2 ? "grid-cols-2" : "grid-cols-1";

    const sections = (menu.Sections || []).slice().sort((a, b) => a.DisplayOrder - b.DisplayOrder);
    const templateKey = getTemplateKey(menu.TemplateKey);

    return {
      bg,
      text,
      muted,
      accent,
      logoUrl,
      bgImage,
      overlayColor,
      overlayOpacity,
      sectionImages,
      sectionCols,
      sections,
      templateKey,
    };
  }, [menu]);

  useEffect(() => {
    const el = contentRef.current;
    if (!el) return;
    if (!menu) return;

    const recompute = () => {
      const vw = window.innerWidth || 0;
      const vh = window.innerHeight || 0;
      if (vw <= 0 || vh <= 0) return;

      const w = el.scrollWidth || 0;
      const h = el.scrollHeight || 0;
      if (w <= 0 || h <= 0) return;

      // Scale both directions: shrink if too big, and enlarge if sparse.
      const raw = Math.min(vw / w, vh / h);
      const next = Math.max(0.25, Math.min(1.75, raw));
      setScale((prev) => (Math.abs(prev - next) >= 0.01 ? next : prev));
    };

    recompute();

    const maybeResizeObserver = (globalThis as any).ResizeObserver as (typeof ResizeObserver) | undefined;
    const ro = maybeResizeObserver ? new maybeResizeObserver(() => recompute()) : null;
    if (ro) ro.observe(el);

    window.addEventListener("resize", recompute);
    return () => {
      if (ro) ro.disconnect();
      window.removeEventListener("resize", recompute);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, menu?.Id, menu?.TemplateKey, menu?.Orientation, computed.sections.length, computed.sectionCols]);

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

  const {
    bg,
    text,
    muted,
    accent,
    logoUrl,
    bgImage,
    overlayColor,
    overlayOpacity,
    sectionImages,
    sectionCols,
    sections,
    templateKey,
  } = computed;

  return (
    <div
      className="fixed inset-0 overflow-hidden"
      style={{
        backgroundColor: bg,
        color: text,
        backgroundImage: bgImage ? `url(${bgImage})` : undefined,
        backgroundSize: "cover",
        backgroundPosition: "center",
        backgroundRepeat: "no-repeat",
      }}
    >
      {bgImage ? (
        <div
          className="fixed inset-0"
          style={{ backgroundColor: overlayColor, opacity: Math.max(0, Math.min(1, overlayOpacity)), pointerEvents: "none" }}
        />
      ) : null}
      <div className="relative h-full w-full overflow-hidden">
        <div className="absolute inset-0 flex items-start justify-center">
          <div
            ref={contentRef}
            style={{
              transform: `scale(${scale})`,
              transformOrigin: "top center",
              width: "fit-content",
              maxWidth: "100vw",
            }}
          >
            {templateKey === "minimal"
              ? renderMinimal({
                  menuName: menu.Name,
                  muted,
                  accent,
                  sectionCols,
                  sections,
                  logoUrl: logoUrl || undefined,
                  sectionImages,
                })
              : templateKey === "neon"
                ? renderNeon({
                    menuName: menu.Name,
                    muted,
                    accent,
                    sectionCols,
                    sections,
                    logoUrl: logoUrl || undefined,
                    sectionImages,
                  })
                : renderClassic({
                    menuName: menu.Name,
                    muted,
                    accent,
                    sectionCols,
                    sections,
                    logoUrl: logoUrl || undefined,
                    sectionImages,
                  })}
          </div>
        </div>
      </div>
    </div>
  );
}
