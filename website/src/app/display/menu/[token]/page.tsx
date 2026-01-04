"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useParams } from "next/navigation";

type ThemeConfig = Record<string, unknown>;

type HeaderMode = "auto" | "none" | "logo" | "image" | "text";

type ItemCardStyle = "standard" | "compact" | "image-left" | "image-right" | "hero";

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
  const env = process.env.NEXT_PUBLIC_API_URL;
  if (env) return env;

  // Default to same-origin nginx proxy in production.
  // This avoids CORS/preflight issues and works well inside WebViews.
  if (typeof window !== "undefined") return `${window.location.origin}/api`;
  return "/api";
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

function getHeaderMode(theme: ThemeConfig | undefined): HeaderMode {
  const raw = getThemeString(theme, "headerMode", "auto").trim().toLowerCase();
  if (raw === "none" || raw === "logo" || raw === "image" || raw === "text" || raw === "auto") return raw;
  return "auto";
}

function resolveHeaderMode(mode: HeaderMode, logoUrl: string, headerImageUrl: string): Exclude<HeaderMode, "auto"> {
  if (mode !== "auto") return mode;
  if (headerImageUrl) return "image";
  if (logoUrl) return "logo";
  return "none";
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

function getItemCardStyle(theme: ThemeConfig | undefined): ItemCardStyle {
  const raw = getThemeString(theme, "itemCardStyle", "standard").trim().toLowerCase();
  if (raw === "compact" || raw === "image-left" || raw === "image-right" || raw === "hero" || raw === "standard") return raw;
  return "standard";
}

function MenuItemCard(props: {
  it: PublicMenuItem;
  muted: string;
  accent: string;
  style: ItemCardStyle;
  priceStyle?: React.CSSProperties;
  imageStyle?: React.CSSProperties;
}) {
  const { it, muted, accent, style, priceStyle, imageStyle } = props;
  const price = it.PriceCents != null ? formatCurrencyZarFromCents(it.PriceCents) : "";
  const hasPrice = Boolean(price);
  const hasImage = Boolean(it.ImageUrl);

  if (style === "compact") {
    return (
      <div className="flex items-start justify-between gap-4 sm:gap-6">
        <div className="flex min-w-0 flex-1 items-start gap-3">
          {hasImage ? (
            <img
              src={it.ImageUrl || ""}
              alt={it.Name}
              className="h-12 w-12 rounded-md object-cover border border-white/10"
              style={imageStyle}
              loading="lazy"
            />
          ) : null}
          <div className="min-w-0 flex-1">
            <div className="flex items-baseline justify-between gap-3">
              <div className="text-lg sm:text-xl font-medium leading-snug truncate">{it.Name}</div>
              {hasPrice ? (
                <div className="shrink-0 text-lg sm:text-xl font-semibold" style={{ color: accent, ...(priceStyle || {}) }}>
                  {price}
                </div>
              ) : null}
            </div>
            {it.Description ? (
              <div className="mt-1 text-sm leading-snug line-clamp-1" style={{ color: muted }}>
                {it.Description}
              </div>
            ) : null}
          </div>
        </div>
      </div>
    );
  }

  if (style === "image-left" || style === "image-right") {
    const image = hasImage ? (
      <img
        src={it.ImageUrl || ""}
        alt={it.Name}
        className="h-20 w-28 sm:h-24 sm:w-32 rounded-lg object-cover border border-white/10"
        style={imageStyle}
        loading="lazy"
      />
    ) : null;

    return (
      <div className="rounded-xl border border-white/10 bg-white/[0.02] p-3 sm:p-4">
        <div className={`flex items-start gap-4 ${style === "image-right" ? "flex-row-reverse" : ""}`}>
          {image}
          <div className="min-w-0 flex-1">
            <div className="flex items-start justify-between gap-3">
              <div className="text-lg sm:text-xl font-semibold leading-snug min-w-0 truncate">{it.Name}</div>
              {hasPrice ? (
                <div className="shrink-0 text-lg sm:text-xl font-semibold" style={{ color: accent, ...(priceStyle || {}) }}>
                  {price}
                </div>
              ) : null}
            </div>
            {it.Description ? (
              <div className="mt-1 text-sm leading-snug" style={{ color: muted }}>
                {it.Description}
              </div>
            ) : null}
          </div>
        </div>
      </div>
    );
  }

  if (style === "hero") {
    return (
      <div className="rounded-xl border border-white/10 bg-white/[0.02] overflow-hidden">
        {hasImage ? (
          <div className="relative">
            <img
              src={it.ImageUrl || ""}
              alt={it.Name}
              className="w-full h-36 sm:h-44 object-cover"
              style={imageStyle}
              loading="lazy"
            />
            {hasPrice ? (
              <div
                className="absolute top-2 right-2 rounded-full px-3 py-1 text-sm font-semibold backdrop-blur border border-white/15"
                style={{ backgroundColor: "rgba(0,0,0,0.45)", color: accent, ...(priceStyle || {}) }}
              >
                {price}
              </div>
            ) : null}
          </div>
        ) : null}

        <div className="p-3 sm:p-4">
          <div className="flex items-start justify-between gap-3">
            <div className="text-lg sm:text-xl font-semibold leading-snug min-w-0">{it.Name}</div>
            {!hasImage && hasPrice ? (
              <div className="shrink-0 text-lg sm:text-xl font-semibold" style={{ color: accent, ...(priceStyle || {}) }}>
                {price}
              </div>
            ) : null}
          </div>
          {it.Description ? (
            <div className="mt-1 text-sm leading-snug" style={{ color: muted }}>
              {it.Description}
            </div>
          ) : null}
        </div>
      </div>
    );
  }

  // standard
  return (
    <div className="flex items-start justify-between gap-4 sm:gap-6">
      <div className="min-w-0 flex-1">
        <div className="flex items-start justify-between gap-3">
          <div className="text-lg sm:text-xl font-medium leading-snug min-w-0">{it.Name}</div>
          {hasPrice ? (
            <div className="shrink-0 text-lg sm:text-xl font-semibold" style={{ color: accent, ...(priceStyle || {}) }}>
              {price}
            </div>
          ) : null}
        </div>
        {it.Description ? (
          <div className="mt-1 text-sm leading-snug" style={{ color: muted }}>
            {it.Description}
          </div>
        ) : null}
        {hasImage ? (
          <img
            src={it.ImageUrl || ""}
            alt={it.Name}
            className="mt-2 h-24 sm:h-28 w-full rounded-lg object-cover border border-white/10"
            style={imageStyle}
            loading="lazy"
          />
        ) : null}
      </div>
    </div>
  );
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
  itemCardStyle: ItemCardStyle;
  sectionCols: string;
  sections: PublicMenuSection[];
  dense?: boolean;
  logoUrl?: string;
  sectionImages?: Record<string, string>;
  headerMode: Exclude<HeaderMode, "auto">;
  headerImageUrl?: string;
}) {
  const { menuName, muted, accent, itemCardStyle, sectionCols, sections, dense, logoUrl, sectionImages, headerMode, headerImageUrl } = args;
  const headerSrc = headerMode === "image" ? headerImageUrl : headerMode === "logo" ? logoUrl : "";
  const rootClass = dense ? "px-3 sm:px-4 md:px-6 py-4 sm:py-5" : "px-4 sm:px-6 md:px-10 py-6 sm:py-8";
  const titleClass = dense ? "text-2xl sm:text-4xl" : "text-3xl sm:text-5xl";
  const gridTopClass = headerMode === "none" ? "mt-2" : dense ? "mt-5 sm:mt-6" : "mt-8 sm:mt-10";
  const gridGapClass = dense ? "gap-4 sm:gap-6" : "gap-5 sm:gap-8";
  const sectionCardClass = dense ? "rounded-2xl border border-white/20 bg-white/[0.03] p-3 sm:p-4" : "rounded-2xl border border-white/20 bg-white/[0.03] p-3 sm:p-6";
  return (
    <div className={rootClass}>
      {headerMode === "text" ? (
        <div className="flex items-end justify-between gap-6">
          <div>
            <h1 className={`${titleClass} font-bold tracking-tight`}>{menuName}</h1>
          </div>
        </div>
      ) : headerSrc ? (
        <div className="flex justify-center">
          <img src={headerSrc} alt="" className="h-12 sm:h-16 w-auto object-contain" />
        </div>
      ) : null}

      <div className={`${gridTopClass} grid ${sectionCols} ${gridGapClass}`}>
        {sections.map((s) => {
          const items = (s.Items || [])
            .filter((i) => i.IsAvailable !== false)
            .slice()
            .sort((a, b) => a.DisplayOrder - b.DisplayOrder);

          return (
            <div key={s.Id} className={sectionCardClass}>
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
                  <h2 className="text-2xl sm:text-3xl font-semibold truncate">{s.Name}</h2>
                </div>
                <div className="h-[2px] flex-1 bg-white/10" />
              </div>

              <div className="mt-5 space-y-4">
                {items.length === 0 ? (
                  <div className="text-sm" style={{ color: muted }}>
                    No items
                  </div>
                ) : (
                  items.map((it) => {
                    return (
                      <MenuItemCard key={it.Id} it={it} muted={muted} accent={accent} style={itemCardStyle} />
                    );
                  })
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
  itemCardStyle: ItemCardStyle;
  sectionCols: string;
  sections: PublicMenuSection[];
  dense?: boolean;
  logoUrl?: string;
  sectionImages?: Record<string, string>;
  headerMode: Exclude<HeaderMode, "auto">;
  headerImageUrl?: string;
}) {
  const { menuName, muted, accent, itemCardStyle, sectionCols, sections, dense, logoUrl, sectionImages, headerMode, headerImageUrl } = args;
  const headerSrc = headerMode === "image" ? headerImageUrl : headerMode === "logo" ? logoUrl : "";
  const rootClass = dense ? "px-3 sm:px-4 md:px-8 py-4 sm:py-6" : "px-4 sm:px-6 md:px-12 py-6 sm:py-10";
  const titleClass = dense ? "text-3xl sm:text-5xl" : "text-4xl sm:text-6xl";
  const gridTopClass = headerMode === "none" ? "mt-2" : dense ? "mt-5 sm:mt-6" : "mt-8 sm:mt-10";
  const gridGapClass = dense ? "gap-5 sm:gap-8" : "gap-6 sm:gap-10";
  return (
    <div className={rootClass}>
      {headerMode === "text" ? (
        <div className="flex items-center justify-between gap-6">
          <div>
            <h1 className={`${titleClass} font-semibold tracking-tight`}>{menuName}</h1>
          </div>
        </div>
      ) : headerSrc ? (
        <div className="flex justify-center">
          <img src={headerSrc} alt="" className="h-12 sm:h-16 w-auto object-contain" />
        </div>
      ) : null}

      <div className={`${gridTopClass} grid ${sectionCols} ${gridGapClass}`}>
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
                    <MenuItemCard
                      key={it.Id}
                      it={it}
                      muted={muted}
                      accent={accent}
                      style={itemCardStyle}
                      imageStyle={it.ImageUrl ? { border: `1px solid ${accent}2A` } : undefined}
                    />
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
  itemCardStyle: ItemCardStyle;
  sectionCols: string;
  sections: PublicMenuSection[];
  dense?: boolean;
  logoUrl?: string;
  sectionImages?: Record<string, string>;
  headerMode: Exclude<HeaderMode, "auto">;
  headerImageUrl?: string;
}) {
  const { menuName, muted, accent, itemCardStyle, sectionCols, sections, dense, logoUrl, sectionImages, headerMode, headerImageUrl } = args;
  const headerSrc = headerMode === "image" ? headerImageUrl : headerMode === "logo" ? logoUrl : "";

  const glow = `0 0 18px ${accent}55, 0 0 42px ${accent}33`;
  const border = `1px solid ${accent}40`;
  const rootClass = dense ? "px-3 sm:px-4 md:px-6 py-4 sm:py-5" : "px-4 sm:px-6 md:px-10 py-6 sm:py-8";
  const titleClass = dense ? "text-3xl sm:text-5xl" : "text-4xl sm:text-6xl";
  const gridTopClass = headerMode === "none" ? "mt-2" : dense ? "mt-5 sm:mt-6" : "mt-8 sm:mt-10";
  const gridGapClass = dense ? "gap-4 sm:gap-6" : "gap-5 sm:gap-8";
  const sectionPadClass = dense ? "rounded-2xl p-4" : "rounded-2xl p-6";

  return (
    <div className={rootClass}>
      {headerMode === "text" ? (
        <div className="flex items-end justify-between gap-6">
          <div>
            <h1 className={`${titleClass} font-bold tracking-tight`} style={{ textShadow: glow }}>
              {menuName}
            </h1>
          </div>
        </div>
      ) : headerSrc ? (
        <div className="flex justify-center">
          <img src={headerSrc} alt="" className="h-12 sm:h-16 w-auto object-contain" style={{ filter: "drop-shadow(0 0 16px rgba(0,0,0,0.45))" }} />
        </div>
      ) : null}

      <div className={`${gridTopClass} grid ${sectionCols} ${gridGapClass}`}>
        {sections.map((s) => {
          const items = (s.Items || [])
            .filter((i) => i.IsAvailable !== false)
            .slice()
            .sort((a, b) => a.DisplayOrder - b.DisplayOrder);

          return (
            <div
              key={s.Id}
              className={sectionPadClass}
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
                    <MenuItemCard
                      key={it.Id}
                      it={it}
                      muted={muted}
                      accent={accent}
                      style={itemCardStyle}
                      priceStyle={{ textShadow: glow }}
                      imageStyle={it.ImageUrl ? { border, boxShadow: glow } : undefined}
                    />
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
  const [isCompact, setIsCompact] = useState(false);
  const [isWide, setIsWide] = useState(false);
  const [isLandscapeViewport, setIsLandscapeViewport] = useState(false);

  const [menu, setMenu] = useState<PublicMenu | null>(null);
  const [error, setError] = useState<string>("");
  const [loading, setLoading] = useState(true);

  const apiUrl = useMemo(() => getApiUrl(), []);

  const resolveMediaRefs = (m: PublicMenu): PublicMenu => {
    const theme = (m.ThemeConfig || {}) as ThemeConfig;

    // Prefer a same-origin proxy path. This avoids relying on the MinIO domain
    // from the browser/WebView (CSP, DNS, cert, and cross-origin quirks).
    const replace = (v: unknown) => {
      if (typeof v !== "string") return v;
      const id = parseMediaRef(v);
      if (!id) return v;
      return `/public-media/menus/${encodeURIComponent(token)}/media-files/${id}`;
    };

    const nextTheme: ThemeConfig = { ...(theme || {}) };
    nextTheme.logoUrl = replace(nextTheme.logoUrl) as any;
    nextTheme.headerImageUrl = replace((nextTheme as any).headerImageUrl) as any;
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
      const resolved = resolveMediaRefs(data);
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
        headerImageUrl: "",
        headerMode: "none" as const,
        bgImage: "",
        overlayColor: "#000000",
        overlayOpacity: 0.35,
        sectionImages: {} as Record<string, string>,
        sectionCols: "grid-cols-2",
        sections: [] as PublicMenuSection[],
        templateKey: "classic" as const,
        itemCardStyle: "standard" as const,
      };
    }

    const theme = menu.ThemeConfig || {};
    const bg = getThemeString(theme, "backgroundColor", "#0b0f19");
    const text = getThemeString(theme, "textColor", "#ffffff");
    const muted = getThemeString(theme, "mutedTextColor", "#cbd5e1");
    const accent = getThemeString(theme, "accentColor", "#22c55e");
    const itemCardStyle = getItemCardStyle(theme);
    const logoUrl = getThemeString(theme, "logoUrl", "");
    const headerImageUrl = getThemeString(theme, "headerImageUrl", "");
    const headerMode = resolveHeaderMode(getHeaderMode(theme), logoUrl, headerImageUrl);

    const bgImages = getThemeStringArray(theme, "backgroundImageUrls");
    const singleBgImage = getThemeString(theme, "backgroundImageUrl", "");
    const bgImage = bgImages.length ? bgImages[Math.floor(Math.random() * bgImages.length)] : singleBgImage;

    const overlayColor = getThemeString(theme, "backgroundOverlayColor", "#000000");
    const overlayOpacity = getThemeNumber(theme, "backgroundOverlayOpacity") ?? 0.35;
    const sectionImages = getThemeStringMap(theme, "sectionImages");

    const orientation = (menu.Orientation || "Landscape").toLowerCase();
    const themeCols = getThemeNumber(theme, "layoutColumns");
    const resolvedCols =
      themeCols && [1, 2, 3].includes(themeCols)
        ? themeCols
        : orientation === "portrait"
          ? 1
          : isWide
            ? 3
            : 2;
    const sectionCols = resolvedCols === 3 ? "grid-cols-3" : resolvedCols === 2 ? "grid-cols-2" : "grid-cols-1";

    const sections = (menu.Sections || []).slice().sort((a, b) => a.DisplayOrder - b.DisplayOrder);
    const templateKey = getTemplateKey(menu.TemplateKey);

    return {
      bg,
      text,
      muted,
      accent,
      logoUrl,
      headerImageUrl,
      headerMode,
      bgImage,
      overlayColor,
      overlayOpacity,
      sectionImages,
      sectionCols,
      sections,
      templateKey,
      itemCardStyle,
    };
  }, [menu, isWide]);

  useEffect(() => {
    const el = contentRef.current;
    if (!el) return;
    if (!menu) return;

    const recompute = () => {
      const vw = window.innerWidth || 0;
      const vh = window.innerHeight || 0;
      if (vw <= 0 || vh <= 0) return;

      const landscape = vw > vh;
      setIsLandscapeViewport((prev) => (prev === landscape ? prev : landscape));

      const compact = vw < 768;
      setIsCompact((prev) => (prev === compact ? prev : compact));

      const wide = vw >= 1400;
      setIsWide((prev) => (prev === wide ? prev : wide));

      const w = el.scrollWidth || 0;
      const h = el.scrollHeight || 0;
      if (w <= 0 || h <= 0) return;

      // Scale both directions: shrink if too big, and enlarge if sparse.
      const raw = Math.min(vw / w, vh / h);
      const next = compact
        ? Math.max(0.3, Math.min(1.2, raw))
        : Math.max(0.25, Math.min(1.75, raw));
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
    headerImageUrl,
    headerMode,
    bgImage,
    overlayColor,
    overlayOpacity,
    sectionImages,
    sectionCols,
    sections,
    templateKey,
    itemCardStyle,
  } = computed;

  // Landscape tends to be height-constrained; use a denser layout so scaling
  // doesn't shrink the content and create big empty side margins.
  const dense = isLandscapeViewport && !isCompact;

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
              width: "100vw",
              maxWidth: "100vw",
            }}
          >
            {templateKey === "minimal"
              ? renderMinimal({
                  menuName: menu.Name,
                  muted,
                  accent,
                  itemCardStyle,
                  sectionCols,
                  sections,
                  dense,
                  logoUrl: logoUrl || undefined,
                  sectionImages,
                  headerMode,
                  headerImageUrl: headerImageUrl || undefined,
                })
              : templateKey === "neon"
                ? renderNeon({
                    menuName: menu.Name,
                    muted,
                    accent,
                    itemCardStyle,
                    sectionCols,
                    sections,
                    dense,
                    logoUrl: logoUrl || undefined,
                    sectionImages,
                    headerMode,
                    headerImageUrl: headerImageUrl || undefined,
                  })
                : renderClassic({
                    menuName: menu.Name,
                    muted,
                    accent,
                    itemCardStyle,
                    sectionCols,
                    sections,
                    dense,
                    logoUrl: logoUrl || undefined,
                    sectionImages,
                    headerMode,
                    headerImageUrl: headerImageUrl || undefined,
                  })}
          </div>
        </div>
      </div>
    </div>
  );
}
