"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import { AppShell, PageHeader } from "@/components/layout";

import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent } from "@/components/ui/card";
import { Search, AlertTriangle, SlidersHorizontal, Plus, LayoutList, Grid3X3 } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";
import { cn } from "@/lib/utils";

// ─── Types ────────────────────────────────────────────────────────────────────
interface InventoryBalance {
  id: number;
  product_id: number;
  product_name: string;
  sku: string;
  branch_id: number;
  branch_name: string;
  qty_on_hand: number;
  qty_reserved: number;
  qty_available: number;
  min_qty_threshold: number | null;
  low_stock: boolean;
  updated_at: string;
}

interface Branch { id: number; name: string; }

function fmtQty(n: number | string | null | undefined) {
  const num = Number(n ?? 0);
  return (isNaN(num) ? 0 : num).toLocaleString("en-IN", { minimumFractionDigits: 0, maximumFractionDigits: 3 });
}

// ─── Heatmap helpers ──────────────────────────────────────────────────────────
function cellColor(qty: number | null | undefined, threshold: number | null | undefined): string {
  if (threshold == null || threshold <= 0 || qty == null) return "bg-gray-100 text-gray-500";
  const ratio = qty / threshold;
  if (ratio > 2)  return "bg-green-200 text-green-800";
  if (ratio >= 1) return "bg-yellow-200 text-yellow-800";
  return "bg-red-200 text-red-700";
}
function cellLabel(qty: number | null | undefined, threshold: number | null | undefined): string {
  if (threshold == null || threshold <= 0) return "—";
  if (qty == null) return "—";
  const ratio = qty / threshold;
  if (ratio > 2)  return "> 2×";
  if (ratio >= 1) return "1–2×";
  return "< 1×";
}

