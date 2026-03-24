"use client";

import { useState, useEffect } from "react";
import { useParams, useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { ArrowLeft, Mail, Phone, UserX } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";
import { AccessDeniedError } from "@/components/errors/access-denied-error";

interface UserDetail {
  id: number;
  email: string;
  first_name: string;
  last_name: string;
  full_name: string;
  phone: string | null;
  active: boolean;
  created_at: string;
  membership: {
    id: number;
    role: { id: number; name: string };
    branch: { id: number; name: string } | null;
    status: string;
    created_at: string;
  } | null;
}

const ROLE_BADGE_VARIANT: Record<string, "default" | "secondary" | "success" | "warning" | "danger" | "outline"> = {
  owner:           "warning",
  admin:           "default",
  manager:         "secondary",
  sales_rep:       "outline",
  warehouse_staff: "outline",
  accountant:      "outline",
};

export default function UserDetailPage() {
  const params   = useParams();
  const router   = useRouter();
  const userId   = params.id as string;

  const [user, setUser]         = useState<UserDetail | null>(null);
  const [loading, setLoading]   = useState(false);
  const [deactivating, setDeactivating] = useState(false);
  const [error, setError]       = useState<{ status: number; message: string } | null>(null);

  const { token, orgId } = useOrgBranch();

  useEffect(() => {
    const fetchUser = async () => {
      if (!token || !orgId) return;
      setLoading(true);
      setError(null);
      try {
        const res  = await fetch(`${API_URL}/api/v1/users/${userId}`, {
          headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
        });
        if (!res.ok) {
          const json = await res.json();
          setError({
            status: res.status,
            message: json.errors?.[0] ?? "Failed to load user"
          });
          setLoading(false);
          return;
        }
        const json = await res.json();
        setUser(json.data);
      } finally {
        setLoading(false);
      }
    };
    fetchUser();
  }, [userId, token, orgId]);

  const handleDeactivate = async () => {
    if (!confirm("Deactivate this user from your organization?")) return;
    setDeactivating(true);
    try {
      await fetch(`${API_URL}/api/v1/users/${userId}/deactivate`, {
        method:  "POST",
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      router.push("/users");
    } finally {
      setDeactivating(false);
    }
  };

  if (loading) {
    return (
      <AppShell title="Team" breadcrumbs={[
        { label: "Team", href: "/users" },
        { label: "User" },
      ]}>
        <div className="flex items-center justify-center h-48">
          <div className="h-6 w-6 animate-spin rounded-full border-2 border-accent border-t-transparent" />
        </div>
      </AppShell>
    );
  }

  if (error) {
    return <AccessDeniedError
      status={error.status}
      message={error.message}
      backLink="/users"
      resourceType="User"
    />;
  }

  if (!user) {
    return (
      <AppShell title="Team" breadcrumbs={[
        { label: "Team", href: "/users" },
        { label: "User" },
      ]}>
        <p className="text-text-secondary">User not found.</p>
      </AppShell>
    );
  }

  return (
    <AppShell title="Team" breadcrumbs={[
      { label: "Team", href: "/users" },
      { label: user.full_name },
    ]}>
      <div className="mb-4">
        <button
          onClick={() => router.push("/users")}
          className="flex items-center gap-1.5 text-sm text-text-secondary hover:text-text-primary transition-colors"
        >
          <ArrowLeft className="h-4 w-4" /> Back to Team
        </button>
      </div>

      <PageHeader
        title={user.full_name}
        description={user.email}
        actions={
          user.active
            ? [{ label: "Deactivate User", onClick: handleDeactivate, variant: "outline", icon: UserX }]
            : []
        }
      />

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {/* Profile Card */}
        <Card className="lg:col-span-1">
          <CardHeader>
            <CardTitle className="text-sm font-semibold">Profile</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="flex items-center gap-2">
              <div className="flex h-12 w-12 items-center justify-center rounded-full bg-primary/10 text-primary font-semibold text-lg">
                {user.first_name[0]}{user.last_name[0]}
              </div>
              <div>
                <p className="font-medium text-text-primary">{user.full_name}</p>
                <Badge variant={user.active ? "success" : "danger"} className="mt-0.5">
                  {user.active ? "Active" : "Inactive"}
                </Badge>
              </div>
            </div>

            <div className="space-y-2 pt-2 border-t border-border">
              <div className="flex items-center gap-2 text-sm text-text-secondary">
                <Mail className="h-3.5 w-3.5 shrink-0" />
                <span>{user.email}</span>
              </div>
              {user.phone && (
                <div className="flex items-center gap-2 text-sm text-text-secondary">
                  <Phone className="h-3.5 w-3.5 shrink-0" />
                  <span>{user.phone}</span>
                </div>
              )}
            </div>

            <p className="text-xs text-text-secondary pt-1">
              Member since {new Date(user.created_at).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}
            </p>
          </CardContent>
        </Card>

        {/* Membership Card */}
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle className="text-sm font-semibold">Membership</CardTitle>
          </CardHeader>
          <CardContent>
            {user.membership ? (
              <div className="space-y-3">
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <p className="text-xs font-medium text-text-secondary uppercase tracking-wide">Role</p>
                    <Badge
                      variant={ROLE_BADGE_VARIANT[user.membership.role.name] ?? "outline"}
                      className="mt-1"
                    >
                      {user.membership.role.name.replace(/_/g, " ")}
                    </Badge>
                  </div>
                  <div>
                    <p className="text-xs font-medium text-text-secondary uppercase tracking-wide">Branch</p>
                    <p className="mt-1 text-sm text-text-primary">
                      {user.membership.branch?.name ?? "—"}
                    </p>
                  </div>
                  <div>
                    <p className="text-xs font-medium text-text-secondary uppercase tracking-wide">Status</p>
                    <Badge variant={user.membership.status === "active" ? "success" : "danger"} className="mt-1">
                      {user.membership.status}
                    </Badge>
                  </div>
                  <div>
                    <p className="text-xs font-medium text-text-secondary uppercase tracking-wide">Joined Org</p>
                    <p className="mt-1 text-sm text-text-primary">
                      {new Date(user.membership.created_at).toLocaleDateString("en-IN")}
                    </p>
                  </div>
                </div>
              </div>
            ) : (
              <p className="text-sm text-text-secondary">No active membership in this organization.</p>
            )}
          </CardContent>
        </Card>
      </div>

      {deactivating && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/20">
          <div className="h-8 w-8 animate-spin rounded-full border-2 border-accent border-t-transparent" />
        </div>
      )}
    </AppShell>
  );
}
