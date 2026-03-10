"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { Input } from "@/components/ui/input";
import { PackageX, RotateCcw, Clock, TrendingDown, Search } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";

// ─── Types ────────────────────────────────────────────────────────────────────

interface RejectionRecord {
  id: number;
  qty_rejected: number;
  reason_code: string;
  condition: string;
  notes: string | null;
  auto_return: boolean;
  created_at: string;
  product: { id: number; name: string; sku: string };
  order: { id: number; order_number: string; customer_name: string };
  trip: { id: number; trip_number: string; trip_date: string };
  rejected_by: { id: number; name: string };
  return_request_id: number | null;
}

interface RejectionSummary {
  total_rejections: number;
  by_reason: Record<string, number>;
  auto_return_count: number;
  pending_return_count: number;
  total_qty_rejected: number;
}

interface PageMeta {
  current_page: number;
  total_pages: number;
  total_count: number;
  per_page: number;
  summary?: RejectionSummary;
}

// ─── Constants ────────────────────────────────────────────────────────────────

const REASON_TABS = [
  { key: "",                label: "All" },
  { key: "customer_refused", label: "Refused" },
  { key: "quality_issue",    label: "Quality" },
  { key: "damaged",          label: "Damaged" },
  { key: "expired",          label: "Expired" },
  { key: "wrong_item",       label: "Wrong Item" },
  { key: "short_supply",     label: "Short Supply" },
];

const REASON_VARIANT: Record<string, "default" | "secondary" | "warning" | "success" | "danger" | "outline"> = {
  customer_refused: "warning",
  quality_issue:    "danger",
  damaged:          "danger",
  expired:          "danger",
  wrong_item:       "secondary",
  short_supply:     "outline",
  other:            "secondary",
};

const fmt = (n: number) =>
  new Intl.NumberFormat("en-IN", { maximumFractionDigits: 2 }).format(n);

// ─── Page ─────────────────────────────────────────────────────────────────────

