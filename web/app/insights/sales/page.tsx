"use client";

import { useState, useEffect, useCallback } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { DataTable, Column } from "@/components/ui/data-table";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";
import { RefreshCw, TrendingUp, FileText, AlertCircle } from "lucide-react";
import {
  ResponsiveContainer, AreaChart, Area, XAxis, YAxis, CartesianGrid,
  Tooltip, BarChart, Bar, Legend, Cell,
} from "recharts";

function fmt(n: number | undefined | null, prefix = "") {
  if (n == null) return "—";
  return `${prefix}${Number(n).toLocaleString("en-IN")}`;
}

// Color palette for bars - sales theme
const RETAILER_COLORS = [
  "#3b82f6", // blue-500
  "#2563eb", // blue-600
  "#1d4ed8", // blue-700
  "#1e40af", // blue-800
  "#1e3a8a", // blue-900
  "#0369a1", // cyan-700
  "#0284c7", // cyan-600
  "#06b6d4", // cyan-500
];

const PRODUCT_COLORS = [
  "#10b981", // emerald-500
  "#059669", // emerald-600
  "#047857", // emerald-700
  "#065f46", // emerald-800
  "#064e3b", // emerald-900
  "#14b8a6", // teal-500
  "#0d9488", // teal-600
  "#0f766e", // teal-700
];

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

      {/* Trend Chart */}
      {(data?.timeseries?.length ?? 0) > 0 && (
        <div className="px-6 mb-6">
          <div className="rounded-lg border border-border bg-surface p-4">
            <p className="mb-3 text-sm font-semibold text-text-primary">Orders &amp; Invoices Trend</p>
            <ResponsiveContainer width="100%" height={260}>
              <AreaChart data={data?.timeseries ?? []} margin={{ top: 4, right: 16, left: 0, bottom: 0 }}>
                <defs>
                  <linearGradient id="gradOrders" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%"  stopColor="#3b82f6" stopOpacity={0.3} />
                    <stop offset="95%" stopColor="#3b82f6" stopOpacity={0} />
                  </linearGradient>
                  <linearGradient id="gradInvoices" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%"  stopColor="#10b981" stopOpacity={0.3} />
                    <stop offset="95%" stopColor="#10b981" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
                <XAxis
                  dataKey="period"
                  tickLine={false}
                  axisLine={false}
                  tick={{ fontSize: 11, fill: "hsl(var(--text-secondary))" }}
                  tickFormatter={(v) => String(v).slice(0, 10)}
                />
                <YAxis
                  tickLine={false}
                  axisLine={false}
                  tick={{ fontSize: 11, fill: "hsl(var(--text-secondary))" }}
                  tickFormatter={(v) => `₹${Number(v).toLocaleString("en-IN")}`}
                  width={80}
                />
                <Tooltip
                  contentStyle={{ background: "hsl(var(--surface))", border: "1px solid hsl(var(--border))", borderRadius: 6, fontSize: 12 }}
                  formatter={(v: number) => [`₹${v.toLocaleString("en-IN")}`, ""]}
                  labelFormatter={(l) => String(l).slice(0, 10)}
                />
                <Legend wrapperStyle={{ fontSize: 12 }} />
                <Area type="monotone" dataKey="orders_value"   name="Order Value"   stroke="#3b82f6" fill="url(#gradOrders)"   strokeWidth={2} dot={false} />
                <Area type="monotone" dataKey="invoices_value" name="Invoice Value" stroke="#10b981" fill="url(#gradInvoices)" strokeWidth={2} dot={false} />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}

      {/* Top Retailers + Top Products */}
      <div className="grid grid-cols-1 gap-5 px-6 pb-6 lg:grid-cols-2">
        {/* Top Retailers bar chart */}
        <div className="rounded-lg border border-border bg-surface p-4">
          <p className="mb-3 text-sm font-semibold text-text-primary">Top Retailers by Value</p>
          {(data?.top_retailers?.length ?? 0) > 0 ? (
            <ResponsiveContainer width="100%" height={220}>
              <BarChart
                data={data?.top_retailers?.slice(0, 8) ?? []}
                layout="vertical"
                margin={{ top: 0, right: 16, left: 0, bottom: 0 }}
              >
                <CartesianGrid strokeDasharray="3 3" horizontal={false} stroke="hsl(var(--border))" />
                <XAxis
                  type="number"
                  tickLine={false}
                  axisLine={false}
                  tick={{ fontSize: 10, fill: "hsl(var(--text-secondary))" }}
                  tickFormatter={(v) => `₹${(v / 1000).toFixed(0)}k`}
                />
                <YAxis
                  type="category"
                  dataKey="name"
                  tickLine={false}
                  axisLine={false}
                  tick={{ fontSize: 10, fill: "hsl(var(--text-secondary))" }}
                  width={90}
                />
                <Tooltip
                  contentStyle={{ background: "hsl(var(--surface))", border: "1px solid hsl(var(--border))", borderRadius: 6, fontSize: 12 }}
                  formatter={(v: number) => [`₹${v.toLocaleString("en-IN")}`, "Value"]}
                />
                <Bar dataKey="total_value" name="Total Value" radius={[0, 3, 3, 0]}>
                  {(data?.top_retailers?.slice(0, 8) ?? []).map((_, idx) => (
                    <Cell key={`cell-${idx}`} fill={RETAILER_COLORS[idx % RETAILER_COLORS.length]} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          ) : (
            <DataTable columns={retailerColumns} data={data?.top_retailers ?? []} />
          )}
        </div>

        {/* Top Products bar chart */}
        <div className="rounded-lg border border-border bg-surface p-4">
          <p className="mb-3 text-sm font-semibold text-text-primary">Top Products by Revenue</p>
          {(data?.top_products?.length ?? 0) > 0 ? (
            <ResponsiveContainer width="100%" height={220}>
              <BarChart
                data={data?.top_products?.slice(0, 8) ?? []}
                layout="vertical"
                margin={{ top: 0, right: 16, left: 0, bottom: 0 }}
              >
                <CartesianGrid strokeDasharray="3 3" horizontal={false} stroke="hsl(var(--border))" />
                <XAxis
                  type="number"
                  tickLine={false}
                  axisLine={false}
                  tick={{ fontSize: 10, fill: "hsl(var(--text-secondary))" }}
                  tickFormatter={(v) => `₹${(v / 1000).toFixed(0)}k`}
                />
                <YAxis
                  type="category"
                  dataKey="name"
                  tickLine={false}
                  axisLine={false}
                  tick={{ fontSize: 10, fill: "hsl(var(--text-secondary))" }}
                  width={90}
                />
                <Tooltip
                  contentStyle={{ background: "hsl(var(--surface))", border: "1px solid hsl(var(--border))", borderRadius: 6, fontSize: 12 }}
                  formatter={(v: number) => [`₹${v.toLocaleString("en-IN")}`, "Revenue"]}
                />
                <Bar dataKey="total_value" name="Revenue" radius={[0, 3, 3, 0]}>
                  {(data?.top_products?.slice(0, 8) ?? []).map((_, idx) => (
                    <Cell key={`cell-${idx}`} fill={PRODUCT_COLORS[idx % PRODUCT_COLORS.length]} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          ) : (
            <DataTable columns={productColumns} data={data?.top_products ?? []} />
          )}
        </div>
      </div>
    </AppShell>
  );
}
