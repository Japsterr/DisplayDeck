"use client";

import { useCallback, useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { toast } from "sonner";
import {
  ArrowLeft,
  Plus,
  Trash2,
  Save,
  GripVertical,
  Edit2,
  LayoutGrid,
  Building2,
  FileWarning,
  MapPin,
  Image as ImageIcon,
  Settings,
  Eye,
  ExternalLink,
} from "lucide-react";
import { DragDropContext, Droppable, Draggable, DropResult } from "@hello-pangea/dnd";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Separator } from "@/components/ui/separator";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";

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

interface InfoBoardSection {
  Id: number;
  InfoBoardId: number;
  Title: string;
  DisplayOrder: number;
  LayoutType: string;
  BackgroundColor?: string;
  TextColor?: string;
}

interface InfoBoardItem {
  Id: number;
  SectionId: number;
  ItemType: string;
  Title: string;
  Subtitle?: string;
  Description?: string;
  ImageUrl?: string;
  LinkUrl?: string;
  DisplayOrder: number;
  CustomData?: Record<string, unknown>;
}

const BOARD_TYPE_ICONS: Record<string, React.ReactNode> = {
  directory: <Building2 className="h-4 w-4" />,
  hseq: <FileWarning className="h-4 w-4" />,
  notice: <LayoutGrid className="h-4 w-4" />,
  custom: <MapPin className="h-4 w-4" />,
};

const BOARD_TYPE_LABELS: Record<string, string> = {
  directory: "Directory",
  hseq: "HSEQ / Safety",
  notice: "Notice Board",
  custom: "Custom",
};

