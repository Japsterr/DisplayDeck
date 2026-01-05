"use client";

import { useEffect, useState } from "react";
import { Plus, Calendar, MoreVertical, RefreshCw, Clock, Power } from "lucide-react";
import { formatDistanceToNow } from "date-fns";
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
import { Switch } from "@/components/ui/switch";

interface ContentSchedule {
  Id: number;
  Name: string;
  ContentType: string;
  ContentId: number;
  Priority: number;
  StartDate: string;
  EndDate: string;
  StartTime: string;
  EndTime: string;
  DaysOfWeek: string;
  IsActive: boolean;
}

const DAYS_OF_WEEK = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

export default function SchedulesPage() {
  const [schedules, setSchedules] = useState<ContentSchedule[]>([]);
  const [loading, setLoading] = useState(true);
  const [isAddDialogOpen, setIsAddDialogOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [newSchedule, setNewSchedule] = useState({
    name: "",
    contentType: "campaign",
    contentId: 0,
    priority: 0,
    startDate: "",
    endDate: "",
    startTime: "00:00",
    endTime: "23:59",
    daysOfWeek: "Mon,Tue,Wed,Thu,Fri,Sat,Sun",
    isActive: true,
  });

  // Content options for assignment
  const [campaigns, setCampaigns] = useState<{Id: number; Name: string}[]>([]);
  const [menus, setMenus] = useState<{Id: number; Name: string}[]>([]);
  const [infoboards, setInfoboards] = useState<{Id: number; Name: string}[]>([]);

  const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";

  const fetchSchedules = async () => {
    try {
      setLoading(true);
      const token = localStorage.getItem("token");
      if (!token) return;
      const res = await fetch(`${apiUrl}/content-schedules`, {
        headers: { "X-Auth-Token": token },
      });
      const data = await res.json();
      setSchedules(data.value || []);
    } catch {
      toast.error("Failed to load schedules");
    } finally {
      setLoading(false);
    }
  };

  const fetchContentOptions = async () => {
    try {
      const token = localStorage.getItem("token");
      const userStr = localStorage.getItem("user");
      if (!token || !userStr) return;
      const user = JSON.parse(userStr);
      const orgId = user.OrganizationId;

      const [campaignsRes, menusRes, infoboardsRes] = await Promise.all([
        fetch(`${apiUrl}/organizations/${orgId}/campaigns`, { headers: { "X-Auth-Token": token } }),
        fetch(`${apiUrl}/organizations/${orgId}/menus`, { headers: { "X-Auth-Token": token } }),
        fetch(`${apiUrl}/organizations/${orgId}/infoboards`, { headers: { "X-Auth-Token": token } }),
      ]);

      const [campaignsData, menusData, infoboardsData] = await Promise.all([
        campaignsRes.json().catch(() => ({ value: [] })),
        menusRes.json().catch(() => ({ value: [] })),
        infoboardsRes.json().catch(() => ({ value: [] })),
      ]);

      setCampaigns(campaignsData.value || []);
      setMenus(menusData.value || []);
      setInfoboards(infoboardsData.value || []);
    } catch {
      console.error("Failed to load content options");
    }
  };

  useEffect(() => {
    fetchSchedules();
    fetchContentOptions();
  }, []);

  const handleCreateSchedule = async () => {
    if (!newSchedule.name.trim()) {
      toast.error("Please enter a schedule name");
      return;
    }
    if (!newSchedule.contentId || newSchedule.contentId === 0) {
      toast.error("Please select content to schedule");
      return;
    }
    try {
      setIsSubmitting(true);
      const token = localStorage.getItem("token");
      if (!token) return;

      const res = await fetch(`${apiUrl}/content-schedules`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": token,
        },
        body: JSON.stringify({
          Name: newSchedule.name,
          ContentType: newSchedule.contentType,
          ContentId: newSchedule.contentId,
          Priority: newSchedule.priority,
          StartDate: newSchedule.startDate || new Date().toISOString(),
          EndDate: newSchedule.endDate || new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
          StartTime: newSchedule.startTime,
          EndTime: newSchedule.endTime,
          DaysOfWeek: newSchedule.daysOfWeek,
          IsActive: newSchedule.isActive,
        }),
      });

      if (!res.ok) throw new Error("Failed to create schedule");
      toast.success("Schedule created successfully");
      setIsAddDialogOpen(false);
      setNewSchedule({
        name: "",
        contentType: "campaign",
        contentId: 0,
        priority: 0,
        startDate: "",
        endDate: "",
        startTime: "00:00",
        endTime: "23:59",
        daysOfWeek: "Mon,Tue,Wed,Thu,Fri,Sat,Sun",
        isActive: true,
      });
      fetchSchedules();
    } catch {
      toast.error("Failed to create schedule");
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDeleteSchedule = async (id: number) => {
    try {
      const token = localStorage.getItem("token");
      if (!token) return;
      await fetch(`${apiUrl}/content-schedules/${id}`, {
        method: "DELETE",
        headers: { "X-Auth-Token": token },
      });
      toast.success("Schedule deleted");
      fetchSchedules();
    } catch {
      toast.error("Failed to delete schedule");
    }
  };

  const toggleScheduleActive = async (schedule: ContentSchedule) => {
    try {
      const token = localStorage.getItem("token");
      if (!token) return;
      await fetch(`${apiUrl}/content-schedules/${schedule.Id}`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": token,
        },
        body: JSON.stringify({
          IsActive: !schedule.IsActive,
        }),
      });
      toast.success(`Schedule ${schedule.IsActive ? "deactivated" : "activated"}`);
      fetchSchedules();
    } catch {
      toast.error("Failed to update schedule");
    }
  };

  const getContentName = (schedule: ContentSchedule) => {
    switch (schedule.ContentType) {
      case "campaign":
        return campaigns.find((c) => c.Id === schedule.ContentId)?.Name || `Campaign #${schedule.ContentId}`;
      case "menu":
        return menus.find((m) => m.Id === schedule.ContentId)?.Name || `Menu #${schedule.ContentId}`;
      case "infoboard":
        return infoboards.find((i) => i.Id === schedule.ContentId)?.Name || `InfoBoard #${schedule.ContentId}`;
      default:
        return `#${schedule.ContentId}`;
    }
  };

  const getContentOptions = () => {
    switch (newSchedule.contentType) {
      case "campaign":
        return campaigns;
      case "menu":
        return menus;
      case "infoboard":
        return infoboards;
      default:
        return [];
    }
  };

  return (
    <div className="container mx-auto py-6 px-4">
      <div className="flex justify-between items-center mb-6">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Schedules</h1>
          <p className="text-muted-foreground">Manage content schedules for your displays</p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" size="icon" onClick={fetchSchedules}>
            <RefreshCw className="h-4 w-4" />
          </Button>
          <Button onClick={() => setIsAddDialogOpen(true)}>
            <Plus className="mr-2 h-4 w-4" />
            Add Schedule
          </Button>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center">
            <Calendar className="mr-2 h-5 w-5" />
            Content Schedules
          </CardTitle>
          <CardDescription>
            Schedule when content should play on your displays. Higher priority schedules take precedence.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="flex justify-center p-8">
              <RefreshCw className="h-6 w-6 animate-spin" />
            </div>
          ) : schedules.length === 0 ? (
            <div className="text-center py-8 text-muted-foreground">
              <Calendar className="h-12 w-12 mx-auto mb-4 opacity-50" />
              <p>No schedules configured yet.</p>
              <p className="text-sm">Create a schedule to control when content plays on your displays.</p>
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Content</TableHead>
                  <TableHead>Priority</TableHead>
                  <TableHead>Time</TableHead>
                  <TableHead>Days</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="w-[50px]"></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {schedules.map((schedule) => (
                  <TableRow key={schedule.Id}>
                    <TableCell className="font-medium">{schedule.Name}</TableCell>
                    <TableCell>
                      <Badge variant="outline" className="mr-2">
                        {schedule.ContentType}
                      </Badge>
                      {getContentName(schedule)}
                    </TableCell>
                    <TableCell>
                      <Badge variant="secondary">{schedule.Priority}</Badge>
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center text-sm">
                        <Clock className="h-3 w-3 mr-1" />
                        {schedule.StartTime} - {schedule.EndTime}
                      </div>
                    </TableCell>
                    <TableCell>
                      <div className="flex gap-1">
                        {DAYS_OF_WEEK.map((day) => (
                          <Badge
                            key={day}
                            variant={schedule.DaysOfWeek?.includes(day) ? "default" : "outline"}
                            className="text-xs px-1"
                          >
                            {day.charAt(0)}
                          </Badge>
                        ))}
                      </div>
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-2">
                        <Power className={`h-4 w-4 ${schedule.IsActive ? "text-green-500" : "text-gray-400"}`} />
                        <span className={schedule.IsActive ? "text-green-600" : "text-gray-500"}>
                          {schedule.IsActive ? "Active" : "Inactive"}
                        </span>
                      </div>
                    </TableCell>
                    <TableCell>
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="icon">
                            <MoreVertical className="h-4 w-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuLabel>Actions</DropdownMenuLabel>
                          <DropdownMenuSeparator />
                          <DropdownMenuItem onClick={() => toggleScheduleActive(schedule)}>
                            {schedule.IsActive ? "Deactivate" : "Activate"}
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            className="text-destructive"
                            onClick={() => handleDeleteSchedule(schedule.Id)}
                          >
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

      {/* Add Schedule Dialog */}
      <Dialog open={isAddDialogOpen} onOpenChange={setIsAddDialogOpen}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>Create Schedule</DialogTitle>
            <DialogDescription>
              Configure when this content should be displayed. Higher priority schedules override lower ones.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label htmlFor="name">Schedule Name</Label>
              <Input
                id="name"
                placeholder="e.g., Weekend Promo"
                value={newSchedule.name}
                onChange={(e) => setNewSchedule({ ...newSchedule, name: e.target.value })}
              />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="grid gap-2">
                <Label>Content Type</Label>
                <Select
                  value={newSchedule.contentType}
                  onValueChange={(v) => setNewSchedule({ ...newSchedule, contentType: v, contentId: 0 })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="campaign">Ad Campaign</SelectItem>
                    <SelectItem value="menu">Menu</SelectItem>
                    <SelectItem value="infoboard">Info Board</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="grid gap-2">
                <Label>Content</Label>
                <Select
                  value={String(newSchedule.contentId)}
                  onValueChange={(v) => setNewSchedule({ ...newSchedule, contentId: parseInt(v) })}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select content" />
                  </SelectTrigger>
                  <SelectContent>
                    {getContentOptions().map((item) => (
                      <SelectItem key={item.Id} value={String(item.Id)}>
                        {item.Name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>
            <div className="grid gap-2">
              <Label>Priority (Higher = More Important)</Label>
              <Input
                type="number"
                value={newSchedule.priority}
                onChange={(e) => setNewSchedule({ ...newSchedule, priority: parseInt(e.target.value) || 0 })}
              />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="grid gap-2">
                <Label>Start Time</Label>
                <Input
                  type="time"
                  value={newSchedule.startTime}
                  onChange={(e) => setNewSchedule({ ...newSchedule, startTime: e.target.value })}
                />
              </div>
              <div className="grid gap-2">
                <Label>End Time</Label>
                <Input
                  type="time"
                  value={newSchedule.endTime}
                  onChange={(e) => setNewSchedule({ ...newSchedule, endTime: e.target.value })}
                />
              </div>
            </div>
            <div className="grid gap-2">
              <Label>Days of Week</Label>
              <div className="flex gap-2 flex-wrap">
                {DAYS_OF_WEEK.map((day) => {
                  const isSelected = newSchedule.daysOfWeek.includes(day);
                  return (
                    <Badge
                      key={day}
                      variant={isSelected ? "default" : "outline"}
                      className="cursor-pointer"
                      onClick={() => {
                        const days = newSchedule.daysOfWeek.split(",").filter((d) => d);
                        if (isSelected) {
                          setNewSchedule({
                            ...newSchedule,
                            daysOfWeek: days.filter((d) => d !== day).join(","),
                          });
                        } else {
                          setNewSchedule({
                            ...newSchedule,
                            daysOfWeek: [...days, day].join(","),
                          });
                        }
                      }}
                    >
                      {day}
                    </Badge>
                  );
                })}
              </div>
            </div>
            <div className="flex items-center gap-2">
              <Switch
                checked={newSchedule.isActive}
                onCheckedChange={(v) => setNewSchedule({ ...newSchedule, isActive: v })}
              />
              <Label>Active</Label>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsAddDialogOpen(false)}>
              Cancel
            </Button>
            <Button onClick={handleCreateSchedule} disabled={isSubmitting}>
              {isSubmitting ? "Creating..." : "Create Schedule"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
