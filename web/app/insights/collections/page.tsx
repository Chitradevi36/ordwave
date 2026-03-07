"use client";

import { useState, useEffect, useCallback } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { Button } from "@/components/ui/button";
import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";
import { RefreshCw, Download, Wallet, AlertCircle } from "lucide-react";

function fmt(n: number | undefined | null, prefix = "") {
  if (n == null) return "—";
  return `${prefix}${Number(n).toLocaleString("en-IN")}`;
}
function fmtPct(n: number | undefined | null) {
  if (n == null) return "—";
  return `${Number(n).toFixed(1)}%`;
}

interface Collector { id: number; name: string; total_collected: number; payment_count: number }
interface UnpaidInvoice {
  id: number;
  invoice_number: string;
  customer_name: string;
  invoice_date: string;
  due_date: string;
  grand_total: number;
  outstanding_amount: number;
  paid_amount: number;
}
interface CollectionsData {
  summary?: {
    payments_today?: number;
    payments_mtd?: number;
    payments_period?: number;
    unpaid_invoices_count?: number;
    unpaid_invoices_value?: number;
    collection_rate?: number;
  };
  timeseries?: Array<{ period: string; amount: number; count: number }>;
  top_collectors?: Collector[];
  unpaid_invoices?: UnpaidInvoice[];
}

const collectorColumns: Column<Collector>[] = [
  { key: "name",            header: "Rep" },
  { key: "payment_count",   header: "Payments",   render: (v) => fmt(v as number) },
  { key: "total_collected", header: "Collected",  render: (v) => fmt(v as number, "₹") },
];

const invoiceColumns: Column<UnpaidInvoice>[] = [
  { key: "invoice_number",    header: "Invoice #" },
  { key: "customer_name",     header: "Customer" },
  { key: "invoice_date",      header: "Date",      render: (v) => String(v).slice(0, 10) },
  { key: "due_date",          header: "Due",       render: (v) => v ? String(v).slice(0, 10) : "—" },
  { key: "grand_total",       header: "Total",     render: (v) => fmt(v as number, "₹") },
  { key: "outstanding_amount", header: "Outstanding", render: (v) => (
    <span className="font-semibold text-error">{fmt(v as number, "₹")}</span>
  )},
  { key: "paid_amount",       header: "Paid",      render: (v) => fmt(v as number, "₹") },
  { key: "id",                header: "Status",    render: (_, row) => (
    <Badge variant={row.outstanding_amount > 0 ? "warning" : "success"}>
      {row.outstanding_amount > 0 ? "Unpaid" : "Paid"}
    </Badge>
  )},
];

