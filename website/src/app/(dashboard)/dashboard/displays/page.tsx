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
  const [isAddDialogOpen, setIsAddDialogOpen] = useState(false);
  const [newDisplay, setNewDisplay] = useState({ name: "", orientation: "Landscape" });
  const [isSubmitting, setIsSubmitting] = useState(false);

  const fetchDisplays = async () => {
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

      const response = await fetch(`${apiUrl}/organizations/${orgId}/displays`, {
        headers: {
          "X-Auth-Token": token || "",
        },
      });

      if (response.status === 401) {
        router.push("/login");
        return;
      }

      if (!response.ok) throw new Error("Failed to fetch displays");

      const data = await response.json();
      setDisplays(data.value || []);
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

  const handleCreateDisplay = async () => {
    if (!newDisplay.name) {
      toast.error("Display name is required");
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

      const response = await fetch(`${apiUrl}/organizations/${orgId}/displays`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": token || "",
        },
        body: JSON.stringify({
          Name: newDisplay.name,
          Orientation: newDisplay.orientation,
        }),
      });

      if (!response.ok) throw new Error("Failed to create display");

      const createdDisplay = await response.json();
      
      toast.success("Display created successfully");
      setDisplays([...displays, createdDisplay]);
      setIsAddDialogOpen(false);
      setNewDisplay({ name: "", orientation: "Landscape" });
    } catch (error) {
      console.error(error);
      toast.error("Failed to create display");
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
          <Button variant="outline" size="icon" onClick={fetchDisplays}>
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
                <DialogTitle>Add New Display</DialogTitle>
                <DialogDescription>
                  Create a new display endpoint. You will receive a provisioning token to pair your device.
                </DialogDescription>
              </DialogHeader>
              <div className="grid gap-4 py-4">
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
                <Button onClick={handleCreateDisplay} disabled={isSubmitting}>
                  {isSubmitting ? "Creating..." : "Create Display"}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </div>
      </div>

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
