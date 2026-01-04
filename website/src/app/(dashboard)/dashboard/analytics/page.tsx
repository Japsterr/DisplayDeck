"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { formatDistanceToNow, isValid, parseISO, subDays, format, differenceInDays, eachDayOfInterval } from "date-fns";
import { BarChart3, Download, FileDown, RefreshCw, Monitor, PlayCircle, TrendingUp, AlertTriangle, CheckCircle2, Clock } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Progress } from "@/components/ui/progress";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { toast } from "sonner";

function asArray<T>(value: unknown): T[] {
  return Array.isArray(value) ? (value as T[]) : [];
}

function safeDistanceToNow(input: string | null | undefined): string {
  if (!input) return "Unknown";
  try {
    const parsed = parseISO(input);
    const date = isValid(parsed) ? parsed : new Date(input);
    if (!isValid(date)) return "Unknown";
    return formatDistanceToNow(date, { addSuffix: true });
  } catch {
    return "Unknown";
  }
}

function toDatetimeLocalValue(date: Date): string {
  // yyyy-MM-ddTHH:mm (local)
  const pad = (n: number) => `${n}`.padStart(2, "0");
  const y = date.getFullYear();
  const m = pad(date.getMonth() + 1);
  const d = pad(date.getDate());
  const hh = pad(date.getHours());
  const mm = pad(date.getMinutes());
  return `${y}-${m}-${d}T${hh}:${mm}`;
}

function datetimeLocalToISO(value: string): string | null {
  if (!value) return null;
  const date = new Date(value);
  if (!isValid(date)) return null;
  return date.toISOString();
}

function extractLocationFromDisplayName(name: string): string {
  // Lightweight convention-based rollup:
  // "Store 12 - Screen A" -> "Store 12"
  // "Store 12 | Screen A" -> "Store 12"
  // "Store 12: Screen A" -> "Store 12"
  const candidates = [" - ", " | ", ": "];
  for (const sep of candidates) {
    const idx = name.indexOf(sep);
    if (idx > 0) return name.slice(0, idx).trim();
  }
  return "Unassigned";
}

