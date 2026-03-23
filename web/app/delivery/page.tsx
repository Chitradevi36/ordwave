"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { EmptyState } from "@/components/ui/empty-state";
import { Modal } from "@/components/ui/modal";
import { API_URL } from "@/lib/api/client";
import {
  Plus, Search, Truck, CheckCircle,
  Clock, XCircle, Wand2,
} from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { dispatchEvents } from "@/lib/analytics";

// ─── Types ───────────────────────────────────────────────────────────────────
interface TripSummary {
  id: number;
  trip_number: string;
  trip_date: string;
  status: string;
  stops_count: number;
  branch: { id: number; name: string };
  vehicle: { id: number; registration_number: string; vehicle_type: string } | null;
  driver: { id: number; name: string } | null;
  dispatched_at: string | null;
  completed_at: string | null;
  created_at: string;
}

interface PageMeta {
  current_page: number; total_pages: number; total_count: number; per_page: number;
  counts?: Record<string, number>;
}

// ─── Constants ────────────────────────────────────────────────────────────────
const STATUS_TABS = [
  { key: "", label: "All" },
  { key: "draft", label: "Draft" },
  { key: "planned", label: "Planned" },
  { key: "dispatched", label: "Dispatched" },
  { key: "completed", label: "Completed" },
  { key: "cancelled", label: "Cancelled" },
];

const STATUS_VARIANT: Record<string, "default" | "secondary" | "warning" | "success" | "danger" | "outline"> = {
  draft:      "secondary",
  planned:    "default",
  dispatched: "warning",
  completed:  "success",
  cancelled:  "outline",
};

