"use client";

import { useEffect, useMemo, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { toast } from "sonner";
import {
  ArrowLeft,
  Plus,
  Save,
  Trash2,
  ExternalLink,
  Copy,
  RefreshCw,
  Settings2,
} from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Separator } from "@/components/ui/separator";
import { Textarea } from "@/components/ui/textarea";
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
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Switch } from "@/components/ui/switch";

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

interface MenuSection {
  Id: number;
  MenuId: number;
  Name: string;
  DisplayOrder: number;
}

interface MenuItem {
  Id: number;
  MenuSectionId: number;
  Name: string;
  Description: string | null;
  PriceCents: number | null;
  IsAvailable: boolean;
  DisplayOrder: number;
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

function formatCurrencyZarFromCents(priceCents: number) {
  try {
    return new Intl.NumberFormat("en-ZA", { style: "currency", currency: "ZAR" }).format(priceCents / 100);
  } catch {
    // fallback
    return `R ${(priceCents / 100).toFixed(2)}`;
  }
}

export default function MenuEditorPage() {
  const params = useParams();
  const router = useRouter();
  const menuId = parseInt(params.id as string);

  const [menu, setMenu] = useState<Menu | null>(null);
  const [sections, setSections] = useState<MenuSection[]>([]);
  const [itemsBySection, setItemsBySection] = useState<Record<number, MenuItem[]>>({});
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const [savingMenu, setSavingMenu] = useState(false);
  const [themeJsonText, setThemeJsonText] = useState<string>("{}");

  const [isAddSectionOpen, setIsAddSectionOpen] = useState(false);
  const [newSection, setNewSection] = useState({ name: "", displayOrder: 0 });

  const [addItemSectionId, setAddItemSectionId] = useState<number | null>(null);
  const [newItem, setNewItem] = useState({ name: "", description: "", price: "", isAvailable: true, displayOrder: 0 });

  const publicBaseUrl = useMemo(() => {
    if (typeof window === "undefined") return "";
    return window.location.origin;
  }, []);

  const publicUrl = useMemo(() => {
    if (!menu) return "";
    return `${publicBaseUrl}/display/menu/${menu.PublicToken}`;
  }, [menu, publicBaseUrl]);

  const fetchAll = async () => {
    const auth = getAuth();
    if (!auth) {
      router.push("/login");
      return;
    }

    const apiUrl = getApiUrl();
    const headers = { "X-Auth-Token": auth.token };

    const menuRes = await fetch(`${apiUrl}/menus/${menuId}`, { headers });
    if (menuRes.status === 401) {
      router.push("/login");
      return;
    }
    if (!menuRes.ok) throw new Error(await menuRes.text());
    const m = (await menuRes.json()) as Menu;
    if (m.OrganizationId !== auth.orgId) throw new Error("Forbidden");
    setMenu(m);

    const theme = (m.ThemeConfig ?? {}) as ThemeConfig;
    setThemeJsonText(JSON.stringify(theme, null, 2));

    const secRes = await fetch(`${apiUrl}/menus/${menuId}/sections`, { headers });
    if (!secRes.ok) throw new Error(await secRes.text());
    const secData = await secRes.json();
    const secList = (secData.value || []) as MenuSection[];
    setSections(secList);

    const itemPairs = await Promise.all(
      secList.map(async (s) => {
        const res = await fetch(`${apiUrl}/menu-sections/${s.Id}/items`, { headers });
        if (!res.ok) return { sectionId: s.Id, items: [] as MenuItem[] };
        const data = await res.json();
        return { sectionId: s.Id, items: (data.value || []) as MenuItem[] };
      })
    );

    const map: Record<number, MenuItem[]> = {};
    for (const p of itemPairs) map[p.sectionId] = p.items;
    setItemsBySection(map);
  };

  const refresh = async () => {
    try {
      setRefreshing(true);
      await fetchAll();
      toast.success("Refreshed");
    } catch (e) {
      console.error(e);
      toast.error("Failed to refresh menu");
    } finally {
      setRefreshing(false);
    }
  };

  useEffect(() => {
    const run = async () => {
      try {
        setLoading(true);
        await fetchAll();
      } catch (e) {
        console.error(e);
        toast.error("Failed to load menu");
      } finally {
        setLoading(false);
      }
    };

    if (menuId) run();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [menuId]);

  const handleSaveMenu = async () => {
    if (!menu) return;

    let theme: ThemeConfig = {};
    try {
      theme = JSON.parse(themeJsonText || "{}") as ThemeConfig;
    } catch {
      toast.error("ThemeConfig must be valid JSON");
      return;
    }

    try {
      setSavingMenu(true);
      const auth = getAuth();
      if (!auth) return;
      const apiUrl = getApiUrl();

      const res = await fetch(`${apiUrl}/menus/${menu.Id}`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": auth.token,
        },
        body: JSON.stringify({
          Name: menu.Name,
          Orientation: menu.Orientation,
          TemplateKey: menu.TemplateKey,
          ThemeConfig: theme,
        }),
      });

      if (!res.ok) throw new Error(await res.text());
      const updated = (await res.json()) as Menu;
      setMenu(updated);
      toast.success("Menu saved");
    } catch (e) {
      console.error(e);
      toast.error("Failed to save menu");
    } finally {
      setSavingMenu(false);
    }
  };

