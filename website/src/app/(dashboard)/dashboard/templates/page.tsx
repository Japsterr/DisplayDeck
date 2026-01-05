"use client";

import { useEffect, useState } from "react";
import { Plus, FileText, MoreVertical, RefreshCw, Layout, Copy, Eye, Grid, Trash2 } from "lucide-react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
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
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

interface ContentTemplate {
  Id: number;
  Name: string;
  Description: string;
  Category: string;
  ContentType: string;
  PreviewImage: string;
  IsSystemTemplate: boolean;
  UsageCount: number;
}

interface LayoutTemplate {
  Id: number;
  Name: string;
  Description: string;
  ZoneCount: number;
  ZoneConfig: Record<string, unknown>;
  PreviewImage: string;
  IsSystemTemplate: boolean;
}

const CATEGORIES = ["Promotional", "Menu", "Information", "Event", "Social", "Weather", "Custom"];

export default function TemplatesPage() {
  const [contentTemplates, setContentTemplates] = useState<ContentTemplate[]>([]);
  const [layoutTemplates, setLayoutTemplates] = useState<LayoutTemplate[]>([]);
  const [loading, setLoading] = useState(true);
  const [isAddDialogOpen, setIsAddDialogOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [activeTab, setActiveTab] = useState("content");
  
  const [newTemplate, setNewTemplate] = useState({
    name: "",
    description: "",
    category: "Custom",
    contentType: "campaign",
  });

  const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";

  const fetchTemplates = async () => {
    try {
      setLoading(true);
      const token = localStorage.getItem("token");
      if (!token) return;

      const [contentRes, layoutRes] = await Promise.all([
        fetch(`${apiUrl}/templates`, { headers: { "X-Auth-Token": token } }),
        fetch(`${apiUrl}/layout-templates`, { headers: { "X-Auth-Token": token } }),
      ]);

      const [contentData, layoutData] = await Promise.all([
        contentRes.json().catch(() => ({ value: [] })),
        layoutRes.json().catch(() => ({ value: [] })),
      ]);

      setContentTemplates(contentData.value || []);
      setLayoutTemplates(layoutData.value || []);
    } catch {
      toast.error("Failed to load templates");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchTemplates();
  }, []);

  const handleCreateTemplate = async () => {
    if (!newTemplate.name.trim()) {
      toast.error("Please enter a template name");
      return;
    }
    try {
      setIsSubmitting(true);
      const token = localStorage.getItem("token");
      if (!token) return;

      const res = await fetch(`${apiUrl}/templates`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": token,
        },
        body: JSON.stringify({
          Name: newTemplate.name,
          Description: newTemplate.description,
          Category: newTemplate.category,
          ContentType: newTemplate.contentType,
          TemplateData: {},
        }),
      });

      if (!res.ok) throw new Error("Failed to create template");
      toast.success("Template created successfully");
      setIsAddDialogOpen(false);
      setNewTemplate({ name: "", description: "", category: "Custom", contentType: "campaign" });
      fetchTemplates();
    } catch {
      toast.error("Failed to create template");
    } finally {
      setIsSubmitting(false);
    }
  };

  const getCategoryColor = (category: string) => {
    const colors: Record<string, string> = {
      Promotional: "bg-red-100 text-red-800",
      Menu: "bg-orange-100 text-orange-800",
      Information: "bg-blue-100 text-blue-800",
      Event: "bg-purple-100 text-purple-800",
      Social: "bg-pink-100 text-pink-800",
      Weather: "bg-cyan-100 text-cyan-800",
      Custom: "bg-gray-100 text-gray-800",
    };
    return colors[category] || colors.Custom;
  };

  const handleDeleteTemplate = async (id: number, isSystem: boolean) => {
    if (isSystem) {
      toast.error("Cannot delete system templates");
      return;
    }
    if (!confirm("Are you sure you want to delete this template?")) return;
    try {
      const token = localStorage.getItem("token");
      if (!token) return;
      const res = await fetch(`${apiUrl}/templates/${id}`, {
        method: "DELETE",
        headers: { "X-Auth-Token": token },
      });
      if (!res.ok) {
        const data = await res.json().catch(() => null);
        throw new Error(data?.Error || "Failed to delete template");
      }
      toast.success("Template deleted");
      fetchTemplates();
    } catch (err: any) {
      toast.error(err.message || "Failed to delete template");
    }
  };

  return (
    <div className="container mx-auto py-6 px-4">
      <div className="flex justify-between items-center mb-6">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Templates</h1>
          <p className="text-muted-foreground">Browse and create content and layout templates</p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" size="icon" onClick={fetchTemplates}>
            <RefreshCw className="h-4 w-4" />
          </Button>
          <Button onClick={() => setIsAddDialogOpen(true)}>
            <Plus className="mr-2 h-4 w-4" />
            Create Template
          </Button>
        </div>
      </div>

      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <TabsList className="mb-4">
          <TabsTrigger value="content" className="flex items-center gap-2">
            <FileText className="h-4 w-4" />
            Content Templates
          </TabsTrigger>
          <TabsTrigger value="layouts" className="flex items-center gap-2">
            <Layout className="h-4 w-4" />
            Layout Templates
          </TabsTrigger>
        </TabsList>

        <TabsContent value="content">
          {loading ? (
            <div className="flex justify-center p-8">
              <RefreshCw className="h-6 w-6 animate-spin" />
            </div>
          ) : contentTemplates.length === 0 ? (
            <Card>
              <CardContent className="text-center py-12">
                <FileText className="h-12 w-12 mx-auto mb-4 opacity-50" />
                <p className="text-muted-foreground">No content templates yet.</p>
                <p className="text-sm text-muted-foreground">Create reusable templates for your content.</p>
              </CardContent>
            </Card>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {contentTemplates.map((template) => (
                <Card key={template.Id} className="overflow-hidden">
                  <div className="aspect-video bg-muted flex items-center justify-center relative">
                    {template.PreviewImage ? (
                      <img
                        src={template.PreviewImage}
                        alt={template.Name}
                        className="w-full h-full object-cover"
                      />
                    ) : (
                      <FileText className="h-12 w-12 text-muted-foreground" />
                    )}
                    {template.IsSystemTemplate && (
                      <Badge className="absolute top-2 right-2" variant="secondary">
                        System
                      </Badge>
                    )}
                  </div>
                  <CardHeader className="pb-2">
                    <div className="flex items-start justify-between">
                      <div>
                        <CardTitle className="text-lg">{template.Name}</CardTitle>
                        <CardDescription>{template.Description || "No description"}</CardDescription>
                      </div>
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="icon">
                            <MoreVertical className="h-4 w-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuLabel>Actions</DropdownMenuLabel>
                          <DropdownMenuSeparator />
                          <DropdownMenuItem>
                            <Eye className="mr-2 h-4 w-4" /> Preview
                          </DropdownMenuItem>
                          <DropdownMenuItem>
                            <Copy className="mr-2 h-4 w-4" /> Duplicate
                          </DropdownMenuItem>
                          {!template.IsSystemTemplate && (
                            <>
                              <DropdownMenuSeparator />
                              <DropdownMenuItem
                                className="text-red-600"
                                onClick={() => handleDeleteTemplate(template.Id, template.IsSystemTemplate)}
                              >
                                <Trash2 className="mr-2 h-4 w-4" /> Delete
                              </DropdownMenuItem>
                            </>
                          )}
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </div>
                  </CardHeader>
                  <CardContent>
                    <div className="flex items-center gap-2">
                      <Badge className={getCategoryColor(template.Category)}>{template.Category}</Badge>
                      <Badge variant="outline">{template.ContentType}</Badge>
                      <span className="text-sm text-muted-foreground ml-auto">
                        Used {template.UsageCount} times
                      </span>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          )}
        </TabsContent>

        <TabsContent value="layouts">
          {loading ? (
            <div className="flex justify-center p-8">
              <RefreshCw className="h-6 w-6 animate-spin" />
            </div>
          ) : layoutTemplates.length === 0 ? (
            <Card>
              <CardContent className="text-center py-12">
                <Layout className="h-12 w-12 mx-auto mb-4 opacity-50" />
                <p className="text-muted-foreground">No layout templates yet.</p>
                <p className="text-sm text-muted-foreground">Layout templates define multi-zone screen configurations.</p>
              </CardContent>
            </Card>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {layoutTemplates.map((template) => (
                <Card key={template.Id} className="overflow-hidden">
                  <div className="aspect-video bg-muted flex items-center justify-center relative p-4">
                    {template.PreviewImage ? (
                      <img
                        src={template.PreviewImage}
                        alt={template.Name}
                        className="w-full h-full object-contain"
                      />
                    ) : (
                      <div className="w-full h-full border-2 border-dashed border-muted-foreground/30 rounded flex items-center justify-center">
                        <Grid className="h-8 w-8 text-muted-foreground" />
                      </div>
                    )}
                    {template.IsSystemTemplate && (
                      <Badge className="absolute top-2 right-2" variant="secondary">
                        System
                      </Badge>
                    )}
                  </div>
                  <CardHeader className="pb-2">
                    <div className="flex items-start justify-between">
                      <div>
                        <CardTitle className="text-lg">{template.Name}</CardTitle>
                        <CardDescription>{template.Description || "No description"}</CardDescription>
                      </div>
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="icon">
                            <MoreVertical className="h-4 w-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuLabel>Actions</DropdownMenuLabel>
                          <DropdownMenuSeparator />
                          <DropdownMenuItem>
                            <Eye className="mr-2 h-4 w-4" /> Preview
                          </DropdownMenuItem>
                          <DropdownMenuItem>
                            <Copy className="mr-2 h-4 w-4" /> Duplicate
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </div>
                  </CardHeader>
                  <CardContent>
                    <div className="flex items-center gap-2">
                      <Badge variant="default">{template.ZoneCount} zones</Badge>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          )}
        </TabsContent>
      </Tabs>

      {/* Add Template Dialog */}
      <Dialog open={isAddDialogOpen} onOpenChange={setIsAddDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Create Template</DialogTitle>
            <DialogDescription>
              Create a reusable template for your content.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label htmlFor="name">Template Name</Label>
              <Input
                id="name"
                placeholder="e.g., Holiday Sale Banner"
                value={newTemplate.name}
                onChange={(e) => setNewTemplate({ ...newTemplate, name: e.target.value })}
              />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="description">Description</Label>
              <Textarea
                id="description"
                placeholder="Describe what this template is for..."
                value={newTemplate.description}
                onChange={(e) => setNewTemplate({ ...newTemplate, description: e.target.value })}
              />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="grid gap-2">
                <Label>Category</Label>
                <Select
                  value={newTemplate.category}
                  onValueChange={(v) => setNewTemplate({ ...newTemplate, category: v })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {CATEGORIES.map((cat) => (
                      <SelectItem key={cat} value={cat}>
                        {cat}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="grid gap-2">
                <Label>Content Type</Label>
                <Select
                  value={newTemplate.contentType}
                  onValueChange={(v) => setNewTemplate({ ...newTemplate, contentType: v })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="campaign">Campaign</SelectItem>
                    <SelectItem value="menu">Menu</SelectItem>
                    <SelectItem value="infoboard">Info Board</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsAddDialogOpen(false)}>
              Cancel
            </Button>
            <Button onClick={handleCreateTemplate} disabled={isSubmitting}>
              {isSubmitting ? "Creating..." : "Create Template"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
