"use client";

import { useEffect, useState } from "react";
import { Plus, Monitor, MoreVertical, RefreshCw } from "lucide-react";
import { formatDistanceToNow } from "date-fns";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

interface NowPlaying {
  ItemType?: "media" | "menu";
  DisplayId: number;
  CampaignId?: number | null;
  MediaFileId?: number | null;
  PlaybackTimestamp?: string | null;
  StartedAt?: string | null;
  MediaFileName?: string | null;
  MediaFileType?: string | null;
  CampaignName?: string | null;
  MenuId?: number | null;
  MenuName?: string | null;
  MenuPublicToken?: string | null;
}

interface Display {
  Id: number;
  Name: string;
  Orientation: string;
  CurrentStatus: string;
  LastSeen: string;
  ProvisioningToken?: string;
}

export default function DisplaysPage() {
  const router = useRouter();
  const [displays, setDisplays] = useState<Display[]>([]);
  const [loading, setLoading] = useState(true);
  const [nowPlayingByDisplayId, setNowPlayingByDisplayId] = useState<Record<number, NowPlaying | null>>({});
  const [nowPlayingLoading, setNowPlayingLoading] = useState(false);
  const [nowPlayingLastUpdatedAt, setNowPlayingLastUpdatedAt] = useState<Date | null>(null);
  const [mediaPreviewByMediaFileId, setMediaPreviewByMediaFileId] = useState<
    Record<number, { url: string; fetchedAtMs: number }>
  >({});
  const [isAddDialogOpen, setIsAddDialogOpen] = useState(false);
  const [newDisplay, setNewDisplay] = useState({ name: "", pairingCode: "", orientation: "Landscape" });
  const [isSubmitting, setIsSubmitting] = useState(false);

  const getAuthContext = () => {
    const token = localStorage.getItem("token");
    const userStr = localStorage.getItem("user");
    if (!token || !userStr) return null;
    const user = JSON.parse(userStr);
    const orgId = user.OrganizationId;
    const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";
    return { token, orgId, apiUrl };
  };

  const mapWithConcurrency = async <T, R>(
    items: T[],
    concurrency: number,
    mapper: (item: T) => Promise<R>
  ): Promise<R[]> => {
    const results: R[] = new Array(items.length);
    let index = 0;

    const workers = new Array(Math.min(concurrency, items.length)).fill(0).map(async () => {
      while (index < items.length) {
        const currentIndex = index;
        index += 1;
        results[currentIndex] = await mapper(items[currentIndex]);
      }
    });

    await Promise.all(workers);
    return results;
  };

  const fetchNowPlaying = async (displaysList: Display[]) => {
    const auth = getAuthContext();
    if (!auth) return;

    const activeDisplays = displaysList.filter((d) => d.CurrentStatus === "Online");
    if (activeDisplays.length === 0) {
      setNowPlayingByDisplayId({});
      setNowPlayingLastUpdatedAt(new Date());
      return;
    }

    try {
      setNowPlayingLoading(true);

      const entries = await mapWithConcurrency(activeDisplays, 6, async (display) => {
        try {
          const res = await fetch(`${auth.apiUrl}/displays/${display.Id}/current-playing`, {
            headers: {
              "X-Auth-Token": auth.token,
            },
          });

          if (res.status === 404) {
            return [display.Id, null] as const;
          }
          if (!res.ok) {
            throw new Error(`Failed to fetch current playing for display ${display.Id}`);
          }

          const payload = (await res.json()) as NowPlaying;
          return [display.Id, payload] as const;
        } catch (err) {
          console.error(err);
          return [display.Id, null] as const;
        }
      });

      setNowPlayingByDisplayId(Object.fromEntries(entries));
      setNowPlayingLastUpdatedAt(new Date());

      // Prefetch preview URLs for media content so the dashboard can show a visual.
      const nowPlayingRows = entries
        .map(([, value]) => value)
        .filter((v): v is NowPlaying => Boolean(v));

      const mediaFileIds = Array.from(
        new Set(
          nowPlayingRows
            .map((r) => r.MediaFileId)
            .filter((id): id is number => typeof id === "number")
        )
      );
      const nowMs = Date.now();
      const maxAgeMs = 5 * 60 * 1000; // refresh presigned URLs occasionally

      const idsToFetch = mediaFileIds.filter((id) => {
        const cached = mediaPreviewByMediaFileId[id];
        return !cached || nowMs - cached.fetchedAtMs > maxAgeMs;
      });

      if (idsToFetch.length > 0) {
        const fetched = await mapWithConcurrency(idsToFetch, 6, async (mediaFileId) => {
          try {
            const res = await fetch(`${auth.apiUrl}/media-files/${mediaFileId}/download-url`, {
              headers: { "X-Auth-Token": auth.token },
            });

            if (!res.ok) throw new Error("Failed to fetch media download URL");
            const payload = await res.json().catch(() => null);
            const url = payload?.DownloadUrl ?? payload?.downloadUrl;
            if (!url) return [mediaFileId, null] as const;
            return [mediaFileId, { url, fetchedAtMs: Date.now() }] as const;
          } catch (err) {
            console.error(err);
            return [mediaFileId, null] as const;
          }
        });

        setMediaPreviewByMediaFileId((prev) => {
          const next = { ...prev };
          for (const [id, value] of fetched) {
            if (value) next[id] = value;
          }
          return next;
        });
      }
    } finally {
      setNowPlayingLoading(false);
    }
  };

  const fetchDisplays = async () => {
    try {
      setLoading(true);
      const auth = getAuthContext();
      if (!auth) {
        router.push("/login");
        return;
      }

      const response = await fetch(`${auth.apiUrl}/organizations/${auth.orgId}/displays`, {
        headers: {
          "X-Auth-Token": auth.token,
        },
      });

      if (response.status === 401) {
        router.push("/login");
        return;
      }

      if (!response.ok) throw new Error("Failed to fetch displays");

      const data = await response.json();
      const list = data.value || [];
      setDisplays(list);
      await fetchNowPlaying(list);
    } catch (error) {
      console.error(error);
      toast.error("Failed to load displays");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchDisplays();
  }, []);

  useEffect(() => {
    if (loading) return;

    const handle = window.setInterval(() => {
      void fetchNowPlaying(displays);
    }, 15000);

    return () => window.clearInterval(handle);
  }, [loading, displays]);

  const handlePairDisplay = async () => {
    if (!newDisplay.name) {
      toast.error("Display name is required");
      return;
    }

    if (!newDisplay.pairingCode.trim()) {
      toast.error("Pairing code is required");
      return;
    }

    try {
      setIsSubmitting(true);
      const token = localStorage.getItem("token");
      const userStr = localStorage.getItem("user");
      
      if (!token || !userStr) return;

      const user = JSON.parse(userStr);
      const orgId = user.OrganizationId;
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";

      const response = await fetch(`${apiUrl}/organizations/${orgId}/displays/claim`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": token || "",
        },
        body: JSON.stringify({
          ProvisioningToken: newDisplay.pairingCode.trim().toUpperCase(),
          Name: newDisplay.name,
          Orientation: newDisplay.orientation,
        }),
      });

      const payload = await response.json().catch(() => null);
      if (!response.ok) {
        const msg = payload?.message || "Failed to pair display";
        throw new Error(msg);
      }

      toast.success("Display paired successfully");
      await fetchDisplays();
      setIsAddDialogOpen(false);
      setNewDisplay({ name: "", pairingCode: "", orientation: "Landscape" });
    } catch (error) {
      console.error(error);
      toast.error(error instanceof Error ? error.message : "Failed to pair display");
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDeleteDisplay = async (id: number) => {
    if (!confirm("Are you sure you want to delete this display?")) return;

    try {
      const token = localStorage.getItem("token");
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";

      const response = await fetch(`${apiUrl}/displays/${id}`, {
        method: "DELETE",
        headers: {
          "X-Auth-Token": token || "",
        },
      });

      if (!response.ok) throw new Error("Failed to delete display");

      toast.success("Display deleted");
      setDisplays(displays.filter(d => d.Id !== id));
    } catch (error) {
      console.error(error);
      toast.error("Failed to delete display");
    }
  };

  return (
    <div className="flex flex-col gap-4 p-4 pt-0">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Displays</h2>
          <p className="text-muted-foreground">
            Manage your digital signage screens and their status.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="icon"
            onClick={() => {
              void fetchDisplays();
            }}
          >
            <RefreshCw className="h-4 w-4" />
          </Button>
          <Dialog open={isAddDialogOpen} onOpenChange={setIsAddDialogOpen}>
            <DialogTrigger asChild>
              <Button>
                <Plus className="mr-2 h-4 w-4" /> Add Display
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Add Display</DialogTitle>
                <DialogDescription>
                  Turn on the Android player and enter the 6-character code shown on the screen.
                </DialogDescription>
              </DialogHeader>
              <div className="grid gap-4 py-4">
                <div className="grid grid-cols-4 items-center gap-4">
                  <Label htmlFor="pairingCode" className="text-right">
                    Code
                  </Label>
                  <Input
                    id="pairingCode"
                    value={newDisplay.pairingCode}
                    onChange={(e) => setNewDisplay({ ...newDisplay, pairingCode: e.target.value })}
                    className="col-span-3 font-mono uppercase"
                    placeholder="A1B2C3"
                  />
                </div>
                <div className="grid grid-cols-4 items-center gap-4">
                  <Label htmlFor="name" className="text-right">
                    Name
                  </Label>
                  <Input
                    id="name"
                    value={newDisplay.name}
                    onChange={(e) => setNewDisplay({ ...newDisplay, name: e.target.value })}
                    className="col-span-3"
                    placeholder="Lobby Screen 1"
                  />
                </div>
                <div className="grid grid-cols-4 items-center gap-4">
                  <Label htmlFor="orientation" className="text-right">
                    Orientation
                  </Label>
                  <Select
                    value={newDisplay.orientation}
                    onValueChange={(val) => setNewDisplay({ ...newDisplay, orientation: val })}
                  >
                    <SelectTrigger className="col-span-3">
                      <SelectValue placeholder="Select orientation" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="Landscape">Landscape (16:9)</SelectItem>
                      <SelectItem value="Portrait">Portrait (9:16)</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setIsAddDialogOpen(false)}>Cancel</Button>
                <Button onClick={handlePairDisplay} disabled={isSubmitting}>
                  {isSubmitting ? "Pairing..." : "Pair Display"}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Active Displays</CardTitle>
          <CardDescription>
            What each online display is showing right now.
            {nowPlayingLastUpdatedAt
              ? ` Updated ${formatDistanceToNow(nowPlayingLastUpdatedAt, { addSuffix: true })}.`
              : ""}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="text-center py-8 text-muted-foreground">Loading...</div>
          ) : displays.filter((d) => d.CurrentStatus === "Online").length === 0 ? (
            <div className="text-center py-10 border-2 border-dashed rounded-lg">
              <Monitor className="h-10 w-10 mx-auto text-muted-foreground opacity-50" />
              <h3 className="mt-3 text-lg font-semibold">No active displays</h3>
              <p className="text-muted-foreground">Once a screen comes online, it will show up here.</p>
            </div>
          ) : (
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {displays
                .filter((d) => d.CurrentStatus === "Online")
                .map((display) => {
                  const nowPlaying = nowPlayingByDisplayId[display.Id] ?? null;
                  const mediaId = nowPlaying?.MediaFileId ?? null;
                  const mediaPreview = mediaId
                    ? mediaPreviewByMediaFileId[mediaId]?.url
                    : undefined;
                  const mediaType = (nowPlaying?.MediaFileType || "").toLowerCase();
                  const isImage = mediaType.includes("image") || mediaType === "jpg" || mediaType === "jpeg" || mediaType === "png" || mediaType === "webp";
                  const isVideo = mediaType.includes("video") || mediaType === "mp4" || mediaType === "webm" || mediaType === "mov";

                  return (
                    <div
                      key={display.Id}
                      className="rounded-lg border p-4 flex flex-col gap-3"
                    >
                      <div className="flex items-start justify-between gap-3">
                        <div className="min-w-0">
                          <div className="font-semibold truncate">{display.Name}</div>
                          <div className="text-xs text-muted-foreground">
                            Last seen{" "}
                            {display.LastSeen
                              ? formatDistanceToNow(new Date(display.LastSeen), { addSuffix: true })
                              : "Never"}
                          </div>
                        </div>
                        <Badge className="bg-green-500 hover:bg-green-600">Online</Badge>
                      </div>

                      {nowPlaying && mediaPreview && isImage ? (
                        <img
                          src={mediaPreview}
                          alt={nowPlaying.MediaFileName || "Now playing"}
                          className="w-full aspect-video object-cover rounded-md border"
                          loading="lazy"
                        />
                      ) : nowPlaying && mediaPreview && isVideo ? (
                        <video
                          src={mediaPreview}
                          className="w-full aspect-video object-cover rounded-md border"
                          muted
                          playsInline
                          preload="metadata"
                          controls
                        />
                      ) : null}

                      {nowPlayingLoading && !nowPlaying ? (
                        <div className="text-sm text-muted-foreground">Loading now playing…</div>
                      ) : nowPlaying ? (
                        <div className="flex flex-col gap-1">
                          {(nowPlaying.ItemType || "media") === "menu" ? (
                            <>
                              <div className="text-sm">
                                <span className="text-muted-foreground">Menu:</span>{" "}
                                {nowPlaying.MenuId ? (
                                  <button
                                    type="button"
                                    className="underline underline-offset-4"
                                    onClick={() => router.push(`/dashboard/menus/${nowPlaying.MenuId}`)}
                                  >
                                    {nowPlaying.MenuName || `#${nowPlaying.MenuId}`}
                                  </button>
                                ) : (
                                  <span>{nowPlaying.MenuName || "Assigned menu"}</span>
                                )}
                              </div>
                              <div className="text-xs text-muted-foreground">
                                Showing assigned menu (no playback logs yet).
                              </div>
                            </>
                          ) : (
                            <>
                              <div className="text-sm">
                                <span className="text-muted-foreground">Campaign:</span>{" "}
                                {nowPlaying.CampaignId ? (
                                  <button
                                    type="button"
                                    className="underline underline-offset-4"
                                    onClick={() => router.push(`/dashboard/campaigns/${nowPlaying.CampaignId}`)}
                                  >
                                    {nowPlaying.CampaignName || `#${nowPlaying.CampaignId}`}
                                  </button>
                                ) : (
                                  <span>{nowPlaying.CampaignName || "Assigned campaign"}</span>
                                )}
                              </div>
                              <div className="text-sm">
                                <span className="text-muted-foreground">Media:</span>{" "}
                                <span className="font-mono text-xs">
                                  {nowPlaying.MediaFileName || (nowPlaying.MediaFileId ? `#${nowPlaying.MediaFileId}` : "(unknown)")}
                                </span>
                              </div>
                              <div className="text-xs text-muted-foreground">
                                {nowPlaying.MediaFileType ? `${nowPlaying.MediaFileType} • ` : ""}
                                {nowPlaying.StartedAt
                                  ? `Started ${formatDistanceToNow(new Date(nowPlaying.StartedAt), { addSuffix: true })}`
                                  : "Showing assigned campaign (no playback logs yet)."}
                              </div>
                              {!mediaPreview && nowPlaying.MediaFileId ? (
                                <div className="text-xs text-muted-foreground">
                                  Preview unavailable for this item.
                                </div>
                              ) : null}
                            </>
                          )}
                        </div>
                      ) : (
                        <div className="text-sm text-muted-foreground">
                          No playback yet.
                        </div>
                      )}
                    </div>
                  );
                })}
            </div>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>All Displays</CardTitle>
          <CardDescription>
            A list of all displays registered to your organization.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="text-center py-8 text-muted-foreground">Loading displays...</div>
          ) : displays.length === 0 ? (
            <div className="text-center py-12 border-2 border-dashed rounded-lg">
              <Monitor className="h-12 w-12 mx-auto text-muted-foreground opacity-50" />
              <h3 className="mt-4 text-lg font-semibold">No displays yet</h3>
              <p className="text-muted-foreground mb-4">Add your first display to get started.</p>
              <Button onClick={() => setIsAddDialogOpen(true)}>Add Display</Button>
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Orientation</TableHead>
                  <TableHead>Last Seen</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {displays.map((display) => (
                  <TableRow key={display.Id}>
                    <TableCell className="font-medium">
                      <div className="flex flex-col">
                        <span>{display.Name}</span>
                        {display.ProvisioningToken && (
                          <span className="text-xs text-muted-foreground font-mono mt-1">
                            Token: {display.ProvisioningToken}
                          </span>
                        )}
                      </div>
                    </TableCell>
                    <TableCell>
                      <Badge variant={display.CurrentStatus === "Online" ? "default" : "secondary"} className={display.CurrentStatus === "Online" ? "bg-green-500 hover:bg-green-600" : ""}>
                        {display.CurrentStatus}
                      </Badge>
                    </TableCell>
                    <TableCell>{display.Orientation}</TableCell>
                    <TableCell>
                      {display.LastSeen ? formatDistanceToNow(new Date(display.LastSeen), { addSuffix: true }) : "Never"}
                    </TableCell>
                    <TableCell className="text-right">
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" className="h-8 w-8 p-0">
                            <span className="sr-only">Open menu</span>
                            <MoreVertical className="h-4 w-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuLabel>Actions</DropdownMenuLabel>
                          <DropdownMenuItem onClick={() => navigator.clipboard.writeText(display.ProvisioningToken || "")}>
                            Copy Token
                          </DropdownMenuItem>
                          <DropdownMenuSeparator />
                          <DropdownMenuItem className="text-red-600" onClick={() => handleDeleteDisplay(display.Id)}>
                            Delete
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </TableCell>
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
