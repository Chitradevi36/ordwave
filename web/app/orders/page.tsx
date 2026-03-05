"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { EmptyState } from "@/components/ui/empty-state";
import { Card, CardContent } from "@/components/ui/card";
import {
  Plus, Search, X, SlidersHorizontal, ClipboardList,
  MoreHorizontal, CheckSquare, Square, TrendingUp,
  Clock, AlertTriangle,
} from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";

// ─── Types ────────────────────────────────────────────────────────────────────
interface OrderSummary {
  id: number;
  order_number: string;
  status: string;
  credit_decision: string | null;
  total_amount: number;
  discount_amount: number;
  delivery_date: string | null;
  submitted_at: string | null;
  created_at: string;
  customer: { id: number; name: string; code: string };
  branch: { id: number; name: string };
  created_by: { id: number; name: string };
}

interface StatusCounts {
  draft?: number;
  submitted?: number;
  on_hold?: number;
  approved?: number;
  rejected?: number;
  cancelled?: number;
  [key: string]: number | undefined;
}

interface TodayMetrics {
  today_orders: number;
  pending_approvals: number;
  on_hold: number;
  today_value: number;
}

interface PageMeta {
  current_page: number;
  total_pages: number;
  total_count: number;
  per_page: number;
  counts?: StatusCounts;
  metrics?: TodayMetrics;
}

// ─── Constants ────────────────────────────────────────────────────────────────
const STATUS_TABS = [
  { key: "",           label: "All" },
  { key: "draft",      label: "Draft" },
  { key: "submitted",  label: "Submitted" },
  { key: "on_hold",    label: "On Hold" },
  { key: "approved",   label: "Approved" },
  { key: "rejected",   label: "Rejected" },
  { key: "cancelled",  label: "Cancelled" },
];

const STATUS_VARIANT: Record<string, "default" | "secondary" | "warning" | "success" | "danger" | "outline"> = {
  draft:     "secondary",
  submitted: "default",
  on_hold:   "warning",
  approved:  "success",
  rejected:  "danger",
  cancelled: "outline",
};

const RISK_CONFIG: Record<string, { color: string; label: string }> = {
  hold:    { color: "bg-warning",  label: "Credit Hold" },
  blocked: { color: "bg-danger",   label: "Credit Blocked" },
};

// ─── Helpers ──────────────────────────────────────────────────────────────────
function fmtINR(n: number) {
  return `₹${n.toLocaleString("en-IN", { maximumFractionDigits: 0 })}`;
}

function fmtDate(d: string | null) {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

function relativeTime(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1)  return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24)  return `${hrs}h ago`;
  if (hrs < 48)  return "Yesterday";
  return new Date(iso).toLocaleDateString("en-IN", { day: "2-digit", month: "short" });
}

