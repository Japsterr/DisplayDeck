"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Plus, RefreshCw, UtensilsCrossed, MoreVertical, ExternalLink } from "lucide-react";

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

function getApiUrl() {
  return process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";
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
  const [newMenu, setNewMenu] = useState({ name: "", orientation: "Landscape", templateKey: "classic" });

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
          ThemeConfig: {},
        }),
      });

      if (!res.ok) throw new Error(await res.text());
      const created = (await res.json()) as Menu;
      toast.success("Menu created");
      setIsAddDialogOpen(false);
      setNewMenu({ name: "", orientation: "Landscape", templateKey: "classic" });
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
                    <SelectContent>
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
                    <SelectContent>
                      <SelectItem value="classic">Classic</SelectItem>
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
