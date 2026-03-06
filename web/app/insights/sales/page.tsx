"use client";

import { useState, useEffect, useCallback } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { Button } from "@/components/ui/button";
import { DataTable, Column } from "@/components/ui/data-table";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";
import { RefreshCw, TrendingUp, FileText, AlertCircle } from "lucide-react";

function fmt(n: number | undefined | null, prefix = "") {
  if (n == null) return "—";
  return `${prefix}${Number(n).toLocaleString("en-IN")}`;
}

interface Retailer { id: number; name: string; invoice_count: number; total_value: number }
interface TopProduct { id: number; name: string; sku: string; total_qty: number; total_value: number }

interface SalesData {
  orders?: { count?: number; value?: number; avg?: number };
  invoices?: { count?: number; value?: number; outstanding?: number };
  timeseries?: Array<{ period: string; orders_count: number; orders_value: number; invoices_count: number; invoices_value: number }>;
  top_retailers?: Retailer[];
  top_products?: TopProduct[];
}

const retailerColumns: Column<Retailer>[] = [
  { key: "name", header: "Retailer" },
  { key: "invoice_count", header: "Invoices", render: (v) => fmt(v as number) },
  { key: "total_value", header: "Total Value", render: (v) => fmt(v as number, "₹") },
];

const productColumns: Column<TopProduct>[] = [
  { key: "name", header: "Product" },
  { key: "sku", header: "SKU" },
  { key: "total_qty", header: "Qty Sold", render: (v) => fmt(v as number) },
  { key: "total_value", header: "Revenue", render: (v) => fmt(v as number, "₹") },
];

export default function InsightsSalesPage() {
  const { token, orgId, branches } = useOrgBranch();
  const [data, setData] = useState<SalesData | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Filters
  const [branchId, setBranchId] = useState("");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const [grouping, setGrouping] = useState("day");

  const fetchData = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const qp = new URLSearchParams({ grouping });
      if (branchId) qp.set("branch_id", branchId);
      if (dateFrom) qp.set("date_from", dateFrom);
      if (dateTo)   qp.set("date_to", dateTo);
      const res = await fetch(`${API_URL}/api/v1/analytics/sales?${qp}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      if (!res.ok) throw new Error("Failed to load sales data");
      const json = await res.json();
      setData(json.data);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  }, [token, orgId, branchId, dateFrom, dateTo, grouping]);

  useEffect(() => { void fetchData(); }, [fetchData]);

  const statCards = [
    { label: "Orders (period)",    value: fmt(data?.orders?.count),            icon: TrendingUp,  color: "text-primary" },
    { label: "Order Value",        value: fmt(data?.orders?.value, "₹"),        icon: TrendingUp,  color: "text-primary" },
    { label: "Invoices (period)",  value: fmt(data?.invoices?.count),           icon: FileText,    color: "text-secondary" },
    { label: "Invoice Value",      value: fmt(data?.invoices?.value, "₹"),      icon: FileText,    color: "text-secondary" },
    { label: "Outstanding",        value: fmt(data?.invoices?.outstanding, "₹"), icon: AlertCircle, color: "text-warning" },
    { label: "Avg Order Value",    value: fmt(data?.orders?.avg, "₹"),           icon: TrendingUp,  color: "text-accent" },
  ];

  return (
    <AppShell title="Sales Insights" breadcrumbs={[
      { label: "Insights", href: "/insights" },
      { label: "Sales" },
    ]}>
      <PageHeader
        title="Sales"
        description="Order and invoice trends for the selected period."
        actions={[{ label: "Refresh", onClick: fetchData, icon: RefreshCw }]}
      />

      {/* Filters */}
      <div className="flex flex-wrap gap-3 px-6 mb-4">
        <select
          value={branchId}
          onChange={(e) => setBranchId(e.target.value)}
          className="h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
        >
          <option value="">All Branches</option>
          {branches?.map((b: { id: number; name: string }) => (
            <option key={b.id} value={String(b.id)}>{b.name}</option>
          ))}
        </select>
        <input type="date" value={dateFrom} onChange={(e) => setDateFrom(e.target.value)}
          className="h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent" />
        <input type="date" value={dateTo} onChange={(e) => setDateTo(e.target.value)}
          className="h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent" />
        <select value={grouping} onChange={(e) => setGrouping(e.target.value)}
          className="h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent">
          <option value="day">Daily</option>
          <option value="week">Weekly</option>
          <option value="month">Monthly</option>
        </select>
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

      {/* Trend sparkline — simple bar table */}
      {(data?.timeseries?.length ?? 0) > 0 && (
        <div className="px-6 mb-6">
          <div className="rounded-lg border border-border overflow-hidden">
            <div className="px-4 py-3 border-b border-border bg-background-subtle">
              <span className="text-sm font-medium text-text-primary">Trend</span>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border">
                    <th className="px-4 py-2.5 text-left text-xs font-semibold text-text-secondary bg-background-subtle">Period</th>
                    <th className="px-4 py-2.5 text-right text-xs font-semibold text-text-secondary bg-background-subtle">Orders</th>
                    <th className="px-4 py-2.5 text-right text-xs font-semibold text-text-secondary bg-background-subtle">Order Value</th>
                    <th className="px-4 py-2.5 text-right text-xs font-semibold text-text-secondary bg-background-subtle">Invoices</th>
                    <th className="px-4 py-2.5 text-right text-xs font-semibold text-text-secondary bg-background-subtle">Invoice Value</th>
                  </tr>
                </thead>
                <tbody>
                  {data?.timeseries?.map((row) => (
                    <tr key={String(row.period)} className="border-b border-border last:border-0 hover:bg-surface">
                      <td className="px-4 py-2 font-medium">{String(row.period).slice(0, 10)}</td>
                      <td className="px-4 py-2 text-right">{fmt(row.orders_count)}</td>
                      <td className="px-4 py-2 text-right">{fmt(row.orders_value, "₹")}</td>
                      <td className="px-4 py-2 text-right">{fmt(row.invoices_count)}</td>
                      <td className="px-4 py-2 text-right">{fmt(row.invoices_value, "₹")}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* Top Retailers + Top Products */}
      <div className="grid grid-cols-1 gap-5 px-6 pb-6 lg:grid-cols-2">
        <div className="rounded-lg border border-border overflow-hidden">
          <div className="px-4 py-3 border-b border-border bg-background-subtle">
            <span className="text-sm font-medium text-text-primary">Top Retailers</span>
          </div>
          <DataTable columns={retailerColumns} data={data?.top_retailers ?? []} />
        </div>
        <div className="rounded-lg border border-border overflow-hidden">
          <div className="px-4 py-3 border-b border-border bg-background-subtle">
            <span className="text-sm font-medium text-text-primary">Top Products</span>
          </div>
          <DataTable columns={productColumns} data={data?.top_products ?? []} />
        </div>
      </div>
    </AppShell>
  );
}