function downloadTextFile(filename: string, content: string, mime = "text/plain;charset=utf-8") {
  const blob = new Blob([content], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

type AuthContext = {
  token: string;
  orgId: number;
  apiUrl: string;
};

function getAuthContext(): AuthContext | null {
  const token = localStorage.getItem("token");
  const userStr = localStorage.getItem("user");
  if (!token || !userStr) return null;

  const user = JSON.parse(userStr);
  const orgId = user.OrganizationId;
  const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";
  return { token, orgId, apiUrl };
}

interface Display {
  Id: number;
  Name: string;
  CurrentStatus: string;
  LastSeen: string;
}

interface Campaign {
  Id: number;
  Name: string;
}

interface MediaFile {
  Id: number;
  FileName: string;
  FileType?: string;
}

interface PlayRow {
  DisplayId: number;
  CampaignId: number;
  MediaFileId: number;
  PlaybackTimestamp: string;
  DisplayName: string;
  CampaignName: string;
  MediaFileName: string;
}

interface CampaignSummaryRow {
  CampaignId: number;
  CampaignName: string;
  Plays: number;
}

interface MediaSummaryRow {
  MediaFileId: number;
  MediaFileName: string;
  Plays: number;
}

export default function AnalyticsPage() {
  const router = useRouter();

  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const [displays, setDisplays] = useState<Display[]>([]);
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [mediaFiles, setMediaFiles] = useState<MediaFile[]>([]);

  const [plays, setPlays] = useState<PlayRow[]>([]);
  const [topCampaigns, setTopCampaigns] = useState<CampaignSummaryRow[]>([]);
  const [topMedia, setTopMedia] = useState<MediaSummaryRow[]>([]);

  const [fromLocal, setFromLocal] = useState(() => toDatetimeLocalValue(subDays(new Date(), 7)));
  const [toLocal, setToLocal] = useState(() => toDatetimeLocalValue(new Date()));
  const [displayId, setDisplayId] = useState<string>("all");
  const [campaignId, setCampaignId] = useState<string>("all");
  const [mediaFileId, setMediaFileId] = useState<string>("all");
  const [slaMinutes, setSlaMinutes] = useState<string>("5");

  const fromISO = useMemo(() => datetimeLocalToISO(fromLocal), [fromLocal]);
  const toISO = useMemo(() => datetimeLocalToISO(toLocal), [toLocal]);

  const fetchBaseLists = async (auth: AuthContext) => {
    const headers = { "X-Auth-Token": auth.token };

    const [displaysRes, campaignsRes, mediaRes] = await Promise.all([
      fetch(`${auth.apiUrl}/organizations/${auth.orgId}/displays`, { headers }),
      fetch(`${auth.apiUrl}/organizations/${auth.orgId}/campaigns`, { headers }),
      fetch(`${auth.apiUrl}/organizations/${auth.orgId}/media-files`, { headers }),
    ]);

    if (displaysRes.status === 401 || campaignsRes.status === 401 || mediaRes.status === 401) {
      router.push("/login");
      return;
    }

    const displaysData = await displaysRes.json().catch(() => null);
    const campaignsData = await campaignsRes.json().catch(() => null);
    const mediaData = await mediaRes.json().catch(() => null);

    setDisplays(asArray<Display>(displaysData?.value ?? displaysData?.Value ?? displaysData?.items ?? displaysData?.Items));
    setCampaigns(asArray<Campaign>(campaignsData?.value ?? campaignsData?.Value ?? campaignsData?.items ?? campaignsData?.Items));
    setMediaFiles(asArray<MediaFile>(mediaData?.value ?? mediaData?.Value ?? mediaData?.items ?? mediaData?.Items));
  };

  const fetchReport = async (auth: AuthContext) => {
    if (!fromISO || !toISO) {
      toast.error("Invalid date range");
      return;
    }

    const headers = { "X-Auth-Token": auth.token };

    const qs = new URLSearchParams();
    qs.set("organizationId", String(auth.orgId));
    qs.set("from", fromISO);
    qs.set("to", toISO);

    if (displayId !== "all") qs.set("displayId", displayId);
    if (campaignId !== "all") qs.set("campaignId", campaignId);
    if (mediaFileId !== "all") qs.set("mediaFileId", mediaFileId);

    const [playsRes, campaignsSummaryRes, mediaSummaryRes] = await Promise.all([
      fetch(`${auth.apiUrl}/analytics/plays?${qs.toString()}`, { headers }),
      fetch(
        `${auth.apiUrl}/analytics/summary/campaigns?${new URLSearchParams({
          organizationId: String(auth.orgId),
          from: fromISO,
          to: toISO,
        }).toString()}`,
        { headers }
      ),
      fetch(
        `${auth.apiUrl}/analytics/summary/media?${new URLSearchParams({
          organizationId: String(auth.orgId),
          from: fromISO,
          to: toISO,
        }).toString()}`,
        { headers }
      ),
    ]);

    if (playsRes.status === 401 || campaignsSummaryRes.status === 401 || mediaSummaryRes.status === 401) {
      router.push("/login");
      return;
    }

    if (!playsRes.ok) throw new Error("Failed to load proof of play data");

    const playsData = await playsRes.json().catch(() => null);
    const campaignsSummaryData = await campaignsSummaryRes.json().catch(() => null);
    const mediaSummaryData = await mediaSummaryRes.json().catch(() => null);

    const playsList = asArray<PlayRow>(playsData?.value ?? playsData?.Value ?? playsData?.items ?? playsData?.Items);
    const campaignsSummaryList = asArray<CampaignSummaryRow>(
      campaignsSummaryData?.value ?? campaignsSummaryData?.Value ?? campaignsSummaryData?.items ?? campaignsSummaryData?.Items
    );
    const mediaSummaryList = asArray<MediaSummaryRow>(
      mediaSummaryData?.value ?? mediaSummaryData?.Value ?? mediaSummaryData?.items ?? mediaSummaryData?.Items
    );

    setPlays(playsList);
    setTopCampaigns(campaignsSummaryList.sort((a, b) => (b.Plays ?? 0) - (a.Plays ?? 0)).slice(0, 10));
    setTopMedia(mediaSummaryList.sort((a, b) => (b.Plays ?? 0) - (a.Plays ?? 0)).slice(0, 10));
  };

  const run = async (isRefresh = false) => {
    const auth = getAuthContext();
    if (!auth) {
      router.push("/login");
      return;
    }

    try {
      isRefresh ? setRefreshing(true) : setLoading(true);
      await fetchBaseLists(auth);
      await fetchReport(auth);
    } catch (e) {
      console.error(e);
      toast.error(e instanceof Error ? e.message : "Failed to load analytics");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    void run(false);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const displayHealth = useMemo(() => {
    const total = displays.length;
    const online = displays.filter((d) => d.CurrentStatus === "Online").length;

    const sla = Math.max(1, Number.parseInt(slaMinutes || "5", 10) || 5);
    const cutoff = new Date(Date.now() - sla * 60 * 1000);

    const seenRecently = displays.filter((d) => {
      if (!d.LastSeen) return false;
      const dt = new Date(d.LastSeen);
      return isValid(dt) && dt >= cutoff;
    }).length;

    const offline = displays.filter((d) => d.CurrentStatus !== "Online");

    const displaysWithPlays = new Set(plays.map((p) => p.DisplayId));
    const playbackActiveRate = total > 0 ? Math.round((displaysWithPlays.size / total) * 100) : 0;

    return {
      total,
      online,
      onlineRateNow: total > 0 ? Math.round((online / total) * 100) : 0,
      slaMinutes: sla,
      seenRecently,
      offline,
      playbackActiveRate,
    };
  }, [displays, plays, slaMinutes]);

  const locationRollup = useMemo(() => {
    const groups = new Map<
      string,
      {
        location: string;
        displayIds: number[];
        displayCount: number;
        onlineCount: number;
        plays: number;
      }
    >();

    for (const d of displays) {
      const loc = extractLocationFromDisplayName(d.Name || "");
      const existing = groups.get(loc) ?? {
        location: loc,
        displayIds: [],
        displayCount: 0,
        onlineCount: 0,
        plays: 0,
      };

      existing.displayIds.push(d.Id);
      existing.displayCount += 1;
      if (d.CurrentStatus === "Online") existing.onlineCount += 1;
      groups.set(loc, existing);
    }

    for (const row of plays) {
      for (const group of groups.values()) {
        // Fast path: only count if display is in group
        // (groups are small; correctness > micro-optimization here)
        if (group.displayIds.includes(row.DisplayId)) group.plays += 1;
      }
    }

    return Array.from(groups.values()).sort((a, b) => b.plays - a.plays);
  }, [displays, plays]);

  // Daily plays chart data
  const dailyPlaysData = useMemo(() => {
    if (!fromISO || !toISO) return [];
    const start = parseISO(fromISO);
    const end = parseISO(toISO);
    if (!isValid(start) || !isValid(end)) return [];
    
    const days = eachDayOfInterval({ start, end });
    const playsByDay = new Map<string, number>();
    
    for (const day of days) {
      playsByDay.set(format(day, "yyyy-MM-dd"), 0);
    }
    
    for (const play of plays) {
      if (!play.PlaybackTimestamp) continue;
      const date = parseISO(play.PlaybackTimestamp);
      if (!isValid(date)) continue;
      const key = format(date, "yyyy-MM-dd");
      if (playsByDay.has(key)) {
        playsByDay.set(key, (playsByDay.get(key) || 0) + 1);
      }
    }
    
    return Array.from(playsByDay.entries()).map(([date, count]) => ({
      date,
      label: format(parseISO(date), "MMM d"),
      count,
    }));
  }, [plays, fromISO, toISO]);

  const maxDailyPlays = useMemo(() => Math.max(1, ...dailyPlaysData.map(d => d.count)), [dailyPlaysData]);

  // Calculate average plays per day
  const avgPlaysPerDay = useMemo(() => {
    if (dailyPlaysData.length === 0) return 0;
    const total = dailyPlaysData.reduce((sum, d) => sum + d.count, 0);
    return Math.round(total / dailyPlaysData.length);
  }, [dailyPlaysData]);

  // Peak hour calculation
  const peakHour = useMemo(() => {
    const hourCounts = new Array(24).fill(0);
    for (const play of plays) {
      if (!play.PlaybackTimestamp) continue;
      const date = parseISO(play.PlaybackTimestamp);
      if (!isValid(date)) continue;
      hourCounts[date.getHours()]++;
    }
    const maxHour = hourCounts.indexOf(Math.max(...hourCounts));
    return { hour: maxHour, count: hourCounts[maxHour] };
  }, [plays]);

  const exportCsv = () => {
    const headers = [
      "PlaybackTimestamp",
      "DisplayId",
      "DisplayName",
      "CampaignId",
      "CampaignName",
      "MediaFileId",
      "MediaFileName",
    ];

    const escape = (v: unknown) => {
      const s = `${v ?? ""}`;
      if (/[\n\r,"]/.test(s)) return `"${s.replaceAll('"', '""')}"`;
      return s;
    };

    const lines = [headers.join(",")].concat(
      plays.map((p) =>
        [
          p.PlaybackTimestamp,
          p.DisplayId,
          p.DisplayName,
          p.CampaignId,
          p.CampaignName,
          p.MediaFileId,
          p.MediaFileName,
        ]
          .map(escape)
          .join(",")
      )
    );

    downloadTextFile(`displaydeck-proof-of-play-${new Date().toISOString().slice(0, 10)}.csv`, lines.join("\n"), "text/csv;charset=utf-8");
  };

  if (loading) {
    return <div className="p-8 text-center text-muted-foreground">Loading analytics...</div>;
  }

  return (
    <div className="flex flex-1 flex-col gap-6 p-4 pt-0">
      <div className="flex items-start justify-between gap-4 print:hidden">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Analytics</h2>
          <p className="text-muted-foreground">Proof-of-play reporting and display health metrics.</p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" onClick={() => window.print()}>
            <FileDown className="mr-2 h-4 w-4" /> Export PDF
          </Button>
          <Button variant="outline" onClick={exportCsv} disabled={plays.length === 0}>
            <Download className="mr-2 h-4 w-4" /> Export CSV
          </Button>
          <Button variant="outline" onClick={() => void run(true)} disabled={refreshing}>
            <RefreshCw className={`mr-2 h-4 w-4 ${refreshing ? "animate-spin" : ""}`} /> Refresh
          </Button>
        </div>
      </div>

      {/* Key Metrics Summary */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card className="bg-gradient-to-br from-blue-500/10 to-blue-600/5 border-blue-500/20">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Plays</CardTitle>
            <PlayCircle className="h-4 w-4 text-blue-500" />
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{plays.length.toLocaleString()}</div>
            <p className="text-xs text-muted-foreground mt-1">
              {avgPlaysPerDay.toLocaleString()} avg/day
            </p>
          </CardContent>
        </Card>

        <Card className="bg-gradient-to-br from-green-500/10 to-green-600/5 border-green-500/20">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Displays Online</CardTitle>
            <Monitor className="h-4 w-4 text-green-500" />
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{displayHealth.online}/{displayHealth.total}</div>
            <div className="flex items-center gap-2 mt-1">
              <Progress value={displayHealth.onlineRateNow} className="h-2" />
              <span className="text-xs text-muted-foreground">{displayHealth.onlineRateNow}%</span>
            </div>
          </CardContent>
        </Card>

        <Card className="bg-gradient-to-br from-purple-500/10 to-purple-600/5 border-purple-500/20">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active Campaigns</CardTitle>
            <TrendingUp className="h-4 w-4 text-purple-500" />
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{topCampaigns.length}</div>
            <p className="text-xs text-muted-foreground mt-1">
              {campaigns.length} total campaigns
            </p>
          </CardContent>
        </Card>

        <Card className="bg-gradient-to-br from-amber-500/10 to-amber-600/5 border-amber-500/20">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Peak Hour</CardTitle>
            <Clock className="h-4 w-4 text-amber-500" />
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{peakHour.hour.toString().padStart(2, "0")}:00</div>
            <p className="text-xs text-muted-foreground mt-1">
              {peakHour.count.toLocaleString()} plays at peak
            </p>
          </CardContent>
        </Card>
      </div>

      <div className="hidden print:block">
        <div className="flex items-center gap-2">
          <BarChart3 className="h-5 w-5" />
          <div className="text-xl font-semibold">DisplayDeck Analytics Report</div>
        </div>
        <div className="text-sm text-muted-foreground">
          Range: {fromISO ? new Date(fromISO).toLocaleString() : ""} – {toISO ? new Date(toISO).toLocaleString() : ""}
        </div>
      </div>

      {/* Daily Plays Chart */}
      {dailyPlaysData.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <BarChart3 className="h-5 w-5" />
              Daily Plays
            </CardTitle>
            <CardDescription>Playback activity over the selected date range.</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="flex items-end gap-1 h-40">
              {dailyPlaysData.map((day) => (
                <div
                  key={day.date}
                  className="flex-1 flex flex-col items-center gap-1 group"
                >
                  <div className="relative w-full flex justify-center">
                    <div
                      className="w-full max-w-8 bg-primary/80 hover:bg-primary rounded-t transition-all cursor-default"
                      style={{ height: `${Math.max(4, (day.count / maxDailyPlays) * 128)}px` }}
                      title={`${day.label}: ${day.count.toLocaleString()} plays`}
                    />
                    <div className="absolute -top-6 opacity-0 group-hover:opacity-100 transition-opacity text-xs font-medium bg-background border rounded px-1 py-0.5 shadow-sm">
                      {day.count}
                    </div>
                  </div>
                  <span className="text-[10px] text-muted-foreground rotate-45 origin-left whitespace-nowrap">
                    {day.label}
                  </span>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      <Card className="print:hidden">
        <CardHeader>
          <CardTitle>Filters</CardTitle>
          <CardDescription>Pick a date range and optional filters, then refresh.</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-6">
            <div className="grid gap-1 lg:col-span-2">
              <Label htmlFor="from">From</Label>
              <Input id="from" type="datetime-local" value={fromLocal} onChange={(e) => setFromLocal(e.target.value)} />
            </div>
            <div className="grid gap-1 lg:col-span-2">
              <Label htmlFor="to">To</Label>
              <Input id="to" type="datetime-local" value={toLocal} onChange={(e) => setToLocal(e.target.value)} />
            </div>

            <div className="grid gap-1">
              <Label>Display</Label>
              <Select value={displayId} onValueChange={setDisplayId}>
                <SelectTrigger>
                  <SelectValue placeholder="All displays" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All displays</SelectItem>
                  {displays.map((d) => (
                    <SelectItem key={d.Id} value={String(d.Id)}>
                      {d.Name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="grid gap-1">
              <Label>Campaign</Label>
              <Select value={campaignId} onValueChange={setCampaignId}>
                <SelectTrigger>
                  <SelectValue placeholder="All campaigns" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All campaigns</SelectItem>
                  {campaigns.map((c) => (
                    <SelectItem key={c.Id} value={String(c.Id)}>
                      {c.Name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="grid gap-1">
              <Label>Media</Label>
              <Select value={mediaFileId} onValueChange={setMediaFileId}>
                <SelectTrigger>
                  <SelectValue placeholder="All media" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All media</SelectItem>
                  {mediaFiles.map((m) => (
                    <SelectItem key={m.Id} value={String(m.Id)}>
                      {m.FileName}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="grid gap-1">
              <Label htmlFor="sla">SLA (minutes)</Label>
              <Input
                id="sla"
                inputMode="numeric"
                value={slaMinutes}
                onChange={(e) => setSlaMinutes(e.target.value)}
                placeholder="5"
              />
            </div>

            <div className="flex items-end lg:col-span-6">
              <Button onClick={() => void run(true)} disabled={refreshing}>
                Run report
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>

      <div className="grid gap-4 lg:grid-cols-3">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              {displayHealth.offline.length > 0 ? (
                <AlertTriangle className="h-4 w-4 text-amber-500" />
              ) : (
                <CheckCircle2 className="h-4 w-4 text-green-500" />
              )}
              Display Health
            </CardTitle>
            <CardDescription>Real-time status + SLA compliance.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="flex items-center justify-between">
              <div className="text-sm text-muted-foreground">Online rate</div>
              <div className="flex items-center gap-2">
                <Progress value={displayHealth.onlineRateNow} className="w-20 h-2" />
                <span className="font-semibold text-green-500">{displayHealth.onlineRateNow}%</span>
              </div>
            </div>
            <div className="flex items-center justify-between">
              <div className="text-sm text-muted-foreground">Within SLA ({displayHealth.slaMinutes}m)</div>
              <div className="font-semibold">{displayHealth.seenRecently}/{displayHealth.total}</div>
            </div>
            <div className="flex items-center justify-between">
              <div className="text-sm text-muted-foreground">Playback active</div>
              <div className="flex items-center gap-2">
                <Progress value={displayHealth.playbackActiveRate} className="w-20 h-2" />
                <span className="font-semibold">{displayHealth.playbackActiveRate}%</span>
              </div>
            </div>
            {displayHealth.offline.length > 0 && (
              <div className="pt-2 border-t">
                <div className="text-xs text-amber-500 font-medium">{displayHealth.offline.length} display{displayHealth.offline.length > 1 ? "s" : ""} offline</div>
              </div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <TrendingUp className="h-4 w-4 text-purple-500" />
              Top Campaigns
            </CardTitle>
            <CardDescription>By plays in selected range.</CardDescription>
          </CardHeader>
          <CardContent>
            {topCampaigns.length === 0 ? (
              <div className="text-sm text-muted-foreground">No data.</div>
            ) : (
              <div className="space-y-2">
                {topCampaigns.slice(0, 6).map((c, idx) => (
                  <div key={c.CampaignId} className="flex items-center justify-between gap-3">
                    <div className="flex items-center gap-2 min-w-0">
                      <span className="text-xs text-muted-foreground w-4">{idx + 1}.</span>
                      <button
                        type="button"
                        className="text-sm hover:text-primary truncate transition-colors"
                        onClick={() => router.push(`/dashboard/campaigns/${c.CampaignId}`)}
                      >
                        {c.CampaignName || `#${c.CampaignId}`}
                      </button>
                    </div>
                    <Badge variant="secondary" className="shrink-0">{c.Plays.toLocaleString()}</Badge>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Top media</CardTitle>
            <CardDescription>By plays in the selected range.</CardDescription>
          </CardHeader>
          <CardContent>
            {topMedia.length === 0 ? (
              <div className="text-sm text-muted-foreground">No data.</div>
            ) : (
              <div className="space-y-2">
                {topMedia.slice(0, 6).map((m) => (
                  <div key={m.MediaFileId} className="flex items-center justify-between gap-3">
                    <div className="text-sm truncate">{m.MediaFileName || `#${m.MediaFileId}`}</div>
                    <Badge variant="secondary">{m.Plays}</Badge>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Location rollup</CardTitle>
          <CardDescription>
            Grouped by display naming convention (e.g. “Store 12 - Screen A”). This is the fastest way to generate per-store sales stats without new schema.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {locationRollup.length === 0 ? (
            <div className="text-sm text-muted-foreground">No displays found.</div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Location</TableHead>
                  <TableHead>Displays</TableHead>
                  <TableHead>Online</TableHead>
                  <TableHead className="text-right">Plays (range)</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {locationRollup.slice(0, 25).map((g) => (
                  <TableRow key={g.location}>
                    <TableCell className="font-medium">{g.location}</TableCell>
                    <TableCell>{g.displayCount}</TableCell>
                    <TableCell>{g.onlineCount}</TableCell>
                    <TableCell className="text-right">{g.plays}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Proof of play</CardTitle>
          <CardDescription>
            Raw playback log rows (great for audits and partner reports). Export CSV or print to PDF.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {plays.length === 0 ? (
            <div className="text-center py-10 text-muted-foreground">No plays found for this range.</div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Time</TableHead>
                  <TableHead>Display</TableHead>
                  <TableHead>Campaign</TableHead>
                  <TableHead>Media</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {plays.slice(0, 500).map((p, idx) => (
                  <TableRow key={`${p.DisplayId}-${p.MediaFileId}-${p.PlaybackTimestamp}-${idx}`}>
                    <TableCell className="whitespace-nowrap">{safeDistanceToNow(p.PlaybackTimestamp)}</TableCell>
                    <TableCell className="font-medium">{p.DisplayName || `#${p.DisplayId}`}</TableCell>
                    <TableCell>
                      <button
                        type="button"
                        className="underline underline-offset-4"
                        onClick={() => router.push(`/dashboard/campaigns/${p.CampaignId}`)}
                      >
                        {p.CampaignName || `#${p.CampaignId}`}
                      </button>
                    </TableCell>
                    <TableCell className="font-mono text-xs">{p.MediaFileName || `#${p.MediaFileId}`}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}

          {plays.length > 500 ? (
            <div className="mt-3 text-xs text-muted-foreground">
              Showing first 500 rows for performance. Use CSV export for full detail.
            </div>
          ) : null}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Offline streaks</CardTitle>
          <CardDescription>Displays currently offline, ordered by how long they’ve been unseen.</CardDescription>
        </CardHeader>
        <CardContent>
          {displayHealth.offline.length === 0 ? (
            <div className="text-sm text-muted-foreground">All displays are online.</div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Display</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Last seen</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {displayHealth.offline
                  .slice()
                  .sort((a, b) => {
                    const ad = a.LastSeen ? new Date(a.LastSeen).getTime() : 0;
                    const bd = b.LastSeen ? new Date(b.LastSeen).getTime() : 0;
                    return ad - bd;
                  })
                  .slice(0, 25)
                  .map((d) => (
                    <TableRow key={d.Id}>
                      <TableCell className="font-medium">{d.Name}</TableCell>
                      <TableCell>
                        <Badge variant="secondary">{d.CurrentStatus || "Offline"}</Badge>
                      </TableCell>
                      <TableCell>{safeDistanceToNow(d.LastSeen)}</TableCell>
                    </TableRow>
                  ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