// ─── Heatmap Component ────────────────────────────────────────────────────────
function StockHeatmap({ balances }: { balances: InventoryBalance[] }) {
  const [tooltip, setTooltip] = useState<{ text: string; x: number; y: number } | null>(null);
  const router = useRouter();

  // Derive unique products and branches
  const productMap = new Map<number, { name: string; sku: string }>();
  const branchMap  = new Map<number, string>();
  balances.forEach((b) => {
    if (!productMap.has(b.product_id)) productMap.set(b.product_id, { name: b.product_name, sku: b.sku });
    if (!branchMap.has(b.branch_id))   branchMap.set(b.branch_id, b.branch_name);
  });

  const products = Array.from(productMap.entries());
  const branches  = Array.from(branchMap.entries());

  // Build lookup: `${product_id}-${branch_id}` → balance
  const lookup = new Map<string, InventoryBalance>();
  balances.forEach((b) => lookup.set(`${b.product_id}-${b.branch_id}`, b));

  if (!products.length) return <p className="text-sm text-text-secondary py-4">No data for heatmap.</p>;

  return (
    <div>
      {/* Legend */}
      <div className="flex gap-4 mb-3 text-xs">
        {[
          { color: "bg-green-200",  label: "> 2× threshold — Good" },
          { color: "bg-yellow-200", label: "1–2× threshold — OK" },
          { color: "bg-red-200",    label: "< 1× threshold — Low" },
          { color: "bg-gray-100",   label: "No threshold set" },
        ].map(({ color, label }) => (
          <span key={label} className="flex items-center gap-1.5 text-text-secondary">
            <span className={`inline-block h-3 w-5 rounded-sm ${color}`} />
            {label}
          </span>
        ))}
      </div>

      {/* Scrollable grid */}
      <div className="overflow-x-auto">
        <table className="border-collapse text-xs min-w-full">
          <thead>
            <tr>
              <th className="border border-border bg-background-subtle px-3 py-2 text-left text-xs font-semibold text-text-secondary sticky left-0 z-10 w-48">
                Product
              </th>
              {branches.map(([bid, bname]) => (
                <th key={bid} className="border border-border bg-background-subtle px-3 py-2 text-center font-semibold text-text-secondary whitespace-nowrap min-w-[100px]">
                  {bname}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {products.map(([pid, { name, sku }]) => (
              <tr key={pid} className="hover:bg-background-subtle/50">
                <td className="border border-border px-3 py-2 sticky left-0 bg-white z-10">
                  <button
                    onClick={() => router.push(`/inventory/stock/${pid}`)}
                    className="text-left text-primary hover:underline font-medium leading-tight"
                  >
                    {name}
                  </button>
                  <p className="text-text-secondary font-mono">{sku}</p>
                </td>
                {branches.map(([bid]) => {
                  const bal = lookup.get(`${pid}-${bid}`);
                  const qty = bal?.qty_on_hand;
                  const thr = bal?.min_qty_threshold;
                  const cls = cellColor(qty, thr);
                  const tip = bal
                    ? `${name} @ ${branchMap.get(bid)} — On hand: ${fmtQty(qty)}${thr ? ` | Threshold: ${fmtQty(thr)}` : ""}`
                    : `No stock record for this branch`;
                  return (
                    <td
                      key={bid}
                      className={cn("border border-border px-2 py-1.5 text-center cursor-pointer transition-opacity hover:opacity-80", cls)}
                      onMouseEnter={(e) => setTooltip({ text: tip, x: e.clientX, y: e.clientY })}
                      onMouseLeave={() => setTooltip(null)}
                      onClick={() => bal && router.push(`/inventory/stock/${pid}?branch_id=${bid}`)}
                    >
                      {qty != null ? fmtQty(qty) : "—"}
                      {thr != null && thr > 0 && (
                        <p className="text-[10px] opacity-60">{cellLabel(qty, thr)}</p>
                      )}
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Tooltip */}
      {tooltip && (
        <div
          className="fixed z-50 bg-gray-900 text-white text-xs rounded px-2 py-1.5 pointer-events-none max-w-xs"
          style={{ top: tooltip.y + 12, left: tooltip.x + 8 }}
        >
          {tooltip.text}
        </div>
      )}
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function StockOverviewPage() {
  const router  = useRouter();
  const searchParams = useSearchParams();
  const { token, orgId } = useOrgBranch();

  const [viewMode,   setViewMode]   = useState<"list" | "heatmap">("list");
  const [balances,   setBalances]   = useState<InventoryBalance[]>([]);
  const [branches,   setBranches]   = useState<Branch[]>([]);
  const [isLoading,  setIsLoading]  = useState(false);
  const [search,     setSearch]     = useState("");
  const [branchId,   setBranchId]   = useState("");
  const [lowStock,   setLowStock]   = useState(searchParams.get("filter") === "low_stock");
  const [page,       setPage]       = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalCount, setTotalCount] = useState(0);

  // Fetch branches for filter
  useEffect(() => {
    if (!token || !orgId) return;
    fetch(`${API_URL}/api/v1/branches?per_page=200`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then((r) => r.json())
      .then((j) => setBranches(j.data ?? []));
  }, [token, orgId]);

  const fetchBalances = useCallback(async () => {
    if (!token || !orgId) return;
    setIsLoading(true);
    try {
      const params = new URLSearchParams({
        page: viewMode === "heatmap" ? "1" : String(page),
        per_page: viewMode === "heatmap" ? "500" : "25",
        ...(branchId && viewMode !== "heatmap" && { branch_id: branchId }),
        ...(search    && { q: search }),
        ...(lowStock  && { low_stock: "true" }),
      });

      const res = await fetch(
        `${API_URL}/api/v1/inventory/balances?${params}`,
        { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId } }
      );
      const json = await res.json();

      setBalances(json.data ?? []);
      setTotalPages(json.meta?.total_pages ?? 1);
      setTotalCount(json.meta?.total_count ?? 0);
    } finally {
      setIsLoading(false);
    }
  }, [token, orgId, page, branchId, search, lowStock, viewMode]);

  useEffect(() => {
    setPage(1);
  }, [branchId, search, lowStock, viewMode]);

  useEffect(() => { fetchBalances(); }, [fetchBalances]);

  // ─── Columns ───────────────────────────────────────────────────────────────
  const columns: Column<InventoryBalance>[] = [
    {
      key: "product_name",
      header: "Product",
      render: (_: unknown, row: InventoryBalance) => (
        <div>
          <Link
            href={`/inventory/stock/${row.product_id}?branch_id=${row.branch_id}`}
            className="font-medium text-primary hover:underline"
            onClick={(e) => e.stopPropagation()}
          >
            {row.product_name}
          </Link>
          <p className="text-xs text-text-secondary">{row.sku}</p>
        </div>
      ),
    },
    {
      key: "branch_name",
      header: "Branch",
      render: (_: unknown, row: InventoryBalance) => <span className="text-sm">{row.branch_name}</span>,
    },
    {
      key: "qty_on_hand",
      header: "On Hand",
      render: (_: unknown, row: InventoryBalance) => <span className="font-mono text-sm">{fmtQty(row.qty_on_hand)}</span>,
    },
    {
      key: "qty_reserved",
      header: "Reserved",
      render: (_: unknown, row: InventoryBalance) => <span className="font-mono text-sm text-amber-600">{fmtQty(row.qty_reserved)}</span>,
    },
    {
      key: "qty_available",
      header: "Available",
      render: (_: unknown, row: InventoryBalance) => <span className="font-mono text-sm font-semibold">{fmtQty(row.qty_available)}</span>,
    },
    {
      key: "low_stock",
      header: "Status",
      render: (_: unknown, row: InventoryBalance) =>
        row.low_stock ? (
          <Badge variant="warning" className="flex items-center gap-1 w-fit">
            <AlertTriangle className="h-3 w-3" /> Low Stock
          </Badge>
        ) : (
          <Badge variant="success">Normal</Badge>
        ),
    },
  ];

  return (
    <AppShell>
      <PageHeader
        title="Stock Overview"
        description={`${totalCount} inventory record${totalCount !== 1 ? "s" : ""}`}
        actions={[{ label: "New Adjustment", onClick: () => router.push("/inventory/adjustments/new"), icon: Plus }]}
      />

      {/* ── Filters + view toggle ── */}
      <div className="flex flex-wrap items-center gap-3 mb-4">
        {/* Branch filter (hidden in heatmap — all branches shown by default) */}
        {viewMode === "list" && (
          <select
            value={branchId}
            onChange={(e) => setBranchId(e.target.value)}
            className="h-9 rounded-md border border-input bg-background px-3 text-sm"
          >
            <option value="">All branches</option>
            {branches.map((b) => (
              <option key={b.id} value={String(b.id)}>{b.name}</option>
            ))}
          </select>
        )}

        {/* Search */}
        <div className="relative">
          <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-text-secondary" />
          <Input
            className="pl-8 w-56"
            placeholder="Search product or SKU…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>

        {/* Low stock toggle */}
        <Button
          variant={lowStock ? "default" : "outline"}
          size="sm"
          onClick={() => setLowStock(!lowStock)}
          className="flex items-center gap-2"
        >
          <SlidersHorizontal className="h-4 w-4" />
          Low stock only
        </Button>

        {/* Spacer */}
        <div className="flex-1" />

        {/* View mode toggle */}
        <div className="flex rounded-md border border-border overflow-hidden">
          <button
            onClick={() => setViewMode("list")}
            className={cn("flex items-center gap-1.5 px-3 py-1.5 text-sm transition-colors",
              viewMode === "list" ? "bg-primary text-white" : "bg-white hover:bg-background-subtle text-text-secondary"
            )}
          >
            <LayoutList className="h-4 w-4" /> List
          </button>
          <button
            onClick={() => setViewMode("heatmap")}
            className={cn("flex items-center gap-1.5 px-3 py-1.5 text-sm transition-colors border-l border-border",
              viewMode === "heatmap" ? "bg-primary text-white" : "bg-white hover:bg-background-subtle text-text-secondary"
            )}
          >
            <Grid3X3 className="h-4 w-4" /> Heatmap
          </button>
        </div>
      </div>

      {/* ── Content ── */}
      {viewMode === "list" ? (
        <>
          <DataTable
            columns={columns}
            data={balances}
            isLoading={isLoading}
            emptyMessage="No inventory records found."
            onRowClick={(row) => router.push(`/inventory/stock/${row.product_id}?branch_id=${row.branch_id}`)}
          />
          {totalPages > 1 && (
            <div className="mt-4 flex items-center justify-between text-sm text-text-secondary">
              <span>Page {page} of {totalPages}</span>
              <div className="flex gap-2">
                <Button variant="outline" size="sm" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>Previous</Button>
                <Button variant="outline" size="sm" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>Next</Button>
              </div>
            </div>
          )}
        </>
      ) : (
        <Card className="border border-border">
          <CardContent className="p-4">
            {isLoading ? (
              <p className="text-sm text-text-secondary">Loading heatmap…</p>
            ) : (
              <StockHeatmap balances={balances} />
            )}
          </CardContent>
        </Card>
      )}
    </AppShell>
  );
}


import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Search, AlertTriangle, SlidersHorizontal, Plus } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";

// ─── Types ────────────────────────────────────────────────────────────────────
interface InventoryBalance {
  id: number;
  product_id: number;
  product_name: string;
  sku: string;
  branch_id: number;
  branch_name: string;
  qty_on_hand: number;
  qty_reserved: number;
  qty_available: number;
  min_qty_threshold: number | null;
  low_stock: boolean;
  updated_at: string;
}

interface Branch { id: number; name: string; }

function fmtQty(n: number | string | null | undefined) {
  const num = Number(n ?? 0);
  return (isNaN(num) ? 0 : num).toLocaleString("en-IN", { minimumFractionDigits: 0, maximumFractionDigits: 3 });
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function StockOverviewPage() {
  const router = useRouter();
  const { token, orgId } = useOrgBranch();

  const [balances,   setBalances]   = useState<InventoryBalance[]>([]);
  const [branches,   setBranches]   = useState<Branch[]>([]);
  const [isLoading,  setIsLoading]  = useState(false);
  const [search,     setSearch]     = useState("");
  const [branchId,   setBranchId]   = useState("");
  const [lowStock,   setLowStock]   = useState(false);
  const [page,       setPage]       = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalCount, setTotalCount] = useState(0);

  // Fetch branches for filter
  useEffect(() => {
    if (!token || !orgId) return;
    fetch(`${API_URL}/api/v1/branches?per_page=200`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then((r) => r.json())
      .then((j) => setBranches(j.data ?? []));
  }, [token, orgId]);

  const fetchBalances = useCallback(async () => {
    if (!token || !orgId) return;
    setIsLoading(true);
    try {
      const params = new URLSearchParams({
        page: String(page),
        per_page: "25",
        ...(branchId   && { branch_id: branchId }),
        ...(search     && { q: search }),
        ...(lowStock   && { low_stock: "true" }),
      });

      const res = await fetch(
        `${API_URL}/api/v1/inventory/balances?${params}`,
        { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId } }
      );
      const json = await res.json();

      setBalances(json.data ?? []);
      setTotalPages(json.meta?.total_pages ?? 1);
      setTotalCount(json.meta?.total_count ?? 0);
    } finally {
      setIsLoading(false);
    }
  }, [token, orgId, page, branchId, search, lowStock]);

  useEffect(() => {
    setPage(1);
  }, [branchId, search, lowStock]);

  useEffect(() => { fetchBalances(); }, [fetchBalances]);

  // ─── Columns ───────────────────────────────────────────────────────────────
  const columns: Column<InventoryBalance>[] = [
    {
      key: "product_name",
      header: "Product",
      render: (_: unknown, row: InventoryBalance) => (
        <div>
          <Link
            href={`/inventory/stock/${row.product_id}?branch_id=${row.branch_id}`}
            className="font-medium text-primary hover:underline"
            onClick={(e) => e.stopPropagation()}
          >
            {row.product_name}
          </Link>
          <p className="text-xs text-text-secondary">{row.sku}</p>
        </div>
      ),
    },
    {
      key: "branch_name",
      header: "Branch",
      render: (_: unknown, row: InventoryBalance) => <span className="text-sm">{row.branch_name}</span>,
    },
    {
      key: "qty_on_hand",
      header: "On Hand",
      render: (_: unknown, row: InventoryBalance) => <span className="font-mono text-sm">{fmtQty(row.qty_on_hand)}</span>,
    },
    {
      key: "qty_reserved",
      header: "Reserved",
      render: (_: unknown, row: InventoryBalance) => <span className="font-mono text-sm text-amber-600">{fmtQty(row.qty_reserved)}</span>,
    },
    {
      key: "qty_available",
      header: "Available",
      render: (_: unknown, row: InventoryBalance) => <span className="font-mono text-sm font-semibold">{fmtQty(row.qty_available)}</span>,
    },
    {
      key: "low_stock",
      header: "Status",
      render: (_: unknown, row: InventoryBalance) =>
        row.low_stock ? (
          <Badge variant="warning" className="flex items-center gap-1 w-fit">
            <AlertTriangle className="h-3 w-3" /> Low Stock
          </Badge>
        ) : (
          <Badge variant="success">Normal</Badge>
        ),
    },
  ];

  return (
    <AppShell>
      <PageHeader
        title="Stock Overview"
        description={`${totalCount} inventory record${totalCount !== 1 ? "s" : ""}`}
        actions={[{ label: "New Adjustment", onClick: () => router.push("/inventory/adjustments/new"), icon: Plus }]}
      />

      {/* ── Filters ── */}
      <div className="flex flex-wrap items-center gap-3 mb-4">
        {/* Branch filter */}
        <select
          value={branchId}
          onChange={(e) => setBranchId(e.target.value)}
          className="h-9 rounded-md border border-input bg-background px-3 text-sm"
        >
          <option value="">All branches</option>
          {branches.map((b) => (
            <option key={b.id} value={String(b.id)}>{b.name}</option>
          ))}
        </select>

        {/* Search */}
        <div className="relative">
          <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-text-secondary" />
          <Input
            className="pl-8 w-56"
            placeholder="Search product or SKU…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>

        {/* Low stock toggle */}
        <Button
          variant={lowStock ? "default" : "outline"}
          size="sm"
          onClick={() => setLowStock(!lowStock)}
          className="flex items-center gap-2"
        >
          <SlidersHorizontal className="h-4 w-4" />
          Low stock only
        </Button>
      </div>

      {/* ── Table ── */}
      <DataTable
        columns={columns}
        data={balances}
        isLoading={isLoading}
        emptyMessage="No inventory records found."
        onRowClick={(row) => router.push(`/inventory/stock/${row.product_id}?branch_id=${row.branch_id}`)}
      />
      {totalPages > 1 && (
        <div className="mt-4 flex items-center justify-between text-sm text-text-secondary">
          <span>Page {page} of {totalPages}</span>
          <div className="flex gap-2">
            <Button variant="outline" size="sm" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>Previous</Button>
            <Button variant="outline" size="sm" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>Next</Button>
          </div>
        </div>
      )}
    </AppShell>
  );
}
