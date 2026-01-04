"use client";

import { useEffect, useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Monitor, Megaphone, AlertCircle, Activity } from "lucide-react";
import { useRouter } from "next/navigation";
import { formatDistanceToNow, isValid, parseISO } from "date-fns";

const APP_VERSION = process.env.NEXT_PUBLIC_APP_VERSION || "dev";

function safeDistanceToNow(input: string | null | undefined): string {
  if (!input) return "Unknown";
  try {
    // Prefer ISO parsing; fall back to Date parsing.
    const parsed = parseISO(input);
    const date = isValid(parsed) ? parsed : new Date(input);
    if (!isValid(date)) return "Unknown";
    return formatDistanceToNow(date, { addSuffix: true });
  } catch {
    return "Unknown";
  }
}

function asArray<T>(value: unknown): T[] {
  return Array.isArray(value) ? (value as T[]) : [];
}

interface Display {
  Id: number;
  Name: string;
  CurrentStatus: string;
  LastSeen: string;
}

interface Campaign {
  Id: number;
  Name: string;
}

interface AuditLog {
  AuditLogId: number;
  Action: string;
  Details: string;
  CreatedAt: string;
}

export default function DashboardPage() {
  const router = useRouter();
  const [stats, setStats] = useState({
    totalDisplays: 0,
    activeCampaigns: 0,
    offlineDisplays: 0,
    systemStatus: "Checking...",
  });
  const [displayLifecycle, setDisplayLifecycle] = useState<{ paired: number; removed: number; days: number } | null>(null);
  const [displays, setDisplays] = useState<Display[]>([]);
  const [recentActivity, setRecentActivity] = useState<AuditLog[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const token = localStorage.getItem("token");
        const userStr = localStorage.getItem("user");

        if (!token || !userStr) {
          // If no user info, try to fetch it or just redirect
          // For now, if we have a token but no user, we might be in a weird state.
          // But let's assume if token exists we might be okay, but we need OrgId.
          // If we can't get OrgId, we can't fetch data.
          if (!userStr) {
             console.error("No user info found in localStorage");
             // Optional: Fetch user profile if endpoint existed
             router.push("/login");
             return;
          }
          router.push("/login");
          return;
        }

        let user: any;
        try {
          user = JSON.parse(userStr);
        } catch {
          console.error("Invalid user JSON in localStorage");
          router.push("/login");
          return;
        }

        const orgId = user?.OrganizationId;
        if (!orgId) {
          console.error("Missing OrganizationId in user profile");
          router.push("/login");
          return;
        }
        const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";

        const headers = {
          "X-Auth-Token": token || "",
        };

        // Fetch Displays
        const displaysRes = await fetch(`${apiUrl}/organizations/${orgId}/displays`, { headers });
        if (displaysRes.status === 401) {
            router.push("/login");
            return;
        }
        const displaysData = await displaysRes.json();
        const displaysList: Display[] = asArray<Display>(
          (displaysData && (displaysData.value ?? displaysData.Value ?? displaysData.items ?? displaysData.Items))
        );

        // Fetch Campaigns
        const campaignsRes = await fetch(`${apiUrl}/organizations/${orgId}/campaigns`, { headers });
        const campaignsData = await campaignsRes.json();
        const campaignsList: Campaign[] = asArray<Campaign>(
          (campaignsData && (campaignsData.value ?? campaignsData.Value ?? campaignsData.items ?? campaignsData.Items))
        );

        // Fetch Audit Log
        const auditRes = await fetch(`${apiUrl}/organizations/${orgId}/audit-log?limit=5`, { headers });
        const auditData = await auditRes.json();
        const auditList: AuditLog[] = asArray<AuditLog>(
          (auditData && (auditData.Items ?? auditData.items ?? auditData.value ?? auditData.Value))
        );

        // Fetch display lifecycle stats (paired/removed)
        try {
          const lifecycleRes = await fetch(`${apiUrl}/organizations/${orgId}/stats/display-lifecycle?days=30`, { headers });
          if (lifecycleRes.ok) {
            const lifecycleData = await lifecycleRes.json().catch(() => null);
            const counts = lifecycleData?.Counts ?? lifecycleData?.counts;
            const paired = Number(counts?.Paired ?? counts?.paired ?? 0);
            const removed = Number(counts?.Removed ?? counts?.removed ?? 0);
            const days = Number(lifecycleData?.Days ?? lifecycleData?.days ?? 30);
            setDisplayLifecycle({ paired, removed, days });
          } else {
            setDisplayLifecycle(null);
          }
        } catch {
          setDisplayLifecycle(null);
        }

        // Check System Health
        let healthStatus = "Healthy";
        try {
            const healthRes = await fetch(`${apiUrl}/health`);
            if (!healthRes.ok) healthStatus = "Degraded";
        } catch (e) {
            healthStatus = "Offline";
        }

        // Calculate Stats
        const offlineCount = displaysList.filter(d => d?.CurrentStatus === "Offline").length;

        setStats({
          totalDisplays: displaysList.length,
          activeCampaigns: campaignsList.length,
          offlineDisplays: offlineCount,
          systemStatus: healthStatus,
        });

        setDisplays(displaysList.slice(0, 5)); // Show top 5
        setRecentActivity(auditList);

      } catch (error) {
        console.error("Failed to fetch dashboard data", error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [router]);

  if (loading) {
    return <div className="p-8 text-center">Loading dashboard...</div>;
  }

  return (
    <div className="flex flex-1 flex-col gap-4 p-4 pt-0">
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-5">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Displays</CardTitle>
            <Monitor className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.totalDisplays}</div>
            <p className="text-xs text-muted-foreground">
              Registered devices
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active Campaigns</CardTitle>
            <Megaphone className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.activeCampaigns}</div>
            <p className="text-xs text-muted-foreground">
              Total campaigns
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Offline Displays</CardTitle>
            <AlertCircle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.offlineDisplays}</div>
            <p className="text-xs text-muted-foreground">
              Needs attention
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">System Status</CardTitle>
            <Activity className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.systemStatus}</div>
            <p className="text-xs text-muted-foreground">
              API Connection • UI build: {APP_VERSION}
            </p>
          </CardContent>
        </Card>

        <Card
          className="cursor-pointer transition-colors hover:bg-muted/50"
          onClick={() => router.push(`/dashboard/audit-log?action=display.delete&days=${displayLifecycle?.days ?? 30}`)}
        >
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Displays removed ({displayLifecycle?.days ?? 30}d)</CardTitle>
            <Monitor className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{displayLifecycle ? displayLifecycle.removed : "—"}</div>
            <p className="text-xs text-muted-foreground">
              {displayLifecycle
                ? `Paired: ${displayLifecycle.paired} • Removed: ${displayLifecycle.removed}`
                : "Click to view audit log"}
            </p>
          </CardContent>
        </Card>
      </div>
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-7">
        <Card className="col-span-4">
          <CardHeader>
            <CardTitle>Recent Activity</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-8">
              {recentActivity.length === 0 ? (
                <div className="text-center text-muted-foreground py-8">No recent activity</div>
              ) : (
                recentActivity.map((log) => (
                  <div key={log.AuditLogId} className="flex items-center">
                    <div className="ml-4 space-y-1">
                      <p className="text-sm font-medium leading-none">{log.Action}</p>
                      <p className="text-sm text-muted-foreground">
                        {log.Details}
                      </p>
                    </div>
                    <div className="ml-auto font-medium text-xs text-muted-foreground">
                      {safeDistanceToNow(log.CreatedAt)}
                    </div>
                  </div>
                ))
              )}
            </div>
          </CardContent>
        </Card>
        <Card className="col-span-3">
          <CardHeader>
            <CardTitle>Display Status</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-8">
              {displays.length === 0 ? (
                <div className="text-center text-muted-foreground py-8">No displays found</div>
              ) : (
                displays.map((display) => (
                  <div key={display.Id} className="flex items-center">
                    <div className="ml-4 space-y-1">
                      <p className="text-sm font-medium leading-none">{display.Name}</p>
                      <p className="text-sm text-muted-foreground">
                        {display.CurrentStatus} • Last seen {safeDistanceToNow(display.LastSeen)}
                      </p>
                    </div>
                    <div className={`ml-auto font-medium ${display.CurrentStatus === 'Online' ? 'text-green-500' : 'text-red-500'}`}>
                      {display.CurrentStatus}
                    </div>
                  </div>
                ))
              )}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
