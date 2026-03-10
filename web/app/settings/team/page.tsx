"use client";

import { useState, useEffect, useCallback } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";
import {
  Users, UserPlus, Mail, MoreHorizontal, CheckCircle, XCircle,
  Clock, Shield, RefreshCw
} from "lucide-react";

interface Member {
  id: number;
  user_id: number;
  email: string;
  first_name: string;
  last_name: string;
  phone?: string;
  role: string;
  active: boolean;
  created_at: string;
}

interface Invitation {
  id: number;
  email: string;
  role: string;
  status: string;
  expires_at: string;
  created_at: string;
}

interface Role { id: number; name: string; display_name?: string }

const ROLE_COLORS: Record<string, string> = {
  admin:       "bg-purple-100 text-purple-700",
  manager:     "bg-blue-100 text-blue-700",
  sales_rep:   "bg-green-100 text-green-700",
  accountant:  "bg-amber-100 text-amber-700",
  warehouse:   "bg-orange-100 text-orange-700",
  driver:      "bg-teal-100 text-teal-700",
};

function RoleBadge({ role }: { role: string }) {
  const cls = ROLE_COLORS[role] ?? "bg-muted text-text-secondary";
  return (
    <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ${cls}`}>
      {role.replace(/_/g, " ")}
    </span>
  );
}

export default function TeamSettingsPage() {
  const { token, orgId } = useOrgBranch();

  const [members,     setMembers]     = useState<Member[]>([]);
  const [invitations, setInvitations] = useState<Invitation[]>([]);
  const [roles,       setRoles]       = useState<Role[]>([]);
  const [loading,     setLoading]     = useState(false);
  const [showInvite,  setShowInvite]  = useState(false);
  const [inviteEmail, setInviteEmail] = useState("");
  const [inviteRole,  setInviteRole]  = useState("sales_rep");
  const [inviting,    setInviting]    = useState(false);
  const [toast,       setToast]       = useState<{ type: "success" | "error"; msg: string } | null>(null);

  const showToast = (type: "success" | "error", msg: string) => {
    setToast({ type, msg });
    setTimeout(() => setToast(null), 4000);
  };

  const headers = useCallback(
    () => ({ Authorization: `Bearer ${token}`, "X-Organization-Id": orgId ?? "" }),
    [token, orgId]
  );

  const fetchAll = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const [membRes, invRes, roleRes] = await Promise.all([
        fetch(`${API_URL}/api/v1/memberships`, { headers: headers() }),
        fetch(`${API_URL}/api/v1/invitations`, { headers: headers() }),
        fetch(`${API_URL}/api/v1/roles`,       { headers: headers() }),
      ]);
      const [membJson, invJson, roleJson] = await Promise.all([
        membRes.json(), invRes.json(), roleRes.json(),
      ]);
      if (membRes.ok) setMembers(membJson.data ?? []);
      if (invRes.ok)  setInvitations(invJson.data ?? []);
      if (roleRes.ok) setRoles(roleJson.data ?? []);
    } finally {
      setLoading(false);
    }
  }, [token, orgId, headers]);

  useEffect(() => { fetchAll(); }, [fetchAll]);

  const handleInvite = async () => {
    if (!inviteEmail.trim() || !token || !orgId) return;
    setInviting(true);
    try {
      const res  = await fetch(`${API_URL}/api/v1/invitations`, {
        method: "POST",
        headers: { ...headers(), "Content-Type": "application/json" },
        body: JSON.stringify({ email: inviteEmail.trim(), role: inviteRole }),
      });
      const json = await res.json();
      if (res.ok) {
        showToast("success", `Invitation sent to ${inviteEmail}`);
        setInviteEmail("");
        setShowInvite(false);
        fetchAll();
      } else {
        showToast("error", json.errors?.join(", ") ?? "Failed to send invitation");
      }
    } finally {
      setInviting(false);
    }
  };

  const handleRevokeInvitation = async (id: number) => {
    if (!token || !orgId) return;
    const res = await fetch(`${API_URL}/api/v1/invitations/${id}`, {
      method: "DELETE", headers: headers(),
    });
    if (res.ok) {
      showToast("success", "Invitation revoked");
      fetchAll();
    }
  };

  const handleDeactivate = async (memberId: number) => {
    if (!token || !orgId) return;
    const res = await fetch(`${API_URL}/api/v1/memberships/${memberId}`, {
      method: "DELETE", headers: headers(),
    });
    if (res.ok) {
      showToast("success", "Member removed");
      fetchAll();
    }
  };

  const pendingInvitations = invitations.filter((inv) => inv.status === "pending");

  return (
    <AppShell title="Team Settings">
      <PageHeader
        title="Team"
        description="Manage team members, roles, and invitations"
        backHref="/settings"
        actions={[
          {
            label: "Invite Member",
            onClick: () => setShowInvite(true),
            icon: UserPlus,
          },
        ]}
      />

      {/* Toast */}
      {toast && (
        <div className={`fixed bottom-4 right-4 z-50 flex items-center gap-2 rounded-lg px-4 py-3 shadow-lg text-sm font-medium text-white ${
          toast.type === "success" ? "bg-success" : "bg-danger"
        }`}>
          {toast.type === "success" ? <CheckCircle className="h-4 w-4" /> : <XCircle className="h-4 w-4" />}
          {toast.msg}
        </div>
      )}

      {/* Invite form */}
      {showInvite && (
        <Card className="mb-4">
          <CardHeader>
            <CardTitle className="text-sm font-semibold">Invite a New Member</CardTitle>
          </CardHeader>
          <CardContent className="flex flex-wrap items-end gap-3">
            <div className="flex-1 min-w-[220px]">
              <label className="mb-1 block text-xs text-text-secondary">Email</label>
              <Input
                type="email"
                placeholder="colleague@company.com"
                value={inviteEmail}
                onChange={(e) => setInviteEmail(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleInvite()}
              />
            </div>
            <div className="min-w-[160px]">
              <label className="mb-1 block text-xs text-text-secondary">Role</label>
              <select
                value={inviteRole}
                onChange={(e) => setInviteRole(e.target.value)}
                className="h-9 w-full rounded-md border border-input bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-ring"
              >
                {roles.length > 0
                  ? roles.map((r) => (
                      <option key={r.id} value={r.name}>
                        {r.display_name ?? r.name.replace(/_/g, " ")}
                      </option>
                    ))
                  : Object.keys(ROLE_COLORS).map((r) => (
                      <option key={r} value={r}>{r.replace(/_/g, " ")}</option>
                    ))}
              </select>
            </div>
            <div className="flex gap-2">
              <Button onClick={handleInvite} disabled={inviting || !inviteEmail.trim()}>
                {inviting ? "Sending…" : "Send Invite"}
              </Button>
              <Button variant="outline" onClick={() => setShowInvite(false)}>
                Cancel
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      <div className="space-y-4">
        {/* Active Members */}
        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="flex items-center gap-2 text-sm font-semibold">
              <Users className="h-4 w-4 text-accent" />
              Active Members ({members.filter((m) => m.active).length})
            </CardTitle>
            <button
              onClick={fetchAll}
              className="text-text-secondary hover:text-text-primary transition-colors"
              aria-label="Refresh"
            >
              <RefreshCw className={`h-4 w-4 ${loading ? "animate-spin" : ""}`} />
            </button>
          </CardHeader>
          <CardContent className="p-0">
            {loading ? (
              <div className="space-y-px">
                {[1,2,3].map((i) => (
                  <div key={i} className="flex items-center justify-between px-4 py-3">
                    <div className="space-y-1.5">
                      <div className="h-3.5 w-36 rounded bg-border animate-pulse" />
                      <div className="h-2.5 w-52 rounded bg-border/60 animate-pulse" />
                    </div>
                    <div className="h-5 w-16 rounded-full bg-border animate-pulse" />
                  </div>
                ))}
              </div>
            ) : members.filter((m) => m.active).length === 0 ? (
              <div className="py-10 text-center">
                <Users className="mx-auto mb-2 h-8 w-8 text-text-secondary/40" />
                <p className="text-sm text-text-secondary">No active members yet.</p>
              </div>
            ) : (
              <div className="divide-y divide-border">
                {members.filter((m) => m.active).map((m) => (
                  <div key={m.id} className="flex items-center justify-between px-4 py-3">
                    <div className="flex items-center gap-3 min-w-0">
                      <div className="flex h-8 w-8 items-center justify-center rounded-full bg-accent/10 text-accent text-xs font-semibold shrink-0">
                        {m.first_name[0]}{m.last_name[0]}
                      </div>
                      <div className="min-w-0">
                        <p className="text-sm font-medium text-text-primary truncate">
                          {m.first_name} {m.last_name}
                        </p>
                        <p className="text-xs text-text-secondary truncate">{m.email}</p>
                      </div>
                    </div>
                    <div className="flex items-center gap-3 shrink-0 ml-4">
                      <RoleBadge role={m.role} />
                      <button
                        onClick={() => handleDeactivate(m.id)}
                        className="text-text-secondary hover:text-danger transition-colors"
                        title="Remove member"
                      >
                        <MoreHorizontal className="h-4 w-4" />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        {/* Pending Invitations */}
        {pendingInvitations.length > 0 && (
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-sm font-semibold">
                <Mail className="h-4 w-4 text-accent" />
                Pending Invitations ({pendingInvitations.length})
              </CardTitle>
            </CardHeader>
            <CardContent className="p-0">
              <div className="divide-y divide-border">
                {pendingInvitations.map((inv) => (
                  <div key={inv.id} className="flex items-center justify-between px-4 py-3">
                    <div className="flex items-center gap-3 min-w-0">
                      <Clock className="h-4 w-4 text-text-secondary shrink-0" />
                      <div className="min-w-0">
                        <p className="text-sm font-medium text-text-primary truncate">{inv.email}</p>
                        <p className="text-xs text-text-secondary">
                          Expires {new Date(inv.expires_at).toLocaleDateString("en-IN")}
                        </p>
                      </div>
                    </div>
                    <div className="flex items-center gap-3 shrink-0 ml-4">
                      <RoleBadge role={inv.role} />
                      <button
                        onClick={() => handleRevokeInvitation(inv.id)}
                        className="text-xs text-danger hover:underline"
                      >
                        Revoke
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        )}

        {/* Roles Reference */}
        {roles.length > 0 && (
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-sm font-semibold">
                <Shield className="h-4 w-4 text-accent" />
                Available Roles
              </CardTitle>
            </CardHeader>
            <CardContent className="flex flex-wrap gap-2 pb-4">
              {roles.map((r) => (
                <RoleBadge key={r.id} role={r.name} />
              ))}
            </CardContent>
          </Card>
        )}
      </div>
    </AppShell>
  );
}
