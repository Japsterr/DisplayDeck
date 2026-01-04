"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Plus, RefreshCw, UtensilsCrossed, MoreVertical, ExternalLink, Copy, Monitor } from "lucide-react";

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

interface Menu {
  Id: number;
  OrganizationId: number;
  Name: string;
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

export default function MenusPage() {
  const router = useRouter();
  const [menus, setMenus] = useState<Menu[]>([]);
  const [loading, setLoading] = useState(true);

  const [isAddDialogOpen, setIsAddDialogOpen] = useState(false);
  const [creating, setCreating] = useState(false);
  const [newMenu, setNewMenu] = useState({ name: "", orientation: "Landscape", templateKey: "classic", layoutColumns: "auto" as "auto" | "1" | "2" | "3" });

  const [displays, setDisplays] = useState<Display[]>([]);

  const [isAssignDialogOpen, setIsAssignDialogOpen] = useState(false);
  const [selectedMenu, setSelectedMenu] = useState<Menu | null>(null);
  const [selectedDisplayIds, setSelectedDisplayIds] = useState<number[]>([]);
  const [assigning, setAssigning] = useState(false);

  const publicBaseUrl = useMemo(() => {
    if (typeof window === "undefined") return "";
    return window.location.origin;
  }, []);

  const fetchMenus = async () => {
    try {
      setLoading(true);
      const auth = getAuth();
      if (!auth) {
        router.push("/login");
        return;
      }

      const apiUrl = getApiUrl();
      const res = await fetch(`${apiUrl}/organizations/${auth.orgId}/menus`, {
        headers: { "X-Auth-Token": auth.token },
      });

      if (res.status === 401) {
        router.push("/login");
        return;
      }

      if (!res.ok) throw new Error(await res.text());
      const data = await res.json();
      setMenus((data.value || []) as Menu[]);
    } catch (e) {
      console.error(e);
      toast.error("Failed to load menus");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchMenus();
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

  const handleDuplicateMenu = async (menuId: number) => {
    try {
      const auth = getAuth();
      if (!auth) return;

      const apiUrl = getApiUrl();
      const res = await fetch(`${apiUrl}/menus/${menuId}/duplicate`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": auth.token,
        },
        body: JSON.stringify({}),
      });

      if (!res.ok) throw new Error(await res.text());
      const created = (await res.json()) as Menu;
      toast.success("Menu duplicated");
      router.push(`/dashboard/menus/${created.Id}`);
    } catch (e) {
      console.error(e);
      toast.error("Failed to duplicate menu");
    }
  };

  const openAssignDialog = async (menu: Menu) => {
    try {
      setSelectedMenu(menu);
      setIsAssignDialogOpen(true);
      setAssigning(true);
      const auth = getAuth();
      if (!auth) return;
      const apiUrl = getApiUrl();
      const headers = { "X-Auth-Token": auth.token };

      await ensureDisplaysLoaded();

      const res = await fetch(`${apiUrl}/menus/${menu.Id}/display-assignments`, { headers });
      if (!res.ok) throw new Error(await res.text());
      const data = await res.json();
      const ids = ((data.value || []) as any[])
        .map((a) => Number(a.DisplayId))
        .filter((n) => Number.isFinite(n));
      setSelectedDisplayIds(ids);
    } catch (e) {
      console.error(e);
      toast.error("Failed to load menu assignments");
    } finally {
      setAssigning(false);
    }
  };

  const handleSaveAssignments = async () => {
    if (!selectedMenu) return;
    try {
      setAssigning(true);
      const auth = getAuth();
      if (!auth) return;
      const apiUrl = getApiUrl();
      const res = await fetch(`${apiUrl}/menus/${selectedMenu.Id}/display-assignments`, {
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
      toast.success("Menu assignments updated");
      setIsAssignDialogOpen(false);
    } catch (e) {
      console.error(e);
      const msg = e instanceof Error ? e.message : "";
      toast.error(msg ? `Failed to save menu assignments: ${msg}` : "Failed to save menu assignments");
    } finally {
      setAssigning(false);
    }
  };
  const handleCreateMenu = async () => {
    if (!newMenu.name.trim()) {
      toast.error("Menu name is required");
      return;
    }

    try {
      setCreating(true);
      const auth = getAuth();
      if (!auth) return;

      const apiUrl = getApiUrl();
      const res = await fetch(`${apiUrl}/organizations/${auth.orgId}/menus`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": auth.token,
        },
        body: JSON.stringify({
          Name: newMenu.name.trim(),
          Orientation: newMenu.orientation,
          TemplateKey: newMenu.templateKey,
          ThemeConfig: newMenu.layoutColumns === "auto" ? {} : { layoutColumns: parseInt(newMenu.layoutColumns, 10) },
        }),
      });

      if (!res.ok) throw new Error(await res.text());
      const created = (await res.json()) as Menu;
      toast.success("Menu created");
      setIsAddDialogOpen(false);
      setNewMenu({ name: "", orientation: "Landscape", templateKey: "classic", layoutColumns: "auto" });
      router.push(`/dashboard/menus/${created.Id}`);
    } catch (e) {
      console.error(e);
      toast.error("Failed to create menu");
    } finally {
      setCreating(false);
    }
  };

  return (
    <div className="flex flex-col gap-4 p-4 pt-0">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Menus</h2>
          <p className="text-muted-foreground">Create and manage dynamic menu boards.</p>
          <p className="text-muted-foreground text-xs">UI build: {APP_VERSION}</p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="icon" onClick={fetchMenus} disabled={loading}>
            <RefreshCw className="h-4 w-4" />
          </Button>

          <Dialog open={isAddDialogOpen} onOpenChange={setIsAddDialogOpen}>
            <DialogTrigger asChild>
              <Button>
                <Plus className="mr-2 h-4 w-4" /> New Menu
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Create menu</DialogTitle>
                <DialogDescription>Start with a template, then add sections and items.</DialogDescription>
              </DialogHeader>
              <div className="grid gap-4 py-4">
                <div className="grid gap-2">
                  <Label htmlFor="name">Name</Label>
                  <Input
                    id="name"
                    value={newMenu.name}
                    onChange={(e) => setNewMenu((p) => ({ ...p, name: e.target.value }))}
                    placeholder="e.g. Main Menu"
                  />
                </div>

                <div className="grid gap-2">
                  <Label>Orientation</Label>
                  <Select
                    value={newMenu.orientation}
                    onValueChange={(v) => setNewMenu((p) => ({ ...p, orientation: v }))}
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
                    value={newMenu.templateKey}
                    onValueChange={(v) => setNewMenu((p) => ({ ...p, templateKey: v }))}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select template" />
                    </SelectTrigger>
                    <SelectContent position="popper" className="z-[10000]">
                      <SelectItem value="classic">Classic</SelectItem>
                      <SelectItem value="minimal">Minimal</SelectItem>
                      <SelectItem value="neon">Neon</SelectItem>
                      <SelectItem value="qsr">QSR Board (Fast Food)</SelectItem>
                      <SelectItem value="drivethru">Drive-Thru</SelectItem>
                    </SelectContent>
                  </Select>
                  <p className="text-xs text-muted-foreground">Templates: classic, minimal, neon, qsr, drivethru</p>
                </div>

                <div className="grid gap-2">
                  <Label>Layout columns</Label>
                  <Select
                    value={newMenu.layoutColumns}
                    onValueChange={(v) => setNewMenu((p) => ({ ...p, layoutColumns: v as any }))}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Auto" />
                    </SelectTrigger>
                    <SelectContent position="popper" className="z-[10000]">
                      <SelectItem value="auto">Auto (portrait=1, landscape=2)</SelectItem>
                      <SelectItem value="1">1 column</SelectItem>
                      <SelectItem value="2">2 columns</SelectItem>
                      <SelectItem value="3">3 columns</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <DialogFooter>
                <Button onClick={handleCreateMenu} disabled={creating}>
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
            <UtensilsCrossed className="h-5 w-5" />
            Your menus
          </CardTitle>
          <CardDescription>
            {loading ? "Loading..." : `${menus.length} menu${menus.length === 1 ? "" : "s"}`}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="py-8 text-center text-muted-foreground">Loading menus...</div>
          ) : menus.length === 0 ? (
            <div className="py-8 text-center text-muted-foreground">
              No menus yet. Create one to get started.
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Orientation</TableHead>
                  <TableHead>Template</TableHead>
                  <TableHead>Public</TableHead>
                  <TableHead className="w-[60px]"></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {menus.map((m) => (
                  <TableRow key={m.Id} className="cursor-pointer" onClick={() => router.push(`/dashboard/menus/${m.Id}`)}>
                    <TableCell className="font-medium">{m.Name}</TableCell>
                    <TableCell>
                      <Badge variant="outline">{m.Orientation || "Landscape"}</Badge>
                    </TableCell>
                    <TableCell>{m.TemplateKey || "classic"}</TableCell>
                    <TableCell>
                      <a
                        className="inline-flex items-center gap-1 text-sm text-primary hover:underline"
                        href={`${publicBaseUrl}/display/menu/${m.PublicToken}`}
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
                          <DropdownMenuLabel>Menu</DropdownMenuLabel>
                          <DropdownMenuSeparator />
                          <DropdownMenuItem onClick={() => router.push(`/dashboard/menus/${m.Id}`)}>
                            Edit
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            onClick={() => window.open(`${publicBaseUrl}/display/menu/${m.PublicToken}`, "_blank")}
                          >
                            Preview
                          </DropdownMenuItem>
                          <DropdownMenuItem onClick={() => openAssignDialog(m)}>
                            <Monitor className="mr-2 h-4 w-4" /> Assign to Displays
                          </DropdownMenuItem>
                          <DropdownMenuItem onClick={() => handleDuplicateMenu(m.Id)}>
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
            <DialogTitle>Assign menu to displays</DialogTitle>
            <DialogDescription>
              {selectedMenu ? `Select displays that should show “${selectedMenu.Name}”.` : ""}
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
            <Button type="button" onClick={handleSaveAssignments} disabled={assigning || !selectedMenu}>
              {assigning ? "Saving..." : "Save"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
