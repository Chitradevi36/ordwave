"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import {
  Clock, CheckCircle2, AlertTriangle, Loader2,
  Activity, RefreshCw, XCircle, Search, Filter,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent } from "@/components/ui/card";
import { DataTable, Column } from "@/components/ui/data-table";
import { useOrgBranch } from "@/lib/org-branch-context";
import {
  fetchSyncRecords, fetchIntegrations,
  type AccountingSyncRecord, type SyncDashboardStats,
  type AccountingIntegration,
} from "@/lib/api/accounting";
import { SyncStatusBadge, PriorityBadge, providerLabel, fmtTimestamp, fmtDatetime } from "../_utils";

// ── Stat card ─────────────────────────────────────────────────────────────────

function StatCard({
  icon: Icon, label, value, sub, color,
}: {
  icon: React.ElementType;
  label: string;
  value: number | string;
  sub?: string;
  color: string;
}) {
  return (
    <Card>
      <CardContent className="flex items-center gap-4 p-4">
        <div className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-lg ${color}`}>
          <Icon className="h-5 w-5" />
        </div>
        <div className="min-w-0">
          <p className="text-xs text-text-secondary font-medium truncate">{label}</p>
          <p className="text-xl font-bold text-text-primary">{value}</p>
          {sub && <p className="text-xs text-text-secondary truncate">{sub}</p>}
        </div>
      </CardContent>
    </Card>
  );
}

// ── Filters bar ───────────────────────────────────────────────────────────────

const STATUS_OPTIONS  = ["", "pending", "processing", "success", "failed", "retrying", "skipped"];
const PRIORITY_OPTIONS = ["", "high", "medium", "low"];
const ENTITY_OPTIONS  = ["", "SalesInvoice", "Payment", "CreditNote", "PurchaseInvoice", "Customer", "Supplier", "Product"];

function FiltersBar({
  filters,
  integrations,
  onChange,
  onReset,
}: {
  filters: Record<string, string>;
  integrations: AccountingIntegration[];
  onChange: (key: string, val: string) => void;
  onReset: () => void;
}) {
  const [expanded, setExpanded] = useState(false);
  const activeCount = Object.values(filters).filter(Boolean).length;

  const selectCls = "h-9 rounded-md border border-border bg-background px-2 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-primary";

  return (
    <div className="bg-white rounded-lg border border-border p-3 mb-4">
      {/* Top row: search + toggle */}
      <div className="flex gap-2">
        <div className="relative flex-1">
          <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-text-secondary pointer-events-none" />
          <Input
            value={filters.q ?? ""}
            onChange={(e) => onChange("q", e.target.value)}
            placeholder="Search entity ID, idempotency key…"
            className="pl-8 h-9 text-sm"
          />
        </div>
        <Button
          size="sm"
          variant="outline"
          onClick={() => setExpanded((p) => !p)}
          className="shrink-0"
        >
          <Filter className="mr-1.5 h-3.5 w-3.5" />
          Filters
          {activeCount > 0 && (
            <span className="ml-1.5 flex h-4 w-4 items-center justify-center rounded-full bg-primary text-white text-[10px] font-bold">
              {activeCount}
            </span>
          )}
        </Button>
        {activeCount > 0 && (
          <Button size="sm" variant="ghost" onClick={onReset} className="shrink-0 text-text-secondary">
            Reset
          </Button>
        )}
      </div>

      {/* Expanded filters */}
      {expanded && (
        <div className="mt-3 grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-2">
          <select value={filters.status ?? ""} onChange={(e) => onChange("status", e.target.value)} className={selectCls}>
            <option value="">All statuses</option>
            {STATUS_OPTIONS.filter(Boolean).map((s) => <option key={s} value={s}>{s.charAt(0).toUpperCase() + s.slice(1)}</option>)}
          </select>
          <select value={filters.priority ?? ""} onChange={(e) => onChange("priority", e.target.value)} className={selectCls}>
            <option value="">All priorities</option>
            {PRIORITY_OPTIONS.filter(Boolean).map((p) => <option key={p} value={p}>{p.charAt(0).toUpperCase() + p.slice(1)}</option>)}
          </select>
          <select value={filters.entity_type ?? ""} onChange={(e) => onChange("entity_type", e.target.value)} className={selectCls}>
            <option value="">All entities</option>
            {ENTITY_OPTIONS.filter(Boolean).map((e) => <option key={e} value={e}>{e}</option>)}
          </select>
          <select value={filters.integration_id ?? ""} onChange={(e) => onChange("integration_id", e.target.value)} className={selectCls}>
            <option value="">All integrations</option>
            {integrations.map((i) => <option key={i.id} value={String(i.id)}>{providerLabel(i.provider)}</option>)}
          </select>
          <Input
            type="date"
            value={filters.date_from ?? ""}
            onChange={(e) => onChange("date_from", e.target.value)}
            placeholder="From date"
            className="h-9 text-sm"
          />
        </div>
      )}
    </div>
  );
}

// ── Page ──────────────────────────────────────────────────────────────────────

export default function SyncRecordsPage() {
  const router      = useRouter();
  const searchParams = useSearchParams();
  const { token, orgId } = useOrgBranch();

  // Initialise filters from URL query params
  const [filters, setFilters] = useState<Record<string, string>>(() => {
    const f: Record<string, string> = {};
    ["status", "priority", "entity_type", "event_type", "integration_id", "date_from", "q"].forEach((k) => {
      const v = searchParams.get(k);
      if (v) f[k] = v;
    });
    return f;
  });

  const [records, setRecords]         = useState<AccountingSyncRecord[]>([]);
  const [stats, setStats]             = useState<SyncDashboardStats | null>(null);
  const [integrations, setIntegrations] = useState<AccountingIntegration[]>([]);
  const [loading, setLoading]         = useState(true);
  const [page, setPage]               = useState(1);
  const [totalPages, setTotalPages]   = useState(1);
  const [totalCount, setTotalCount]   = useState(0);

  const load = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const [res, intgs] = await Promise.all([
        fetchSyncRecords({ ...filters, page, per_page: 25 }, token, orgId),
        integrations.length === 0 ? fetchIntegrations(token, orgId) : Promise.resolve(integrations),
      ]);
      setRecords(res.data);
      setStats(res.stats);
      setTotalPages(res.meta?.total_pages ?? 1);
      setTotalCount(res.meta?.total_count ?? 0);
      if (integrations.length === 0) setIntegrations(intgs as AccountingIntegration[]);
    } catch { /* silent */ }
    finally { setLoading(false); }
  }, [token, orgId, filters, page]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => { load(); }, [load]);
  useEffect(() => { setPage(1); }, [filters]);

  const updateFilter = (key: string, val: string) => setFilters((prev) => ({ ...prev, [key]: val }));
  const resetFilters = () => setFilters({});

  const columns: Column<AccountingSyncRecord>[] = [
    {
      key: "created_at",
      header: "Created",
      render: (_, row) => (
        <div className="text-xs text-text-secondary whitespace-nowrap">
          {fmtTimestamp(row.created_at)}
        </div>
      ),
    },
    {
      key: "provider",
      header: "Provider",
      render: (_, row) => (
        <span className="text-sm font-medium">{providerLabel(row.provider)}</span>
      ),
    },
    {
      key: "entity_type",
      header: "Entity",
      render: (_, row) => (
        <div>
          <span className="text-sm font-mono text-primary">{row.entity_type} #{row.entity_id}</span>
          <div className="text-xs text-text-secondary truncate max-w-[140px]">{row.event_type}</div>
        </div>
      ),
    },
    {
      key: "status",
      header: "Status",
      render: (_, row) => <SyncStatusBadge status={row.status} />,
    },
    {
      key: "priority",
      header: "Priority",
      render: (_, row) => <PriorityBadge priority={row.priority} />,
    },
    {
      key: "attempt_count",
      header: "Attempts",
      render: (_, row) => (
        <span className="text-sm text-text-primary">
          {row.attempt_count} / {row.max_retries}
        </span>
      ),
    },
    {
      key: "last_attempted_at",
      header: "Last Try",
      render: (_, row) => (
        <span className="text-xs text-text-secondary whitespace-nowrap">
          {fmtTimestamp(row.last_attempted_at)}
        </span>
      ),
    },
    {
      key: "error_message",
      header: "Error",
      render: (_, row) =>
        row.error_message ? (
          <span className="text-xs text-danger truncate max-w-[160px] block" title={row.error_message}>
            {row.error_message.slice(0, 60)}…
          </span>
        ) : (
          <span className="text-xs text-text-secondary">—</span>
        ),
    },
    {
      key: "actions",
      header: "",
      render: (_, row) => (
        <Button
          size="sm"
          variant="ghost"
          onClick={(e) => { e.stopPropagation(); router.push(`/accounting/sync-records/${row.id}`); }}
          className="text-primary"
        >
          View
        </Button>
      ),
    },
  ];

  return (
    <div>
      {/* ── Stats ── */}
      <div className="grid grid-cols-2 sm:grid-cols-5 gap-3 mb-5">
        <StatCard icon={Clock}         label="Pending"       value={stats?.pending    ?? 0} color="bg-yellow-50 text-warning" />
        <StatCard icon={Loader2}       label="Processing"    value={stats?.processing ?? 0} color="bg-blue-50 text-blue-600" />
        <StatCard icon={CheckCircle2}  label="Success Today" value={stats?.success_today ?? 0} color="bg-[#E8F5EE] text-accent" />
        <StatCard icon={AlertTriangle} label="Failed"        value={stats?.failed     ?? 0} color="bg-red-50 text-danger" />
        <StatCard
          icon={Activity}
          label="Last Sync"
          value={fmtTimestamp(stats?.last_sync_at ?? null)}
          color="bg-primary/10 text-primary"
        />
      </div>

      {/* ── Filters ── */}
      <FiltersBar
        filters={filters}
        integrations={integrations}
        onChange={updateFilter}
        onReset={resetFilters}
      />

      {/* ── Table ── */}
      <DataTable
        columns={columns}
        data={records}
        isLoading={loading}
        emptyMessage="No sync records found for the selected filters."
        onRowClick={(row) => router.push(`/accounting/sync-records/${row.id}`)}
        rowClassName={(row) => row.status === "failed" ? "bg-red-50/30" : undefined}
      />

      {/* ── Pagination ── */}
      {!loading && totalPages > 1 && (
        <div className="flex items-center justify-between mt-4 text-sm text-text-secondary">
          <span>{totalCount} records total</span>
          <div className="flex gap-2">
            <Button size="sm" variant="outline" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
              Previous
            </Button>
            <span className="flex items-center px-2">
              {page} / {totalPages}
            </span>
            <Button size="sm" variant="outline" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>
              Next
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
