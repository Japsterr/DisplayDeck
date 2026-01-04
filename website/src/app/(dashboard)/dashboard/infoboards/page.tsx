"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Plus, RefreshCw, LayoutGrid, MoreVertical, ExternalLink, Copy, Monitor, Building2, FileWarning, MapPin } from "lucide-react";

import { Button } from "@/components/ui/button";
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
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Checkbox } from "@/components/ui/checkbox";

const APP_VERSION = process.env.NEXT_PUBLIC_APP_VERSION || "dev";

type ThemeConfig = Record<string, unknown>;

interface InfoBoard {
  Id: number;
  OrganizationId: number;
  Name: string;
  BoardType: string;
  Orientation: string;
  TemplateKey: string;
  PublicToken: string;
  ThemeConfig?: ThemeConfig;
}

interface Display {
  Id: number;
  Name: string;
  Orientation: string;
  CurrentStatus?: string;
}

const BOARD_TYPE_ICONS: Record<string, React.ReactNode> = {
  directory: <Building2 className="h-4 w-4" />,
  hseq: <FileWarning className="h-4 w-4" />,
  notice: <LayoutGrid className="h-4 w-4" />,
  custom: <MapPin className="h-4 w-4" />,
};

const BOARD_TYPE_LABELS: Record<string, string> = {
  directory: "Directory (Mall/Office)",
  hseq: "HSEQ / Safety",
  notice: "Notice Board",
  custom: "Custom",
};

function getApiUrl() {
  const env = process.env.NEXT_PUBLIC_API_URL;
  if (env) return env;
  if (typeof window !== "undefined") return `${window.location.origin}/api`;
  return "/api";
}

function getAuth() {
  const token = localStorage.getItem("token");
  const userStr = localStorage.getItem("user");
  if (!token || !userStr) return null;
  try {
    const user = JSON.parse(userStr);
    const orgId = user?.OrganizationId;
    if (!orgId) return null;
    return { token, orgId };
  } catch {
    return null;
  }
}