// ─── Page ────────────────────────────────────────────────────────────────────
export default function DeliveryTripsPage() {
  const router = useRouter();
  const { token, orgId } = useOrgBranch();

  const [trips, setTrips]     = useState<TripSummary[]>([]);
  const [meta, setMeta]       = useState<PageMeta | null>(null);
  const [loading, setLoading] = useState(true);
  const [page, setPage]       = useState(1);
  const [activeTab, setActiveTab] = useState("");
  const [search, setSearch]   = useState("");
  const [fromDate, setFromDate] = useState("");
  const [toDate, setToDate]     = useState("");

  // Cancel modal
  const [cancelling, setCancelling] = useState<TripSummary | null>(null);
  const [cancelReason, setCancelReason] = useState("");
  const [cancelLoading, setCancelLoading] = useState(false);

  // Auto-create modal
  const [showAutoCreate, setShowAutoCreate] = useState(false);
  const [autoDate, setAutoDate]             = useState(new Date().toISOString().slice(0, 10));
  const [autoBranchId, setAutoBranchId]     = useState("");
  const [autoCreating, setAutoCreating]     = useState(false);
  const [autoResult, setAutoResult]         = useState<{ created: number; skipped: string[] } | null>(null);
  const [branches, setBranches]             = useState<{ id: number; name: string }[]>([]);

  const fetchTrips = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const qp = new URLSearchParams({ page: String(page), per_page: "25" });
      if (activeTab) qp.set("status",    activeTab);
      if (fromDate)  qp.set("from_date", fromDate);
      if (toDate)    qp.set("to_date",   toDate);
      if (search.trim()) qp.set("q",      search.trim());

      const res  = await fetch(`${API_URL}/api/v1/delivery_trips?${qp}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) {
        setTrips(json.data ?? []);
        setMeta(json.meta ?? null);
        // Track dispatch view if this is the initial load or after search
        if (search.trim()) {
          // Search was performed
          // We'll track this separately
        }
      }
    } finally {
      setLoading(false);
    }
  }, [token, orgId, page, activeTab, fromDate, toDate, search]);

  useEffect(() => { void fetchTrips(); }, [fetchTrips]);

  // ── Cancel trip ──────────────────────────────────────────────────────────
  async function handleCancel() {
    if (!cancelling || !cancelReason.trim()) return;
    setCancelLoading(true);
    try {
      const res = await fetch(`${API_URL}/api/v1/delivery_trips/${cancelling.id}/cancel`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token!}`,
          "X-Organization-Id": orgId!,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ delivery_trip: { cancellation_reason: cancelReason } }),
      });
      if (res.ok) { setCancelling(null); setCancelReason(""); void fetchTrips(); }
    } finally {
      setCancelLoading(false);
    }
  }

  // ── Auto-create trips ─────────────────────────────────────────────────────
  function openAutoCreate() {
    setAutoDate(new Date().toISOString().slice(0, 10));
    setAutoBranchId("");
    setAutoResult(null);
    setShowAutoCreate(true);
    if (!branches.length) {
      fetch(`${API_URL}/api/v1/branches?per_page=100`, {
        headers: { Authorization: `Bearer ${token!}`, "X-Organization-Id": orgId! },
      }).then((r) => r.json()).then((d) => setBranches(d.data ?? []));
    }
  }

  async function handleAutoCreate() {
    setAutoCreating(true);
    setAutoResult(null);
    try {
      const body: Record<string, string> = { trip_date: autoDate };
      if (autoBranchId) body.branch_id = autoBranchId;
      const res = await fetch(`${API_URL}/api/v1/delivery_trips/auto_create`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token!}`,
          "X-Organization-Id": orgId!,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      });
      const json = await res.json();
      if (res.ok) {
        setAutoResult({
          created: json.meta?.trips_created ?? 0,
          skipped: json.meta?.skipped_branches ?? [],
        });
        void fetchTrips();
      }
    } finally {
      setAutoCreating(false);
    }
  }

  // ── Dispatch trip ────────────────────────────────────────────────────────
  async function handleDispatch(trip: TripSummary) {
    const res = await fetch(`${API_URL}/api/v1/delivery_trips/${trip.id}/dispatch`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token!}`, "X-Organization-Id": orgId! },
    });
    if (res.ok) void fetchTrips();
  }

  // ── Summary stat ─────────────────────────────────────────────────────────
  const counts = meta?.counts ?? {};
  const statCards = [
    { label: "Draft",      value: counts["draft"]      ?? 0, icon: Clock,        color: "text-text-secondary" },
    { label: "Dispatched", value: counts["dispatched"] ?? 0, icon: Truck,        color: "text-amber-500" },
    { label: "Completed",  value: counts["completed"]  ?? 0, icon: CheckCircle,  color: "text-green-600" },
    { label: "Cancelled",  value: counts["cancelled"]  ?? 0, icon: XCircle,      color: "text-red-500"   },
  ];

  // ── Columns ───────────────────────────────────────────────────────────────
  const columns: Column<TripSummary>[] = [
    {
      key: "trip_number",
      header: "Trip",
      render: (_cell, t) => (
        <button
          onClick={() => router.push(`/delivery/${t.id}`)}
          className="font-mono text-sm font-semibold text-accent hover:underline"
        >
          {t.trip_number}
        </button>
      ),
    },
    {
      key: "trip_date",
      header: "Date",
      render: (_cell, t) => new Date(t.trip_date).toLocaleDateString("en-IN"),
    },
    {
      key: "status",
      header: "Status",
      render: (_cell, t) => (
        <Badge variant={STATUS_VARIANT[t.status] ?? "secondary"}>
          {t.status.replace("_", " ")}
        </Badge>
      ),
    },
    {
      key: "branch",
      header: "Branch",
      render: (_cell, t) => t.branch.name,
    },
    {
      key: "vehicle",
      header: "Vehicle",
      render: (_cell, t) =>
        t.vehicle ? (
          <span className="text-sm">{t.vehicle.registration_number}</span>
        ) : (
          <span className="text-xs text-text-secondary">—</span>
        ),
    },
    {
      key: "driver",
      header: "Driver",
      render: (_cell, t) =>
        t.driver ? (
          <span className="text-sm">{t.driver.name}</span>
        ) : (
          <span className="text-xs text-text-secondary">—</span>
        ),
    },
    {
      key: "stops_count",
      header: "Stops",
      render: (_cell, t) => <span className="tabular-nums">{t.stops_count}</span>,
    },
    {
      key: "id",
      header: "",
      render: (_cell, t) => (
        <div className="flex gap-2 justify-end">
          {(t.status === "draft" || t.status === "planned") && (
            <Button size="sm" variant="outline" onClick={() => handleDispatch(t)}>
              Dispatch
            </Button>
          )}
          {(t.status === "draft" || t.status === "planned" || t.status === "dispatched") && (
            <Button
              size="sm"
              variant="outline"
              className="text-red-600 border-red-200 hover:bg-red-50"
              onClick={() => { setCancelling(t); setCancelReason(""); }}
            >
              Cancel
            </Button>
          )}
        </div>
      ),
    },
  ];

  return (
    <AppShell>
      <PageHeader
        title="Delivery Trips"
        subtitle="Plan, dispatch and track delivery routes"
        actions={[
          {
            label: "Auto-Create Trips",
            icon: <Wand2 className="h-4 w-4" />,
            onClick: openAutoCreate,
            variant: "outline" as const,
          },
          {
            label: "New Trip",
            icon: <Plus className="h-4 w-4" />,
            onClick: () => router.push("/delivery/new"),
          },
        ]}
      />

      {/* Summary cards */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 mb-6">
        {statCards.map((s) => (
          <div key={s.label} className="bg-background rounded-xl border border-border p-4 flex items-center gap-3 hover:shadow-sm transition-shadow">
            <s.icon className={`h-5 w-5 shrink-0 ${s.color}`} />
            <div>
              <p className="text-xs text-text-secondary">{s.label}</p>
              <p className="text-xl font-bold text-text-primary tabular-nums">{s.value}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3 mb-4">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary" />
          <Input
            placeholder="Search trip…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9 w-48"
          />
        </div>
        <Input type="date" value={fromDate} onChange={(e) => setFromDate(e.target.value)} className="w-36" />
        <Input type="date" value={toDate}   onChange={(e) => setToDate(e.target.value)}   className="w-36" />
      </div>

      {/* Status tabs */}
      <div className="flex gap-1 mb-4 border-b border-border">
        {STATUS_TABS.map((tab) => (
          <button
            key={tab.key}
            onClick={() => { setActiveTab(tab.key); setPage(1); }}
            className={`px-3 py-2 text-sm font-medium border-b-2 transition-colors ${
              activeTab === tab.key
                ? "border-accent text-accent"
                : "border-transparent text-text-secondary hover:text-text-primary"
            }`}
          >
            {tab.label}
            {counts[tab.key] !== undefined && tab.key !== "" && (
              <span className="ml-1.5 rounded-full bg-background-subtle px-1.5 py-0.5 text-xs tabular-nums">
                {counts[tab.key]}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Table */}
      {loading ? (
        <div className="text-center py-12 text-text-secondary">Loading…</div>
      ) : trips.length === 0 ? (
        <EmptyState
          icon={<Truck className="h-10 w-10 text-text-secondary" />}
          title="No trips found"
          description="Create a new delivery trip to get started."
          action={
            <Button onClick={() => router.push("/delivery/new")}>
              <Plus className="mr-2 h-4 w-4" /> New Trip
            </Button>
          }
        />
      ) : (
        <DataTable columns={columns} data={trips} />
      )}

      {/* Pagination */}
      {meta && meta.total_pages > 1 && (
        <div className="flex justify-center gap-2 mt-6">
          <Button variant="outline" size="sm" disabled={page <= 1} onClick={() => setPage(page - 1)}>
            Previous
          </Button>
          <span className="text-sm text-text-secondary px-2 py-1.5">
            {page} / {meta.total_pages}
          </span>
          <Button variant="outline" size="sm" disabled={page >= meta.total_pages} onClick={() => setPage(page + 1)}>
            Next
          </Button>
        </div>
      )}

      {/* Cancel modal */}
      <Modal
        open={!!cancelling}
        onClose={() => setCancelling(null)}
        title="Cancel Trip"
      >
        <div className="space-y-4">
          <p className="text-sm text-text-secondary">
            Cancel trip <span className="font-semibold">{cancelling?.trip_number}</span>? All dispatched orders will be reverted to Approved.
          </p>
          <div>
            <label className="text-sm font-medium text-text-primary block mb-1">Reason *</label>
            <textarea
              className="w-full rounded-md border border-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-accent"
              rows={3}
              placeholder="e.g. Vehicle breakdown"
              value={cancelReason}
              onChange={(e) => setCancelReason(e.target.value)}
            />
          </div>
          <div className="flex justify-end gap-2">
            <Button variant="outline" onClick={() => setCancelling(null)}>Back</Button>
            <Button
              variant="danger"
              disabled={!cancelReason.trim() || cancelLoading}
              onClick={handleCancel}
            >
              {cancelLoading ? "Cancelling…" : "Cancel Trip"}
            </Button>
          </div>
        </div>
      </Modal>

      {/* Auto-Create Trips modal */}
      <Modal
        open={showAutoCreate}
        onClose={() => setShowAutoCreate(false)}
        title="Auto-Create Delivery Trips"
      >
        <div className="space-y-4">
          <p className="text-sm text-text-secondary">
            Groups all approved orders by branch for the selected date and creates one trip per branch,
            auto-assigning the first available vehicle and driver.
          </p>

          <div>
            <label className="text-sm font-medium text-text-primary block mb-1">Trip Date *</label>
            <input
              type="date"
              className="w-full rounded-md border border-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-accent"
              value={autoDate}
              onChange={(e) => setAutoDate(e.target.value)}
            />
          </div>

          <div>
            <label className="text-sm font-medium text-text-primary block mb-1">Branch (optional)</label>
            <select
              className="w-full rounded-md border border-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-accent"
              value={autoBranchId}
              onChange={(e) => setAutoBranchId(e.target.value)}
            >
              <option value="">All branches</option>
              {branches.map((b) => (
                <option key={b.id} value={b.id}>{b.name}</option>
              ))}
            </select>
          </div>

          {autoResult && (
            <div className={`rounded-md p-3 text-sm ${autoResult.created > 0 ? "bg-green-50 border border-green-200 text-green-700" : "bg-amber-50 border border-amber-200 text-amber-700"}`}>
              {autoResult.created > 0
                ? <p><span className="font-semibold">{autoResult.created} trip{autoResult.created !== 1 ? "s" : ""} created!</span></p>
                : <p>No new trips created.</p>
              }
              {autoResult.skipped.length > 0 && (
                <p className="mt-1 text-xs">Skipped (already exists or no orders): {autoResult.skipped.join(", ")}</p>
              )}
            </div>
          )}

          <div className="flex justify-end gap-2">
            {autoResult
              ? <Button onClick={() => setShowAutoCreate(false)}>Done</Button>
              : (
                <>
                  <Button variant="outline" onClick={() => setShowAutoCreate(false)}>Cancel</Button>
                  <Button onClick={handleAutoCreate} disabled={autoCreating || !autoDate}>
                    {autoCreating ? "Creating…" : "Auto-Create"}
                  </Button>
                </>
              )
            }
          </div>
        </div>
      </Modal>
    </AppShell>
  );
}