// ─── Stat Card ────────────────────────────────────────────────────────────────
function StatCard({
  label, value, sub, icon: Icon, accent,
}: {
  label: string;
  value: string | number;
  sub?: string;
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
          {sub && <p className="text-xs text-text-secondary mt-0.5">{sub}</p>}
        </div>
      </CardContent>
    </Card>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function OrdersPage() {
  const router = useRouter();
  const { token, orgId, branches } = useOrgBranch();

  const [orders, setOrders]   = useState<OrderSummary[]>([]);
  const [meta, setMeta]       = useState<PageMeta | null>(null);
  const [loading, setLoading] = useState(false);

  // Filters
  const [tab,          setTab]          = useState("");
  const [search,       setSearch]       = useState("");
  const [branchFilter, setBranchFilter] = useState("");
  const [minValue,     setMinValue]     = useState("");
  const [maxValue,     setMaxValue]     = useState("");
  const [dateFrom,     setDateFrom]     = useState("");
  const [dateTo,       setDateTo]       = useState("");
  const [showFilters,  setShowFilters]  = useState(false);
  const [page,         setPage]         = useState(1);

  // Selection & action menu
  const [selectedIds,  setSelectedIds]  = useState<Set<number>>(new Set());
  const [actionMenuId, setActionMenuId] = useState<number | null>(null);

  const [toast, setToast] = useState<{ type: "success" | "error"; msg: string } | null>(null);

  const showToast = (type: "success" | "error", msg: string) => {
    setToast({ type, msg });
    setTimeout(() => setToast(null), 3500);
  };

  // Close action dropdown on outside click
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (!(e.target as HTMLElement).closest("[data-action-menu]")) {
        setActionMenuId(null);
      }
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, []);

  const hasActiveFilters = !!(branchFilter || minValue || maxValue || dateFrom || dateTo);

  const clearAll = () => {
    setSearch(""); setBranchFilter(""); setMinValue(""); setMaxValue("");
    setDateFrom(""); setDateTo(""); setPage(1);
  };

  const fetchOrders = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const qp = new URLSearchParams();
      if (tab)          qp.set("status",     tab);
      if (search)       qp.set("q",          search);
      if (branchFilter) qp.set("branch_id",  branchFilter);
      if (minValue)     qp.set("min_value",  minValue);
      if (maxValue)     qp.set("max_value",  maxValue);
      if (dateFrom)     qp.set("date_from",  dateFrom);
      if (dateTo)       qp.set("date_to",    dateTo);
      qp.set("page",     String(page));
      qp.set("per_page", "25");

      const res  = await fetch(`http://localhost:3001/api/v1/sales_orders?${qp}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) {
        setOrders(json.data ?? []);
        setMeta(json.meta ?? null);
      } else {
        showToast("error", json.errors?.[0] ?? "Failed to load orders");
      }
    } finally {
      setLoading(false);
    }
  }, [token, orgId, tab, search, branchFilter, minValue, maxValue, dateFrom, dateTo, page]);

  useEffect(() => { void fetchOrders(); }, [fetchOrders]);

  // ─── Actions ────────────────────────────────────────────────────────────────
  const handleApprove = useCallback(async (id: number) => {
    setActionMenuId(null);
    const res = await fetch(`http://localhost:3001/api/v1/sales_orders/${id}/approve`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token!}`,
        "X-Organization-Id": orgId!,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ decision: "approved" }),
    });
    if (res.ok) {
      showToast("success", "Order approved");
      void fetchOrders();
    } else {
      const j = await res.json();
      showToast("error", j.errors?.[0] ?? "Approve failed");
    }
  }, [token, orgId, fetchOrders]);

  const handleCancel = useCallback(async (id: number) => {
    setActionMenuId(null);
    const res = await fetch(`http://localhost:3001/api/v1/sales_orders/${id}/cancel`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token!}`,
        "X-Organization-Id": orgId!,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ reason: "Cancelled via orders list" }),
    });
    if (res.ok) {
      showToast("success", "Order cancelled");
      void fetchOrders();
    } else {
      const j = await res.json();
      showToast("error", j.errors?.[0] ?? "Cancel failed");
    }
  }, [token, orgId, fetchOrders]);

  const handleHold = useCallback(async (id: number) => {
    setActionMenuId(null);
    const res = await fetch(`http://localhost:3001/api/v1/sales_orders/${id}/hold`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token!}`,
        "X-Organization-Id": orgId!,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ reason: "Placed on hold via orders list" }),
    });
    if (res.ok) {
      showToast("success", "Order placed on hold");
      void fetchOrders();
    } else {
      const j = await res.json();
      showToast("error", j.errors?.[0] ?? "Hold failed");
    }
  }, [token, orgId, fetchOrders]);

  const handleBulkApprove = async () => {
    await Promise.all(Array.from(selectedIds).map(id => handleApprove(id)));
    setSelectedIds(new Set());
  };

  const handleBulkCancel = async () => {
    await Promise.all(Array.from(selectedIds).map(id => handleCancel(id)));
    setSelectedIds(new Set());
  };

  // ─── Selection helpers ───────────────────────────────────────────────────
  const toggleSelect = (id: number) => {
    setSelectedIds(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  };

  const allSelected = orders.length > 0 && orders.every(o => selectedIds.has(o.id));

  const toggleAll = () => {
    if (allSelected) setSelectedIds(new Set());
    else             setSelectedIds(new Set(orders.map(o => o.id)));
  };

  // ─── Columns ────────────────────────────────────────────────────────────────
  const columns: Column<OrderSummary>[] = [
    {
      key:       "select",
      header:    "",
      className: "w-10",
      render:    (_, o) => (
        <div onClick={e => e.stopPropagation()} className="flex justify-center">
          <button onClick={() => toggleSelect(o.id)} className="text-text-secondary hover:text-primary">
            {selectedIds.has(o.id)
              ? <CheckSquare className="h-4 w-4 text-primary" />
              : <Square      className="h-4 w-4" />}
          </button>
        </div>
      ),
    },
    {
      key:       "risk",
      header:    "Risk",
      className: "w-24",
      render:    (_, o) => {
        if (!o.credit_decision || o.credit_decision === "ok") {
          return <span className="text-text-secondary text-xs">—</span>;
        }
        const cfg = RISK_CONFIG[o.credit_decision];
        return (
          <div className="flex items-center gap-1.5" title={cfg?.label ?? o.credit_decision}>
            <span className={`inline-block h-2 w-2 rounded-full ${cfg?.color ?? "bg-text-secondary"}`} />
            <span className="text-xs text-text-secondary capitalize">{o.credit_decision.replace("_", " ")}</span>
          </div>
        );
      },
    },
    {
      key:    "order_number",
      header: "Order #",
      render: (_, o) => (
        <button
          onClick={() => router.push(`/orders/${o.id}`)}
          className="font-mono text-sm text-primary hover:underline"
        >
          {o.order_number}
        </button>
      ),
    },
    {
      key:    "customer",
      header: "Customer / Branch",
      render: (_, o) => (
        <div>
          <p className="text-sm font-medium">{o.customer.name}</p>
          <p className="text-xs text-text-secondary">{o.customer.code} · {o.branch.name}</p>
        </div>
      ),
    },
    {
      key:    "status",
      header: "Status",
      render: (_, o) => (
        <Badge variant={STATUS_VARIANT[o.status] ?? "secondary"}>
          {o.status.replace("_", " ")}
        </Badge>
      ),
    },
    {
      key:    "total_amount",
      header: "Total",
      render: (_, o) => (
        <span className={`text-sm ${o.total_amount >= 10000 ? "font-bold text-text-primary" : "font-medium"}`}>
          {fmtINR(o.total_amount)}
        </span>
      ),
    },
    {
      key:    "delivery_date",
      header: "Delivery",
      render: (_, o) => (
        <span className={`text-sm ${o.delivery_date ? "" : "text-text-secondary italic"}`}>
          {o.delivery_date ? fmtDate(o.delivery_date) : "Not scheduled"}
        </span>
      ),
    },
    {
      key:    "created_by",
      header: "Sales Rep",
      render: (_, o) => <span className="text-sm">{o.created_by?.name ?? "—"}</span>,
    },
    {
      key:    "created_at",
      header: "Created",
      render: (_, o) => (
        <span className="text-sm text-text-secondary" title={fmtDate(o.created_at)}>
          {relativeTime(o.created_at)}
        </span>
      ),
    },
    {
      key:       "actions",
      header:    "",
      className: "w-12",
      render:    (_, o) => (
        <div
          className="relative"
          data-action-menu
          onClick={e => e.stopPropagation()}
        >
          <button
            onClick={() => setActionMenuId(actionMenuId === o.id ? null : o.id)}
            className="inline-flex h-7 w-7 items-center justify-center rounded-md hover:bg-background-subtle text-text-secondary"
            title="Actions"
          >
            <MoreHorizontal className="h-4 w-4" />
          </button>

          {actionMenuId === o.id && (
            <div className="absolute right-0 z-30 mt-1 w-44 rounded-lg border border-border bg-white shadow-lg py-1 text-sm">
              <button
                onClick={() => { router.push(`/orders/${o.id}`); setActionMenuId(null); }}
                className="w-full text-left px-3 py-2 hover:bg-background-subtle"
              >
                View order
              </button>

              {o.status === "draft" && (
                <button
                  onClick={() => { router.push(`/orders/${o.id}/edit`); setActionMenuId(null); }}
                  className="w-full text-left px-3 py-2 hover:bg-background-subtle"
                >
                  Edit draft
                </button>
              )}

              {["submitted", "on_hold"].includes(o.status) && (
                <button
                  onClick={() => handleApprove(o.id)}
                  className="w-full text-left px-3 py-2 hover:bg-background-subtle text-success font-medium"
                >
                  Approve
                </button>
              )}

              {o.status === "submitted" && (
                <button
                  onClick={() => handleHold(o.id)}
                  className="w-full text-left px-3 py-2 hover:bg-background-subtle text-warning font-medium"
                >
                  Put on hold
                </button>
              )}

              {!["cancelled", "rejected", "approved"].includes(o.status) && (
                <>
                  <div className="my-1 border-t border-border" />
                  <button
                    onClick={() => handleCancel(o.id)}
                    className="w-full text-left px-3 py-2 hover:bg-background-subtle text-danger"
                  >
                    Cancel order
                  </button>
                </>
              )}
            </div>
          )}
        </div>
      ),
    },
  ];

  const counts  = meta?.counts  ?? {};
  const metrics = meta?.metrics;

  const tabCount = (key: string): number | undefined => {
    if (!key)           return meta?.total_count;
    return counts[key];
  };

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
        title="Sales Orders"
        description={meta ? `${meta.total_count} order${meta.total_count !== 1 ? "s" : ""}` : undefined}
        actions={[
          { label: "New Order", icon: Plus, onClick: () => router.push("/orders/new") },
        ]}
      />

      {/* Summary bar */}
      {metrics && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-5">
          <StatCard
            label="Orders Today"
            value={metrics.today_orders}
            icon={ClipboardList}
            accent="bg-primary/10 text-primary"
          />
          <StatCard
            label="Pending Approval"
            value={metrics.pending_approvals}
            sub="submitted + on hold"
            icon={Clock}
            accent="bg-warning/10 text-warning"
          />
          <StatCard
            label="On Hold"
            value={metrics.on_hold}
            sub="credit review"
            icon={AlertTriangle}
            accent="bg-danger/10 text-danger"
          />
          <StatCard
            label="Today's Value"
            value={fmtINR(metrics.today_value)}
            icon={TrendingUp}
            accent="bg-success/10 text-success"
          />
        </div>
      )}

      {/* Status tabs */}
      <div className="flex items-center gap-1 border-b border-border mb-4 overflow-x-auto">
        {STATUS_TABS.map((t) => {
          const n = tabCount(t.key);
          return (
            <button
              key={t.key}
              onClick={() => { setTab(t.key); setPage(1); setSelectedIds(new Set()); }}
              className={`flex items-center gap-1.5 px-4 py-2 text-sm font-medium whitespace-nowrap transition-colors ${
                tab === t.key
                  ? "border-b-2 border-primary text-primary"
                  : "text-text-secondary hover:text-text-primary"
              }`}
            >
              {t.label}
              {n !== undefined && n > 0 && (
                <span className={`inline-flex items-center justify-center rounded-full min-w-[18px] px-1 py-0.5 text-[10px] font-medium ${
                  tab === t.key
                    ? "bg-primary/10 text-primary"
                    : "bg-background-subtle text-text-secondary"
                }`}>
                  {n}
                </span>
              )}
            </button>
          );
        })}
      </div>

      {/* Search + filter toggle */}
      <div className="flex items-center gap-2 mb-3 flex-wrap">
        <div className="relative flex-1 min-w-[180px] max-w-sm">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary" />
          <Input
            placeholder="Search order # or customer…"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            className="pl-9"
          />
        </div>

        <Button
          variant={showFilters ? "default" : "outline"}
          size="sm"
          onClick={() => setShowFilters(v => !v)}
          className="gap-1.5"
        >
          <SlidersHorizontal className="h-4 w-4" />
          Filters
          {hasActiveFilters && (
            <span className="ml-1 inline-flex h-4 w-4 items-center justify-center rounded-full bg-white/30 text-[10px] font-bold">●</span>
          )}
        </Button>

        {(search || hasActiveFilters) && (
          <Button variant="ghost" size="sm" onClick={clearAll} className="gap-1 text-text-secondary">
            <X className="h-3.5 w-3.5" /> Clear all
          </Button>
        )}
      </div>

      {/* Expanded filter bar */}
      {showFilters && (
        <div className="flex items-end gap-3 mb-4 p-3 rounded-lg border border-border bg-background-subtle flex-wrap">
          <div className="min-w-[180px]">
            <label className="text-xs font-medium text-text-secondary mb-1 block">Branch</label>
            <select
              value={branchFilter}
              onChange={e => { setBranchFilter(e.target.value); setPage(1); }}
              className="w-full rounded-md border border-border px-2 py-1.5 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-primary"
            >
              <option value="">All branches</option>
              {branches.map(b => (
                <option key={b.id} value={String(b.id)}>{b.name}</option>
              ))}
            </select>
          </div>

          <div className="min-w-[120px]">
            <label className="text-xs font-medium text-text-secondary mb-1 block">Min value (₹)</label>
            <Input
              type="number"
              placeholder="0"
              value={minValue}
              onChange={e => { setMinValue(e.target.value); setPage(1); }}
              className="text-sm"
            />
          </div>

          <div className="min-w-[120px]">
            <label className="text-xs font-medium text-text-secondary mb-1 block">Max value (₹)</label>
            <Input
              type="number"
              placeholder="∞"
              value={maxValue}
              onChange={e => { setMaxValue(e.target.value); setPage(1); }}
              className="text-sm"
            />
          </div>

          <div className="min-w-[150px]">
            <label className="text-xs font-medium text-text-secondary mb-1 block">From date</label>
            <Input
              type="date"
              value={dateFrom}
              onChange={e => { setDateFrom(e.target.value); setPage(1); }}
              className="text-sm"
            />
          </div>

          <div className="min-w-[150px]">
            <label className="text-xs font-medium text-text-secondary mb-1 block">To date</label>
            <Input
              type="date"
              value={dateTo}
              onChange={e => { setDateTo(e.target.value); setPage(1); }}
              className="text-sm"
            />
          </div>

          {hasActiveFilters && (
            <Button
              variant="ghost"
              size="sm"
              className="text-text-secondary self-end"
              onClick={() => { setBranchFilter(""); setMinValue(""); setMaxValue(""); setDateFrom(""); setDateTo(""); setPage(1); }}
            >
              <X className="h-3.5 w-3.5 mr-1" /> Reset
            </Button>
          )}
        </div>
      )}

      {/* Bulk action bar */}
      {selectedIds.size > 0 && (
        <div className="flex items-center gap-3 rounded-lg border border-primary/20 bg-primary/5 px-4 py-2.5 mb-3 text-sm">
          <CheckSquare className="h-4 w-4 text-primary shrink-0" />
          <span className="font-medium text-primary">{selectedIds.size} selected</span>
          <div className="h-4 w-px bg-border" />
          <Button size="sm" onClick={handleBulkApprove}>Approve selected</Button>
          <Button size="sm" variant="outline" onClick={handleBulkCancel}>Cancel selected</Button>
          <Button
            size="sm"
            variant="ghost"
            className="text-text-secondary ml-auto"
            onClick={() => setSelectedIds(new Set())}
          >
            Clear selection
          </Button>
        </div>
      )}

      {/* Select-all hint */}
      {orders.length > 0 && (
        <div className="flex items-center gap-2 mb-1 px-1">
          <button
            onClick={toggleAll}
            className="flex items-center gap-1.5 text-xs text-text-secondary hover:text-primary"
          >
            {allSelected
              ? <CheckSquare className="h-3.5 w-3.5 text-primary" />
              : <Square      className="h-3.5 w-3.5" />
            }
            {allSelected ? "Deselect all" : `Select all ${orders.length}`}
          </button>
        </div>
      )}

      {/* Table or empty state */}
      {!loading && orders.length === 0 ? (
        <EmptyState
          icon={ClipboardList}
          title={tab ? `No ${tab.replace("_", " ")} orders` : "No orders yet"}
          description={
            search || hasActiveFilters
              ? "No orders match your current filters."
              : tab
              ? `There are no orders with status "${tab.replace("_", " ")}".`
              : "Create your first sales order to get started."
          }
          action={
            !tab && !search && !hasActiveFilters
              ? { label: "New Order", onClick: () => router.push("/orders/new") }
              : undefined
          }
        />
      ) : (
        <DataTable
          columns={columns}
          data={orders}
          isLoading={loading}
          onRowClick={(o) => router.push(`/orders/${o.id}`)}
        />
      )}

      {/* Pagination */}
      {meta && meta.total_pages > 1 && orders.length > 0 && (
        <div className="mt-4 flex items-center justify-between text-sm text-text-secondary">
          <span>
            Page {meta.current_page} of {meta.total_pages} · {meta.total_count} orders
          </span>
          <div className="flex gap-2">
            <Button
              variant="outline" size="sm"
              disabled={meta.current_page <= 1}
              onClick={() => setPage(page - 1)}
            >
              Previous
            </Button>
            <Button
              variant="outline" size="sm"
              disabled={meta.current_page >= meta.total_pages}
              onClick={() => setPage(page + 1)}
            >
              Next
            </Button>
          </div>
        </div>
      )}
    </AppShell>
  );
}
