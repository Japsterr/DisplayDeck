"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { MoreVertical, Plus, RefreshCw, Users as UsersIcon } from "lucide-react";

import { Button } from "@/components/ui/button";
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
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";

type OrgUser = {
  Id: number;
  OrganizationId: number;
  Email: string;
  Role: string;
  CreatedAt?: string;
  EmailVerifiedAt?: string | null;
};

type Auth = { token: string; orgId: number; role: string; userId: number };

function getApiUrl() {
  return process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";
}

function getAuth() {
  const token = localStorage.getItem("token");
  const userStr = localStorage.getItem("user");
  if (!token || !userStr) return null;
  try {
    const user = JSON.parse(userStr);
    const orgId = user?.OrganizationId;
    if (!orgId) return null;
    return {
      token,
      orgId,
      role: (user?.Role as string | undefined) || "",
      userId: (user?.Id as number | undefined) || 0,
    } as Auth;
  } catch {
    return null;
  }
}

export default function UsersPage() {
  const router = useRouter();

  const [auth, setAuth] = useState<Auth | null>(null);
  const isOwner = auth?.role === "Owner";
  const currentUserId = auth?.userId || 0;

  const [users, setUsers] = useState<OrgUser[]>([]);
  const [loading, setLoading] = useState(true);

  const [isAddOpen, setIsAddOpen] = useState(false);
  const [creating, setCreating] = useState(false);
  const [form, setForm] = useState({ email: "", role: "ContentManager" });

  const [sending, setSending] = useState<{ key: string; action: "verify" | "reset" } | null>(null);

  const [confirm, setConfirm] = useState<
    | null
    | {
        title: string;
        description: string;
        confirmText: string;
        action:
          | { type: "verify"; email: string }
          | { type: "reset"; email: string }
          | { type: "role"; userId: number; email: string; role: "Owner" | "ContentManager" };
      }
  >(null);

  async function fetchUsers(authArg?: Auth | null) {
    try {
      setLoading(true);
      const a = authArg || auth;
      if (!a) {
        router.push("/login");
        return;
      }

      const res = await fetch(`${getApiUrl()}/organizations/${a.orgId}/users`, {
        headers: { "X-Auth-Token": a.token },
      });

      if (res.status === 401) {
        router.push("/login");
        return;
      }

      if (res.status === 403) {
        toast.error("You do not have permission to view users.");
        setUsers([]);
        return;
      }

      if (!res.ok) throw new Error(await res.text());
      const data = (await res.json()) as OrgUser[];
      setUsers(Array.isArray(data) ? data : []);
    } catch (e) {
      console.error(e);
      toast.error("Failed to load users");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    const a = getAuth();
    setAuth(a);
    fetchUsers(a);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function createUser() {
    if (!form.email.trim()) {
      toast.error("Email is required");
      return;
    }

    try {
      setCreating(true);
      const a = auth || getAuth();
      if (!a) {
        router.push("/login");
        return;
      }

      const res = await fetch(`${getApiUrl()}/organizations/${a.orgId}/users`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": a.token,
        },
        body: JSON.stringify({ Email: form.email.trim(), Role: form.role }),
      });

      if (res.status === 401) {
        router.push("/login");
        return;
      }

      if (res.status === 403) {
        toast.error("Only Owners can add users.");
        return;
      }

      if (!res.ok) throw new Error(await res.text());

      toast.success("User created. Invite email sent (or logged).");
      setIsAddOpen(false);
      setForm({ email: "", role: "ContentManager" });
      await fetchUsers();
    } catch (e) {
      console.error(e);
      toast.error("Failed to create user");
    } finally {
      setCreating(false);
    }
  }

  async function resendVerification(email: string) {
    try {
      setSending({ key: email, action: "verify" });
      const res = await fetch(`${getApiUrl()}/auth/resend-verification`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ Email: email }),
      });
      if (!res.ok) throw new Error(await res.text());
      const data = (await res.json().catch(() => null)) as
        | { EmailMode?: "smtp" | "log" }
        | null;
      toast.success("If the account exists, a verification email has been sent.");
      if (data?.EmailMode === "log") {
        toast.warning(
          "Email is in log mode (SMTP not configured). Configure SMTP_HOST to actually deliver emails."
        );
      }
    } catch (e) {
      console.error(e);
      toast.error("Failed to resend verification email");
    } finally {
      setSending(null);
    }
  }

  async function sendResetLink(email: string) {
    try {
      setSending({ key: email, action: "reset" });
      const res = await fetch(`${getApiUrl()}/auth/forgot-password`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ Email: email }),
      });
      if (!res.ok) throw new Error(await res.text());
      const data = (await res.json().catch(() => null)) as
        | { EmailMode?: "smtp" | "log" }
        | null;
      toast.success("If the account exists, a reset email has been sent.");
      if (data?.EmailMode === "log") {
        toast.warning(
          "Email is in log mode (SMTP not configured). Configure SMTP_HOST to actually deliver emails."
        );
      }
    } catch (e) {
      console.error(e);
      toast.error("Failed to send reset email");
    } finally {
      setSending(null);
    }
  }

  async function updateUserRole(userId: number, email: string, role: "Owner" | "ContentManager") {
    try {
      const a = auth || getAuth();
      if (!a) {
        router.push("/login");
        return;
      }

      setSending({ key: email, action: "reset" });

      const res = await fetch(
        `${getApiUrl()}/organizations/${a.orgId}/users/${userId}`,
        {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            "X-Auth-Token": a.token,
          },
          body: JSON.stringify({ Role: role }),
        }
      );

      if (res.status === 401) {
        router.push("/login");
        return;
      }

      if (res.status === 403) {
        toast.error("Only Owners can change roles.");
        return;
      }

      if (!res.ok) {
        const text = await res.text();
        if (text.includes("cannot_remove_last_owner")) {
          toast.error("You cannot remove the last Owner.");
          return;
        }
        if (text.includes("cannot_change_own_role")) {
          toast.error("You cannot change your own role.");
          return;
        }
        throw new Error(text);
      }

      toast.success("Role updated. User may need to re-login.");
      await fetchUsers();
    } catch (e) {
      console.error(e);
      toast.error("Failed to update role");
    } finally {
      setSending(null);
    }
  }

  async function runConfirmed() {
    if (!confirm) return;
    const action = confirm.action;
    setConfirm(null);
    if (action.type === "verify") await resendVerification(action.email);
    if (action.type === "reset") await sendResetLink(action.email);
    if (action.type === "role") await updateUserRole(action.userId, action.email, action.role);
  }

  return (
    <div className="space-y-4">
      <Dialog open={!!confirm} onOpenChange={(open) => (!open ? setConfirm(null) : null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{confirm?.title || "Confirm"}</DialogTitle>
            <DialogDescription>{confirm?.description || ""}</DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="secondary" onClick={() => setConfirm(null)}>
              Cancel
            </Button>
            <Button onClick={runConfirmed}>{confirm?.confirmText || "Confirm"}</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Users</h1>
          <p className="text-sm text-muted-foreground">
            Manage who can access this organization.
          </p>
        </div>
        <div className="flex gap-2">
          <Button variant="secondary" onClick={() => fetchUsers()} disabled={loading}>
            <RefreshCw className="mr-2 size-4" />
            Refresh
          </Button>

          {isOwner ? (
            <Dialog open={isAddOpen} onOpenChange={setIsAddOpen}>
              <DialogTrigger asChild>
                <Button>
                  <Plus className="mr-2 size-4" />
                  Add user
                </Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Add user</DialogTitle>
                  <DialogDescription>
                    Creates an account and sends a “set password” email.
                  </DialogDescription>
                </DialogHeader>

                <div className="space-y-4">
                  <div className="space-y-2">
                    <Label>Email</Label>
                    <Input
                      value={form.email}
                      onChange={(e) => setForm((s) => ({ ...s, email: e.target.value }))}
                      placeholder="user@example.com"
                    />
                  </div>

                  <div className="space-y-2">
                    <Label>Role</Label>
                    <Select
                      value={form.role}
                      onValueChange={(v) => setForm((s) => ({ ...s, role: v }))}
                    >
                      <SelectTrigger>
                        <SelectValue placeholder="Select role" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="Owner">Owner</SelectItem>
                        <SelectItem value="ContentManager">Content Manager</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </div>

                <DialogFooter>
                  <Button
                    variant="secondary"
                    onClick={() => setIsAddOpen(false)}
                    disabled={creating}
                  >
                    Cancel
                  </Button>
                  <Button onClick={createUser} disabled={creating}>
                    {creating ? "Creating…" : "Create & send invite"}
                  </Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
          ) : null}
        </div>
      </div>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle className="flex items-center gap-2">
            <UsersIcon className="size-5" />
            Organization users
          </CardTitle>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="text-sm text-muted-foreground">Loading…</div>
          ) : users.length === 0 ? (
            <div className="text-sm text-muted-foreground">No users found.</div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Email</TableHead>
                  <TableHead>Role</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="text-right">Created</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {users.map((u) => {
                  const verified = !!u.EmailVerifiedAt;
                  const isBusyVerify = sending?.key === u.Email && sending?.action === "verify";
                  const isBusyReset = sending?.key === u.Email && sending?.action === "reset";
                  return (
                    <TableRow key={u.Id}>
                      <TableCell className="font-medium">{u.Email}</TableCell>
                      <TableCell>
                        <Badge variant={u.Role === "Owner" ? "default" : "secondary"}>
                          {u.Role}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        <Badge variant={verified ? "default" : "outline"}>
                          {verified ? "Verified" : "Pending"}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-right text-xs text-muted-foreground">
                        {u.CreatedAt ? new Date(u.CreatedAt).toLocaleString() : ""}
                      </TableCell>
                      <TableCell className="text-right">
                        <DropdownMenu>
                          <DropdownMenuTrigger asChild>
                            <Button variant="ghost" size="icon" aria-label="User actions">
                              <MoreVertical className="size-4" />
                            </Button>
                          </DropdownMenuTrigger>
                          <DropdownMenuContent align="end">
                            <DropdownMenuLabel>Actions</DropdownMenuLabel>
                            <DropdownMenuSeparator />
                            {!verified ? (
                              <DropdownMenuItem
                                onClick={() =>
                                  setConfirm({
                                    title: "Resend verification",
                                    description: `Send a verification email to ${u.Email}?`,
                                    confirmText: "Send verification",
                                    action: { type: "verify", email: u.Email },
                                  })
                                }
                                disabled={!!sending}
                              >
                                {isBusyVerify ? "Sending…" : "Resend verification"}
                              </DropdownMenuItem>
                            ) : null}
                            <DropdownMenuItem
                              onClick={() =>
                                setConfirm({
                                  title: "Send reset link",
                                  description: `Send a password reset email to ${u.Email}?`,
                                  confirmText: "Send reset link",
                                  action: { type: "reset", email: u.Email },
                                })
                              }
                              disabled={!!sending}
                            >
                              {isBusyReset ? "Sending…" : "Send reset link"}
                            </DropdownMenuItem>

                            <DropdownMenuSeparator />
                              {isOwner ? (
                                <>
                                  <DropdownMenuLabel>Role</DropdownMenuLabel>
                                  <DropdownMenuItem
                                    onClick={() =>
                                      setConfirm({
                                        title: "Change role",
                                        description: `Change ${u.Email} to Owner?`,
                                        confirmText: "Set to Owner",
                                        action: { type: "role", userId: u.Id, email: u.Email, role: "Owner" },
                                      })
                                    }
                                    disabled={!!sending || u.Role === "Owner" || u.Id === currentUserId}
                                  >
                                    Set role: Owner
                                  </DropdownMenuItem>
                                  <DropdownMenuItem
                                    onClick={() =>
                                      setConfirm({
                                        title: "Change role",
                                        description: `Change ${u.Email} to Content Manager?`,
                                        confirmText: "Set to Content Manager",
                                        action: {
                                          type: "role",
                                          userId: u.Id,
                                          email: u.Email,
                                          role: "ContentManager",
                                        },
                                      })
                                    }
                                    disabled={!!sending || u.Role === "ContentManager" || u.Id === currentUserId}
                                  >
                                    Set role: Content Manager
                                  </DropdownMenuItem>
                                </>
                              ) : null}
                          </DropdownMenuContent>
                        </DropdownMenu>
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
