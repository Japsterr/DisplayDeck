import React from "react";

type ThemeConfig = Record<string, unknown>;

interface PublicInfoBoardItem {
  Id: number;
  ItemType: string;
  Title: string;
  Subtitle: string | null;
  Description: string | null;
  ImageUrl: string | null;
  IconEmoji: string | null;
  Location: string | null;
  ContactInfo: string | null;
  QrCodeUrl: string | null;
  HighlightColor: string | null;
  DisplayOrder: number;
}

interface PublicInfoBoardSection {
  Id: number;
  Name: string;
  Subtitle: string | null;
  IconEmoji: string | null;
  IconUrl: string | null;
  BackgroundColor: string | null;
  TitleColor: string | null;
  LayoutStyle: string;
  DisplayOrder: number;
  Items: PublicInfoBoardItem[];
}

interface PublicInfoBoard {
  Id: number;
  Name: string;
  BoardType: string;
  Orientation: string;
  TemplateKey: string;
  ThemeConfig?: ThemeConfig;
  Sections: PublicInfoBoardSection[];
}

export const dynamic = "force-dynamic";

function getInternalApiBase(): string {
  return process.env.INTERNAL_API_BASE_URL || "http://nginx/api";
}

function getThemeString(theme: ThemeConfig | undefined, key: string, fallback: string) {
  const val = theme?.[key];
  return typeof val === "string" && val.trim() ? val : fallback;
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

function InfoBoardItemCard(props: { item: PublicInfoBoardItem; muted: string; accent: string }) {
  const { item, muted, accent } = props;
  const hasImage = Boolean(item.ImageUrl);

  return (
    <div className="rounded-xl border border-white/10 bg-white/[0.02] p-4">
      <div className="flex items-start gap-4">
        {item.IconEmoji ? (
          <div className="text-3xl flex-shrink-0">{item.IconEmoji}</div>
        ) : hasImage ? (
          <img src={item.ImageUrl || ""} alt={item.Title} className="h-16 w-16 rounded-lg object-cover border border-white/10" />
        ) : null}
        <div className="min-w-0 flex-1">
          <div className="flex items-start justify-between gap-3">
            <div>
              <div className="text-lg sm:text-xl font-semibold leading-snug">{item.Title}</div>
              {item.Subtitle ? (
                <div className="mt-0.5 text-sm" style={{ color: muted }}>
                  {item.Subtitle}
                </div>
              ) : null}
            </div>
            {item.HighlightColor ? (
              <div className="h-3 w-3 rounded-full flex-shrink-0" style={{ backgroundColor: item.HighlightColor }} />
            ) : null}
          </div>
          {item.Description ? (
            <div className="mt-2 text-sm leading-snug" style={{ color: muted }}>
              {item.Description}
            </div>
          ) : null}
          {item.Location ? (
            <div className="mt-2 text-sm flex items-center gap-2" style={{ color: accent }}>
              <span>📍</span>
              <span>{item.Location}</span>
            </div>
          ) : null}
          {item.ContactInfo ? (
            <div className="mt-1 text-sm flex items-center gap-2" style={{ color: muted }}>
              <span>📞</span>
              <span>{item.ContactInfo}</span>
            </div>
          ) : null}
        </div>
        {item.QrCodeUrl ? (
          <div className="flex-shrink-0">
            <img src={item.QrCodeUrl} alt="QR Code" className="h-16 w-16 rounded border border-white/10 bg-white p-1" />
          </div>
        ) : null}
      </div>
    </div>
  );
}

function renderInfoBoard(args: {
  boardName: string;
  boardType: string;
  bg: string;
  text: string;
  muted: string;
  accent: string;
  sectionCols: string;
  sections: PublicInfoBoardSection[];
  headerImageUrl?: string;
  logoUrl?: string;
}) {
  const { boardName, boardType, muted, accent, sectionCols, sections, headerImageUrl, logoUrl } = args;
  const headerSrc = headerImageUrl || logoUrl;

  return (
    <div className="px-4 sm:px-6 md:px-10 py-6 sm:py-8">
      {headerSrc ? (
        <div className="flex justify-center mb-6">
          <img src={headerSrc} alt="" className="h-12 sm:h-16 w-auto object-contain" />
        </div>
      ) : (
        <div className="mb-6">
          <h1 className="text-3xl sm:text-5xl font-bold tracking-tight text-center">{boardName}</h1>
          {boardType ? (
            <div className="text-center text-sm mt-2" style={{ color: muted }}>
              {boardType}
            </div>
          ) : null}
        </div>
      )}

      <div className={`grid ${sectionCols} gap-5 sm:gap-8`}>
        {sections.map((s) => {
          const items = (s.Items || []).slice().sort((a, b) => a.DisplayOrder - b.DisplayOrder);
          const sectionBg = s.BackgroundColor || "rgba(255,255,255,0.03)";
          const sectionTitleColor = s.TitleColor;

          return (
            <div
              key={s.Id}
              className="rounded-2xl border border-white/20 p-4 sm:p-6"
              style={{ backgroundColor: sectionBg }}
            >
              <div className="flex items-center gap-3 mb-4">
                {s.IconEmoji ? <div className="text-2xl">{s.IconEmoji}</div> : null}
                {s.IconUrl ? <img src={s.IconUrl} alt="" className="h-8 w-8 rounded object-cover" /> : null}
                <div>
                  <h2
                    className="text-xl sm:text-2xl font-semibold"
                    style={sectionTitleColor ? { color: sectionTitleColor } : undefined}
                  >
                    {s.Name}
                  </h2>
                  {s.Subtitle ? (
                    <div className="text-sm" style={{ color: muted }}>
                      {s.Subtitle}
                    </div>
                  ) : null}
                </div>
              </div>

              <div className="space-y-3">
                {items.length === 0 ? (
                  <div className="text-sm" style={{ color: muted }}>
                    No items
                  </div>
                ) : (
                  items.map((item) => (
                    <InfoBoardItemCard key={item.Id} item={item} muted={muted} accent={accent} />
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

export default async function DisplayInfoBoardSsrPage({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;

  let board: PublicInfoBoard | null = null;
  try {
    const apiBase = getInternalApiBase();
    const res = await fetch(`${apiBase}/public/infoboards/${encodeURIComponent(token)}`, { cache: "no-store" });
    if (res.ok) {
      board = (await res.json()) as PublicInfoBoard;
    }
  } catch {
    board = null;
  }

  if (!board) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-black text-white">
        <div className="text-center">
          <div className="text-lg font-semibold">Info Board unavailable</div>
          <div className="text-sm text-white/70">Failed to load info board</div>
        </div>
      </div>
    );
  }

  const theme = board.ThemeConfig || {};
  const bg = getThemeString(theme, "backgroundColor", "#0b0f19");
  const text = getThemeString(theme, "textColor", "#ffffff");
  const muted = getThemeString(theme, "mutedTextColor", "#cbd5e1");
  const accent = getThemeString(theme, "accentColor", "#22c55e");
  const logoUrl = getThemeString(theme, "logoUrl", "");
  const headerImageUrl = getThemeString(theme, "headerImageUrl", "");
  const bgImage = getThemeString(theme, "backgroundImageUrl", "");

  const overlayColor = getThemeString(theme, "backgroundOverlayColor", "#000000");
  const overlayOpacity = getThemeNumber(theme, "backgroundOverlayOpacity") ?? 0.35;

  const orientation = (board.Orientation || "Landscape").toLowerCase();
  const themeCols = getThemeNumber(theme, "layoutColumns");
  const resolvedCols = themeCols && [1, 2, 3].includes(themeCols) ? themeCols : orientation === "portrait" ? 1 : 2;
  const sectionCols = resolvedCols === 3 ? "grid-cols-3" : resolvedCols === 2 ? "grid-cols-2" : "grid-cols-1";

  const sections = (board.Sections || []).slice().sort((a, b) => a.DisplayOrder - b.DisplayOrder);

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
      <div className="relative h-full w-full overflow-auto pb-6">
        {renderInfoBoard({
          boardName: board.Name,
          boardType: board.BoardType,
          bg,
          text,
          muted,
          accent,
          sectionCols,
          sections,
          headerImageUrl: headerImageUrl || undefined,
          logoUrl: logoUrl || undefined,
        })}
      </div>

      {/* periodic refresh for signage */}
      <script dangerouslySetInnerHTML={{ __html: "(function(){try{setTimeout(function(){location.reload();},15000);}catch(e){}})();" }} />
    </div>
  );
}