  const handleDeleteMenu = async () => {
    if (!menu) return;
    if (!confirm("Delete this menu? This cannot be undone.")) return;

    try {
      const auth = getAuth();
      if (!auth) return;
      const apiUrl = getApiUrl();

      const res = await fetch(`${apiUrl}/menus/${menu.Id}`, {
        method: "DELETE",
        headers: { "X-Auth-Token": auth.token },
      });
      if (!res.ok) throw new Error(await res.text());

      toast.success("Menu deleted");
      router.push("/dashboard/menus");
    } catch (e) {
      console.error(e);
      toast.error("Failed to delete menu");
    }
  };

  const handleCreateSection = async () => {
    if (!menu) return;
    if (!newSection.name.trim()) {
      toast.error("Section name is required");
      return;
    }

    try {
      const auth = getAuth();
      if (!auth) return;
      const apiUrl = getApiUrl();

      const order = newSection.displayOrder || (sections.length ? Math.max(...sections.map((s) => s.DisplayOrder)) + 1 : 1);
      const res = await fetch(`${apiUrl}/menus/${menu.Id}/sections`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": auth.token,
        },
        body: JSON.stringify({ Name: newSection.name.trim(), DisplayOrder: order }),
      });
      if (!res.ok) throw new Error(await res.text());
      const created = (await res.json()) as MenuSection;
      setSections((prev) => [...prev, created].sort((a, b) => a.DisplayOrder - b.DisplayOrder));
      setItemsBySection((prev) => ({ ...prev, [created.Id]: [] }));
      setIsAddSectionOpen(false);
      setNewSection({ name: "", displayOrder: 0 });
      toast.success("Section created");
    } catch (e) {
      console.error(e);
      toast.error("Failed to create section");
    }
  };

  const handleUpdateSection = async (section: MenuSection) => {
    try {
      const auth = getAuth();
      if (!auth) return;
      const apiUrl = getApiUrl();

      const res = await fetch(`${apiUrl}/menu-sections/${section.Id}`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": auth.token,
        },
        body: JSON.stringify({ Name: section.Name, DisplayOrder: section.DisplayOrder }),
      });
      if (!res.ok) throw new Error(await res.text());
      const updated = (await res.json()) as MenuSection;

      setSections((prev) =>
        prev
          .map((s) => (s.Id === updated.Id ? updated : s))
          .sort((a, b) => a.DisplayOrder - b.DisplayOrder)
      );
    } catch (e) {
      console.error(e);
      toast.error("Failed to update section");
    }
  };

  const handleDeleteSection = async (sectionId: number) => {
    if (!confirm("Delete this section and all its items?")) return;

    try {
      const auth = getAuth();
      if (!auth) return;
      const apiUrl = getApiUrl();

      const res = await fetch(`${apiUrl}/menu-sections/${sectionId}`, {
        method: "DELETE",
        headers: { "X-Auth-Token": auth.token },
      });
      if (!res.ok) throw new Error(await res.text());

      setSections((prev) => prev.filter((s) => s.Id !== sectionId));
      setItemsBySection((prev) => {
        const copy = { ...prev };
        delete copy[sectionId];
        return copy;
      });
      toast.success("Section deleted");
    } catch (e) {
      console.error(e);
      toast.error("Failed to delete section");
    }
  };

  const openAddItem = (sectionId: number) => {
    const existing = itemsBySection[sectionId] || [];
    const order = existing.length ? Math.max(...existing.map((i) => i.DisplayOrder)) + 1 : 1;
    setNewItem({ name: "", description: "", price: "", isAvailable: true, displayOrder: order });
    setAddItemSectionId(sectionId);
  };

  const handleCreateItem = async () => {
    if (!addItemSectionId) return;
    if (!newItem.name.trim()) {
      toast.error("Item name is required");
      return;
    }

    const priceText = newItem.price.trim();
    const hasPrice = priceText !== "";
    const priceCents = hasPrice ? Math.round(parseFloat(priceText) * 100) : 0;

    if (hasPrice && (!isFinite(priceCents) || priceCents < 0)) {
      toast.error("Invalid price");
      return;
    }

    try {
      const auth = getAuth();
      if (!auth) return;
      const apiUrl = getApiUrl();

      const res = await fetch(`${apiUrl}/menu-sections/${addItemSectionId}/items`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": auth.token,
        },
        body: JSON.stringify({
          Name: newItem.name.trim(),
          Description: newItem.description.trim() || null,
          PriceCents: hasPrice ? priceCents : null,
          IsAvailable: newItem.isAvailable,
          DisplayOrder: newItem.displayOrder,
        }),
      });
      if (!res.ok) throw new Error(await res.text());
      const created = (await res.json()) as MenuItem;

      setItemsBySection((prev) => {
        const list = [...(prev[addItemSectionId] || []), created].sort((a, b) => a.DisplayOrder - b.DisplayOrder);
        return { ...prev, [addItemSectionId]: list };
      });
      setAddItemSectionId(null);
      toast.success("Item created");
    } catch (e) {
      console.error(e);
      let msg = "Failed to create item";
      if (e instanceof Error && e.message) msg = e.message;
      // If the API returned our standard JSONError payload, prefer its `message` field.
      try {
        const parsed = JSON.parse(msg) as { message?: string };
        if (parsed?.message) msg = parsed.message;
      } catch {
        // ignore
      }
      toast.error(msg);
    }
  };

  const handleUpdateItem = async (item: MenuItem) => {
    try {
      const auth = getAuth();
      if (!auth) return;
      const apiUrl = getApiUrl();

      const res = await fetch(`${apiUrl}/menu-items/${item.Id}`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": auth.token,
        },
        body: JSON.stringify({
          Name: item.Name,
          Description: item.Description,
          PriceCents: item.PriceCents,
          IsAvailable: item.IsAvailable,
          DisplayOrder: item.DisplayOrder,
        }),
      });
      if (!res.ok) throw new Error(await res.text());
      const updated = (await res.json()) as MenuItem;

      setItemsBySection((prev) => {
        const list = (prev[updated.MenuSectionId] || []).map((i) => (i.Id === updated.Id ? updated : i)).sort((a, b) => a.DisplayOrder - b.DisplayOrder);
        return { ...prev, [updated.MenuSectionId]: list };
      });
    } catch (e) {
      console.error(e);
      toast.error("Failed to update item");
    }
  };

  const handleDeleteItem = async (item: MenuItem) => {
    if (!confirm("Delete this item?")) return;

    try {
      const auth = getAuth();
      if (!auth) return;
      const apiUrl = getApiUrl();

      const res = await fetch(`${apiUrl}/menu-items/${item.Id}`, {
        method: "DELETE",
        headers: { "X-Auth-Token": auth.token },
      });
      if (!res.ok) throw new Error(await res.text());

      setItemsBySection((prev) => {
        const list = (prev[item.MenuSectionId] || []).filter((i) => i.Id !== item.Id);
        return { ...prev, [item.MenuSectionId]: list };
      });
      toast.success("Item deleted");
    } catch (e) {
      console.error(e);
      toast.error("Failed to delete item");
    }
  };

  const handleCopyPublicUrl = async () => {
    if (!publicUrl) return;
    try {
      await navigator.clipboard.writeText(publicUrl);
      toast.success("Copied public URL");
    } catch {
      toast.error("Failed to copy");
    }
  };

  if (loading) return <div className="p-8 text-center">Loading menu...</div>;
  if (!menu) return <div className="p-8 text-center">Menu not found</div>;

  return (
    <div className="flex flex-col gap-4 p-4 pt-0">
      <div className="flex items-center justify-between gap-4">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="icon" onClick={() => router.back()}>
            <ArrowLeft className="h-4 w-4" />
          </Button>
          <div>
            <h2 className="text-2xl font-bold tracking-tight">{menu.Name}</h2>
            <p className="text-muted-foreground text-sm">
              {menu.Orientation || "Landscape"} • template: {menu.TemplateKey || "classic"}
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <Button variant="outline" size="icon" onClick={refresh} disabled={refreshing}>
            <RefreshCw className="h-4 w-4" />
          </Button>
          <Button variant="outline" onClick={handleCopyPublicUrl} disabled={!publicUrl}>
            <Copy className="mr-2 h-4 w-4" /> Copy public link
          </Button>
          <Button variant="outline" onClick={() => window.open(publicUrl, "_blank")} disabled={!publicUrl}>
            <ExternalLink className="mr-2 h-4 w-4" /> Preview
          </Button>
          <Button onClick={handleSaveMenu} disabled={savingMenu}>
            <Save className="mr-2 h-4 w-4" /> {savingMenu ? "Saving..." : "Save"}
          </Button>
          <Button variant="destructive" onClick={handleDeleteMenu}>
            <Trash2 className="mr-2 h-4 w-4" /> Delete
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <Card className="lg:col-span-1">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Settings2 className="h-5 w-5" />
              Menu settings
            </CardTitle>
            <CardDescription>Basic properties and theme JSON.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid gap-2">
              <Label>Name</Label>
              <Input value={menu.Name} onChange={(e) => setMenu((p) => (p ? { ...p, Name: e.target.value } : p))} />
            </div>

            <div className="grid gap-2">
              <Label>Orientation</Label>
              <Select value={menu.Orientation || "Landscape"} onValueChange={(v) => setMenu((p) => (p ? { ...p, Orientation: v } : p))}>
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
              <Select value={menu.TemplateKey || "classic"} onValueChange={(v) => setMenu((p) => (p ? { ...p, TemplateKey: v } : p))}>
                <SelectTrigger>
                  <SelectValue placeholder="Select template" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="classic">Classic</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <Separator />

            <div className="grid gap-2">
              <Label>ThemeConfig (JSON)</Label>
              <Textarea value={themeJsonText} onChange={(e) => setThemeJsonText(e.target.value)} className="font-mono text-xs min-h-[220px]" />
              <p className="text-xs text-muted-foreground">Example keys: backgroundColor, textColor, accentColor.</p>
            </div>
          </CardContent>
        </Card>

        <Card className="lg:col-span-2">
          <CardHeader className="flex flex-row items-start justify-between gap-4">
            <div>
              <CardTitle>Sections</CardTitle>
              <CardDescription>Build your menu structure: sections and items.</CardDescription>
            </div>
            <Dialog open={isAddSectionOpen} onOpenChange={setIsAddSectionOpen}>
              <DialogTrigger asChild>
                <Button>
                  <Plus className="mr-2 h-4 w-4" /> Add section
                </Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Add section</DialogTitle>
                  <DialogDescription>Sections group items on your menu board.</DialogDescription>
                </DialogHeader>
                <div className="grid gap-4 py-4">
                  <div className="grid gap-2">
                    <Label>Name</Label>
                    <Input value={newSection.name} onChange={(e) => setNewSection((p) => ({ ...p, name: e.target.value }))} placeholder="e.g. Burgers" />
                  </div>
                  <div className="grid gap-2">
                    <Label>Display order</Label>
                    <Input
                      type="number"
                      value={newSection.displayOrder}
                      onChange={(e) => setNewSection((p) => ({ ...p, displayOrder: parseInt(e.target.value) || 0 }))}
                      placeholder="Auto"
                    />
                  </div>
                </div>
                <DialogFooter>
                  <Button onClick={handleCreateSection}>Create</Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
          </CardHeader>

          <CardContent>
            {sections.length === 0 ? (
              <div className="py-10 text-center text-muted-foreground">No sections yet. Add one to start.</div>
            ) : (
              <div className="space-y-6">
                {sections
                  .slice()
                  .sort((a, b) => a.DisplayOrder - b.DisplayOrder)
                  .map((s) => {
                    const sectionItems = (itemsBySection[s.Id] || []).slice().sort((a, b) => a.DisplayOrder - b.DisplayOrder);
                    return (
                      <Card key={s.Id} className="border-dashed">
                        <CardHeader className="pb-2">
                          <div className="flex flex-col md:flex-row md:items-end md:justify-between gap-3">
                            <div className="flex-1 grid grid-cols-1 md:grid-cols-3 gap-3">
                              <div className="grid gap-2 md:col-span-2">
                                <Label>Section name</Label>
                                <Input
                                  value={s.Name}
                                  onChange={(e) =>
                                    setSections((prev) => prev.map((x) => (x.Id === s.Id ? { ...x, Name: e.target.value } : x)))
                                  }
                                  onBlur={() => {
                                    const latest = sections.find((x) => x.Id === s.Id) || s;
                                    handleUpdateSection(latest);
                                  }}
                                />
                              </div>
                              <div className="grid gap-2">
                                <Label>Order</Label>
                                <Input
                                  type="number"
                                  value={s.DisplayOrder}
                                  onChange={(e) =>
                                    setSections((prev) =>
                                      prev.map((x) => (x.Id === s.Id ? { ...x, DisplayOrder: parseInt(e.target.value) || 0 } : x))
                                    )
                                  }
                                  onBlur={() => {
                                    const latest = sections.find((x) => x.Id === s.Id) || s;
                                    handleUpdateSection(latest);
                                  }}
                                />
                              </div>
                            </div>
                            <div className="flex items-center gap-2">
                              <Button variant="outline" onClick={() => openAddItem(s.Id)}>
                                <Plus className="mr-2 h-4 w-4" /> Add item
                              </Button>
                              <Button variant="destructive" onClick={() => handleDeleteSection(s.Id)}>
                                <Trash2 className="mr-2 h-4 w-4" /> Delete
                              </Button>
                            </div>
                          </div>
                        </CardHeader>
                        <CardContent>
                          {sectionItems.length === 0 ? (
                            <div className="py-6 text-center text-muted-foreground">No items in this section yet.</div>
                          ) : (
                            <Table>
                              <TableHeader>
                                <TableRow>
                                  <TableHead>Name</TableHead>
                                  <TableHead>Description</TableHead>
                                  <TableHead className="w-[140px]">Price</TableHead>
                                  <TableHead className="w-[120px]">Available</TableHead>
                                  <TableHead className="w-[120px]">Order</TableHead>
                                  <TableHead className="w-[70px]"></TableHead>
                                </TableRow>
                              </TableHeader>
                              <TableBody>
                                {sectionItems.map((it) => (
                                  <TableRow key={it.Id}>
                                    <TableCell>
                                      <Input
                                        value={it.Name}
                                        onChange={(e) =>
                                          setItemsBySection((prev) => ({
                                            ...prev,
                                            [s.Id]: (prev[s.Id] || []).map((x) => (x.Id === it.Id ? { ...x, Name: e.target.value } : x)),
                                          }))
                                        }
                                        onBlur={() => {
                                          const latest = (itemsBySection[s.Id] || []).find((x) => x.Id === it.Id) || it;
                                          handleUpdateItem(latest);
                                        }}
                                      />
                                    </TableCell>
                                    <TableCell>
                                      <Input
                                        value={it.Description ?? ""}
                                        onChange={(e) =>
                                          setItemsBySection((prev) => ({
                                            ...prev,
                                            [s.Id]: (prev[s.Id] || []).map((x) => (x.Id === it.Id ? { ...x, Description: e.target.value || null } : x)),
                                          }))
                                        }
                                        onBlur={() => {
                                          const latest = (itemsBySection[s.Id] || []).find((x) => x.Id === it.Id) || it;
                                          handleUpdateItem(latest);
                                        }}
                                        placeholder="Optional"
                                      />
                                    </TableCell>
                                    <TableCell>
                                      <Input
                                        value={it.PriceCents != null ? (it.PriceCents / 100).toFixed(2) : ""}
                                        onChange={(e) => {
                                          const txt = e.target.value;
                                          const cents = txt.trim() === "" ? null : Math.round(parseFloat(txt) * 100);
                                          setItemsBySection((prev) => ({
                                            ...prev,
                                            [s.Id]: (prev[s.Id] || []).map((x) => (x.Id === it.Id ? { ...x, PriceCents: isFinite(Number(cents)) ? cents : x.PriceCents } : x)),
                                          }));
                                        }}
                                        onBlur={() => {
                                          const latest = (itemsBySection[s.Id] || []).find((x) => x.Id === it.Id) || it;
                                          handleUpdateItem(latest);
                                        }}
                                        placeholder="e.g. 49.99"
                                      />
                                      {it.PriceCents != null && (
                                        <div className="text-[11px] text-muted-foreground mt-1">
                                          {formatCurrencyZarFromCents(it.PriceCents)}
                                        </div>
                                      )}
                                    </TableCell>
                                    <TableCell>
                                      <div className="flex items-center gap-2">
                                        <Switch
                                          checked={it.IsAvailable}
                                          onCheckedChange={(checked) => {
                                            setItemsBySection((prev) => ({
                                              ...prev,
                                              [s.Id]: (prev[s.Id] || []).map((x) => (x.Id === it.Id ? { ...x, IsAvailable: checked } : x)),
                                            }));
                                            handleUpdateItem({ ...it, IsAvailable: checked });
                                          }}
                                        />
                                      </div>
                                    </TableCell>
                                    <TableCell>
                                      <Input
                                        type="number"
                                        value={it.DisplayOrder}
                                        onChange={(e) =>
                                          setItemsBySection((prev) => ({
                                            ...prev,
                                            [s.Id]: (prev[s.Id] || []).map((x) => (x.Id === it.Id ? { ...x, DisplayOrder: parseInt(e.target.value) || 0 } : x)),
                                          }))
                                        }
                                        onBlur={() => {
                                          const latest = (itemsBySection[s.Id] || []).find((x) => x.Id === it.Id) || it;
                                          handleUpdateItem(latest);
                                        }}
                                      />
                                    </TableCell>
                                    <TableCell>
                                      <Button variant="ghost" size="icon" onClick={() => handleDeleteItem(it)}>
                                        <Trash2 className="h-4 w-4" />
                                      </Button>
                                    </TableCell>
                                  </TableRow>
                                ))}
                              </TableBody>
                            </Table>
                          )}
                        </CardContent>
                      </Card>
                    );
                  })}
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      <Dialog open={addItemSectionId != null} onOpenChange={(open) => !open && setAddItemSectionId(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Add item</DialogTitle>
            <DialogDescription>Add an item to this section.</DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label>Name</Label>
              <Input value={newItem.name} onChange={(e) => setNewItem((p) => ({ ...p, name: e.target.value }))} />
            </div>
            <div className="grid gap-2">
              <Label>Description</Label>
              <Input value={newItem.description} onChange={(e) => setNewItem((p) => ({ ...p, description: e.target.value }))} placeholder="Optional" />
            </div>
            <div className="grid gap-2">
              <Label>Price (ZAR)</Label>
              <Input value={newItem.price} onChange={(e) => setNewItem((p) => ({ ...p, price: e.target.value }))} placeholder="Optional, e.g. 49.99" />
            </div>
            <div className="flex items-center justify-between">
              <div className="grid gap-1">
                <Label>Available</Label>
                <span className="text-xs text-muted-foreground">Hide/unavailable items on the board.</span>
              </div>
              <Switch checked={newItem.isAvailable} onCheckedChange={(v) => setNewItem((p) => ({ ...p, isAvailable: v }))} />
            </div>
            <div className="grid gap-2">
              <Label>Order</Label>
              <Input type="number" value={newItem.displayOrder} onChange={(e) => setNewItem((p) => ({ ...p, displayOrder: parseInt(e.target.value) || 0 }))} />
            </div>
          </div>
          <DialogFooter>
            <Button onClick={handleCreateItem}>Create</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