export default function InfoBoardsPage() {
  const router = useRouter();
  const [boards, setBoards] = useState<InfoBoard[]>([]);
  const [loading, setLoading] = useState(true);

  const [isAddDialogOpen, setIsAddDialogOpen] = useState(false);
  const [creating, setCreating] = useState(false);
  const [newBoard, setNewBoard] = useState({
    name: "",
    boardType: "directory",
    orientation: "Landscape",
    templateKey: "standard",
  });

  const [displays, setDisplays] = useState<Display[]>([]);

  const [isAssignDialogOpen, setIsAssignDialogOpen] = useState(false);
  const [selectedBoard, setSelectedBoard] = useState<InfoBoard | null>(null);
  const [selectedDisplayIds, setSelectedDisplayIds] = useState<number[]>([]);
  const [assigning, setAssigning] = useState(false);

  const publicBaseUrl = useMemo(() => {
    if (typeof window === "undefined") return "";
    return window.location.origin;
  }, []);

  const fetchBoards = async () => {
    try {
      setLoading(true);
      const auth = getAuth();
      if (!auth) {
        router.push("/login");
        return;
      }

      const apiUrl = getApiUrl();
      const res = await fetch(`${apiUrl}/organizations/${auth.orgId}/infoboards`, {
        headers: { "X-Auth-Token": auth.token },
      });

      if (res.status === 401) {
        router.push("/login");
        return;
      }

      if (!res.ok) throw new Error(await res.text());
      const data = await res.json();
      setBoards((data.value || []) as InfoBoard[]);
    } catch (e) {
      console.error(e);
      toast.error("Failed to load info boards");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchBoards();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const ensureDisplaysLoaded = async (): Promise<Display[]> => {
    if (displays.length) return displays;
    const auth = getAuth();
    if (!auth) return [];
    const apiUrl = getApiUrl();
    const res = await fetch(`${apiUrl}/organizations/${auth.orgId}/displays`, {
      headers: { "X-Auth-Token": auth.token },
    });
    if (!res.ok) throw new Error(await res.text());
    const data = await res.json();
    const loaded = (data.value || []) as Display[];
    setDisplays(loaded);
    return loaded;
  };

  const handleDuplicateBoard = async (boardId: number) => {
    try {
      const auth = getAuth();
      if (!auth) return;

      const apiUrl = getApiUrl();
      const res = await fetch(`${apiUrl}/infoboards/${boardId}/duplicate`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": auth.token,
        },
        body: JSON.stringify({}),
      });

      if (!res.ok) throw new Error(await res.text());
      const created = (await res.json()) as InfoBoard;
      toast.success("Info board duplicated");
      router.push(`/dashboard/infoboards/${created.Id}`);
    } catch (e) {
      console.error(e);
      toast.error("Failed to duplicate info board");
    }
  };

  const openAssignDialog = async (board: InfoBoard) => {
    try {
      setSelectedBoard(board);
      setIsAssignDialogOpen(true);
      setAssigning(true);
      const auth = getAuth();
      if (!auth) return;
      const apiUrl = getApiUrl();
      const headers = { "X-Auth-Token": auth.token };

      await ensureDisplaysLoaded();

      const res = await fetch(`${apiUrl}/infoboards/${board.Id}/display-assignments`, { headers });
      if (!res.ok) throw new Error(await res.text());
      const data = await res.json();
      const ids = ((data.value || []) as any[])
        .map((a) => Number(a.DisplayId))
        .filter((n) => Number.isFinite(n));
      setSelectedDisplayIds(ids);
    } catch (e) {
      console.error(e);
      toast.error("Failed to load board assignments");
    } finally {
      setAssigning(false);
    }
  };

  const handleSaveAssignments = async () => {
    if (!selectedBoard) return;
    try {
      setAssigning(true);
      const auth = getAuth();
      if (!auth) return;
      const apiUrl = getApiUrl();
      const res = await fetch(`${apiUrl}/infoboards/${selectedBoard.Id}/display-assignments`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": auth.token,
        },
        body: JSON.stringify({ DisplayIds: selectedDisplayIds, SetPrimary: true }),
      });
      if (!res.ok) {
        const raw = await res.text();
        let msg = raw;
        try {
          const j = JSON.parse(raw);
          msg = j?.message || j?.Message || raw;
        } catch {
          // keep raw
        }
        throw new Error(msg || `HTTP ${res.status}`);
      }
      toast.success("Board assignments updated");
      setIsAssignDialogOpen(false);
    } catch (e) {
      console.error(e);
      const msg = e instanceof Error ? e.message : "";
      toast.error(msg ? `Failed to save board assignments: ${msg}` : "Failed to save board assignments");
    } finally {
      setAssigning(false);
    }
  };

  const handleCreateBoard = async () => {
    if (!newBoard.name.trim()) {
      toast.error("Board name is required");
      return;
    }

    try {
      setCreating(true);
      const auth = getAuth();
      if (!auth) return;

      const apiUrl = getApiUrl();
      const res = await fetch(`${apiUrl}/organizations/${auth.orgId}/infoboards`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": auth.token,
        },
        body: JSON.stringify({
          Name: newBoard.name.trim(),
          BoardType: newBoard.boardType,
          Orientation: newBoard.orientation,
          TemplateKey: newBoard.templateKey,
          ThemeConfig: {},
        }),
      });

      if (!res.ok) throw new Error(await res.text());
      const created = (await res.json()) as InfoBoard;
      toast.success("Info board created");
      setIsAddDialogOpen(false);
      setNewBoard({ name: "", boardType: "directory", orientation: "Landscape", templateKey: "standard" });
      router.push(`/dashboard/infoboards/${created.Id}`);
    } catch (e) {
      console.error(e);
      toast.error("Failed to create info board");
    } finally {
      setCreating(false);
    }
  };

  return (
    <div className="flex flex-col gap-4 p-4 pt-0">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Information Boards</h2>
          <p className="text-muted-foreground">Create directories, notices, and HSEQ/safety displays.</p>
          <p className="text-muted-foreground text-xs">UI build: {APP_VERSION}</p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="icon" onClick={fetchBoards} disabled={loading}>
            <RefreshCw className="h-4 w-4" />
          </Button>

          <Dialog open={isAddDialogOpen} onOpenChange={setIsAddDialogOpen}>
            <DialogTrigger asChild>
              <Button>
                <Plus className="mr-2 h-4 w-4" /> New Info Board
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Create Info Board</DialogTitle>
                <DialogDescription>
                  Create a directory, notice board, HSEQ poster, or custom information display.
                </DialogDescription>
              </DialogHeader>
              <div className="grid gap-4 py-4">
                <div className="grid gap-2">
                  <Label htmlFor="name">Name</Label>
                  <Input
                    id="name"
                    value={newBoard.name}
                    onChange={(e) => setNewBoard((p) => ({ ...p, name: e.target.value }))}
                    placeholder="e.g. Mall Directory, Floor Plan, Safety Notice"
                  />
                </div>

                <div className="grid gap-2">
                  <Label>Board Type</Label>
                  <Select
                    value={newBoard.boardType}
                    onValueChange={(v) => setNewBoard((p) => ({ ...p, boardType: v }))}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select type" />
                    </SelectTrigger>
                    <SelectContent position="popper" className="z-[10000]">
                      <SelectItem value="directory">
                        <div className="flex items-center gap-2">
                          <Building2 className="h-4 w-4" />
                          Directory (Mall/Office)
                        </div>
                      </SelectItem>
                      <SelectItem value="hseq">
                        <div className="flex items-center gap-2">
                          <FileWarning className="h-4 w-4" />
                          HSEQ / Safety
                        </div>
                      </SelectItem>
                      <SelectItem value="notice">
                        <div className="flex items-center gap-2">
                          <LayoutGrid className="h-4 w-4" />
                          Notice Board
                        </div>
                      </SelectItem>
                      <SelectItem value="custom">
                        <div className="flex items-center gap-2">
                          <MapPin className="h-4 w-4" />
                          Custom
                        </div>
                      </SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                <div className="grid gap-2">
                  <Label>Orientation</Label>
                  <Select
                    value={newBoard.orientation}
                    onValueChange={(v) => setNewBoard((p) => ({ ...p, orientation: v }))}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select orientation" />
                    </SelectTrigger>
                    <SelectContent position="popper" className="z-[10000]">
                      <SelectItem value="Landscape">Landscape</SelectItem>
                      <SelectItem value="Portrait">Portrait</SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                <div className="grid gap-2">
                  <Label>Template</Label>
                  <Select
                    value={newBoard.templateKey}
                    onValueChange={(v) => setNewBoard((p) => ({ ...p, templateKey: v }))}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select template" />
                    </SelectTrigger>
                    <SelectContent position="popper" className="z-[10000]">
                      <SelectItem value="standard">Standard</SelectItem>
                      <SelectItem value="corporate">Corporate</SelectItem>
                      <SelectItem value="modern">Modern</SelectItem>
                      <SelectItem value="minimal">Minimal</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <DialogFooter>
                <Button onClick={handleCreateBoard} disabled={creating}>
                  {creating ? "Creating..." : "Create"}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <LayoutGrid className="h-5 w-5" />
            Your Info Boards
          </CardTitle>
          <CardDescription>
            {loading ? "Loading..." : `${boards.length} board${boards.length === 1 ? "" : "s"}`}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="py-8 text-center text-muted-foreground">Loading info boards...</div>
          ) : boards.length === 0 ? (
            <div className="py-8 text-center text-muted-foreground">
              No info boards yet. Create one to get started.
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Type</TableHead>
                  <TableHead>Orientation</TableHead>
                  <TableHead>Template</TableHead>
                  <TableHead>Public</TableHead>
                  <TableHead className="w-[60px]"></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {boards.map((b) => (
                  <TableRow
                    key={b.Id}
                    className="cursor-pointer"
                    onClick={() => router.push(`/dashboard/infoboards/${b.Id}`)}
                  >
                    <TableCell className="font-medium">{b.Name}</TableCell>
                    <TableCell>
                      <div className="flex items-center gap-2">
                        {BOARD_TYPE_ICONS[b.BoardType] || BOARD_TYPE_ICONS.custom}
                        <span className="text-sm">{BOARD_TYPE_LABELS[b.BoardType] || b.BoardType}</span>
                      </div>
                    </TableCell>
                    <TableCell>
                      <Badge variant="outline">{b.Orientation || "Landscape"}</Badge>
                    </TableCell>
                    <TableCell>{b.TemplateKey || "standard"}</TableCell>
                    <TableCell>
                      <a
                        className="inline-flex items-center gap-1 text-sm text-primary hover:underline"
                        href={`${publicBaseUrl}/display/infoboard/${b.PublicToken}`}
                        target="_blank"
                        rel="noreferrer"
                        onClick={(e) => e.stopPropagation()}
                      >
                        Open <ExternalLink className="h-3 w-3" />
                      </a>
                    </TableCell>
                    <TableCell onClick={(e) => e.stopPropagation()}>
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="icon">
                            <MoreVertical className="h-4 w-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuLabel>Info Board</DropdownMenuLabel>
                          <DropdownMenuSeparator />
                          <DropdownMenuItem onClick={() => router.push(`/dashboard/infoboards/${b.Id}`)}>
                            Edit
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            onClick={() =>
                              window.open(`${publicBaseUrl}/display/infoboard/${b.PublicToken}`, "_blank")
                            }
                          >
                            Preview
                          </DropdownMenuItem>
                          <DropdownMenuItem onClick={() => openAssignDialog(b)}>
                            <Monitor className="mr-2 h-4 w-4" /> Assign to Displays
                          </DropdownMenuItem>
                          <DropdownMenuItem onClick={() => handleDuplicateBoard(b.Id)}>
                            <Copy className="mr-2 h-4 w-4" /> Duplicate
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

      <Dialog open={isAssignDialogOpen} onOpenChange={setIsAssignDialogOpen}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>Assign info board to displays</DialogTitle>
            <DialogDescription>
              {selectedBoard ? `Select displays that should show "${selectedBoard.Name}".` : ""}
            </DialogDescription>
          </DialogHeader>

          <div className="flex items-center justify-between">
            <Button
              type="button"
              variant="outline"
              onClick={() => setSelectedDisplayIds(displays.map((d) => d.Id))}
              disabled={assigning || displays.length === 0}
            >
              Select all
            </Button>
            <Button
              type="button"
              variant="outline"
              onClick={() => setSelectedDisplayIds([])}
              disabled={assigning || displays.length === 0}
            >
              Clear
            </Button>
          </div>

          <div className="max-h-[50vh] overflow-auto rounded-md border">
            {displays.length === 0 ? (
              <div className="p-4 text-sm text-muted-foreground">No displays yet.</div>
            ) : (
              <div className="divide-y">
                {displays.map((d) => {
                  const checked = selectedDisplayIds.includes(d.Id);
                  return (
                    <label key={d.Id} className="flex items-center gap-3 p-3 hover:bg-muted/40 cursor-pointer">
                      <Checkbox
                        checked={checked}
                        onCheckedChange={(v) => {
                          const isChecked = v === true;
                          setSelectedDisplayIds((prev) => {
                            if (isChecked) return prev.includes(d.Id) ? prev : [...prev, d.Id];
                            return prev.filter((x) => x !== d.Id);
                          });
                        }}
                      />
                      <div className="min-w-0 flex-1">
                        <div className="font-medium truncate">{d.Name}</div>
                        <div className="text-xs text-muted-foreground">{d.Orientation || "Landscape"}</div>
                      </div>
                      {d.CurrentStatus ? <Badge variant="outline">{d.CurrentStatus}</Badge> : null}
                    </label>
                  );
                })}
              </div>
            )}
          </div>

          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => setIsAssignDialogOpen(false)} disabled={assigning}>
              Cancel
            </Button>
            <Button type="button" onClick={handleSaveAssignments} disabled={assigning || !selectedBoard}>
              {assigning ? "Saving..." : "Save"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