export default function DeliveryRejectionsPage() {
  const router = useRouter();
  const { token, orgId } = useOrgBranch();

  const [rejections, setRejections] = useState<RejectionRecord[]>([]);
  const [meta, setMeta]             = useState<PageMeta | null>(null);
  const [loading, setLoading]       = useState(true);
  const [page, setPage]             = useState(1);
  const [activeTab, setActiveTab]   = useState("");
  const [pendingOnly, setPendingOnly] = useState(false);
  const [search, setSearch]         = useState("");
  const [fromDate, setFromDate]     = useState("");
  const [toDate, setToDate]         = useState("");

  const authHeaders = {
    Authorization:       `Bearer ${token}`,
    "X-Organization-Id": orgId,
  } as Record<string, string>;

  const fetchRejections = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const qp = new URLSearchParams({ page: String(page), per_page: "25" });
      if (activeTab)   qp.set("reason_code",    activeTab);
      if (pendingOnly) qp.set("pending_return",  "true");
      if (fromDate)    qp.set("from_date",       fromDate);
      if (toDate)      qp.set("to_date",         toDate);

      const res  = await fetch(`${API_URL}/api/v1/delivery_rejections?${qp}`, {
        headers: authHeaders,
      });
      const json = await res.json();
      if (res.ok) {
        setRejections(json.data ?? []);
        setMeta(json.meta ?? null);
      }
    } finally {
      setLoading(false);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, orgId, page, activeTab, pendingOnly, fromDate, toDate]);

  useEffect(() => { void fetchRejections(); }, [fetchRejections]);

  const summary = meta?.summary;

  const topReason = summary?.by_reason
    ? Object.entries(summary.by_reason).sort(([, a], [, b]) => b - a)[0]?.[0]?.replace(/_/g, " ") ?? "—"
    : "—";

  const statCards = [
    {
      label: "Total Rejections",
      value: summary?.total_rejections ?? 0,
      icon:  PackageX,
      color: "text-red-500",
    },
    {
      label: "Qty Rejected",
      value: summary ? fmt(summary.total_qty_rejected) : "—",
      icon:  TrendingDown,
      color: "text-amber-500",
    },
    {
      label: "Auto-Return Triggered",
      value: summary?.auto_return_count ?? 0,
      icon:  RotateCcw,
      color: "text-blue-500",
    },
    {
      label: "Pending Return",
      value: summary?.pending_return_count ?? 0,
      icon:  Clock,
      color: "text-orange-500",
    },
  ];

  // Client-side search filter on customer name / product name / order number
  const filtered = search
    ? rejections.filter((r) => {
        const q = search.toLowerCase();
        return (
          r.order.customer_name.toLowerCase().includes(q) ||
          r.order.order_number.toLowerCase().includes(q) ||
          r.product.name.toLowerCase().includes(q) ||
          r.product.sku.toLowerCase().includes(q)
        );
      })
    : rejections;

  const columns: Column<RejectionRecord>[] = [
    {
      key: "created_at",
      header: "Date",
      render: (_c, r) =>
        new Date(r.created_at).toLocaleDateString("en-IN", {
          day: "2-digit", month: "short", year: "numeric",
        }),
    },
    {
      key: "trip",
      header: "Trip",
      render: (_c, r) => (
        <button
          onClick={() => router.push(`/delivery/${r.trip.id}`)}
          className="font-mono text-sm text-accent hover:underline"
        >
          {r.trip.trip_number}
        </button>
      ),
    },
    {
      key: "order",
      header: "Order / Customer",
      render: (_c, r) => (
        <div>
          <p className="text-sm font-medium">{r.order.customer_name}</p>
          <p className="font-mono text-xs text-text-secondary">{r.order.order_number}</p>
        </div>
      ),
    },
    {
      key: "product",
      header: "Product",
      render: (_c, r) => (
        <div>
          <p className="text-sm font-medium">{r.product.name}</p>
          <p className="font-mono text-xs text-text-secondary">{r.product.sku}</p>
        </div>
      ),
    },
    {
      key: "qty_rejected",
      header: "Qty",
      render: (_c, r) => (
        <span className="tabular-nums font-semibold text-destructive">
          {fmt(r.qty_rejected)}
        </span>
      ),
    },
    {
      key: "reason_code",
      header: "Reason",
      render: (_c, r) => (
        <Badge variant={REASON_VARIANT[r.reason_code] ?? "secondary"}>
          {r.reason_code.replace(/_/g, " ")}
        </Badge>
      ),
    },
    {
      key: "condition",
      header: "Condition",
      render: (_c, r) => (
        <span className="text-xs capitalize text-text-secondary">{r.condition}</span>
      ),
    },
    {
      key: "auto_return",
      header: "Return",
      render: (_c, r) =>
        r.auto_return ? (
          r.return_request_id ? (
            <Badge variant="success" className="text-xs">RR #{r.return_request_id}</Badge>
          ) : (
            <Badge variant="warning" className="text-xs">Pending</Badge>
          )
        ) : (
          <span className="text-xs text-text-secondary">—</span>
        ),
    },
    {
      key: "rejected_by",
      header: "By",
      render: (_c, r) => (
        <span className="text-xs text-text-secondary">{r.rejected_by.name}</span>
      ),
    },
  ];

  return (
    <AppShell
      breadcrumbs={[
        { label: "Delivery", href: "/delivery" },
        { label: "Rejections" },
      ]}
    >
      <div className="max-w-7xl space-y-5">
        <PageHeader
          title="Delivery Rejections"
          subtitle="Items rejected at the point of delivery across all trips"
        />

        {/* Summary cards */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
          {statCards.map((s) => (
            <Card key={s.label} className="border border-border shadow-none">
              <CardContent className="flex items-center gap-3 py-4 px-4">
                <s.icon className={`h-5 w-5 shrink-0 ${s.color}`} />
                <div>
                  <p className="text-xs text-text-secondary">{s.label}</p>
                  <p className="text-xl font-bold tabular-nums">{s.value}</p>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>

        {/* Top reason pill */}
        {summary && summary.total_rejections > 0 && (
          <p className="text-xs text-text-secondary">
            Top rejection reason: <span className="font-semibold capitalize">{topReason}</span>
          </p>
        )}

        {/* Reason tabs */}
        <div className="border-b flex gap-1 overflow-x-auto">
          {REASON_TABS.map((t) => (
            <button
              key={t.key}
              onClick={() => { setActiveTab(t.key); setPage(1); }}
              className={`px-4 py-2 text-sm font-medium whitespace-nowrap border-b-2 transition-colors ${
                activeTab === t.key
                  ? "border-primary text-primary"
                  : "border-transparent text-text-secondary hover:text-text-primary"
              }`}
            >
              {t.label}
              {t.key && summary?.by_reason?.[t.key] ? (
                <span className="ml-1.5 text-xs text-text-secondary">
                  ({summary.by_reason[t.key]})
                </span>
              ) : null}
            </button>
          ))}
        </div>

        {/* Filters */}
        <div className="flex flex-wrap items-center gap-3">
          <div className="relative flex-1 min-w-48">
            <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-text-secondary pointer-events-none" />
            <input
              className="w-full pl-8 pr-3 py-2 text-sm border border-border rounded-md bg-background focus:outline-none focus:ring-2 focus:ring-primary"
              placeholder="Search customer, order, product…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <Input
            type="date"
            label=""
            placeholder="From"
            value={fromDate}
            onChange={(e) => { setFromDate(e.target.value); setPage(1); }}
            className="w-36"
          />
          <Input
            type="date"
            label=""
            placeholder="To"
            value={toDate}
            onChange={(e) => { setToDate(e.target.value); setPage(1); }}
            className="w-36"
          />
          <label className="flex items-center gap-1.5 text-sm cursor-pointer select-none">
            <input
              type="checkbox"
              checked={pendingOnly}
              onChange={(e) => { setPendingOnly(e.target.checked); setPage(1); }}
              className="rounded border-border"
            />
            Pending return only
          </label>
        </div>

        {/* Table */}
        {loading ? (
          <p className="text-sm text-text-secondary py-8 text-center">Loading rejections…</p>
        ) : filtered.length === 0 ? (
          <EmptyState
            icon={PackageX}
            title="No rejections found"
            description="No delivery rejections match your current filters."
          />
        ) : (
          <>
            <DataTable columns={columns} data={filtered} />

            {/* Pagination */}
            {meta && meta.total_pages > 1 && (
              <div className="flex items-center justify-between text-sm text-text-secondary pt-2">
                <span>
                  Page {meta.current_page} of {meta.total_pages} ·{" "}
                  {meta.total_count} total
                </span>
                <div className="flex gap-2">
                  <button
                    disabled={page <= 1}
                    onClick={() => setPage((p) => p - 1)}
                    className="px-3 py-1 rounded border border-border hover:bg-muted/40 disabled:opacity-40"
                  >
                    Prev
                  </button>
                  <button
                    disabled={page >= meta.total_pages}
                    onClick={() => setPage((p) => p + 1)}
                    className="px-3 py-1 rounded border border-border hover:bg-muted/40 disabled:opacity-40"
                  >
                    Next
                  </button>
                </div>
              </div>
            )}
          </>
        )}
      </div>
    </AppShell>
  );
}
