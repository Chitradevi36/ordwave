"use client";

import { useState, useEffect, useCallback } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";
import { RefreshCw, Package, AlertTriangle, TrendingUp } from "lucide-react";

function fmt(n: number | undefined | null, prefix = "") {
  if (n == null) return "—";
  return `${prefix}${Number(n).toLocaleString("en-IN")}`;
}

interface LowStockItem {
  id: number;
  product_id: number;
  product_name: string;
  product_sku: string;
  qty_on_hand: number;
  qty_reserved: number;
  qty_available: number;
  min_qty_threshold: number;
}

interface DeadStockItem {
  id: number;
  product_id: number;
  product_name: string;
  product_sku: string;
  qty_on_hand: number;
  qty_reserved: number;
}

interface FastMovingItem {
  id: number;
  name: string;
  sku: string;
  total_qty: number;
  total_value: number;
}

interface InventoryData {
  summary?: {
    low_stock_count?: number;
    dead_stock_count?: number;
    total_skus?: number;
    zero_stock_count?: number;
  };
  low_stock?: LowStockItem[];
  dead_stock?: DeadStockItem[];
  fast_moving?: FastMovingItem[];
}

const lowStockColumns: Column<LowStockItem>[] = [
  { key: "product_name", header: "Product" },
  { key: "product_sku",  header: "SKU" },
  { key: "qty_on_hand",  header: "On Hand",   render: (v) => fmt(v as number) },
  { key: "qty_reserved", header: "Reserved",  render: (v) => fmt(v as number) },
  { key: "qty_available", header: "Available", render: (v) => (
    <span className={(v as number) <= 0 ? "text-error font-semibold" : "text-warning font-semibold"}>
      {fmt(v as number)}
    </span>
  )},
  { key: "min_qty_threshold", header: "Reorder Level", render: (v) => fmt(v as number) },
  { key: "product_id",  header: "Status",    render: (_, row) => (
    <Badge variant={row.qty_available <= 0 ? "danger" : "warning"}>
      {row.qty_available <= 0 ? "Out of Stock" : "Low"}
    </Badge>
  )},
];

const deadStockColumns: Column<DeadStockItem>[] = [
  { key: "product_name", header: "Product" },
  { key: "product_sku",  header: "SKU" },
  { key: "qty_on_hand",  header: "On Hand",   render: (v) => fmt(v as number) },
  { key: "qty_reserved", header: "Reserved",  render: (v) => fmt(v as number) },
  { key: "product_id",   header: "Status",    render: () => <Badge variant="secondary">No Sales (90d)</Badge> },
];

const fastMovingColumns: Column<FastMovingItem>[] = [
  { key: "name",        header: "Product" },
  { key: "sku",         header: "SKU" },
  { key: "total_qty",   header: "Qty Sold (30d)", render: (v) => fmt(v as number) },
  { key: "total_value", header: "Revenue (30d)",  render: (v) => fmt(v as number, "₹") },
];

export default function InsightsInventoryPage() {
  const { token, orgId, branches } = useOrgBranch();
  const [data, setData] = useState<InventoryData | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [branchId, setBranchId] = useState("");

  const fetchData = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const qp = new URLSearchParams();
      if (branchId) qp.set("branch_id", branchId);
      const res = await fetch(`${API_URL}/api/v1/analytics/inventory_health?${qp}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      if (!res.ok) throw new Error("Failed to load inventory data");
      const json = await res.json();
      setData(json.data);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  }, [token, orgId, branchId]);

  useEffect(() => { void fetchData(); }, [fetchData]);

  const s = data?.summary;
  const statCards = [
    { label: "Total SKUs",       value: fmt(s?.total_skus),         icon: Package,       color: "text-text-secondary" },
    { label: "Zero Stock",       value: fmt(s?.zero_stock_count),   icon: AlertTriangle, color: "text-error" },
    { label: "Low Stock",        value: fmt(s?.low_stock_count),    icon: AlertTriangle, color: "text-warning" },
    { label: "Dead Stock",       value: fmt(s?.dead_stock_count),   icon: Package,       color: "text-orange-500" },
    { label: "Fast Moving (30d)", value: fmt(data?.fast_moving?.length), icon: TrendingUp, color: "text-primary" },
  ];

  return (
    <AppShell title="Inventory Health" breadcrumbs={[
      { label: "Insights", href: "/insights" },
      { label: "Inventory" },
    ]}>
      <PageHeader
        title="Inventory Health"
        description="Low stock alerts, dead stock, and fast-moving products."
        actions={[{ label: "Refresh", onClick: fetchData, icon: RefreshCw }]}
      />

      {/* Branch filter */}
      <div className="flex flex-wrap gap-3 px-6 mb-4">
        <select value={branchId} onChange={(e) => setBranchId(e.target.value)}
          className="h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent">
          <option value="">All Branches</option>
          {branches?.map((b: { id: number; name: string }) => (
            <option key={b.id} value={String(b.id)}>{b.name}</option>
          ))}
        </select>
      </div>

      {error && (
        <div className="mx-6 mb-4 rounded-md bg-danger/8 border border-danger/20 px-4 py-3 text-sm text-danger">{error}</div>
      )}

      {/* Stat Strip */}
      <div className="grid grid-cols-2 gap-3 px-6 mb-6 sm:grid-cols-3 lg:grid-cols-5">
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

      {/* Low Stock */}
      <div className="px-6 mb-6">
        <div className="rounded-lg border border-border overflow-hidden">
          <div className="px-4 py-3 border-b border-border bg-background-subtle flex items-center gap-2">
            <AlertTriangle className="h-4 w-4 text-warning" />
            <span className="text-sm font-medium text-text-primary">Low Stock / Out of Stock</span>
          </div>
          <DataTable columns={lowStockColumns} data={data?.low_stock ?? []} />
        </div>
      </div>

      {/* Dead Stock + Fast Moving */}
      <div className="grid grid-cols-1 gap-5 px-6 pb-6 lg:grid-cols-2">
        <div className="rounded-lg border border-border overflow-hidden">
          <div className="px-4 py-3 border-b border-border bg-background-subtle flex items-center gap-2">
            <Package className="h-4 w-4 text-orange-500" />
            <span className="text-sm font-medium text-text-primary">Dead Stock (No sales in 90 days)</span>
          </div>
          <DataTable columns={deadStockColumns} data={data?.dead_stock ?? []} />
        </div>
        <div className="rounded-lg border border-border overflow-hidden">
          <div className="px-4 py-3 border-b border-border bg-background-subtle flex items-center gap-2">
            <TrendingUp className="h-4 w-4 text-primary" />
            <span className="text-sm font-medium text-text-primary">Fast Moving (Last 30 days)</span>
          </div>
          <DataTable columns={fastMovingColumns} data={data?.fast_moving ?? []} />
        </div>
      </div>
    </AppShell>
  );
}
