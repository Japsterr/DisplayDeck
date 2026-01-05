"use client";

import { useEffect, useState } from "react";
import { Plus, Plug, MoreVertical, RefreshCw, Cloud, Rss, Twitter, Zap, Settings, Power } from "lucide-react";
import { formatDistanceToNow } from "date-fns";
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
import { Card, CardContent, CardDescription, CardHeader, CardTitle, CardFooter } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";

interface Integration {
  Id: number;
  Name: string;
  IntegrationType: string;
  IsActive: boolean;
  LastSyncAt: string;
}

const INTEGRATION_TYPES = [
  { value: "weather", label: "Weather", icon: Cloud, description: "Display current weather and forecasts" },
  { value: "rss", label: "RSS Feed", icon: Rss, description: "Show news and blog content" },
  { value: "social", label: "Social Media", icon: Twitter, description: "Display social media feeds" },
  { value: "api", label: "Custom API", icon: Zap, description: "Connect to any REST API" },
];

export default function IntegrationsPage() {
  const [integrations, setIntegrations] = useState<Integration[]>([]);
  const [loading, setLoading] = useState(true);
  const [isAddDialogOpen, setIsAddDialogOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [newIntegration, setNewIntegration] = useState({
    name: "",
    integrationType: "weather",
    apiKey: "",
    endpoint: "",
  });

  const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";

  const fetchIntegrations = async () => {
    try {
      setLoading(true);
      const token = localStorage.getItem("token");
      if (!token) return;
      const res = await fetch(`${apiUrl}/integrations`, {
        headers: { "X-Auth-Token": token },
      });
      const data = await res.json();
      setIntegrations(data.value || []);
    } catch {
      toast.error("Failed to load integrations");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchIntegrations();
  }, []);

  const handleCreateIntegration = async () => {
    if (!newIntegration.name.trim()) {
      toast.error("Please enter an integration name");
      return;
    }
    try {
      setIsSubmitting(true);
      const token = localStorage.getItem("token");
      if (!token) return;

      const config: Record<string, string> = {};
      if (newIntegration.apiKey) config.apiKey = newIntegration.apiKey;
      if (newIntegration.endpoint) config.endpoint = newIntegration.endpoint;

      const res = await fetch(`${apiUrl}/integrations`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": token,
        },
        body: JSON.stringify({
          Name: newIntegration.name,
          IntegrationType: newIntegration.integrationType,
          Config: config,
        }),
      });

      if (!res.ok) throw new Error("Failed to create integration");
      toast.success("Integration created successfully");
      setIsAddDialogOpen(false);
      setNewIntegration({ name: "", integrationType: "weather", apiKey: "", endpoint: "" });
      fetchIntegrations();
    } catch {
      toast.error("Failed to create integration");
    } finally {
      setIsSubmitting(false);
    }
  };

  const getIntegrationIcon = (type: string) => {
    const integration = INTEGRATION_TYPES.find((i) => i.value === type);
    const IconComponent = integration?.icon || Plug;
    return <IconComponent className="h-6 w-6" />;
  };

  const getIntegrationLabel = (type: string) => {
    return INTEGRATION_TYPES.find((i) => i.value === type)?.label || type;
  };

  return (
    <div className="container mx-auto py-6 px-4">
      <div className="flex justify-between items-center mb-6">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Integrations</h1>
          <p className="text-muted-foreground">Connect external services to enhance your displays</p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" size="icon" onClick={fetchIntegrations}>
            <RefreshCw className="h-4 w-4" />
          </Button>
          <Button onClick={() => setIsAddDialogOpen(true)}>
            <Plus className="mr-2 h-4 w-4" />
            Add Integration
          </Button>
        </div>
      </div>

      {/* Available Integrations */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle>Available Integrations</CardTitle>
          <CardDescription>Connect these services to enhance your digital signage content</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            {INTEGRATION_TYPES.map((type) => {
              const Icon = type.icon;
              return (
                <Card
                  key={type.value}
                  className="cursor-pointer hover:border-primary transition-colors"
                  onClick={() => {
                    setNewIntegration({ ...newIntegration, integrationType: type.value });
                    setIsAddDialogOpen(true);
                  }}
                >
                  <CardContent className="pt-6 text-center">
                    <div className="rounded-full bg-muted p-4 w-fit mx-auto mb-4">
                      <Icon className="h-8 w-8" />
                    </div>
                    <h3 className="font-semibold">{type.label}</h3>
                    <p className="text-sm text-muted-foreground mt-1">{type.description}</p>
                  </CardContent>
                </Card>
              );
            })}
          </div>
        </CardContent>
      </Card>

      {/* Connected Integrations */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center">
            <Plug className="mr-2 h-5 w-5" />
            Connected Integrations
          </CardTitle>
          <CardDescription>
            Manage your active integration connections
          </CardDescription>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="flex justify-center p-8">
              <RefreshCw className="h-6 w-6 animate-spin" />
            </div>
          ) : integrations.length === 0 ? (
            <div className="text-center py-8 text-muted-foreground">
              <Plug className="h-12 w-12 mx-auto mb-4 opacity-50" />
              <p>No integrations connected yet.</p>
              <p className="text-sm">Add an integration to pull in external content.</p>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {integrations.map((integration) => (
                <Card key={integration.Id}>
                  <CardHeader className="pb-2">
                    <div className="flex items-start justify-between">
                      <div className="flex items-center gap-3">
                        <div className="rounded-full bg-muted p-2">
                          {getIntegrationIcon(integration.IntegrationType)}
                        </div>
                        <div>
                          <CardTitle className="text-lg">{integration.Name}</CardTitle>
                          <CardDescription>{getIntegrationLabel(integration.IntegrationType)}</CardDescription>
                        </div>
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
                            <Settings className="mr-2 h-4 w-4" /> Configure
                          </DropdownMenuItem>
                          <DropdownMenuItem>
                            <RefreshCw className="mr-2 h-4 w-4" /> Sync Now
                          </DropdownMenuItem>
                          <DropdownMenuSeparator />
                          <DropdownMenuItem className="text-destructive">
                            Disconnect
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </div>
                  </CardHeader>
                  <CardContent>
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <Power className={`h-4 w-4 ${integration.IsActive ? "text-green-500" : "text-gray-400"}`} />
                        <span className={integration.IsActive ? "text-green-600" : "text-gray-500"}>
                          {integration.IsActive ? "Active" : "Inactive"}
                        </span>
                      </div>
                      <span className="text-sm text-muted-foreground">
                        Last sync: {integration.LastSyncAt ? formatDistanceToNow(new Date(integration.LastSyncAt), { addSuffix: true }) : "Never"}
                      </span>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Add Integration Dialog */}
      <Dialog open={isAddDialogOpen} onOpenChange={setIsAddDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Add Integration</DialogTitle>
            <DialogDescription>
              Connect an external service to pull in dynamic content.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label htmlFor="name">Integration Name</Label>
              <Input
                id="name"
                placeholder="e.g., Office Weather"
                value={newIntegration.name}
                onChange={(e) => setNewIntegration({ ...newIntegration, name: e.target.value })}
              />
            </div>
            <div className="grid gap-2">
              <Label>Type</Label>
              <Select
                value={newIntegration.integrationType}
                onValueChange={(v) => setNewIntegration({ ...newIntegration, integrationType: v })}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {INTEGRATION_TYPES.map((type) => (
                    <SelectItem key={type.value} value={type.value}>
                      {type.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            
            {newIntegration.integrationType === "weather" && (
              <div className="grid gap-2">
                <Label htmlFor="apiKey">API Key (OpenWeatherMap)</Label>
                <Input
                  id="apiKey"
                  type="password"
                  placeholder="Enter your API key"
                  value={newIntegration.apiKey}
                  onChange={(e) => setNewIntegration({ ...newIntegration, apiKey: e.target.value })}
                />
                <p className="text-sm text-muted-foreground">
                  Get a free API key at{" "}
                  <a href="https://openweathermap.org/api" target="_blank" rel="noopener" className="underline">
                    openweathermap.org
                  </a>
                </p>
              </div>
            )}

            {newIntegration.integrationType === "rss" && (
              <div className="grid gap-2">
                <Label htmlFor="endpoint">RSS Feed URL</Label>
                <Input
                  id="endpoint"
                  placeholder="https://example.com/feed.xml"
                  value={newIntegration.endpoint}
                  onChange={(e) => setNewIntegration({ ...newIntegration, endpoint: e.target.value })}
                />
              </div>
            )}

            {newIntegration.integrationType === "api" && (
              <>
                <div className="grid gap-2">
                  <Label htmlFor="endpoint">API Endpoint</Label>
                  <Input
                    id="endpoint"
                    placeholder="https://api.example.com/data"
                    value={newIntegration.endpoint}
                    onChange={(e) => setNewIntegration({ ...newIntegration, endpoint: e.target.value })}
                  />
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="apiKey">API Key (Optional)</Label>
                  <Input
                    id="apiKey"
                    type="password"
                    placeholder="Enter API key if required"
                    value={newIntegration.apiKey}
                    onChange={(e) => setNewIntegration({ ...newIntegration, apiKey: e.target.value })}
                  />
                </div>
              </>
            )}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsAddDialogOpen(false)}>
              Cancel
            </Button>
            <Button onClick={handleCreateIntegration} disabled={isSubmitting}>
              {isSubmitting ? "Connecting..." : "Connect Integration"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
