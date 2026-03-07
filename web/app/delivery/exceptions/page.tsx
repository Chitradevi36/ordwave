"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { AlertTriangle, XCircle, TrendingDown, Search } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";

interface ExceptionStop {
  id: number;
  sequence: number;
  status: string;
  exception_code: string;
  delivery_notes: string | null;
  delivered_at: string | null;
  trip: { id: number; trip_number: string; trip_date: string; status: string };
  order: { id: number; order_number: string; customer_name: string; total_amount: number };
}

interface ExceptionSummary {
  total_exceptions: number;
  by_code: Record<string, number>;
  failed_stops: number;
}

interface PageMeta {
  current_page: number; total_pages: number; total_count: number; per_page: number;
  summary?: ExceptionSummary;
}

const STATUS_VARIANT: Record<string, "default" | "secondary" | "warning" | "success" | "danger" | "outline"> = {
  pending:          "secondary",
  delivered:        "success",
  partial_delivery: "warning",
  failed:           "danger",
  skipped:          "outline",
};

const EXCEPTION_TABS = [
  { key: "", label: "All" },
  { key: "failed", label: "Failed" },
  { key: "partial_delivery", label: "Partial" },
];

export default function DeliveryExceptionsPage() {
  const router = useRouter();
  const { token, orgId } = useOrgBranch();

  const [exceptions, setExceptions] = useState<ExceptionStop[]>([]);
  const [meta, setMeta]             = useState<PageMeta | null>(null);
  const [loading, setLoading]       = useState(true);
  const [page, setPage]             = useState(1);
  const [activeTab, setActiveTab]   = useState("");
  const [exceptionCode, setExceptionCode] = useState("");
  const [fromDate, setFromDate]     = useState("");
  const [toDate, setToDate]         = useState("");

  const authHeaders = {
    Authorization: `Bearer ${token}`,
    "X-Organization-Id": orgId,
  } as Record<string, string>;

  const fetchExceptions = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const qp = new URLSearchParams({ page: String(page), per_page: "25" });
      if (activeTab)     qp.set("status",         activeTab);
      if (exceptionCode) qp.set("exception_code", exceptionCode);
      if (fromDate)      qp.set("from_date",       fromDate);
      if (toDate)        qp.set("to_date",         toDate);

      const res  = await fetch(`${API_URL}/api/v1/delivery_exceptions?${qp}`, { headers: authHeaders });
      const json = await res.json();
      if (res.ok) { setExceptions(json.data ?? []); setMeta(json.meta ?? null); }
    } finally {
      setLoading(false);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, orgId, page, activeTab, exceptionCode, fromDate, toDate]);

  useEffect(() => { void fetchExceptions(); }, [fetchExceptions]);

  const summary = meta?.summary;

  const statCards = [
    {
      label: "Total Exceptions",
      value: summary?.total_exceptions ?? 0,
      icon:  AlertTriangle,
      color: "text-amber-500",
    },
    {
      label: "Failed Stops",
      value: summary?.failed_stops ?? 0,
      icon:  XCircle,
      color: "text-red-500",
    },
    {
      label: "Top Reason",
      value: summary?.by_code
        ? Object.entries(summary.by_code).sort(([, a], [, b]) => b - a)[0]?.[0]?.replace(/_/g, " ") ?? "—"
        : "—",
      icon:  TrendingDown,
      color: "text-text-secondary",
    },
  ];

  const columns: Column<ExceptionStop>[] = [
    {
      key: "trip",
      header: "Trip",
      render: (_cell, e) => (
        <button
          onClick={() => router.push(`/delivery/${e.trip.id}`)}
          className="font-mono text-sm text-accent hover:underline"
        >
          {e.trip.trip_number}
        </button>
      ),
    },
    {
      key: "trip",
      header: "Date",
      render: (_cell, e) => new Date(e.trip.trip_date).toLocaleDateString("en-IN"),
    },
    {
      key: "order",
      header: "Order / Customer",
      render: (_cell, e) => (
        <div>
          <p className="text-sm font-medium">{e.order.customer_name}</p>
          <p className="font-mono text-xs text-text-secondary">{e.order.order_number}</p>
        </div>
      ),
    },
    {
      key: "status",
      header: "Stop Status",
      render: (_cell, e) => (
        <Badge variant={STATUS_VARIANT[e.status] ?? "secondary"}>
          {e.status.replace("_", " ")}
        </Badge>
      ),
    },
    {
      key: "exception_code",
      header: "Exception",
      render: (_cell, e) => (
        <Badge variant="warning" className="text-xs">
          {e.exception_code.replace(/_/g, " ")}
        </Badge>
      ),
    },
    {
      key: "delivery_notes",
      header: "Notes",
      render: (_cell, e) => (
        <span className="text-xs text-text-secondary line-clamp-1">
          {e.delivery_notes ?? "—"}
        </span>
      ),
    },
    {
      key: "order",
      header: "Order Value",
      render: (_cell, e) => (
        <span className="tabular-nums text-sm">
          ₹{Number(e.order.total_amount).toLocaleString("en-IN", { maximumFractionDigits: 0 })}
        </span>
      ),
    },
  ];

  return (
    <AppShell>
      <PageHeader
        title="Delivery Exceptions"
        subtitle="Stops with failed, partial, or problematic deliveries"
      />

      {/* Summary cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-6">
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

      {/* Filters */}
      <div className="flex flex-wrap gap-3 mb-4">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary" />
          <Input
            placeholder="Exception code…"
            value={exceptionCode}
            onChange={(e) => setExceptionCode(e.target.value)}
            className="pl-9 w-48"
          />
        </div>
        <Input type="date" value={fromDate} onChange={(e) => setFromDate(e.target.value)} className="w-36" />
        <Input type="date" value={toDate}   onChange={(e) => setToDate(e.target.value)}   className="w-36" />
      </div>

      {/* Tabs */}
      <div className="flex gap-1 mb-4 border-b border-border">
        {EXCEPTION_TABS.map((tab) => (
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
          </button>
        ))}
      </div>

      {/* Table */}
      {loading ? (
        <div className="text-center py-12 text-text-secondary">Loading…</div>
      ) : exceptions.length === 0 ? (
        <EmptyState
          icon={<AlertTriangle className="h-10 w-10 text-text-secondary" />}
          title="No exceptions found"
          description="All stops are on track."
        />
      ) : (
        <DataTable columns={columns} data={exceptions} />
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
    </AppShell>
  );
}
