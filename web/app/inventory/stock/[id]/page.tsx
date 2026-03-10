"use client";

import { useState, useEffect, useCallback } from "react";
import { useParams, useSearchParams, useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";

import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Warehouse, ArrowLeft, TrendingUp, TrendingDown, Package, Plus, ExternalLink } from "lucide-react";
import Link from "next/link";
import { useOrgBranch } from "@/lib/org-branch-context";
import { cn } from "@/lib/utils";
import { API_URL } from "@/lib/api/client";

// ─── Types ────────────────────────────────────────────────────────────────────
interface BalanceSummary {
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

interface StockMovement {
  id: number;
  movement_type: string;
  direction: string;
  qty: number;
  unit_cost: number | null;
  on_hand_delta: number;
  reference_type: string | null;
  reference_id: number | null;
  reference_number: string | null;
  notes: string | null;
  occurred_at: string;
  created_by_name: string | null;
  branch_name: string | null;
}

interface Branch { id: number; name: string; }

interface Reservation {
  id: number;
  sales_order_id: number;
  qty_reserved: number;
  status: string;
  created_at: string;
}

type Tab = "overview" | "movements" | "reservations";

function fmtQty(n: number | string | null | undefined) {
  const num = Number(n ?? 0);
  return (isNaN(num) ? 0 : num).toLocaleString("en-IN", { minimumFractionDigits: 0, maximumFractionDigits: 3 });
}

function fmtDate(d: string) {
  return new Date(d).toLocaleDateString("en-IN", {
    day: "2-digit", month: "short", year: "numeric",
  });
}

const MOVE_TYPE_LABEL: Record<string, string> = {
  purchase_posted:   "Purchase Posted",
  purchase_cancelled:"Purchase Cancelled",
  sale_reserved:     "Reserved",
  sale_unreserved:   "Unreserved",
  sale_dispatched:   "Dispatched",
  sale_delivered:    "Delivered",
  sale_cancelled:    "Order Cancelled",
  return_received:   "Return Received",
  transfer_in:       "Transfer In",
  transfer_out:      "Transfer Out",
  adjustment_in:     "Adjustment In",
  adjustment_out:    "Adjustment Out",
  purchase:          "Purchase (Legacy)",
  reversal:          "Reversal (Legacy)",
};

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function ProductStockDetailPage() {
  const params      = useParams();
  const searchParams = useSearchParams();
  const router      = useRouter();
  const { token, orgId } = useOrgBranch();

  const productId = params.id as string;
  const branchId  = searchParams.get("branch_id") ?? "";

  const [activeTab,    setActiveTab]    = useState<Tab>("overview");
  const [balance,      setBalance]      = useState<BalanceSummary | null>(null);
  const [movements,    setMovements]    = useState<StockMovement[]>([]);
  const [reservations, setReservations] = useState<Reservation[]>([]);
  const [mvPage,       setMvPage]       = useState(1);
  const [mvTotalPages, setMvTotalPages] = useState(1);
  const [loading,      setLoading]      = useState(false);

  // Movement filters
  const [mvType,     setMvType]     = useState("");
  const [mvFromDate, setMvFromDate] = useState("");
  const [mvToDate,   setMvToDate]   = useState("");
  const [mvBranchId, setMvBranchId] = useState(branchId);
  const [branches,   setBranches]   = useState<Branch[]>([]);

  // Pre-load branch list for the filter
  useEffect(() => {
    if (!token || !orgId) return;
    fetch(`${API_URL}/api/v1/branches?per_page=200`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then((r) => r.json())
      .then((j) => setBranches(j.data ?? []));
  }, [token, orgId]);

  // Fetch balance
  useEffect(() => {
    if (!token || !orgId || !productId) return;
    const p = new URLSearchParams({ product_id: productId, ...(branchId && { branch_id: branchId }) });
    fetch(`${API_URL}/api/v1/inventory/balances?${p}&per_page=1`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then((r) => r.json())
      .then((j) => setBalance(j.data?.[0] ?? null));
  }, [token, orgId, productId, branchId]);

  // Fetch movements
  const fetchMovements = useCallback(async () => {
    if (!token || !orgId || !productId) return;
    setLoading(true);
    try {
      const p = new URLSearchParams({
        product_id: productId,
        page: String(mvPage),
        per_page: "20",
        ...(mvBranchId && { branch_id: mvBranchId }),
        ...(mvType     && { movement_type: mvType }),
        ...(mvFromDate && { from_date: mvFromDate }),
        ...(mvToDate   && { to_date: mvToDate }),
      });
      const res = await fetch(
        `${API_URL}/api/v1/inventory/movements?${p}`,
        { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId } }
      );
      const json = await res.json();
      setMovements(json.data ?? []);
      setMvTotalPages(json.meta?.total_pages ?? 1);
    } finally {
      setLoading(false);
    }
  }, [token, orgId, productId, mvBranchId, mvPage, mvType, mvFromDate, mvToDate]);

  useEffect(() => { if (activeTab === "movements") fetchMovements(); }, [activeTab, fetchMovements]);
  // Reset to page 1 whenever filter values change
  useEffect(() => { setMvPage(1); }, [mvType, mvFromDate, mvToDate, mvBranchId]);

  // Route helper: maps reference_type → source document URL
  function referenceHref(m: StockMovement): string | null {
    if (!m.reference_type || !m.reference_id) return null;
    switch (m.reference_type.toLowerCase().replace(/_/g, "")) {
      case "salesorder":      return `/orders/${m.reference_id}`;
      case "stocktransfer":   return `/inventory/transfers/${m.reference_id}`;
      case "stockadjustment": return `/inventory/adjustments/${m.reference_id}`;
      case "purchaseinvoice": return `/purchases/invoices/${m.reference_id}`;
      case "returnrequest":   return `/returns/${m.reference_id}`;
      default: return null;
    }
  }

  // Movement columns
  const mvColumns: Column<StockMovement>[] = [
    {
      key: "occurrence",
      header: "Date",
      render: (_: unknown, m: StockMovement) => <span className="text-sm text-text-secondary">{fmtDate(m.occurred_at)}</span>,
    },
    {
      key: "movement_type",
      header: "Type",
      render: (_: unknown, m: StockMovement) => (
        <div className="flex items-center gap-1.5">
          {m.direction === "in"
            ? <TrendingUp className="h-3.5 w-3.5 text-emerald-500" />
            : <TrendingDown className="h-3.5 w-3.5 text-rose-500" />}
          <span className="text-sm">{MOVE_TYPE_LABEL[m.movement_type] ?? m.movement_type}</span>
        </div>
      ),
    },
    {
      key: "qty",
      header: "Qty",
      render: (_: unknown, m: StockMovement) => (
        <span className={cn("font-mono text-sm font-medium", m.direction === "in" ? "text-emerald-600" : "text-rose-600")}>
          {m.direction === "in" ? "+" : "-"}{fmtQty(m.qty)}
        </span>
      ),
    },
    {
      key: "branch_name",
      header: "Branch",
      render: (_: unknown, m: StockMovement) => <span className="text-xs text-text-secondary">{m.branch_name ?? "—"}</span>,
    },
    {
      key: "reference",
      header: "Reference",
      render: (_: unknown, m: StockMovement) => {
        const href  = referenceHref(m);
        const label = m.reference_number
          ?? (m.reference_type ? `${m.reference_type.replace(/_/g, " ")} #${m.reference_id}` : null);
        if (!label) return null;
        return href ? (
          <Link
            href={href}
            onClick={(e) => e.stopPropagation()}
            className="text-xs text-primary hover:underline flex items-center gap-1"
          >
            {label} <ExternalLink className="h-3 w-3" />
          </Link>
        ) : (
          <span className="text-xs text-text-secondary">{label}</span>
        );
      },
    },
    {
      key: "actor",
      header: "By",
      render: (_: unknown, m: StockMovement) => <span className="text-xs text-text-secondary">{m.created_by_name ?? "—"}</span>,
    },
  ];

  const tabs: { key: Tab; label: string }[] = [
    { key: "overview",     label: "Overview" },
    { key: "movements",    label: "Movements" },
    { key: "reservations", label: "Reservations" },
  ];

  return (
    <AppShell breadcrumbs={[
      { label: "Inventory",     href: "/inventory" },
      { label: "Stock",         href: "/inventory/stock" },
      { label: balance?.product_name ?? "Product" },
    ]}>
      <PageHeader
        title={balance?.product_name ?? "Product Stock Detail"}
        subtitle={balance ? `SKU: ${balance.sku} · ${balance.branch_name}` : "Loading…"}
        actions={[
          { label: "Back to Stock", onClick: () => router.push("/inventory/stock"), variant: "outline", icon: ArrowLeft },
          { label: "Adjust Stock", onClick: () => router.push(`/inventory/adjustments/new?product_id=${productId}&branch_id=${branchId}`), icon: Plus },
        ]}
      />

      {/* ── Tabs ── */}
      <div className="flex gap-1 border-b mb-6">
        {tabs.map((t) => (
          <button
            key={t.key}
            onClick={() => setActiveTab(t.key)}
            className={cn(
              "px-4 py-2 text-sm font-medium -mb-px border-b-2 transition-colors",
              activeTab === t.key
                ? "border-primary text-primary"
                : "border-transparent text-text-secondary hover:text-text-primary"
            )}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* ── Overview Tab ── */}
      {activeTab === "overview" && balance && (
        <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
          {[
            { label: "On Hand",    value: fmtQty(balance.qty_on_hand),    color: "text-foreground" },
            { label: "Reserved",   value: fmtQty(balance.qty_reserved),   color: "text-amber-600" },
            { label: "Available",  value: fmtQty(balance.qty_available),  color: "text-emerald-600" },
            {
              label: "Min Threshold",
              value: balance.min_qty_threshold != null ? fmtQty(balance.min_qty_threshold) : "—",
              color: balance.low_stock ? "text-destructive" : "text-text-secondary",
            },
          ].map((card) => (
            <div key={card.label} className="rounded-lg border bg-card p-4">
              <p className="text-xs text-text-secondary uppercase tracking-wide mb-1">{card.label}</p>
              <p className={cn("text-2xl font-bold font-mono", card.color)}>{card.value}</p>
            </div>
          ))}
          {balance.low_stock && (
            <div className="col-span-full rounded-lg border border-amber-300 bg-amber-50 p-3 text-sm text-amber-700">
              ⚠️ Stock is below minimum threshold. Consider raising a purchase order.
            </div>
          )}
        </div>
      )}

      {/* ── Movements Tab ── */}
      {activeTab === "movements" && (
        <>
          {/* Filter bar */}
          <div className="flex flex-wrap gap-3 mb-4">
            <select
              value={mvBranchId}
              onChange={(e) => setMvBranchId(e.target.value)}
              className="h-9 rounded-md border border-input bg-background px-3 text-sm"
            >
              <option value="">All branches</option>
              {branches.map((b) => (
                <option key={b.id} value={String(b.id)}>{b.name}</option>
              ))}
            </select>
            <select
              value={mvType}
              onChange={(e) => setMvType(e.target.value)}
              className="h-9 rounded-md border border-input bg-background px-3 text-sm"
            >
              <option value="">All types</option>
              {Object.entries(MOVE_TYPE_LABEL).map(([val, label]) => (
                <option key={val} value={val}>{label}</option>
              ))}
            </select>
            <div className="flex items-center gap-2">
              <label className="text-xs text-text-secondary whitespace-nowrap">From</label>
              <Input type="date" className="h-9 w-36 text-sm" value={mvFromDate}
                onChange={(e) => setMvFromDate(e.target.value)} />
            </div>
            <div className="flex items-center gap-2">
              <label className="text-xs text-text-secondary whitespace-nowrap">To</label>
              <Input type="date" className="h-9 w-36 text-sm" value={mvToDate}
                onChange={(e) => setMvToDate(e.target.value)} />
            </div>
            {(mvType || mvFromDate || mvToDate || mvBranchId !== branchId) && (
              <Button variant="outline" size="sm" onClick={() => {
                setMvType(""); setMvFromDate(""); setMvToDate(""); setMvBranchId(branchId);
              }}>Clear</Button>
            )}
          </div>

          <DataTable
            columns={mvColumns}
            data={movements}
            isLoading={loading}
            emptyMessage="No movements recorded for this product."
          />
          {mvTotalPages > 1 && (
            <div className="mt-4 flex items-center justify-between text-sm text-text-secondary">
              <span>Page {mvPage} of {mvTotalPages}</span>
              <div className="flex gap-2">
                <Button variant="outline" size="sm" disabled={mvPage <= 1} onClick={() => setMvPage((p) => p - 1)}>Previous</Button>
                <Button variant="outline" size="sm" disabled={mvPage >= mvTotalPages} onClick={() => setMvPage((p) => p + 1)}>Next</Button>
              </div>
            </div>
          )}
        </>
      )}

      {/* ── Reservations Tab ── */}
      {activeTab === "reservations" && (
        <div className="text-sm text-text-secondary">
          {reservations.length === 0
            ? "No active reservations."
            : reservations.map((r) => (
                <div key={r.id} className="flex items-center justify-between border-b py-3">
                  <span>Order #{r.sales_order_id}</span>
                  <span className="font-mono">{fmtQty(r.qty_reserved)}</span>
                  <Badge variant={r.status === "active" ? "warning" : "secondary"}>{r.status}</Badge>
                </div>
              ))}
        </div>
      )}
    </AppShell>
  );
}
