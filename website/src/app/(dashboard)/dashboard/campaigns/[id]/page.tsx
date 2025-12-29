"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { ArrowLeft, Plus, Trash2, Save, Clock, GripVertical, Image as ImageIcon, FileVideo, UtensilsCrossed } from "lucide-react";
import { toast } from "sonner";
import { DragDropContext, Droppable, Draggable, DropResult } from "@hello-pangea/dnd";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Separator } from "@/components/ui/separator";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

interface Campaign {
  Id: number;
  Name: string;
  Orientation: string;
}

interface MediaFile {
  Id: number;
  FileName: string;
  FileType: string;
  Orientation: string;
  StorageURL: string;
}

interface Menu {
  Id: number;
  Name: string;
  Orientation: string;
  TemplateKey: string;
  PublicToken: string;
}

interface CampaignItem {
  Id: number;
  ItemType: "media" | "menu";
  MediaFileId: number | null;
  MenuId: number | null;
  DisplayOrder: number;
  Duration: number;
  MediaFile?: MediaFile; // Enriched manually
  Menu?: Menu; // Enriched manually
}

export default function EditCampaignPage() {
  const params = useParams();
  const router = useRouter();
  const campaignId = parseInt(params.id as string);

  const [campaign, setCampaign] = useState<Campaign | null>(null);
  const [items, setItems] = useState<CampaignItem[]>([]);
  const [mediaLibrary, setMediaLibrary] = useState<MediaFile[]>([]);
  const [menus, setMenus] = useState<Menu[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const token = localStorage.getItem("token");
        const userStr = localStorage.getItem("user");
        if (!token || !userStr) {
          router.push("/login");
          return;
        }

        const user = JSON.parse(userStr);
        const orgId = user.OrganizationId;
        const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";
        const headers = { "X-Auth-Token": token || "" };

        // 1. Fetch Campaign Details
        const campaignRes = await fetch(`${apiUrl}/campaigns/${campaignId}`, { headers });
        if (!campaignRes.ok) throw new Error("Failed to fetch campaign");
        const campaignData = await campaignRes.json();
        setCampaign(campaignData);

        // 2. Fetch Media Library
        const mediaRes = await fetch(`${apiUrl}/organizations/${orgId}/media-files`, { headers });
        if (!mediaRes.ok) throw new Error("Failed to fetch media library");
        const mediaData = await mediaRes.json();
        const allMedia: MediaFile[] = mediaData.value || [];
        setMediaLibrary(allMedia);

        // 2b. Fetch Menus
        const menusRes = await fetch(`${apiUrl}/organizations/${orgId}/menus`, { headers });
        if (!menusRes.ok) throw new Error("Failed to fetch menus");
        const menusData = await menusRes.json();
        const allMenus: Menu[] = menusData.value || [];
        setMenus(allMenus);

        // 3. Fetch Campaign Items
        const itemsRes = await fetch(`${apiUrl}/campaigns/${campaignId}/items`, { headers });
        if (!itemsRes.ok) throw new Error("Failed to fetch campaign items");
        const itemsData = await itemsRes.json();
        const rawItems: CampaignItem[] = (itemsData.value || []).map((it: any) => ({
          ...it,
          ItemType: (it.ItemType || "media") as "media" | "menu",
          MediaFileId: it.MediaFileId ?? null,
          MenuId: it.MenuId ?? null,
        }));

        // Enrich items with media/menu details
        const enrichedItems = rawItems
          .map((item) => {
            if (item.ItemType === "menu") {
              return {
                ...item,
                MediaFile: undefined,
                Menu: allMenus.find((m) => m.Id === (item.MenuId || 0)),
              };
            }
            return {
              ...item,
              Menu: undefined,
              MediaFile: allMedia.find((m) => m.Id === (item.MediaFileId || 0)),
            };
          })
          .sort((a, b) => a.DisplayOrder - b.DisplayOrder);

        setItems(enrichedItems);

      } catch (error) {
        console.error(error);
        toast.error("Failed to load campaign data");
      } finally {
        setLoading(false);
      }
    };

    if (campaignId) fetchData();
  }, [campaignId, router]);

  const handleAddItem = async (media: MediaFile) => {
    try {
      const token = localStorage.getItem("token");
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";
      
      const newItemOrder = items.length + 1;
      const defaultDuration = media.FileType.startsWith("video") ? 0 : 10; // 0 for video means play full length usually, or we default to 10s

      const response = await fetch(`${apiUrl}/campaigns/${campaignId}/items`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": token || "",
        },
        body: JSON.stringify({
          ItemType: "media",
          MediaFileId: media.Id,
          DisplayOrder: newItemOrder,
          Duration: defaultDuration
        }),
      });

      if (!response.ok) throw new Error("Failed to add item");

      const createdItem = await response.json();
      const enrichedItem: CampaignItem = {
        ...createdItem,
        ItemType: "media",
        MediaFileId: createdItem.MediaFileId ?? media.Id,
        MenuId: null,
        MediaFile: media,
      };
      
      setItems([...items, enrichedItem]);
      toast.success("Added to playlist");
    } catch (error) {
      console.error(error);
      toast.error("Failed to add item");
    }
  };

  const handleAddMenuItem = async (menu: Menu) => {
    try {
      const token = localStorage.getItem("token");
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";

      const newItemOrder = items.length + 1;
      const defaultDuration = 10;

      const response = await fetch(`${apiUrl}/campaigns/${campaignId}/items`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": token || "",
        },
        body: JSON.stringify({
          ItemType: "menu",
          MenuId: menu.Id,
          DisplayOrder: newItemOrder,
          Duration: defaultDuration,
        }),
      });

      if (!response.ok) throw new Error("Failed to add menu item");

      const createdItem = await response.json();
      const enrichedItem: CampaignItem = {
        ...createdItem,
        ItemType: "menu",
        MediaFileId: null,
        MenuId: createdItem.MenuId ?? menu.Id,
        Menu: menu,
      };

      setItems([...items, enrichedItem]);
      toast.success("Menu added to playlist");
    } catch (error) {
      console.error(error);
      toast.error("Failed to add menu");
    }
  };

  const buildCampaignItemPutBody = (item: CampaignItem, overrides?: Partial<CampaignItem>) => {
    const merged = { ...item, ...(overrides || {}) } as CampaignItem;
    const itemType = merged.ItemType === "menu" ? "menu" : "media";
    return {
      ItemType: itemType,
      MediaFileId: itemType === "media" ? (merged.MediaFileId || 0) : 0,
      MenuId: itemType === "menu" ? (merged.MenuId || 0) : 0,
      DisplayOrder: merged.DisplayOrder,
      Duration: merged.Duration,
    };
  };

  const handleRemoveItem = async (itemId: number) => {
    try {
      const token = localStorage.getItem("token");
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";

      const response = await fetch(`${apiUrl}/campaign-items/${itemId}`, {
        method: "DELETE",
        headers: { "X-Auth-Token": token || "" },
      });

      if (!response.ok) throw new Error("Failed to remove item");

      setItems(items.filter(i => i.Id !== itemId));
      toast.success("Removed from playlist");
    } catch (error) {
      console.error(error);
      toast.error("Failed to remove item");
    }
  };

  const handleUpdateDuration = async (itemId: number, duration: number) => {
    // Optimistic update
    const updatedItems = items.map(i => i.Id === itemId ? { ...i, Duration: duration } : i);
    setItems(updatedItems);

    try {
      const token = localStorage.getItem("token");
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";
      
      const item = items.find(i => i.Id === itemId);
      if (!item) return;

      await fetch(`${apiUrl}/campaign-items/${itemId}`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": token || "",
        },
        body: JSON.stringify(buildCampaignItemPutBody(item, { Duration: duration })),
      });
    } catch (error) {
      console.error(error);
      toast.error("Failed to update duration");
    }
  };

  const onDragEnd = async (result: DropResult) => {
    if (!result.destination) return;

    const reorderedItems = Array.from(items);
    const [removed] = reorderedItems.splice(result.source.index, 1);
    reorderedItems.splice(result.destination.index, 0, removed);

    // Update DisplayOrder locally
    const updatedItems = reorderedItems.map((item, index) => ({
      ...item,
      DisplayOrder: index + 1
    }));

    setItems(updatedItems);

    // Persist new order
    try {
      const token = localStorage.getItem("token");
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";

      // We need to update each item that changed order. 
      // For simplicity in this MVP, we'll update all items in the list.
      // In a real app, we'd batch this or only update affected ones.
      setSaving(true);
      await Promise.all(updatedItems.map(item => 
        fetch(`${apiUrl}/campaign-items/${item.Id}`, {
          method: "PUT",
          headers: {
            "Content-Type": "application/json",
            "X-Auth-Token": token || "",
          },
          body: JSON.stringify(buildCampaignItemPutBody(item)),
        })
      ));
      toast.success("Order saved");
    } catch (error) {
      console.error(error);
      toast.error("Failed to save order");
    } finally {
      setSaving(false);
    }
  };

  if (loading) return <div className="p-8 text-center">Loading campaign...</div>;
  if (!campaign) return <div className="p-8 text-center">Campaign not found</div>;

  const filteredMedia = mediaLibrary.filter(m => m.Orientation === campaign.Orientation);
  const filteredMenus = menus.filter(m => (m.Orientation || campaign.Orientation) === campaign.Orientation);

  return (
    <div className="flex flex-col gap-4 p-4 pt-0 h-[calc(100vh-100px)]">
      <div className="flex items-center gap-4">
        <Button variant="ghost" size="icon" onClick={() => router.back()}>
          <ArrowLeft className="h-4 w-4" />
        </Button>
        <div>
          <h2 className="text-2xl font-bold tracking-tight">{campaign.Name}</h2>
          <p className="text-muted-foreground text-sm">
            {campaign.Orientation} • {items.length} items • Total Duration: {items.reduce((acc, i) => acc + i.Duration, 0)}s
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 h-full">
        {/* Playlist Column */}
        <Card className="md:col-span-2 flex flex-col h-full">
          <CardHeader>
            <CardTitle>Playlist</CardTitle>
            <CardDescription>Drag and drop to reorder content.</CardDescription>
          </CardHeader>
          <CardContent className="flex-1 overflow-hidden">
            <DragDropContext onDragEnd={onDragEnd}>
              <Droppable droppableId="playlist">
                {(provided) => (
                  <div className="h-full overflow-y-auto pr-4">
                    <div
                      {...provided.droppableProps}
                      ref={provided.innerRef}
                      className="space-y-2"
                    >
                      {items.length === 0 && (
                        <div className="text-center py-12 border-2 border-dashed rounded-lg text-muted-foreground">
                          Playlist is empty. Add media or a menu.
                        </div>
                      )}
                      {items.map((item, index) => (
                        <Draggable key={item.Id} draggableId={item.Id.toString()} index={index}>
                          {(provided) => (
                            <div
                              ref={provided.innerRef}
                              {...provided.draggableProps}
                              className="flex items-center gap-4 p-3 bg-card border rounded-lg group"
                            >
                              <div {...provided.dragHandleProps} className="cursor-grab text-muted-foreground hover:text-foreground">
                                <GripVertical className="h-5 w-5" />
                              </div>
                              
                              <div className="h-16 w-24 bg-muted rounded overflow-hidden flex-shrink-0 relative">
                                {item.ItemType === "menu" ? (
                                  <div className="w-full h-full flex items-center justify-center">
                                    <UtensilsCrossed className="h-7 w-7 text-muted-foreground" />
                                  </div>
                                ) : item.MediaFile?.FileType.startsWith("image/") ? (
                                  // eslint-disable-next-line @next/next/no-img-element
                                  <img
                                    src={item.MediaFile.StorageURL}
                                    alt={item.MediaFile.FileName}
                                    className="w-full h-full object-cover"
                                  />
                                ) : (
                                  <div className="w-full h-full flex items-center justify-center">
                                    <FileVideo className="h-8 w-8 text-muted-foreground" />
                                  </div>
                                )}
                                <div className="absolute bottom-0 right-0 bg-black/60 text-white text-[10px] px-1">
                                  {index + 1}
                                </div>
                              </div>

                              <div className="flex-1 min-w-0">
                                <p className="font-medium truncate">
                                  {item.ItemType === "menu" ? item.Menu?.Name || "Menu" : item.MediaFile?.FileName || "Unknown File"}
                                </p>
                                <p className="text-xs text-muted-foreground">
                                  {item.ItemType === "menu" ? "Menu" : item.MediaFile?.FileType}
                                </p>
                              </div>

                              <div className="flex items-center gap-2">
                                <Clock className="h-4 w-4 text-muted-foreground" />
                                <Input 
                                  type="number" 
                                  className="w-20 h-8" 
                                  value={item.Duration}
                                  onChange={(e) => handleUpdateDuration(item.Id, parseInt(e.target.value) || 0)}
                                  min={1}
                                />
                                <span className="text-sm text-muted-foreground">sec</span>
                              </div>

                              <Button 
                                variant="ghost" 
                                size="icon" 
                                className="text-muted-foreground hover:text-red-600"
                                onClick={() => handleRemoveItem(item.Id)}
                              >
                                <Trash2 className="h-4 w-4" />
                              </Button>
                            </div>
                          )}
                        </Draggable>
                      ))}
                      {provided.placeholder}
                    </div>
                  </div>
                )}
              </Droppable>
            </DragDropContext>
          </CardContent>
        </Card>

        {/* Media Library Column */}
        <Card className="flex flex-col h-full">
          <CardHeader>
            <CardTitle>Library</CardTitle>
            <CardDescription>Pick media or menus to add to the playlist.</CardDescription>
          </CardHeader>
          <CardContent className="flex-1 overflow-hidden">
            <Tabs defaultValue="media" className="h-full">
              <TabsList className="w-full">
                <TabsTrigger value="media" className="flex-1">Media</TabsTrigger>
                <TabsTrigger value="menus" className="flex-1">Menus</TabsTrigger>
              </TabsList>

              <TabsContent value="media" className="h-[calc(100%-56px)]">
                <div className="h-full overflow-y-auto pr-4">
                  <div className="grid grid-cols-2 gap-3">
                    {filteredMedia.map((media) => (
                      <div key={media.Id} className="group relative border rounded-lg overflow-hidden bg-muted/20 hover:border-primary transition-colors">
                        <div className="aspect-video flex items-center justify-center bg-black/5">
                          {media.FileType.startsWith("image/") ? (
                            // eslint-disable-next-line @next/next/no-img-element
                            <img
                              src={media.StorageURL}
                              alt={media.FileName}
                              className="w-full h-full object-cover"
                            />
                          ) : (
                            <FileVideo className="h-8 w-8 text-muted-foreground" />
                          )}
                        </div>
                        <div className="p-2">
                          <p className="text-xs font-medium truncate" title={media.FileName}>{media.FileName}</p>
                        </div>
                        <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                          <Button size="sm" onClick={() => handleAddItem(media)}>
                            <Plus className="mr-2 h-4 w-4" /> Add
                          </Button>
                        </div>
                      </div>
                    ))}
                    {filteredMedia.length === 0 && (
                      <div className="col-span-2 text-center py-8 text-muted-foreground text-sm">
                        No compatible media found. Upload {campaign.Orientation.toLowerCase()} media in the Media Library.
                      </div>
                    )}
                  </div>
                </div>
              </TabsContent>

              <TabsContent value="menus" className="h-[calc(100%-56px)]">
                <div className="h-full overflow-y-auto pr-4">
                  <div className="grid grid-cols-1 gap-3">
                    {filteredMenus.map((m) => (
                      <div key={m.Id} className="group relative border rounded-lg overflow-hidden bg-muted/20 hover:border-primary transition-colors">
                        <div className="p-3 flex items-center gap-3">
                          <div className="h-10 w-10 rounded bg-muted flex items-center justify-center">
                            <UtensilsCrossed className="h-5 w-5 text-muted-foreground" />
                          </div>
                          <div className="min-w-0 flex-1">
                            <div className="text-sm font-medium truncate">{m.Name}</div>
                            <div className="text-xs text-muted-foreground">{m.TemplateKey || "classic"}</div>
                          </div>
                          <Badge variant="outline">{m.Orientation}</Badge>
                        </div>
                        <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                          <Button size="sm" onClick={() => handleAddMenuItem(m)}>
                            <Plus className="mr-2 h-4 w-4" /> Add
                          </Button>
                        </div>
                      </div>
                    ))}
                    {filteredMenus.length === 0 && (
                      <div className="text-center py-8 text-muted-foreground text-sm">
                        No {campaign.Orientation.toLowerCase()} menus yet. Create one under Menus.
                      </div>
                    )}
                  </div>
                </div>
              </TabsContent>
            </Tabs>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
