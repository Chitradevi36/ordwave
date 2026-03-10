"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { DataTable } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Modal } from "@/components/ui/modal";
import { UserPlus, Search, X, ChevronRight } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";

// ─── Types ──────────────────────────────────────────────────────────────────
interface Role {
  id: number;
  name: string;
}

interface Membership {
  id: number;
  role: Role;
  branch: { id: number; name: string } | null;
  status: string;
  created_at: string;
}

interface TeamMember {
  id: number;
  email: string;
  first_name: string;
  last_name: string;
  full_name: string;
  phone: string | null;
  active: boolean;
  membership: Membership | null;
  created_at: string;
}

interface Invitation {
  id: number;
  email: string;
  status: "pending" | "accepted" | "declined" | "revoked" | "expired";
  role: Role | null;
  branch: { id: number; name: string } | null;
  invited_by: { id: number; name: string } | null;
  expires_at: string;
  created_at: string;
}

type DisplayRow =
  | ({ rowKind: "member" } & TeamMember)
  | ({ rowKind: "invitation" } & Invitation);

interface InviteForm {
  email: string;
  role_id: string;
  branch_id: string;
}

const ROLE_LABEL: Record<string, string> = {
  owner:           "Owner",
  admin:           "Admin",
  manager:         "Manager",
  sales_rep:       "Sales Rep",
  warehouse_staff: "Warehouse Staff",
  accountant:      "Accountant",
};

const ROLE_BADGE_VARIANT: Record<string, "default" | "secondary" | "success" | "warning" | "danger" | "outline"> = {
  owner:           "warning",
  admin:           "default",
  manager:         "secondary",
  sales_rep:       "outline",
  warehouse_staff: "outline",
  accountant:      "outline",
};

const INVITATION_STATUS_VARIANT: Record<string, "default" | "secondary" | "success" | "warning" | "danger" | "outline"> = {
  pending:  "warning",
  accepted: "success",
  declined: "danger",
  revoked:  "danger",
  expired:  "outline",
};

// ─── Columns ────────────────────────────────────────────────────────────────
function buildColumns(
  onDeactivate: (id: number) => void,
  onRevoke: (id: number) => void,
  currentUserId: number | null,
) {
  return [
    {
      key: "email" as keyof DisplayRow,
      header: "Name",
      render: (_: unknown, row: DisplayRow) => {
        if (row.rowKind === "invitation") {
          return (
            <div>
              <p className="font-medium text-text-primary">{row.email}</p>
              <p className="text-xs text-text-secondary">Pending invitation</p>
            </div>
          );
        }
        return (
          <div>
            <p className="font-medium text-text-primary">{row.full_name}</p>
            <p className="text-xs text-text-secondary">{row.email}</p>
          </div>
        );
      },
    },
    {
      key: "email" as keyof DisplayRow,
      header: "Role",
      render: (_: unknown, row: DisplayRow) => {
        const roleName =
          row.rowKind === "member"
            ? row.membership?.role.name
            : row.role?.name;
        return roleName ? (
          <Badge variant={ROLE_BADGE_VARIANT[roleName] ?? "outline"}>
            {roleName.replace(/_/g, " ")}
          </Badge>
        ) : (
          <span className="text-text-secondary text-xs">—</span>
        );
      },
    },
    {
      key: "email" as keyof DisplayRow,
      header: "Branch",
      render: (_: unknown, row: DisplayRow) => {
        const branch =
          row.rowKind === "member" ? row.membership?.branch : row.branch;
        return (
          <span className="text-sm text-text-primary">{branch?.name ?? "—"}</span>
        );
      },
    },
    {
      key: "email" as keyof DisplayRow,
      header: "Status",
      render: (_: unknown, row: DisplayRow) => {
        if (row.rowKind === "invitation") {
          return (
            <Badge variant={INVITATION_STATUS_VARIANT[row.status] ?? "outline"}>
              {row.status.charAt(0).toUpperCase() + row.status.slice(1)}
            </Badge>
          );
        }
        return (
          <Badge variant={row.active ? "success" : "danger"}>
            {row.active ? "Active" : "Inactive"}
          </Badge>
        );
      },
    },
    {
      key: "id" as keyof DisplayRow,
      header: "",
      render: (_: unknown, row: DisplayRow) => {
        if (row.rowKind === "invitation" && row.status === "pending") {
          return (
            <Button
              size="sm"
              variant="ghost"
              onClick={() => onRevoke(row.id)}
              className="text-danger hover:text-danger h-7 px-2 text-xs"
            >
              Revoke
            </Button>
          );
        }
        if (row.rowKind === "member" && row.active && row.id !== currentUserId) {
          return (
            <Button
              size="sm"
              variant="ghost"
              onClick={() => onDeactivate(row.id)}
              className="text-danger hover:text-danger h-7 px-2 text-xs"
            >
              Deactivate
            </Button>
          );
        }
        return null;
      },
    },
  ];
}

