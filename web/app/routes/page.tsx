"use client";

import React, { useEffect, useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { useOrgBranch } from "@/lib/org-branch-context";
import { CreateRouteModal } from "@/components/routes/create-route-modal";
import { Plus, Search, X, MapPin, CheckCircle2, Route as RouteIcon } from "lucide-react";

// ─── Types ────────────────────────────────────────────────────────────────────
interface Route {
  id: number;
  name: string;
  code: string;
  active: boolean;
  branch_id: number;
  customers_count?: number;
}

interface PageMeta {
  current_page: number;
  total_pages: number;
  total_count: number;
}

// ─── Stat Card ────────────────────────────────────────────────────────────────
function StatCard({
  label, value, icon: Icon, accent,
}: {
  label: string;
  value: string | number;
  icon: React.FC<{ className?: string }>;
  accent: string;
}) {
  return (
    <Card>
      <CardContent className="p-4 flex items-start gap-3">
        <div className={`rounded-lg p-2 shrink-0 ${accent}`}>
          <Icon className="h-4 w-4" />
        </div>
        <div className="min-w-0">
          <p className="text-xs text-text-secondary">{label}</p>
          <p className="text-xl font-bold text-text-primary leading-tight">{value}</p>
        </div>
      </CardContent>
    </Card>
  );
}

// ─── Filter tabs ──────────────────────────────────────────────────────────────
const FILTER_TABS = [
  { key: "",         label: "All" },
  { key: "active",   label: "Active" },
  { key: "inactive", label: "Inactive" },
];

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function RoutesPage() {
  const router = useRouter();
  const { token, orgId, branchId } = useOrgBranch();

  const [routes, setRoutes]   = useState<Route[]>([]);
  const [meta, setMeta]       = useState<PageMeta | null>(null);
  const [loading, setLoading] = useState(false);
  const [showCreate, setShowCreate] = useState(false);

  // Stats
  const [totalCount,    setTotalCount]    = useState(0);
  const [activeCount,   setActiveCount]   = useState(0);
  const [inactiveCount, setInactiveCount] = useState(0);

  // Filters
  const [tab,    setTab]    = useState("");
  const [search, setSearch] = useState("");
  const [page,   setPage]   = useState(1);

  // Toast
  const [toast, setToast] = useState<{ type: "success" | "error"; msg: string } | null>(null);
  const showToast = (type: "success" | "error", msg: string) => {
    setToast({ type, msg });
    setTimeout(() => setToast(null), 3500);
  };

  const fetchRoutes = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const qp = new URLSearchParams();
      if (branchId) qp.set("branch_id", branchId);
      if (search)   qp.set("q", search);
      if (tab === "active")   qp.set("active", "true");
      if (tab === "inactive") qp.set("active", "false");
      qp.set("page",     String(page));
      qp.set("per_page", "25");

      const res  = await fetch(`/api/v1/routes?${qp}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) {
        const rows: Route[] = json.data ?? [];
        setRoutes(rows);
        setMeta(json.meta ?? null);
        if (!tab && !search && page === 1) {
          setTotalCount(json.meta?.total_count ?? rows.length);
          setActiveCount(rows.filter((r) => r.active).length);
          setInactiveCount(rows.filter((r) => !r.active).length);
        }
      } else {
        showToast("error", json.errors?.[0] ?? "Failed to load routes");
      }
    } catch {
      showToast("error", "Network error");
    } finally {
      setLoading(false);
    }
  }, [token, orgId, branchId, tab, search, page]);

  useEffect(() => { void fetchRoutes(); }, [fetchRoutes]);

  // ─── Columns ────────────────────────────────────────────────────────────────
  const columns: Column<Route>[] = [
    {
      key: "code",
      header: "Code",
      render: (_, row) => (
        <span className="font-mono text-sm font-semibold text-primary">
          {row.code}
        </span>
      ),
    },
    {
      key: "name",
      header: "Route Name",
      render: (_, row) => (
        <div className="flex items-center gap-2">
          <MapPin className="h-3.5 w-3.5 text-text-secondary shrink-0" />
          <span className="font-medium text-text-primary">{row.name}</span>
        </div>
      ),
    },
    {
      key: "customers_count",
      header: "Customers",
      render: (_, row) => (
        <span className="text-sm text-text-secondary">
          {row.customers_count != null ? row.customers_count : "—"}
        </span>
      ),
    },
    {
      key: "active",
      header: "Status",
      render: (_, row) => (
        <Badge variant={row.active ? "success" : "secondary"}>
          {row.active ? "Active" : "Inactive"}
        </Badge>
      ),
    },
    {
      key: "id",
      header: "",
      className: "w-20 text-right",
      render: (_, row) => (
        <Button
          size="sm"
          variant="ghost"
          onClick={(e) => {
            e.stopPropagation();
            router.push(`/routes/${row.id}`);
          }}
          className="text-xs text-primary"
        >
          View →
        </Button>
      ),
    },
  ];

  const hasSearch = !!search;

  return (
    <AppShell>
      {/* Toast */}
      {toast && (
        <div className={`fixed top-4 right-4 z-50 rounded-lg px-4 py-3 text-sm text-white shadow-lg ${
          toast.type === "success" ? "bg-success" : "bg-danger"
        }`}>
          {toast.msg}
        </div>
      )}

      <PageHeader
        title="Routes"
        description={meta ? `${meta.total_count} route${meta.total_count !== 1 ? "s" : ""}` : "Manage delivery and sales routes for your branches"}
        actions={[
          { label: "New Route", icon: Plus, onClick: () => setShowCreate(true) },
        ]}
      />

      {/* Stat cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 mb-5">
        <StatCard label="Total Routes" value={totalCount}    icon={RouteIcon}    accent="bg-primary/10 text-primary" />
        <StatCard label="Active"       value={activeCount}   icon={CheckCircle2} accent="bg-accent/20 text-[#1B4332]" />
        <StatCard label="Inactive"     value={inactiveCount} icon={MapPin}       accent="bg-background-subtle text-text-secondary" />
      </div>

      {/* Filter tabs */}
      <div className="flex items-center gap-1 mb-4 border-b border-border">
        {FILTER_TABS.map((t) => (
          <button
            key={t.key}
            onClick={() => { setTab(t.key); setPage(1); }}
            className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors ${
              tab === t.key
                ? "border-primary text-primary"
                : "border-transparent text-text-secondary hover:text-text-primary"
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Search bar */}
      <div className="flex items-center gap-2 mb-4">
        <div className="relative flex-1 max-w-sm">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary" />
          <Input
            placeholder="Search by name or code…"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            className="pl-9"
          />
        </div>
        {hasSearch && (
          <Button variant="ghost" size="sm" onClick={() => { setSearch(""); setPage(1); }} className="gap-1 text-text-secondary">
            <X className="h-3.5 w-3.5" /> Clear
          </Button>
        )}
      </div>

      {/* Table or empty state */}
      {!loading && routes.length === 0 ? (
        <EmptyState
          icon={MapPin}
          title={hasSearch ? "No routes match your search" : tab ? `No ${tab} routes` : "No routes yet"}
          description={
            hasSearch
              ? "Try a different search term."
              : tab
              ? undefined
              : "Create a route to organise your customers by delivery area or sales territory."
          }
          action={
            !hasSearch && !tab
              ? { label: "New Route", onClick: () => setShowCreate(true) }
              : undefined
          }
        />
      ) : (
        <DataTable
          columns={columns}
          data={routes}
          isLoading={loading}
          onRowClick={(row) => router.push(`/routes/${row.id}`)}
        />
      )}

      {/* Pagination */}
      {meta && meta.total_pages > 1 && routes.length > 0 && (
        <div className="mt-4 flex items-center justify-between text-sm text-text-secondary">
          <span>Page {meta.current_page} of {meta.total_pages} · {meta.total_count} routes</span>
          <div className="flex gap-2">
            <Button variant="outline" size="sm" disabled={meta.current_page <= 1}              onClick={() => setPage(p => p - 1)}>Previous</Button>
            <Button variant="outline" size="sm" disabled={meta.current_page >= meta.total_pages} onClick={() => setPage(p => p + 1)}>Next</Button>
          </div>
        </div>
      )}

      <CreateRouteModal
        open={showCreate}
        onClose={() => setShowCreate(false)}
        onCreated={() => {
          setShowCreate(false);
          fetchRoutes();
          showToast("success", "Route created successfully");
        }}
      />
    </AppShell>
  );
}
