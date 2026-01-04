"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { formatDistanceToNow, isValid, parseISO } from "date-fns";

interface AuditLog {
  AuditLogId: number;
  CreatedAt: string;
  UserId: number | null;
  Action: string;
  ObjectType: string;
  ObjectId: string;
  Details: string;
  RequestId: string;
  IpAddress: string;
  UserAgent: string;
}

function asArray<T>(value: unknown): T[] {
  return Array.isArray(value) ? (value as T[]) : [];
}

function safeDistanceToNow(input: string | null | undefined): string {
  if (!input) return "Unknown";
  try {
    const parsed = parseISO(input);
    const date = isValid(parsed) ? parsed : new Date(input);
    if (!isValid(date)) return "Unknown";
    return formatDistanceToNow(date, { addSuffix: true });
  } catch {
    return "Unknown";
  }
}

function tryFormatJson(input: string): string {
  const trimmed = (input || "").trim();
  if (!trimmed) return "";
  if (!(trimmed.startsWith("{") || trimmed.startsWith("["))) return input;
  try {
    return JSON.stringify(JSON.parse(trimmed), null, 2);
  } catch {
    return input;
  }
}

export default function AuditLogClient() {
  const router = useRouter();
  const searchParams = useSearchParams();

  const initialAction = searchParams.get("action") ?? "";
  const initialDays = Number(searchParams.get("days") ?? "30");

  const [actionFilter, setActionFilter] = useState(initialAction);
  const [days, setDays] = useState<number>(Number.isFinite(initialDays) && initialDays > 0 ? initialDays : 30);

  const [rows, setRows] = useState<AuditLog[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const getAuthContext = () => {
    const token = localStorage.getItem("token");
    const userStr = localStorage.getItem("user");
    if (!token || !userStr) return null;
    const user = JSON.parse(userStr);
    const orgId = user.OrganizationId;
    const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";
    return { token, orgId, apiUrl };
  };

  const cutoffDate = useMemo(() => {
    const safeDays = Number.isFinite(days) && days > 0 ? Math.min(days, 365) : 30;
    return new Date(Date.now() - safeDays * 24 * 60 * 60 * 1000);
  }, [days]);

  const filtered = useMemo(() => {
    const action = actionFilter.trim();
    if (!action) return rows;
    return rows.filter((r) => r.Action === action);
  }, [rows, actionFilter]);

  const applyFiltersToUrl = (nextAction: string, nextDays: number) => {
    const params = new URLSearchParams();
    if (nextAction.trim()) params.set("action", nextAction.trim());
    params.set("days", String(nextDays));
    router.push(`/dashboard/audit-log?${params.toString()}`);
  };

  const fetchAudit = async () => {
    const auth = getAuthContext();
    if (!auth) {
      router.push("/login");
      return;
    }

    try {
      setLoading(true);
      setError(null);

      const perPage = 200;
      const hardMax = 1000;

      const out: AuditLog[] = [];
      let beforeId: number | null = null;
      let reachedCutoff = false;

      while (out.length < hardMax && !reachedCutoff) {
        const url = new URL(`${auth.apiUrl}/organizations/${auth.orgId}/audit-log`);
        url.searchParams.set("limit", String(perPage));
        if (beforeId && beforeId > 0) url.searchParams.set("beforeId", String(beforeId));

        const res = await fetch(url.toString(), {
          headers: {
            "X-Auth-Token": auth.token,
          },
        });

        if (res.status === 401) {
          router.push("/login");
          return;
        }

        if (!res.ok) {
          throw new Error(`Failed to fetch audit log (${res.status})`);
        }

        const payload = await res.json().catch(() => null);
        const items: AuditLog[] = asArray<AuditLog>(payload?.Items ?? payload?.items ?? payload?.Value ?? payload?.value);
        const nextBeforeId = Number(payload?.NextBeforeId ?? payload?.nextBeforeId ?? 0);

        if (items.length === 0) break;

        for (const item of items) {
          const created = parseISO(item.CreatedAt);
          const createdAt = isValid(created) ? created : new Date(item.CreatedAt);
          if (!isValid(createdAt) || createdAt >= cutoffDate) {
            out.push(item);
          } else {
            reachedCutoff = true;
            break;
          }
        }

        if (reachedCutoff) break;
        if (!nextBeforeId) break;
        beforeId = nextBeforeId;
      }

      setRows(out);
    } catch (e: any) {
      setError(e?.message || "Failed to load audit log");
      setRows([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const nextAction = searchParams.get("action") ?? "";
    const nextDays = Number(searchParams.get("days") ?? "30");
    setActionFilter(nextAction);
    setDays(Number.isFinite(nextDays) && nextDays > 0 ? nextDays : 30);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchParams]);

  useEffect(() => {
    fetchAudit();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [cutoffDate]);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Audit Log</h1>
          <p className="text-muted-foreground">Operational events and changes for your organization.</p>
        </div>
        <Button onClick={fetchAudit} variant="outline" disabled={loading}>
          {loading ? "Refreshing…" : "Refresh"}
        </Button>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Filters</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 md:grid-cols-3">
            <div className="space-y-2">
              <div className="text-sm text-muted-foreground">Action</div>
              <Input
                placeholder="e.g. display.delete"
                value={actionFilter}
                onChange={(e) => setActionFilter(e.target.value)}
              />
            </div>

            <div className="space-y-2">
              <div className="text-sm text-muted-foreground">Time window</div>
              <Select value={String(days)} onValueChange={(v) => setDays(Number(v))}>
                <SelectTrigger>
                  <SelectValue placeholder="Select days" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="7">Last 7 days</SelectItem>
                  <SelectItem value="30">Last 30 days</SelectItem>
                  <SelectItem value="90">Last 90 days</SelectItem>
                  <SelectItem value="365">Last 365 days</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="flex items-end gap-2">
              <Button onClick={() => applyFiltersToUrl(actionFilter, days)} className="w-full">
                Apply
              </Button>
              <Button
                variant="outline"
                onClick={() => {
                  setActionFilter("");
                  setDays(30);
                  applyFiltersToUrl("", 30);
                }}
              >
                Reset
              </Button>
            </div>
          </div>

          {error ? <div className="mt-4 text-sm text-red-600">{error}</div> : null}
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle>Results</CardTitle>
          <div className="text-sm text-muted-foreground">{filtered.length} events</div>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>When</TableHead>
                <TableHead>Action</TableHead>
                <TableHead>Object</TableHead>
                <TableHead>User</TableHead>
                <TableHead>Details</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filtered.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={5} className="text-sm text-muted-foreground">
                    {loading ? "Loading…" : "No matching events."}
                  </TableCell>
                </TableRow>
              ) : (
                filtered.map((r) => (
                  <TableRow key={r.AuditLogId}>
                    <TableCell className="whitespace-nowrap text-xs text-muted-foreground">
                      {safeDistanceToNow(r.CreatedAt)}
                    </TableCell>
                    <TableCell className="font-mono text-xs">{r.Action}</TableCell>
                    <TableCell className="text-xs">
                      <span className="text-muted-foreground">{r.ObjectType}</span>
                      {r.ObjectId ? <span className="font-mono"> #{r.ObjectId}</span> : null}
                    </TableCell>
                    <TableCell className="text-xs">{r.UserId ?? "—"}</TableCell>
                    <TableCell className="max-w-[520px]">
                      <pre className="max-h-40 overflow-auto whitespace-pre-wrap rounded bg-muted p-2 text-[11px] leading-snug">
                        {tryFormatJson(r.Details)}
                      </pre>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>

          <div className="mt-3 text-xs text-muted-foreground">
            Note: this view loads up to 1000 recent events (stopping once it passes the selected time window).
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
