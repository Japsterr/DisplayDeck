"use client";

import { useEffect, useState } from "react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Monitor, Megaphone, AlertCircle, Activity, CheckCircle2, Clock, TrendingUp } from "lucide-react";
import { useRouter } from "next/navigation";
import { formatDistanceToNow, isValid, parseISO } from "date-fns";
import { Progress } from "@/components/ui/progress";
import { Badge } from "@/components/ui/badge";

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
    return <div className="p-8 text-center text-muted-foreground">Loading dashboard...</div>;
  }

  const onlineDisplays = stats.totalDisplays - stats.offlineDisplays;
  const onlineRate = stats.totalDisplays > 0 ? Math.round((onlineDisplays / stats.totalDisplays) * 100) : 0;

  return (
    <div className="flex flex-1 flex-col gap-6 p-4 pt-0">
      {/* Welcome Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Dashboard</h1>
          <p className="text-muted-foreground">Welcome back! Here's an overview of your digital signage network.</p>
        </div>
        <Badge variant="outline" className="text-xs">
          UI build: {APP_VERSION}
        </Badge>
      </div>

      {/* Stats Grid with Enhanced Cards */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card className="bg-gradient-to-br from-blue-500/10 to-blue-600/5 border-blue-500/20">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Displays</CardTitle>
            <Monitor className="h-4 w-4 text-blue-500" />
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{stats.totalDisplays}</div>
            <div className="flex items-center gap-2 mt-2">
              <Progress value={onlineRate} className="h-2 flex-1" />
              <span className="text-xs text-muted-foreground">{onlineRate}% online</span>
            </div>
          </CardContent>
        </Card>

        <Card className="bg-gradient-to-br from-purple-500/10 to-purple-600/5 border-purple-500/20">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active Campaigns</CardTitle>
            <Megaphone className="h-4 w-4 text-purple-500" />
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{stats.activeCampaigns}</div>
            <p className="text-xs text-muted-foreground mt-2">
              <TrendingUp className="inline h-3 w-3 mr-1" />
              Running content loops
            </p>
          </CardContent>
        </Card>

        <Card className={`bg-gradient-to-br ${stats.offlineDisplays > 0 ? 'from-amber-500/10 to-amber-600/5 border-amber-500/20' : 'from-green-500/10 to-green-600/5 border-green-500/20'}`}>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">
              {stats.offlineDisplays > 0 ? 'Offline Displays' : 'All Online'}
            </CardTitle>
            {stats.offlineDisplays > 0 ? (
              <AlertCircle className="h-4 w-4 text-amber-500" />
            ) : (
              <CheckCircle2 className="h-4 w-4 text-green-500" />
            )}
          </CardHeader>
          <CardContent>
            <div className={`text-3xl font-bold ${stats.offlineDisplays > 0 ? 'text-amber-500' : 'text-green-500'}`}>
              {stats.offlineDisplays > 0 ? stats.offlineDisplays : '✓'}
            </div>
            <p className="text-xs text-muted-foreground mt-2">
              {stats.offlineDisplays > 0 ? 'Needs attention' : 'All displays healthy'}
            </p>
          </CardContent>
        </Card>

        <Card className={`bg-gradient-to-br ${stats.systemStatus === 'Healthy' ? 'from-green-500/10 to-green-600/5 border-green-500/20' : 'from-red-500/10 to-red-600/5 border-red-500/20'}`}>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">System Status</CardTitle>
            <Activity className={`h-4 w-4 ${stats.systemStatus === 'Healthy' ? 'text-green-500' : 'text-red-500'}`} />
          </CardHeader>
          <CardContent>
            <div className={`text-3xl font-bold ${stats.systemStatus === 'Healthy' ? 'text-green-500' : 'text-red-500'}`}>
              {stats.systemStatus}
            </div>
            <p className="text-xs text-muted-foreground mt-2">
              API connection active
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Lifecycle Stats */}
      {displayLifecycle && (
        <Card 
          className="cursor-pointer transition-colors hover:bg-muted/50"
          onClick={() => router.push(`/dashboard/audit-log?action=display.delete&days=${displayLifecycle.days}`)}
        >
          <CardHeader className="pb-2">
            <div className="flex items-center justify-between">
              <CardTitle className="text-sm font-medium">Display Lifecycle (Last {displayLifecycle.days} days)</CardTitle>
              <Clock className="h-4 w-4 text-muted-foreground" />
            </div>
          </CardHeader>
          <CardContent>
            <div className="flex items-center gap-8">
              <div>
                <div className="text-2xl font-bold text-green-500">+{displayLifecycle.paired}</div>
                <p className="text-xs text-muted-foreground">Paired</p>
              </div>
              <div>
                <div className="text-2xl font-bold text-red-500">-{displayLifecycle.removed}</div>
                <p className="text-xs text-muted-foreground">Removed</p>
              </div>
              <div>
                <div className="text-2xl font-bold">{displayLifecycle.paired - displayLifecycle.removed}</div>
                <p className="text-xs text-muted-foreground">Net change</p>
              </div>
            </div>
          </CardContent>
        </Card>
      )}

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-7">
        <Card className="col-span-4">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Activity className="h-4 w-4" />
              Recent Activity
            </CardTitle>
            <CardDescription>Latest actions in your organization</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {recentActivity.length === 0 ? (
                <div className="text-center text-muted-foreground py-8">No recent activity</div>
              ) : (
                recentActivity.map((log) => (
                  <div key={log.AuditLogId} className="flex items-start gap-4 p-3 rounded-lg bg-muted/30 hover:bg-muted/50 transition-colors">
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium leading-none">{log.Action}</p>
                      <p className="text-sm text-muted-foreground mt-1 truncate">
                        {log.Details}
                      </p>
                    </div>
                    <Badge variant="outline" className="text-xs shrink-0">
                      {safeDistanceToNow(log.CreatedAt)}
                    </Badge>
                  </div>
                ))
              )}
            </div>
          </CardContent>
        </Card>
        <Card className="col-span-3">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Monitor className="h-4 w-4" />
              Display Status
            </CardTitle>
            <CardDescription>Your registered displays</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {displays.length === 0 ? (
                <div className="text-center text-muted-foreground py-8">No displays found</div>
              ) : (
                displays.map((display) => (
                  <div key={display.Id} className="flex items-center gap-3 p-3 rounded-lg bg-muted/30 hover:bg-muted/50 transition-colors">
                    <div className={`w-2 h-2 rounded-full ${display.CurrentStatus === 'Online' ? 'bg-green-500' : 'bg-red-500'}`} />
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium leading-none truncate">{display.Name}</p>
                      <p className="text-xs text-muted-foreground mt-1">
                        Last seen {safeDistanceToNow(display.LastSeen)}
                      </p>
                    </div>
                    <Badge variant={display.CurrentStatus === 'Online' ? 'default' : 'secondary'} className="shrink-0">
                      {display.CurrentStatus}
                    </Badge>
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
