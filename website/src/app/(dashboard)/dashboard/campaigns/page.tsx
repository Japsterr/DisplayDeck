"use client";

import { useEffect, useState } from "react";
import { Plus, Megaphone, MoreVertical, RefreshCw, Calendar, Monitor, Check } from "lucide-react";
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
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Checkbox } from "@/components/ui/checkbox";

interface Campaign {
  Id: number;
  Name: string;
  Orientation: string;
  CreatedAt: string;
  UpdatedAt: string;
}

interface Display {
  Id: number;
  Name: string;
  Orientation: string;
  CurrentStatus: string;
}

export default function CampaignsPage() {
  const router = useRouter();
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [loading, setLoading] = useState(true);
  const [isAddDialogOpen, setIsAddDialogOpen] = useState(false);
  const [newCampaign, setNewCampaign] = useState({ name: "", orientation: "Landscape" });
  const [isSubmitting, setIsSubmitting] = useState(false);

  // New state for details
  const [itemCounts, setItemCounts] = useState<Record<number, number>>({});
  const [activeDisplays, setActiveDisplays] = useState<Record<number, number>>({});
  const [displays, setDisplays] = useState<Display[]>([]);
  
  // Assignment Dialog State
  const [isAssignDialogOpen, setIsAssignDialogOpen] = useState(false);
  const [selectedCampaign, setSelectedCampaign] = useState<Campaign | null>(null);
  const [selectedDisplayIds, setSelectedDisplayIds] = useState<number[]>([]);
  const [assigning, setAssigning] = useState(false);

  const ensureDisplaysLoaded = async (): Promise<Display[]> => {
    if (displays.length) return displays;
    const token = localStorage.getItem("token");
    const userStr = localStorage.getItem("user");
    if (!token || !userStr) return [];
    const user = JSON.parse(userStr);
    const orgId = user.OrganizationId;
    const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";
    const res = await fetch(`${apiUrl}/organizations/${orgId}/displays`, { headers: { "X-Auth-Token": token } });
    const data = await res.json().catch(() => ({ value: [] }));
    const loaded = (data.value || []) as Display[];
    setDisplays(loaded);
    return loaded;
  };

  const fetchDetails = async (currentCampaigns: Campaign[]) => {
    try {
      const token = localStorage.getItem("token");
      const userStr = localStorage.getItem("user");
      if (!token || !userStr) return;
      const user = JSON.parse(userStr);
      const orgId = user.OrganizationId;
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";
      const headers = { "X-Auth-Token": token };

      // 1. Fetch Item Counts
      const itemPromises = currentCampaigns.map(c => 
        fetch(`${apiUrl}/campaigns/${c.Id}/items`, { headers })
          .then(res => res.json())
          .then(data => ({ id: c.Id, count: data.value?.length || 0 }))
          .catch(() => ({ id: c.Id, count: 0 }))
      );

      // 2. Fetch Displays once (for assignment dialog UI)
      const displaysRes = await fetch(`${apiUrl}/organizations/${orgId}/displays`, { headers });
      const displaysData = await displaysRes.json().catch(() => ({ value: [] }));
      const allDisplays = displaysData.value || [];
      setDisplays(allDisplays);

      // 3. Fetch active display counts per campaign using the bulk endpoint
      const bulkCountsPromises = currentCampaigns.map((c) =>
        fetch(`${apiUrl}/campaigns/${c.Id}/display-assignments`, { headers })
          .then((res) => res.json())
          .then((data) => ({ id: c.Id, count: (data.value || []).length as number }))
          .catch(() => ({ id: c.Id, count: 0 }))
      );

      const [itemResults, bulkCounts] = await Promise.all([
        Promise.all(itemPromises),
        Promise.all(bulkCountsPromises),
      ]);

      // Process Item Counts
      const newItemCounts: Record<number, number> = {};
      itemResults.forEach(r => newItemCounts[r.id] = r.count);
      setItemCounts(newItemCounts);

      const newActiveDisplays: Record<number, number> = {};
      bulkCounts.forEach((r) => {
        newActiveDisplays[r.id] = r.count;
      });
      setActiveDisplays(newActiveDisplays);

    } catch (error) {
      console.error("Failed to fetch details", error);
    }
  };

  const fetchCampaigns = async () => {
    try {
      setLoading(true);
      const token = localStorage.getItem("token");
      const userStr = localStorage.getItem("user");

      if (!token || !userStr) {
        router.push("/login");
        return;
      }

      const user = JSON.parse(userStr);
      const orgId = user.OrganizationId;
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";

      const response = await fetch(`${apiUrl}/organizations/${orgId}/campaigns`, {
        headers: {
          "X-Auth-Token": token || "",
        },
      });

      if (response.status === 401) {
        router.push("/login");
        return;
      }

      if (!response.ok) throw new Error("Failed to fetch campaigns");

      const data = await response.json();
      const loadedCampaigns = data.value || [];
      setCampaigns(loadedCampaigns);
      
      // Fetch details in background
      fetchDetails(loadedCampaigns);

    } catch (error) {
      console.error(error);
      toast.error("Failed to load campaigns");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCampaigns();
  }, []);

  const handleCreateCampaign = async () => {
    if (!newCampaign.name) {
      toast.error("Campaign name is required");
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

      const response = await fetch(`${apiUrl}/organizations/${orgId}/campaigns`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": token || "",
        },
        body: JSON.stringify({
          Name: newCampaign.name,
          Orientation: newCampaign.orientation,
        }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.error("Create Campaign Error:", errorText);
        throw new Error(`Failed to create campaign: ${errorText}`);
      }

      const createdCampaign = await response.json();
      
      toast.success("Campaign created successfully");
      setCampaigns([...campaigns, createdCampaign]);
      setIsAddDialogOpen(false);
      setNewCampaign({ name: "", orientation: "Landscape" });
    } catch (error) {
      console.error(error);
      toast.error("Failed to create campaign");
    } finally {
      setIsSubmitting(false);
    }
  };

  const openAssignDialog = async (campaign: Campaign) => {
    setSelectedCampaign(campaign);
    setIsAssignDialogOpen(true);
    setAssigning(true);

    try {
      const token = localStorage.getItem("token");
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";
      const headers = { "X-Auth-Token": token || "" };

      await ensureDisplaysLoaded();

      const res = await fetch(`${apiUrl}/campaigns/${campaign.Id}/display-assignments`, { headers });
      if (!res.ok) throw new Error(await res.text());
      const data = await res.json();
      const assignedDisplayIds = ((data.value || []) as any[]).map((a) => Number(a.DisplayId)).filter((n) => Number.isFinite(n));
      setSelectedDisplayIds(assignedDisplayIds);
    } catch (error) {
      console.error(error);
      toast.error("Failed to load assignments");
    } finally {
      setAssigning(false);
    }
  };

  const handleSaveAssignments = async () => {
    if (!selectedCampaign) return;
    setAssigning(true);

    try {
      const token = localStorage.getItem("token");
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";
      const headers = { 
        "Content-Type": "application/json",
        "X-Auth-Token": token || "" 
      };

      const res = await fetch(`${apiUrl}/campaigns/${selectedCampaign.Id}/display-assignments`, {
        method: "PUT",
        headers,
        body: JSON.stringify({ DisplayIds: selectedDisplayIds, SetPrimary: true }),
      });
      if (!res.ok) throw new Error(await res.text());

      toast.success("Assignments updated");
      setIsAssignDialogOpen(false);
      fetchDetails(campaigns);
    } catch (error) {
      console.error(error);
      toast.error("Failed to save assignments");
    } finally {
      setAssigning(false);
    }
  };

  const handleDeleteCampaign = async (id: number) => {
    if (!confirm("Are you sure you want to delete this campaign?")) return;

    try {
      const token = localStorage.getItem("token");
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";

      const response = await fetch(`${apiUrl}/campaigns/${id}`, {
        method: "DELETE",
        headers: {
          "X-Auth-Token": token || "",
        },
      });

      if (!response.ok) throw new Error("Failed to delete campaign");

      toast.success("Campaign deleted");
      setCampaigns(campaigns.filter(c => c.Id !== id));
    } catch (error) {
      console.error(error);
      toast.error("Failed to delete campaign");
    }
  };

  return (
    <div className="flex flex-col gap-4 p-4 pt-0">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Campaigns</h2>
          <p className="text-muted-foreground">
            Create and manage your digital signage content playlists.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="icon" onClick={fetchCampaigns}>
            <RefreshCw className="h-4 w-4" />
          </Button>
          <Dialog open={isAddDialogOpen} onOpenChange={setIsAddDialogOpen}>
            <DialogTrigger asChild>
              <Button>
                <Plus className="mr-2 h-4 w-4" /> New Campaign
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Create New Campaign</DialogTitle>
                <DialogDescription>
                  Start a new collection of media to display on your screens.
                </DialogDescription>
              </DialogHeader>
              <div className="grid gap-4 py-4">
                <div className="grid grid-cols-4 items-center gap-4">
                  <Label htmlFor="name" className="text-right">
                    Name
                  </Label>
                  <Input
                    id="name"
                    value={newCampaign.name}
                    onChange={(e) => setNewCampaign({ ...newCampaign, name: e.target.value })}
                    className="col-span-3"
                    placeholder="Summer Promotion"
                  />
                </div>
                <div className="grid grid-cols-4 items-center gap-4">
                  <Label htmlFor="orientation" className="text-right">
                    Orientation
                  </Label>
                  <Select
                    value={newCampaign.orientation}
                    onValueChange={(val) => setNewCampaign({ ...newCampaign, orientation: val })}
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
                <Button onClick={handleCreateCampaign} disabled={isSubmitting}>
                  {isSubmitting ? "Creating..." : "Create Campaign"}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>All Campaigns</CardTitle>
          <CardDescription>
            Manage your campaigns and their schedules.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="text-center py-8 text-muted-foreground">Loading campaigns...</div>
          ) : campaigns.length === 0 ? (
            <div className="text-center py-12 border-2 border-dashed rounded-lg">
              <Megaphone className="h-12 w-12 mx-auto text-muted-foreground opacity-50" />
              <h3 className="mt-4 text-lg font-semibold">No campaigns yet</h3>
              <p className="text-muted-foreground mb-4">Create your first campaign to start showing content.</p>
              <Button onClick={() => setIsAddDialogOpen(true)}>Create Campaign</Button>
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Orientation</TableHead>
                  <TableHead>Media Items</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Created</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {campaigns.map((campaign) => (
                  <TableRow key={campaign.Id}>
                    <TableCell className="font-medium">
                      <div className="flex items-center gap-2">
                        <Megaphone className="h-4 w-4 text-muted-foreground" />
                        {campaign.Name}
                      </div>
                    </TableCell>
                    <TableCell>{campaign.Orientation}</TableCell>
                    <TableCell>
                      <Badge variant="secondary">
                        {itemCounts[campaign.Id] || 0} items
                      </Badge>
                    </TableCell>
                    <TableCell>
                      {activeDisplays[campaign.Id] ? (
                        <Badge className="bg-green-600 hover:bg-green-700">
                          Active ({activeDisplays[campaign.Id]})
                        </Badge>
                      ) : (
                        <Badge variant="outline" className="text-muted-foreground">
                          Inactive
                        </Badge>
                      )}
                    </TableCell>
                    <TableCell>
                      {campaign.CreatedAt ? formatDistanceToNow(new Date(campaign.CreatedAt), { addSuffix: true }) : "-"}
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
                          <DropdownMenuItem onClick={() => router.push(`/dashboard/campaigns/${campaign.Id}`)}>
                            Edit Content
                          </DropdownMenuItem>
                          <DropdownMenuItem onClick={() => openAssignDialog(campaign)}>
                            <Monitor className="mr-2 h-4 w-4" /> Assign to Displays
                          </DropdownMenuItem>
                          <DropdownMenuItem onClick={() => toast.info("Schedule feature coming soon")}>
                            <Calendar className="mr-2 h-4 w-4" /> Schedule
                          </DropdownMenuItem>
                          <DropdownMenuSeparator />
                          <DropdownMenuItem className="text-red-600" onClick={() => handleDeleteCampaign(campaign.Id)}>
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

      <Dialog open={isAssignDialogOpen} onOpenChange={setIsAssignDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Assign Campaign</DialogTitle>
            <DialogDescription>
              Select the displays where <strong>{selectedCampaign?.Name}</strong> should be active.
            </DialogDescription>
          </DialogHeader>
          <div className="py-4 space-y-4">
            {assigning && !selectedDisplayIds.length ? (
              <div className="text-center text-sm text-muted-foreground">Loading assignments...</div>
            ) : displays.length === 0 ? (
              <div className="text-center text-sm text-muted-foreground">No displays found.</div>
            ) : (
              displays.filter(d => d.Orientation === selectedCampaign?.Orientation).map(display => (
                <div key={display.Id} className="flex items-center space-x-2 border p-3 rounded-md">
                  <Checkbox 
                    id={`display-${display.Id}`} 
                    checked={selectedDisplayIds.includes(display.Id)}
                    onCheckedChange={(checked) => {
                      if (checked) {
                        setSelectedDisplayIds([...selectedDisplayIds, display.Id]);
                      } else {
                        setSelectedDisplayIds(selectedDisplayIds.filter(id => id !== display.Id));
                      }
                    }}
                  />
                  <Label htmlFor={`display-${display.Id}`} className="flex-1 cursor-pointer">
                    <div className="font-medium">{display.Name}</div>
                    <div className="text-xs text-muted-foreground">{display.Orientation}</div>
                  </Label>
                  {display.CurrentStatus === "Online" && (
                    <Badge variant="outline" className="text-green-600 border-green-600 text-[10px] px-1 py-0">Online</Badge>
                  )}
                </div>
              ))
            )}
            {displays.filter(d => d.Orientation === selectedCampaign?.Orientation).length === 0 && displays.length > 0 && (
               <div className="text-center text-sm text-muted-foreground">
                 No displays match the campaign orientation ({selectedCampaign?.Orientation}).
               </div>
            )}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsAssignDialogOpen(false)}>Cancel</Button>
            <Button onClick={handleSaveAssignments} disabled={assigning}>
              {assigning ? "Saving..." : "Save Assignments"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
