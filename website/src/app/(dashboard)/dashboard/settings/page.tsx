"use client";

import { useEffect, useState } from "react";
import { User, Building, Key, Shield } from "lucide-react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Separator } from "@/components/ui/separator";

interface Organization {
  Id: number;
  Name: string;
  CreatedAt: string;
}

interface UserProfile {
  Id: number;
  Email: string;
  Role: string;
}

export default function SettingsPage() {
  const router = useRouter();
  const [org, setOrg] = useState<Organization | null>(null);
  const [user, setUser] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const token = localStorage.getItem("token");
        const userStr = localStorage.getItem("user");

        if (!token || !userStr) {
          router.push("/login");
          return;
        }

        const userData = JSON.parse(userStr);
        setUser(userData);
        
        const orgId = userData.OrganizationId;
        const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";

        const orgRes = await fetch(`${apiUrl}/organizations/${orgId}`, {
          headers: {
            "X-Auth-Token": token || "",
          },
        });

        if (orgRes.ok) {
          const orgData = await orgRes.json();
          setOrg(orgData);
        }
      } catch (error) {
        console.error(error);
        toast.error("Failed to load settings");
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [router]);

  if (loading) {
    return <div className="p-8 text-center">Loading settings...</div>;
  }

  return (
    <div className="flex flex-col gap-4 p-4 pt-0">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Settings</h2>
        <p className="text-muted-foreground">
          Manage your account and organization preferences.
        </p>
      </div>

      <Tabs defaultValue="general" className="space-y-4">
        <TabsList>
          <TabsTrigger value="general">General</TabsTrigger>
          <TabsTrigger value="api-keys">API Keys</TabsTrigger>
        </TabsList>
        
        <TabsContent value="general" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Organization Profile</CardTitle>
              <CardDescription>
                Manage your organization details.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid gap-2">
                <Label htmlFor="orgName">Organization Name</Label>
                <Input id="orgName" value={org?.Name || ""} disabled />
                <p className="text-xs text-muted-foreground">
                  Contact support to change your organization name.
                </p>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>User Profile</CardTitle>
              <CardDescription>
                Your personal account information.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid gap-2">
                <Label htmlFor="email">Email Address</Label>
                <Input id="email" value={user?.Email || ""} disabled />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="role">Role</Label>
                <div className="flex items-center gap-2">
                  <Shield className="h-4 w-4 text-muted-foreground" />
                  <span className="text-sm font-medium">{user?.Role || ""}</span>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="api-keys">
          <Card>
            <CardHeader>
              <CardTitle>API Keys</CardTitle>
              <CardDescription>
                Manage API keys for external integrations.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="flex flex-col items-center justify-center py-8 text-center">
                <Key className="h-10 w-10 text-muted-foreground mb-4" />
                <h3 className="text-lg font-medium">No API Keys</h3>
                <p className="text-sm text-muted-foreground max-w-sm mt-2">
                  You haven&apos;t generated any API keys yet. API keys allow you to access the DisplayDeck API programmatically.
                </p>
                <Button className="mt-4" variant="outline" onClick={() => toast.info("API Key generation coming soon")}>
                  Generate New Key
                </Button>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}