// ─── Page ────────────────────────────────────────────────────────────────────
export default function UsersPage() {
  const router = useRouter();
  const [members, setMembers]           = useState<TeamMember[]>([]);
  const [invitations, setInvitations]   = useState<Invitation[]>([]);
  const [loading, setLoading]           = useState(false);
  const [query, setQuery]               = useState("");
  const [roleFilter, setRoleFilter]     = useState("");
  const [showInvite, setShowInvite]     = useState(false);
  const [inviteForm, setInviteForm]     = useState<InviteForm>({ email: "", role_id: "", branch_id: "" });
  const [inviteError, setInviteError]   = useState<string | null>(null);
  const [inviteLoading, setInviteLoading] = useState(false);
  const [inviteSuccess, setInviteSuccess] = useState(false);
  const [totalCount, setTotalCount]     = useState(0);
  const [page, setPage]                 = useState(1);
  const [refreshKey, setRefreshKey]     = useState(0);
  const [roles, setRoles]               = useState<Role[]>([]);
  const [debouncedQuery, setDebouncedQuery] = useState("");

  const { token, orgId, branchId, branches } = useOrgBranch();

  // Decode current user ID from JWT sub claim
  const currentUserId = (() => {
    if (!token) return null;
    try {
      const payload = JSON.parse(atob(token.split(".")[1]));
      return typeof payload.sub === "number" ? payload.sub : parseInt(payload.sub, 10) || null;
    } catch { return null; }
  })();

  // ── Fetch roles once ──────────────────────────────────────────────────────
  useEffect(() => {
    if (!token || !orgId) return;
    fetch(`${API_URL}/api/v1/roles`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then((r) => r.json())
      .then((json) => { if (Array.isArray(json.data)) setRoles(json.data); })
      .catch(() => {});
  }, [token, orgId]);

  // ── Debounce search query ─────────────────────────────────────────────────
  useEffect(() => {
    const t = setTimeout(() => setDebouncedQuery(query), 300);
    return () => clearTimeout(t);
  }, [query]);

  // ── Fetch members + invitations ───────────────────────────────────────────
  useEffect(() => {
    if (!token || !orgId) return;
    let cancelled = false;

    const doFetch = async () => {
      setLoading(true);
      try {
        const params = new URLSearchParams({ page: String(page), per_page: "20" });
        if (debouncedQuery) params.set("q", debouncedQuery);
        if (roleFilter) params.set("role_id", roleFilter);
        if (branchId)   params.set("branch_id", branchId);

        const headers: HeadersInit = {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId,
        };

        const [usersRes, invitesRes] = await Promise.all([
          fetch(`${API_URL}/api/v1/users?${params}`, { headers }),
          fetch(`${API_URL}/api/v1/invitations?per_page=100`, { headers }),
        ]);

        if (cancelled) return;

        const usersJson   = await usersRes.json();
        const invitesJson = await invitesRes.json();

        if (usersRes.ok) {
          setMembers(usersJson.data ?? []);
          setTotalCount(usersJson.meta?.total_count ?? 0);
        }
        if (invitesRes.ok) {
          setInvitations(
            (invitesJson.data ?? []).filter(
              (i: Invitation) => i.status === "pending" || i.status === "expired",
            ),
          );
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    doFetch();
    return () => { cancelled = true; };
  }, [token, orgId, branchId, page, debouncedQuery, roleFilter, refreshKey]);

  const refresh = () => setRefreshKey((k) => k + 1);

  // ── Revoke invitation ──────────────────────────────────────────────────────
  const handleRevoke = async (invitationId: number) => {
    if (!confirm("Revoke this invitation?")) return;
    await fetch(`${API_URL}/api/v1/invitations/${invitationId}`, {
      method: "DELETE",
      headers: {
        Authorization:       `Bearer ${token}`,
        "X-Organization-Id": orgId,
      },
    });
    refresh();
  };

  // ── Deactivate ─────────────────────────────────────────────────────────────
  const handleDeactivate = async (userId: number) => {
    if (!confirm("Deactivate this user from your organization?")) return;
    await fetch(`${API_URL}/api/v1/users/${userId}/deactivate`, {
      method: "POST",
      headers: {
        Authorization:      `Bearer ${token}`,
        "X-Organization-Id": orgId,
      },
    });
    refresh();
  };

  // ── Send invite ────────────────────────────────────────────────────────────
  const handleInvite = async () => {
    if (!inviteForm.email || !inviteForm.role_id) {
      setInviteError("Email and role are required.");
      return;
    }
    setInviteLoading(true);
    setInviteError(null);
    try {
      const res = await fetch(`${API_URL}/api/v1/invitations`, {
        method: "POST",
        headers: {
          "Content-Type":      "application/json",
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify(inviteForm),
      });
      const json = await res.json();
      if (res.ok) {
        setInviteSuccess(true);
        setTimeout(() => {
          setShowInvite(false);
          setInviteForm({ email: "", role_id: "", branch_id: "" });
          setInviteSuccess(false);
          refresh();
        }, 2000);
      } else {
        setInviteError((json.errors ?? []).join(", "));
      }
    } finally {
      setInviteLoading(false);
    }
  };

  const rows: DisplayRow[] = [
    ...members.map((m) => ({ ...m, rowKind: "member" as const })),
    ...invitations.map((i) => ({ ...i, rowKind: "invitation" as const })),
  ];

  const pendingCount = invitations.filter((i) => i.status === "pending").length;

  const columns = buildColumns(handleDeactivate, handleRevoke, currentUserId);

  return (
    <AppShell title="Team" hideBreadcrumb>
      <PageHeader
        title="Team Members"
        description={`${totalCount} member${totalCount !== 1 ? "s" : ""}${pendingCount > 0 ? ` · ${pendingCount} pending invitation${pendingCount !== 1 ? "s" : ""}` : ""}`}
        actions={[
          {
            label: "Invite Member",
            onClick: () => setShowInvite(true),
            icon: UserPlus,
          },
        ]}
      />

      {/* Filters */}
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <div className="relative flex-1 max-w-xs">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary" />
          <input
            type="text"
            placeholder="Search by name or email…"
            value={query}
            onChange={(e) => { setQuery(e.target.value); setPage(1); }}
            className="w-full rounded-lg border border-border bg-white py-2 pl-9 pr-3 text-sm text-text-primary placeholder:text-text-secondary focus:outline-none focus:ring-2 focus:ring-accent"
          />
          {query && (
            <button onClick={() => setQuery("")} className="absolute right-3 top-1/2 -translate-y-1/2">
              <X className="h-3.5 w-3.5 text-text-secondary" />
            </button>
          )}
        </div>

        <select
          value={roleFilter}
          onChange={(e) => { setRoleFilter(e.target.value); setPage(1); }}
          className="rounded-lg border border-border bg-white px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
        >
          <option value="">All Roles</option>
          {roles
            .filter((r) => r.name !== "owner")
            .map((r) => (
              <option key={r.id} value={String(r.id)}>
                {ROLE_LABEL[r.name] ?? r.name}
              </option>
            ))}
        </select>
      </div>

      <DataTable columns={columns} data={rows} isLoading={loading} />

      {/* Pagination */}
      {totalCount > 20 && (
        <div className="mt-4 flex items-center justify-end gap-2">
          <Button size="sm" variant="outline" disabled={page === 1} onClick={() => setPage((p) => p - 1)}>
            Previous
          </Button>
          <span className="text-sm text-text-secondary">Page {page}</span>
          <Button size="sm" variant="outline" disabled={members.length < 20} onClick={() => setPage((p) => p + 1)}>
            Next
          </Button>
        </div>
      )}

      {/* ── Invite Modal ──────────────────────────────────────────────────── */}
      <Modal
        open={showInvite}
        onClose={() => { setShowInvite(false); setInviteError(null); setInviteSuccess(false); }}
        title="Invite Team Member"
        size="md"
      >
        {inviteSuccess ? (
          <div className="flex flex-col items-center gap-3 py-6">
            <div className="flex h-12 w-12 items-center justify-center rounded-full bg-accent/15">
              <UserPlus className="h-6 w-6 text-accent" />
            </div>
            <p className="text-sm font-medium text-text-primary">Invitation sent!</p>
            <p className="text-xs text-text-secondary text-center">
              {inviteForm.email} will receive an invitation email shortly.
            </p>
          </div>
        ) : (
          <div className="space-y-4">
            <Input
              label="Email Address"
              type="email"
              placeholder="colleague@company.com"
              value={inviteForm.email}
              onChange={(e) => setInviteForm((f) => ({ ...f, email: e.target.value }))}
            />

            <div>
              <label className="mb-1 block text-xs font-medium text-text-primary">Role</label>
              <select
                value={inviteForm.role_id}
                onChange={(e) => setInviteForm((f) => ({ ...f, role_id: e.target.value }))}
                className="w-full rounded-lg border border-border bg-white px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
              >
                <option value="">Select a role…</option>
                {roles
                  .filter((r) => r.name !== "owner")
                  .map((r) => (
                    <option key={r.id} value={String(r.id)}>
                      {ROLE_LABEL[r.name] ?? r.name}
                    </option>
                  ))}
              </select>
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-text-primary">Branch (optional)</label>
              <select
                value={inviteForm.branch_id}
                onChange={(e) => setInviteForm((f) => ({ ...f, branch_id: e.target.value }))}
                className="w-full rounded-lg border border-border bg-white px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
                disabled={branches.length === 0}
              >
                <option value="">{branches.length === 0 ? "No branches available" : "All branches"}</option>
                {branches.map((b) => (
                  <option key={b.id} value={String(b.id)}>{b.name}</option>
                ))}
              </select>
            </div>

            {inviteError && (
              <p className="rounded-md bg-danger/10 px-3 py-2 text-xs text-danger">{inviteError}</p>
            )}

            <div className="flex justify-end gap-2 pt-2">
              <Button variant="outline" onClick={() => setShowInvite(false)}>Cancel</Button>
              <Button onClick={handleInvite} isLoading={inviteLoading}>Send Invite</Button>
            </div>
          </div>
        )}
      </Modal>
    </AppShell>
  );
}