export default function EditInfoBoardPage() {
  const params = useParams();
  const router = useRouter();
  const boardId = parseInt(params.id as string);

  const [board, setBoard] = useState<InfoBoard | null>(null);
  const [sections, setSections] = useState<InfoBoardSection[]>([]);
  const [items, setItems] = useState<Record<number, InfoBoardItem[]>>({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  // Editing dialogs
  const [isBoardSettingsOpen, setIsBoardSettingsOpen] = useState(false);
  const [isAddSectionOpen, setIsAddSectionOpen] = useState(false);
  const [editingSectionId, setEditingSectionId] = useState<number | null>(null);
  const [isAddItemOpen, setIsAddItemOpen] = useState(false);
  const [addItemSectionId, setAddItemSectionId] = useState<number | null>(null);
  const [editingItem, setEditingItem] = useState<InfoBoardItem | null>(null);

  // Form states
  const [newSection, setNewSection] = useState({
    title: "",
    layoutType: "grid",
    backgroundColor: "",
    textColor: "",
  });
  const [newItem, setNewItem] = useState({
    itemType: "text",
    title: "",
    subtitle: "",
    description: "",
    imageUrl: "",
    linkUrl: "",
  });

  const publicBaseUrl = typeof window !== "undefined" ? window.location.origin : "";

  const fetchBoard = useCallback(async () => {
    try {
      setLoading(true);
      const auth = getAuth();
      if (!auth) {
        router.push("/login");
        return;
      }

      const apiUrl = getApiUrl();
      const headers = { "X-Auth-Token": auth.token };

      // Fetch board details
      const boardRes = await fetch(`${apiUrl}/infoboards/${boardId}`, { headers });
      if (boardRes.status === 401) {
        router.push("/login");
        return;
      }
      if (!boardRes.ok) throw new Error(await boardRes.text());
      const boardData = await boardRes.json();
      setBoard(boardData);

      // Fetch sections
      const sectionsRes = await fetch(`${apiUrl}/infoboards/${boardId}/sections`, { headers });
      if (sectionsRes.ok) {
        const sectionsData = await sectionsRes.json();
        const sectionsList = (sectionsData.value || []) as InfoBoardSection[];
        sectionsList.sort((a, b) => a.DisplayOrder - b.DisplayOrder);
        setSections(sectionsList);

        // Fetch items for each section
        const itemsMap: Record<number, InfoBoardItem[]> = {};
        await Promise.all(
          sectionsList.map(async (section) => {
            try {
              const itemsRes = await fetch(`${apiUrl}/infoboard-sections/${section.Id}/items`, { headers });
              if (itemsRes.ok) {
                const itemsData = await itemsRes.json();
                itemsMap[section.Id] = ((itemsData.value || []) as InfoBoardItem[]).sort(
                  (a, b) => a.DisplayOrder - b.DisplayOrder
                );
              } else {
                itemsMap[section.Id] = [];
              }
            } catch {
              itemsMap[section.Id] = [];
            }
          })
        );
        setItems(itemsMap);
      }
    } catch (e) {
      console.error(e);
      toast.error("Failed to load info board");
    } finally {
      setLoading(false);
    }
  }, [boardId, router]);

  useEffect(() => {
    if (boardId) fetchBoard();
  }, [boardId, fetchBoard]);

  const handleUpdateBoard = async (updates: Partial<InfoBoard>) => {
    if (!board) return;
    try {
      setSaving(true);
      const auth = getAuth();
      if (!auth) return;

      const apiUrl = getApiUrl();
      const res = await fetch(`${apiUrl}/infoboards/${boardId}`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": auth.token,
        },
        body: JSON.stringify({
          Name: updates.Name ?? board.Name,
          BoardType: updates.BoardType ?? board.BoardType,
          Orientation: updates.Orientation ?? board.Orientation,
          TemplateKey: updates.TemplateKey ?? board.TemplateKey,
          ThemeConfig: updates.ThemeConfig ?? board.ThemeConfig ?? {},
        }),
      });

      if (!res.ok) throw new Error(await res.text());
      const updated = await res.json();
      setBoard(updated);
      toast.success("Board updated");
      setIsBoardSettingsOpen(false);
    } catch (e) {
      console.error(e);
      toast.error("Failed to update board");
    } finally {
      setSaving(false);
    }
  };

  const handleAddSection = async () => {
    if (!newSection.title.trim()) {
      toast.error("Section title is required");
      return;
    }

    try {
      setSaving(true);
      const auth = getAuth();
      if (!auth) return;

      const apiUrl = getApiUrl();
      const res = await fetch(`${apiUrl}/infoboards/${boardId}/sections`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": auth.token,
        },
        body: JSON.stringify({
          Title: newSection.title.trim(),
          LayoutType: newSection.layoutType,
          DisplayOrder: sections.length + 1,
          BackgroundColor: newSection.backgroundColor || null,
          TextColor: newSection.textColor || null,
        }),
      });

      if (!res.ok) throw new Error(await res.text());
      const created = (await res.json()) as InfoBoardSection;
      setSections([...sections, created]);
      setItems({ ...items, [created.Id]: [] });
      setNewSection({ title: "", layoutType: "grid", backgroundColor: "", textColor: "" });
      setIsAddSectionOpen(false);
      toast.success("Section added");
    } catch (e) {
      console.error(e);
      toast.error("Failed to add section");
    } finally {
      setSaving(false);
    }
  };

  const handleUpdateSection = async (sectionId: number, updates: Partial<InfoBoardSection>) => {
    const section = sections.find((s) => s.Id === sectionId);
    if (!section) return;

    try {
      setSaving(true);
      const auth = getAuth();
      if (!auth) return;

      const apiUrl = getApiUrl();
      const res = await fetch(`${apiUrl}/infoboard-sections/${sectionId}`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": auth.token,
        },
        body: JSON.stringify({
          Title: updates.Title ?? section.Title,
          LayoutType: updates.LayoutType ?? section.LayoutType,
          DisplayOrder: updates.DisplayOrder ?? section.DisplayOrder,
          BackgroundColor: updates.BackgroundColor ?? section.BackgroundColor,
          TextColor: updates.TextColor ?? section.TextColor,
        }),
      });

      if (!res.ok) throw new Error(await res.text());
      const updated = (await res.json()) as InfoBoardSection;
      setSections(sections.map((s) => (s.Id === sectionId ? updated : s)));
      setEditingSectionId(null);
      toast.success("Section updated");
    } catch (e) {
      console.error(e);
      toast.error("Failed to update section");
    } finally {
      setSaving(false);
    }
  };

  const handleDeleteSection = async (sectionId: number) => {
    try {
      setSaving(true);
      const auth = getAuth();
      if (!auth) return;

      const apiUrl = getApiUrl();
      const res = await fetch(`${apiUrl}/infoboard-sections/${sectionId}`, {
        method: "DELETE",
        headers: { "X-Auth-Token": auth.token },
      });

      if (!res.ok) throw new Error(await res.text());
      setSections(sections.filter((s) => s.Id !== sectionId));
      const newItems = { ...items };
      delete newItems[sectionId];
      setItems(newItems);
      toast.success("Section deleted");
    } catch (e) {
      console.error(e);
      toast.error("Failed to delete section");
    } finally {
      setSaving(false);
    }
  };

  const handleAddItem = async () => {
    if (!newItem.title.trim() || !addItemSectionId) {
      toast.error("Item title is required");
      return;
    }

    try {
      setSaving(true);
      const auth = getAuth();
      if (!auth) return;

      const sectionItems = items[addItemSectionId] || [];
      const apiUrl = getApiUrl();
      const res = await fetch(`${apiUrl}/infoboard-sections/${addItemSectionId}/items`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": auth.token,
        },
        body: JSON.stringify({
          ItemType: newItem.itemType,
          Title: newItem.title.trim(),
          Subtitle: newItem.subtitle || null,
          Description: newItem.description || null,
          ImageUrl: newItem.imageUrl || null,
          LinkUrl: newItem.linkUrl || null,
          DisplayOrder: sectionItems.length + 1,
          CustomData: {},
        }),
      });

      if (!res.ok) throw new Error(await res.text());
      const created = (await res.json()) as InfoBoardItem;
      setItems({ ...items, [addItemSectionId]: [...sectionItems, created] });
      setNewItem({ itemType: "text", title: "", subtitle: "", description: "", imageUrl: "", linkUrl: "" });
      setIsAddItemOpen(false);
      setAddItemSectionId(null);
      toast.success("Item added");
    } catch (e) {
      console.error(e);
      toast.error("Failed to add item");
    } finally {
      setSaving(false);
    }
  };

  const handleUpdateItem = async () => {
    if (!editingItem) return;

    try {
      setSaving(true);
      const auth = getAuth();
      if (!auth) return;

      const apiUrl = getApiUrl();
      const res = await fetch(`${apiUrl}/infoboard-items/${editingItem.Id}`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": auth.token,
        },
        body: JSON.stringify({
          ItemType: editingItem.ItemType,
          Title: editingItem.Title,
          Subtitle: editingItem.Subtitle || null,
          Description: editingItem.Description || null,
          ImageUrl: editingItem.ImageUrl || null,
          LinkUrl: editingItem.LinkUrl || null,
          DisplayOrder: editingItem.DisplayOrder,
          CustomData: editingItem.CustomData || {},
        }),
      });

      if (!res.ok) throw new Error(await res.text());
      const updated = (await res.json()) as InfoBoardItem;

      // Update in state
      const sectionId = editingItem.SectionId;
      const sectionItems = items[sectionId] || [];
      setItems({
        ...items,
        [sectionId]: sectionItems.map((it) => (it.Id === updated.Id ? updated : it)),
      });
      setEditingItem(null);
      toast.success("Item updated");
    } catch (e) {
      console.error(e);
      toast.error("Failed to update item");
    } finally {
      setSaving(false);
    }
  };

  const handleDeleteItem = async (sectionId: number, itemId: number) => {
    try {
      setSaving(true);
      const auth = getAuth();
      if (!auth) return;

      const apiUrl = getApiUrl();
      const res = await fetch(`${apiUrl}/infoboard-items/${itemId}`, {
        method: "DELETE",
        headers: { "X-Auth-Token": auth.token },
      });

      if (!res.ok) throw new Error(await res.text());
      const sectionItems = items[sectionId] || [];
      setItems({
        ...items,
        [sectionId]: sectionItems.filter((it) => it.Id !== itemId),
      });
      toast.success("Item deleted");
    } catch (e) {
      console.error(e);
      toast.error("Failed to delete item");
    } finally {
      setSaving(false);
    }
  };

  const onSectionDragEnd = async (result: DropResult) => {
    if (!result.destination) return;

    const reordered = Array.from(sections);
    const [removed] = reordered.splice(result.source.index, 1);
    reordered.splice(result.destination.index, 0, removed);

    const updated = reordered.map((s, i) => ({ ...s, DisplayOrder: i + 1 }));
    setSections(updated);

    // Persist order
    const auth = getAuth();
    if (!auth) return;
    const apiUrl = getApiUrl();

    try {
      await Promise.all(
        updated.map((s) =>
          fetch(`${apiUrl}/infoboard-sections/${s.Id}`, {
            method: "PUT",
            headers: {
              "Content-Type": "application/json",
              "X-Auth-Token": auth.token,
            },
            body: JSON.stringify({
              Title: s.Title,
              LayoutType: s.LayoutType,
              DisplayOrder: s.DisplayOrder,
              BackgroundColor: s.BackgroundColor,
              TextColor: s.TextColor,
            }),
          })
        )
      );
      toast.success("Section order saved");
    } catch {
      toast.error("Failed to save section order");
    }
  };

  const onItemDragEnd = async (sectionId: number, result: DropResult) => {
    if (!result.destination) return;

    const sectionItems = items[sectionId] || [];
    const reordered = Array.from(sectionItems);
    const [removed] = reordered.splice(result.source.index, 1);
    reordered.splice(result.destination.index, 0, removed);

    const updated = reordered.map((it, i) => ({ ...it, DisplayOrder: i + 1 }));
    setItems({ ...items, [sectionId]: updated });

    // Persist order
    const auth = getAuth();
    if (!auth) return;
    const apiUrl = getApiUrl();

    try {
      await Promise.all(
        updated.map((it) =>
          fetch(`${apiUrl}/infoboard-items/${it.Id}`, {
            method: "PUT",
            headers: {
              "Content-Type": "application/json",
              "X-Auth-Token": auth.token,
            },
            body: JSON.stringify({
              ItemType: it.ItemType,
              Title: it.Title,
              Subtitle: it.Subtitle,
              Description: it.Description,
              ImageUrl: it.ImageUrl,
              LinkUrl: it.LinkUrl,
              DisplayOrder: it.DisplayOrder,
              CustomData: it.CustomData,
            }),
          })
        )
      );
      toast.success("Item order saved");
    } catch {
      toast.error("Failed to save item order");
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center p-8">
        <div className="text-muted-foreground">Loading info board...</div>
      </div>
    );
  }

  if (!board) {
    return (
      <div className="flex flex-col items-center justify-center p-8 gap-4">
        <div className="text-muted-foreground">Info board not found</div>
        <Button variant="outline" onClick={() => router.push("/dashboard/infoboards")}>
          <ArrowLeft className="mr-2 h-4 w-4" /> Back to Info Boards
        </Button>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4 p-4 pt-0">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="icon" onClick={() => router.push("/dashboard/infoboards")}>
            <ArrowLeft className="h-4 w-4" />
          </Button>
          <div>
            <div className="flex items-center gap-2">
              {BOARD_TYPE_ICONS[board.BoardType] || BOARD_TYPE_ICONS.custom}
              <h2 className="text-2xl font-bold tracking-tight">{board.Name}</h2>
            </div>
            <p className="text-muted-foreground text-sm">
              {BOARD_TYPE_LABELS[board.BoardType] || board.BoardType} • {board.Orientation} •{" "}
              {sections.length} section{sections.length !== 1 ? "s" : ""}
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            onClick={() => window.open(`${publicBaseUrl}/display/infoboard/${board.PublicToken}`, "_blank")}
          >
            <Eye className="mr-2 h-4 w-4" /> Preview
          </Button>
          <Button variant="outline" onClick={() => setIsBoardSettingsOpen(true)}>
            <Settings className="mr-2 h-4 w-4" /> Settings
          </Button>
        </div>
      </div>

      <Separator />

      {/* Sections */}
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-semibold">Sections</h3>
        <Button onClick={() => setIsAddSectionOpen(true)}>
          <Plus className="mr-2 h-4 w-4" /> Add Section
        </Button>
      </div>

      <DragDropContext onDragEnd={onSectionDragEnd}>
        <Droppable droppableId="sections">
          {(provided) => (
            <div ref={provided.innerRef} {...provided.droppableProps} className="space-y-4">
              {sections.length === 0 ? (
                <Card>
                  <CardContent className="py-12 text-center text-muted-foreground">
                    No sections yet. Click "Add Section" to get started.
                  </CardContent>
                </Card>
              ) : (
                sections.map((section, index) => (
                  <Draggable key={section.Id} draggableId={section.Id.toString()} index={index}>
                    {(provided) => (
                      <Card ref={provided.innerRef} {...provided.draggableProps}>
                        <CardHeader className="pb-3">
                          <div className="flex items-center gap-3">
                            <div
                              {...provided.dragHandleProps}
                              className="cursor-grab text-muted-foreground hover:text-foreground"
                            >
                              <GripVertical className="h-5 w-5" />
                            </div>
                            <div className="flex-1">
                              <CardTitle className="text-lg">{section.Title}</CardTitle>
                              <CardDescription>
                                Layout: {section.LayoutType} • {(items[section.Id] || []).length} items
                              </CardDescription>
                            </div>
                            <div className="flex items-center gap-2">
                              <Button
                                variant="outline"
                                size="sm"
                                onClick={() => {
                                  setAddItemSectionId(section.Id);
                                  setIsAddItemOpen(true);
                                }}
                              >
                                <Plus className="mr-1 h-3 w-3" /> Item
                              </Button>
                              <Button
                                variant="ghost"
                                size="icon"
                                onClick={() => setEditingSectionId(section.Id)}
                              >
                                <Edit2 className="h-4 w-4" />
                              </Button>
                              <Button
                                variant="ghost"
                                size="icon"
                                className="text-destructive hover:text-destructive"
                                onClick={() => handleDeleteSection(section.Id)}
                              >
                                <Trash2 className="h-4 w-4" />
                              </Button>
                            </div>
                          </div>
                        </CardHeader>
                        <CardContent>
                          <DragDropContext onDragEnd={(r) => onItemDragEnd(section.Id, r)}>
                            <Droppable droppableId={`items-${section.Id}`}>
                              {(itemsProvided) => (
                                <div
                                  ref={itemsProvided.innerRef}
                                  {...itemsProvided.droppableProps}
                                  className="space-y-2"
                                >
                                  {(items[section.Id] || []).length === 0 ? (
                                    <div className="py-6 text-center text-muted-foreground text-sm border-2 border-dashed rounded-lg">
                                      No items in this section
                                    </div>
                                  ) : (
                                    (items[section.Id] || []).map((item, itemIndex) => (
                                      <Draggable
                                        key={item.Id}
                                        draggableId={`item-${item.Id}`}
                                        index={itemIndex}
                                      >
                                        {(itemProvided) => (
                                          <div
                                            ref={itemProvided.innerRef}
                                            {...itemProvided.draggableProps}
                                            className="flex items-center gap-3 p-3 bg-muted/30 rounded-lg border group"
                                          >
                                            <div
                                              {...itemProvided.dragHandleProps}
                                              className="cursor-grab text-muted-foreground hover:text-foreground"
                                            >
                                              <GripVertical className="h-4 w-4" />
                                            </div>
                                            {item.ImageUrl ? (
                                              <div className="h-12 w-12 rounded bg-muted overflow-hidden flex-shrink-0">
                                                {/* eslint-disable-next-line @next/next/no-img-element */}
                                                <img
                                                  src={item.ImageUrl}
                                                  alt={item.Title}
                                                  className="w-full h-full object-cover"
                                                />
                                              </div>
                                            ) : (
                                              <div className="h-12 w-12 rounded bg-muted flex items-center justify-center flex-shrink-0">
                                                <ImageIcon className="h-5 w-5 text-muted-foreground" />
                                              </div>
                                            )}
                                            <div className="flex-1 min-w-0">
                                              <div className="font-medium truncate">{item.Title}</div>
                                              {item.Subtitle && (
                                                <div className="text-sm text-muted-foreground truncate">
                                                  {item.Subtitle}
                                                </div>
                                              )}
                                            </div>
                                            <Badge variant="outline">{item.ItemType}</Badge>
                                            <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                                              <Button
                                                variant="ghost"
                                                size="icon"
                                                onClick={() => setEditingItem(item)}
                                              >
                                                <Edit2 className="h-4 w-4" />
                                              </Button>
                                              <Button
                                                variant="ghost"
                                                size="icon"
                                                className="text-destructive hover:text-destructive"
                                                onClick={() => handleDeleteItem(section.Id, item.Id)}
                                              >
                                                <Trash2 className="h-4 w-4" />
                                              </Button>
                                            </div>
                                          </div>
                                        )}
                                      </Draggable>
                                    ))
                                  )}
                                  {itemsProvided.placeholder}
                                </div>
                              )}
                            </Droppable>
                          </DragDropContext>
                        </CardContent>
                      </Card>
                    )}
                  </Draggable>
                ))
              )}
              {provided.placeholder}
            </div>
          )}
        </Droppable>
      </DragDropContext>

      {/* Board Settings Dialog */}
      <Dialog open={isBoardSettingsOpen} onOpenChange={setIsBoardSettingsOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Board Settings</DialogTitle>
            <DialogDescription>Update the info board properties.</DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label>Name</Label>
              <Input
                value={board.Name}
                onChange={(e) => setBoard({ ...board, Name: e.target.value })}
              />
            </div>
            <div className="grid gap-2">
              <Label>Board Type</Label>
              <Select
                value={board.BoardType}
                onValueChange={(v) => setBoard({ ...board, BoardType: v })}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="directory">Directory</SelectItem>
                  <SelectItem value="hseq">HSEQ / Safety</SelectItem>
                  <SelectItem value="notice">Notice Board</SelectItem>
                  <SelectItem value="custom">Custom</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="grid gap-2">
              <Label>Orientation</Label>
              <Select
                value={board.Orientation}
                onValueChange={(v) => setBoard({ ...board, Orientation: v })}
              >
                <SelectTrigger>
                  <SelectValue />
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
                value={board.TemplateKey}
                onValueChange={(v) => setBoard({ ...board, TemplateKey: v })}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="standard">Standard</SelectItem>
                  <SelectItem value="corporate">Corporate</SelectItem>
                  <SelectItem value="modern">Modern</SelectItem>
                  <SelectItem value="minimal">Minimal</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsBoardSettingsOpen(false)}>
              Cancel
            </Button>
            <Button onClick={() => handleUpdateBoard(board)} disabled={saving}>
              {saving ? "Saving..." : "Save Changes"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Add Section Dialog */}
      <Dialog open={isAddSectionOpen} onOpenChange={setIsAddSectionOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Add Section</DialogTitle>
            <DialogDescription>Create a new section for your info board.</DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label>Title</Label>
              <Input
                value={newSection.title}
                onChange={(e) => setNewSection({ ...newSection, title: e.target.value })}
                placeholder="e.g. Floor Directory, Emergency Contacts"
              />
            </div>
            <div className="grid gap-2">
              <Label>Layout</Label>
              <Select
                value={newSection.layoutType}
                onValueChange={(v) => setNewSection({ ...newSection, layoutType: v })}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="grid">Grid</SelectItem>
                  <SelectItem value="list">List</SelectItem>
                  <SelectItem value="cards">Cards</SelectItem>
                  <SelectItem value="table">Table</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="grid gap-2">
                <Label>Background Color</Label>
                <Input
                  type="color"
                  value={newSection.backgroundColor || "#1a1a1a"}
                  onChange={(e) => setNewSection({ ...newSection, backgroundColor: e.target.value })}
                />
              </div>
              <div className="grid gap-2">
                <Label>Text Color</Label>
                <Input
                  type="color"
                  value={newSection.textColor || "#ffffff"}
                  onChange={(e) => setNewSection({ ...newSection, textColor: e.target.value })}
                />
              </div>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsAddSectionOpen(false)}>
              Cancel
            </Button>
            <Button onClick={handleAddSection} disabled={saving}>
              {saving ? "Adding..." : "Add Section"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Add Item Dialog */}
      <Dialog open={isAddItemOpen} onOpenChange={setIsAddItemOpen}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>Add Item</DialogTitle>
            <DialogDescription>Add a new item to this section.</DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4 max-h-[60vh] overflow-y-auto">
            <div className="grid gap-2">
              <Label>Item Type</Label>
              <Select
                value={newItem.itemType}
                onValueChange={(v) => setNewItem({ ...newItem, itemType: v })}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="text">Text</SelectItem>
                  <SelectItem value="image">Image</SelectItem>
                  <SelectItem value="link">Link</SelectItem>
                  <SelectItem value="contact">Contact</SelectItem>
                  <SelectItem value="location">Location</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="grid gap-2">
              <Label>Title *</Label>
              <Input
                value={newItem.title}
                onChange={(e) => setNewItem({ ...newItem, title: e.target.value })}
                placeholder="e.g. Company Name, Room 101"
              />
            </div>
            <div className="grid gap-2">
              <Label>Subtitle</Label>
              <Input
                value={newItem.subtitle}
                onChange={(e) => setNewItem({ ...newItem, subtitle: e.target.value })}
                placeholder="e.g. Floor 2, Suite 201"
              />
            </div>
            <div className="grid gap-2">
              <Label>Description</Label>
              <Textarea
                value={newItem.description}
                onChange={(e) => setNewItem({ ...newItem, description: e.target.value })}
                placeholder="Additional details..."
                rows={3}
              />
            </div>
            <div className="grid gap-2">
              <Label>Image URL</Label>
              <Input
                value={newItem.imageUrl}
                onChange={(e) => setNewItem({ ...newItem, imageUrl: e.target.value })}
                placeholder="https://..."
              />
            </div>
            <div className="grid gap-2">
              <Label>Link URL</Label>
              <Input
                value={newItem.linkUrl}
                onChange={(e) => setNewItem({ ...newItem, linkUrl: e.target.value })}
                placeholder="https://..."
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsAddItemOpen(false)}>
              Cancel
            </Button>
            <Button onClick={handleAddItem} disabled={saving}>
              {saving ? "Adding..." : "Add Item"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Edit Item Dialog */}
      <Dialog open={!!editingItem} onOpenChange={(o) => !o && setEditingItem(null)}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>Edit Item</DialogTitle>
            <DialogDescription>Update this item's details.</DialogDescription>
          </DialogHeader>
          {editingItem && (
            <div className="grid gap-4 py-4 max-h-[60vh] overflow-y-auto">
              <div className="grid gap-2">
                <Label>Item Type</Label>
                <Select
                  value={editingItem.ItemType}
                  onValueChange={(v) => setEditingItem({ ...editingItem, ItemType: v })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="text">Text</SelectItem>
                    <SelectItem value="image">Image</SelectItem>
                    <SelectItem value="link">Link</SelectItem>
                    <SelectItem value="contact">Contact</SelectItem>
                    <SelectItem value="location">Location</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="grid gap-2">
                <Label>Title *</Label>
                <Input
                  value={editingItem.Title}
                  onChange={(e) => setEditingItem({ ...editingItem, Title: e.target.value })}
                />
              </div>
              <div className="grid gap-2">
                <Label>Subtitle</Label>
                <Input
                  value={editingItem.Subtitle || ""}
                  onChange={(e) => setEditingItem({ ...editingItem, Subtitle: e.target.value })}
                />
              </div>
              <div className="grid gap-2">
                <Label>Description</Label>
                <Textarea
                  value={editingItem.Description || ""}
                  onChange={(e) => setEditingItem({ ...editingItem, Description: e.target.value })}
                  rows={3}
                />
              </div>
              <div className="grid gap-2">
                <Label>Image URL</Label>
                <Input
                  value={editingItem.ImageUrl || ""}
                  onChange={(e) => setEditingItem({ ...editingItem, ImageUrl: e.target.value })}
                />
              </div>
              <div className="grid gap-2">
                <Label>Link URL</Label>
                <Input
                  value={editingItem.LinkUrl || ""}
                  onChange={(e) => setEditingItem({ ...editingItem, LinkUrl: e.target.value })}
                />
              </div>
            </div>
          )}
          <DialogFooter>
            <Button variant="outline" onClick={() => setEditingItem(null)}>
              Cancel
            </Button>
            <Button onClick={handleUpdateItem} disabled={saving}>
              {saving ? "Saving..." : "Save Changes"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Edit Section Sheet */}
      <Sheet open={editingSectionId !== null} onOpenChange={(o) => !o && setEditingSectionId(null)}>
        <SheetContent>
          <SheetHeader>
            <SheetTitle>Edit Section</SheetTitle>
            <SheetDescription>Update the section properties.</SheetDescription>
          </SheetHeader>
          {editingSectionId && (() => {
            const section = sections.find((s) => s.Id === editingSectionId);
            if (!section) return null;
            return (
              <div className="grid gap-4 py-6">
                <div className="grid gap-2">
                  <Label>Title</Label>
                  <Input
                    value={section.Title}
                    onChange={(e) =>
                      setSections(
                        sections.map((s) =>
                          s.Id === editingSectionId ? { ...s, Title: e.target.value } : s
                        )
                      )
                    }
                  />
                </div>
                <div className="grid gap-2">
                  <Label>Layout</Label>
                  <Select
                    value={section.LayoutType}
                    onValueChange={(v) =>
                      setSections(
                        sections.map((s) =>
                          s.Id === editingSectionId ? { ...s, LayoutType: v } : s
                        )
                      )
                    }
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="grid">Grid</SelectItem>
                      <SelectItem value="list">List</SelectItem>
                      <SelectItem value="cards">Cards</SelectItem>
                      <SelectItem value="table">Table</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="grid gap-2">
                    <Label>Background</Label>
                    <Input
                      type="color"
                      value={section.BackgroundColor || "#1a1a1a"}
                      onChange={(e) =>
                        setSections(
                          sections.map((s) =>
                            s.Id === editingSectionId ? { ...s, BackgroundColor: e.target.value } : s
                          )
                        )
                      }
                    />
                  </div>
                  <div className="grid gap-2">
                    <Label>Text Color</Label>
                    <Input
                      type="color"
                      value={section.TextColor || "#ffffff"}
                      onChange={(e) =>
                        setSections(
                          sections.map((s) =>
                            s.Id === editingSectionId ? { ...s, TextColor: e.target.value } : s
                          )
                        )
                      }
                    />
                  </div>
                </div>
                <Button onClick={() => handleUpdateSection(editingSectionId, section)} disabled={saving}>
                  {saving ? "Saving..." : "Save Changes"}
                </Button>
              </div>
            );
          })()}
        </SheetContent>
      </Sheet>
    </div>
  );
}
