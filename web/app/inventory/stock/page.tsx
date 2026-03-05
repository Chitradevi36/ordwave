"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { AppShell, PageHeader } from "@/components/layout";
import { Breadcrumb } from "@/components/ui/breadcrumb";
import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Search, AlertTriangle, SlidersHorizontal, Plus } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";

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
    fetch("http://localhost:3001/api/v1/branches?per_page=200", {
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
        `http://localhost:3001/api/v1/inventory/balances?${params}`,
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
          <p className="text-xs text-muted-foreground">{row.sku}</p>
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
      <Breadcrumb items={[{ label: "Inventory", href: "/inventory/stock" }, { label: "Stock Overview" }]} />
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
          <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
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
        <div className="mt-4 flex items-center justify-between text-sm text-muted-foreground">
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