export default function InsightsCollectionsPage() {
  const { token, orgId, branches } = useOrgBranch();
  const [data, setData] = useState<CollectionsData | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [meta, setMeta] = useState<{ total_count?: number; total_pages?: number; current_page?: number } | null>(null);

  const [branchId, setBranchId] = useState("");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const [page, setPage] = useState(1);

  const fetchData = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const qp = new URLSearchParams({ page: String(page) });
      if (branchId) qp.set("branch_id", branchId);
      if (dateFrom) qp.set("date_from", dateFrom);
      if (dateTo)   qp.set("date_to", dateTo);
      const res = await fetch(`${API_URL}/api/v1/analytics/collections?${qp}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      if (!res.ok) throw new Error("Failed to load collections data");
      const json = await res.json();
      setData(json.data);
      setMeta(json.meta ?? null);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  }, [token, orgId, branchId, dateFrom, dateTo, page]);

  useEffect(() => { void fetchData(); }, [fetchData]);

  const handleExport = () => {
    if (!token || !orgId) return;
    const qp = new URLSearchParams();
    if (branchId) qp.set("branch_id", branchId);
    if (dateFrom) qp.set("date_from", dateFrom);
    if (dateTo)   qp.set("date_to", dateTo);
    window.location.href = `${API_URL}/api/v1/analytics/collections/export?${qp}`;
  };

  const s = data?.summary;
  const statCards = [
    { label: "Collected Today",     value: fmt(s?.payments_today, "₹"),         icon: Wallet,       color: "text-primary" },
    { label: "MTD Collections",     value: fmt(s?.payments_mtd, "₹"),            icon: Wallet,       color: "text-secondary" },
    { label: "Period Collections",  value: fmt(s?.payments_period, "₹"),         icon: Wallet,       color: "text-accent" },
    { label: "Collection Rate",     value: fmtPct(s?.collection_rate),           icon: Wallet,       color: "text-success" },
    { label: "Unpaid Count",        value: fmt(s?.unpaid_invoices_count),        icon: AlertCircle,  color: "text-warning" },
    { label: "Unpaid Value",        value: fmt(s?.unpaid_invoices_value, "₹"),   icon: AlertCircle,  color: "text-error" },
  ];

  return (
    <AppShell title="Collections Insights" breadcrumbs={[
      { label: "Insights", href: "/insights" },
      { label: "Collections" },
    ]}>
      <PageHeader
        title="Collections"
        description="Payment collections and outstanding invoice tracking."
        actions={[
          { label: "Export CSV", onClick: handleExport, icon: Download },
          { label: "Refresh",    onClick: fetchData,    icon: RefreshCw },
        ]}
      />

      {/* Filters */}
      <div className="flex flex-wrap gap-3 px-6 mb-4">
        <select value={branchId} onChange={(e) => setBranchId(e.target.value)}
          className="h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent">
          <option value="">All Branches</option>
          {branches?.map((b: { id: number; name: string }) => (
            <option key={b.id} value={String(b.id)}>{b.name}</option>
          ))}
        </select>
        <input type="date" value={dateFrom} onChange={(e) => setDateFrom(e.target.value)}
          className="h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent" />
        <input type="date" value={dateTo} onChange={(e) => setDateTo(e.target.value)}
          className="h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent" />
      </div>

      {error && (
        <div className="mx-6 mb-4 rounded-md bg-danger/8 border border-danger/20 px-4 py-3 text-sm text-danger">{error}</div>
      )}

      {/* Stat Strip */}
      <div className="grid grid-cols-2 gap-3 px-6 mb-6 sm:grid-cols-3 lg:grid-cols-6">
        {statCards.map((s) => {
          const Icon = s.icon;
          return (
            <div key={s.label} className="rounded-lg border border-border bg-surface px-4 py-3">
              <div className="flex items-center justify-between mb-1">
                <span className="text-xs font-medium text-text-secondary">{s.label}</span>
                <Icon className={`h-3.5 w-3.5 ${s.color}`} />
              </div>
              {loading
                ? <span className="block h-4 w-16 animate-pulse rounded bg-border" />
                : <p className="text-lg font-bold text-text-primary">{s.value}</p>}
            </div>
          );
        })}
      </div>

      {/* Top Collectors + Trend */}
      <div className="grid grid-cols-1 gap-5 px-6 mb-6 lg:grid-cols-2">
        <div className="rounded-lg border border-border overflow-hidden">
          <div className="px-4 py-3 border-b border-border bg-background-subtle">
            <span className="text-sm font-medium text-text-primary">Top Collectors</span>
          </div>
          <DataTable columns={collectorColumns} data={data?.top_collectors ?? []} />
        </div>
        <div className="rounded-lg border border-border overflow-hidden">
          <div className="px-4 py-3 border-b border-border bg-background-subtle">
            <span className="text-sm font-medium text-text-primary">Daily Trend</span>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border">
                  <th className="px-4 py-2.5 text-left text-xs font-semibold text-text-secondary bg-background-subtle">Date</th>
                  <th className="px-4 py-2.5 text-right text-xs font-semibold text-text-secondary bg-background-subtle">Payments</th>
                  <th className="px-4 py-2.5 text-right text-xs font-semibold text-text-secondary bg-background-subtle">Amount</th>
                </tr>
              </thead>
              <tbody>
                {(data?.timeseries ?? []).map((row) => (
                  <tr key={String(row.period)} className="border-b border-border last:border-0 hover:bg-surface">
                    <td className="px-4 py-2 font-medium">{String(row.period).slice(0, 10)}</td>
                    <td className="px-4 py-2 text-right">{fmt(row.count)}</td>
                    <td className="px-4 py-2 text-right">{fmt(row.amount, "₹")}</td>
                  </tr>
                ))}
                {!data?.timeseries?.length && (
                  <tr><td colSpan={3} className="text-center text-text-secondary text-xs py-6">No data</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {/* Unpaid Invoices */}
      <div className="px-6 pb-6">
        <div className="rounded-lg border border-border overflow-hidden">
          <div className="px-4 py-3 border-b border-border bg-background-subtle flex items-center justify-between">
            <span className="text-sm font-medium text-text-primary">Unpaid Invoices</span>
            {meta && (
              <span className="text-xs text-text-secondary">{meta.total_count?.toLocaleString()} total</span>
            )}
          </div>
          <DataTable columns={invoiceColumns} data={data?.unpaid_invoices ?? []} />
          {meta && (meta.total_pages ?? 1) > 1 && (
            <div className="flex items-center justify-end gap-2 px-4 py-3 border-t border-border">
              <span className="text-xs text-text-secondary mr-2">{page} / {meta.total_pages}</span>
              <Button variant="outline" size="sm" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>Prev</Button>
              <Button variant="outline" size="sm" disabled={page >= (meta.total_pages ?? 1)} onClick={() => setPage((p) => p + 1)}>Next</Button>
            </div>
          )}
        </div>
      </div>
    </AppShell>
  );
}
