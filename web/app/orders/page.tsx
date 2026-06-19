"use client";

import { Suspense, useState, useEffect, useCallback } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { EmptyState } from "@/components/ui/empty-state";
import { Card, CardContent } from "@/components/ui/card";
import {
  Plus, Search, X, SlidersHorizontal, ClipboardList,
  MoreHorizontal, CheckSquare, Square, TrendingUp,
  Clock, AlertTriangle, ArrowLeft,
  Download, Zap, LayoutList, LayoutDashboard,
} from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";
import { orderEvents } from "@/lib/analytics";

// ─── Types ────────────────────────────────────────────────────────────────────
interface LineItem {
  unit_price?: number;
  price?: number;
  rate?: number;
  product?: { price?: number; name?: string; code?: string };
  product_name?: string;
  name?: string;
  product_sku?: string;
  code?: string;
  quantity?: number;
  qty?: number;
  quantity_ordered?: number;
  discount_amount?: number;
  item_discount?: number;
  discount?: number;
  line_discount?: number;
}

interface OrderSummary {
  id: number;
  order_number: string;
  status: string;
  credit_decision: string | null;
  credit_reasons: string[] | null;
  total_amount: number;
  discount_amount: number;
  delivery_date: string | null;
  submitted_at: string | null;
  created_at: string;
  cancellation_reason: string | null;
  customer: { id: number; name: string; code: string };
  branch: { id: number; name: string };
  created_by: { id: number; name: string };
  // possible shapes for order line items returned by the API
  line_items?: LineItem[];
  lines?: LineItem[];
  items?: LineItem[];
}

interface StatusCounts {
  draft?: number;
  submitted?: number;
  on_hold?: number;
  approved?: number;
  rejected?: number;
  cancelled?: number;
  [key: string]: number | undefined;
}

interface TodayMetrics {
  today_orders: number;
  pending_approvals: number;
  on_hold: number;
  today_value: number;
}

interface PageMeta {
  current_page: number;
  total_pages: number;
  total_count: number;
  per_page: number;
  counts?: StatusCounts;
  metrics?: TodayMetrics;
}

// ─── Constants ────────────────────────────────────────────────────────────────
const STATUS_TABS = [
  { key: "",           label: "All" },
  { key: "draft",      label: "Draft" },
  { key: "submitted",  label: "Submitted" },
  { key: "on_hold",    label: "On Hold" },
  { key: "approved",   label: "Approved" },
  { key: "rejected",   label: "Rejected" },
  { key: "cancelled",  label: "Cancelled" },
];

const STATUS_VARIANT: Record<string, "default" | "secondary" | "warning" | "success" | "danger" | "outline"> = {
  draft:     "secondary",
  submitted: "default",
  on_hold:   "warning",
  approved:  "success",
  rejected:  "danger",
  cancelled: "outline",
};

const RISK_CONFIG: Record<string, { color: string; label: string }> = {
  hold:    { color: "bg-warning",  label: "Credit Hold" },
  blocked: { color: "bg-danger",   label: "Credit Blocked" },
};

// ─── Helpers ──────────────────────────────────────────────────────────────────
function fmtINR(n: number) {
  return `₹${n.toLocaleString("en-IN", { maximumFractionDigits: 0 })}`;
}

function fmtDate(d: string | null) {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

function relativeTime(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1)  return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24)  return `${hrs}h ago`;
  if (hrs < 48)  return "Yesterday";
  return new Date(iso).toLocaleDateString("en-IN", { day: "2-digit", month: "short" });
}

// ─── Stat Card ────────────────────────────────────────────────────────────────
function StatCard({
  label, value, sub, icon: Icon, accent,
}: {
  label: string;
  value: string | number;
  sub?: string;
  icon: React.FC<{ className?: string }>;
  accent: string;
}) {
  return (
    <Card>
      <CardContent className="p-4 flex items-start gap-3">
        <div className={`rounded-lg p-2 shrink-0 ${accent}`}>
          <Icon className="h-4 w-4" />
        </div>
        <div className="min-w-0">
          <p className="text-xs text-text-secondary">{label}</p>
          <p className="text-xl font-bold text-text-primary leading-tight">{value}</p>
          {sub && <p className="text-xs text-text-secondary mt-0.5">{sub}</p>}
        </div>
      </CardContent>
    </Card>
  );
}

// ─── Kanban Board ─────────────────────────────────────────────────────────────
const BOARD_COLUMNS: { key: string; label: string; accent: string; header: string }[] = [
  { key: "draft",     label: "Draft",     accent: "bg-background-subtle",  header: "border-text-secondary" },
  { key: "submitted", label: "Submitted", accent: "bg-primary/5",          header: "border-primary" },
  { key: "on_hold",   label: "On Hold",   accent: "bg-warning/5",          header: "border-warning" },
  { key: "approved",  label: "Approved",  accent: "bg-success/5",          header: "border-success" },
  { key: "rejected",  label: "Rejected",  accent: "bg-danger/5",           header: "border-danger" },
  { key: "cancelled", label: "Cancelled", accent: "bg-background-subtle",  header: "border-border" },
];

function KanbanBoard({
  orders,
  loading,
  onNavigate,
}: {
  orders: OrderSummary[];
  loading: boolean;
  onNavigate: (id: number) => void;
}) {
  if (loading) {
    return (
      <div className="flex items-center justify-center py-16 text-text-secondary text-sm">
        Loading board…
      </div>
    );
  }

  return (
    <div className="flex gap-3 overflow-x-auto pb-4 mt-1">
      {BOARD_COLUMNS.map((col) => {
        const cards = orders.filter((o) => o.status === col.key);
        return (
          <div
            key={col.key}
            className={`flex-shrink-0 w-64 rounded-xl border border-border flex flex-col ${col.accent}`}
          >
            {/* Column header */}
            <div className={`flex items-center justify-between px-3 py-2.5 border-b-2 ${col.header}`}>
              <span className="text-xs font-semibold uppercase tracking-wide text-text-primary">
                {col.label}
              </span>
              <span className="inline-flex items-center justify-center rounded-full min-w-[20px] px-1.5 py-0.5 text-[11px] font-bold bg-white/60 text-text-secondary border border-border/50">
                {cards.length}
              </span>
            </div>

            {/* Cards */}
            <div className="flex flex-col gap-2 p-2 overflow-y-auto h-[calc(100vh-380px)] min-h-[240px]">
              {cards.length === 0 && (
                <p className="text-center text-xs text-text-secondary mt-6 italic">
                  No orders
                </p>
              )}
              {cards.map((o) => (
                <button
                  key={o.id}
                  onClick={() => onNavigate(o.id)}
                  className="w-full text-left rounded-lg border border-border bg-white px-3 py-2.5 shadow-sm hover:shadow hover:border-primary/30 transition-all"
                >
                  <div className="flex items-start justify-between gap-1 mb-1.5">
                    <span className="font-mono text-[11px] font-semibold text-primary">
                      {o.order_number}
                    </span>
                    {o.credit_decision && o.credit_decision !== "ok" && (
                      <span
                        className={`inline-block h-2 w-2 rounded-full mt-1 shrink-0 ${
                          o.credit_decision === "blocked" ? "bg-danger" : "bg-warning"
                        }`}
                        title={`Credit ${o.credit_decision}`}
                      />
                    )}
                  </div>
                  <p className="text-xs font-medium text-text-primary truncate">{o.customer.name}</p>
                  <p className="text-[10px] text-text-secondary truncate">{o.customer.code} · {o.branch.name}</p>
                  <div className="flex items-center justify-between mt-2">
                    <span className="text-xs font-bold text-text-primary">{fmtINR(o.total_amount)}</span>
                    <span className="text-[10px] text-text-secondary">{relativeTime(o.created_at)}</span>
                  </div>
                  {o.delivery_date && (() => {
                    const today   = new Date(); today.setHours(0, 0, 0, 0);
                    const delDate = new Date(o.delivery_date); delDate.setHours(0, 0, 0, 0);
                    const terminal = ["cancelled", "rejected", "delivered"].includes(o.status);
                    if (!terminal && delDate < today)
                      return <p className="text-[10px] text-danger font-medium mt-0.5">⏱ Overdue</p>;
                    if (!terminal && delDate.getTime() === today.getTime())
                      return <p className="text-[10px] text-warning font-medium mt-0.5">⏱ Due today</p>;
                    return null;
                  })()}
                </button>
              ))}
            </div>
          </div>
        );
      })}
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────
function OrdersPageContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { token, orgId, branches } = useOrgBranch();

  const [orders, setOrders]   = useState<OrderSummary[]>([]);
  const [meta, setMeta]       = useState<PageMeta | null>(null);
  const [loading, setLoading] = useState(false);

  // Filters
  const [tab,              setTab]              = useState("");
  const [search,           setSearch]           = useState("");
  const [branchFilter,     setBranchFilter]     = useState("");
  const [minValue,         setMinValue]         = useState("");
  const [maxValue,         setMaxValue]         = useState("");
  const [dateFrom,         setDateFrom]         = useState("");
  const [dateTo,           setDateTo]           = useState("");
  const [createdByFilter,  setCreatedByFilter]  = useState("");
  const [deliveryOverdue,  setDeliveryOverdue]  = useState(false);
  const [showFilters,      setShowFilters]      = useState(false);
  const [page,             setPage]             = useState(1);
  const [activeChip,       setActiveChip]       = useState<string | null>(null);

  // View mode
  const [viewMode, setViewMode] = useState<"list" | "board">("list");

  // Sorting
  const [sortBy,  setSortBy]  = useState("created_at");
  const [sortDir, setSortDir] = useState<"asc" | "desc">("desc");

  // Selection & action menu
  const [selectedIds,  setSelectedIds]  = useState<Set<number>>(new Set());
  const [actionMenuId, setActionMenuId] = useState<number | null>(null);

  const [toast, setToast] = useState<{ type: "success" | "error"; msg: string } | null>(null);

  const showToast = (type: "success" | "error", msg: string) => {
    setToast({ type, msg });
    setTimeout(() => setToast(null), 3500);
  };

  // Close action dropdown on outside click
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (!(e.target as HTMLElement).closest("[data-action-menu]")) {
        setActionMenuId(null);
      }
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, []);

  const hasActiveFilters = !!(branchFilter || minValue || maxValue || dateFrom || dateTo || createdByFilter || deliveryOverdue);

  const clearAll = () => {
    setSearch(""); setBranchFilter(""); setMinValue(""); setMaxValue("");
    setDateFrom(""); setDateTo(""); setCreatedByFilter(""); setDeliveryOverdue(false);
    setActiveChip(null); setPage(1);
  };

  useEffect(() => {
    const dateScope = searchParams.get("date");
    const filter = searchParams.get("filter");
    const status = searchParams.get("status");

    if (status) setTab(status);

    const today = new Date();
    const yyyy = today.getFullYear();
    const mm = String(today.getMonth() + 1).padStart(2, "0");
    const dd = String(today.getDate()).padStart(2, "0");
    const todayIso = `${yyyy}-${mm}-${dd}`;

    if (dateScope === "today") {
      setDateFrom(todayIso);
      setDateTo(todayIso);
    } else if (dateScope === "mtd") {
      setDateFrom(`${yyyy}-${mm}-01`);
      setDateTo(todayIso);
    }

    if (filter === "credit_hold") {
      setTab("on_hold");
    }
  }, [searchParams]);

  const fetchOrders = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const qp = new URLSearchParams();
      if (tab)              qp.set("status",           tab);
      if (search)           qp.set("q",                search);
      if (branchFilter)     qp.set("branch_id",        branchFilter);
      if (minValue)         qp.set("min_value",        minValue);
      if (maxValue)         qp.set("max_value",        maxValue);
      if (dateFrom)         qp.set("date_from",        dateFrom);
      if (dateTo)           qp.set("date_to",          dateTo);
      if (createdByFilter)  qp.set("created_by_id",    createdByFilter);
      if (deliveryOverdue)  qp.set("delivery_overdue", "1");
      qp.set("sort_by",  sortBy);
      qp.set("sort_dir", sortDir);
      qp.set("page",     String(page));
      qp.set("per_page", viewMode === "board" ? "200" : "10");

      const res  = await fetch(`${API_URL}/api/v1/sales_orders?${qp}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) {
        setOrders(json.data ?? []);
        setMeta(json.meta ?? null);
        // Track search if search query is active
        if (search && search.trim()) {
          orderEvents.search(search, json.data?.length ?? 0);
        }
      } else {
        showToast("error", json.errors?.[0] ?? "Failed to load orders");
      }
    } finally {
      setLoading(false);
    }
  }, [token, orgId, tab, search, branchFilter, minValue, maxValue, dateFrom, dateTo, createdByFilter, deliveryOverdue, sortBy, sortDir, page, viewMode]);

  useEffect(() => { void fetchOrders(); }, [fetchOrders]);

  // ─── Actions ────────────────────────────────────────────────────────────────
  const handleApprove = useCallback(async (id: number) => {
    setActionMenuId(null);
    const res = await fetch(`${API_URL}/api/v1/sales_orders/${id}/approve`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token!}`,
        "X-Organization-Id": orgId!,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ decision: "approved" }),
    });
    const j = await res.json();
    if (res.ok) {
      const at = j.data?.auto_trip;
      if (at?.ok && at.action === "new_trip_created") {
        showToast("success", `Order approved · New trip ${at.trip_number} created`);
      } else if (at?.ok && at.action === "added_to_existing") {
        showToast("success", `Order approved · Added to trip ${at.trip_number}`);
      } else {
        showToast("success", "Order approved");
      }
      void fetchOrders();
    } else {
      showToast("error", j.errors?.[0] ?? "Approve failed");
    }
  }, [token, orgId, fetchOrders]);

  const handleCancel = useCallback(async (id: number) => {
    setActionMenuId(null);
    const res = await fetch(`${API_URL}/api/v1/sales_orders/${id}/cancel`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token!}`,
        "X-Organization-Id": orgId!,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ reason: "Cancelled via orders list" }),
    });
    if (res.ok) {
      showToast("success", "Order cancelled");
      void fetchOrders();
    } else {
      const j = await res.json();
      showToast("error", j.errors?.[0] ?? "Cancel failed");
    }
  }, [token, orgId, fetchOrders]);

  const handleHold = useCallback(async (id: number) => {
    setActionMenuId(null);
    const res = await fetch(`${API_URL}/api/v1/sales_orders/${id}/hold`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token!}`,
        "X-Organization-Id": orgId!,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ reason: "Placed on hold via orders list" }),
    });
    if (res.ok) {
      showToast("success", "Order placed on hold");
      void fetchOrders();
    } else {
      const j = await res.json();
      showToast("error", j.errors?.[0] ?? "Hold failed");
    }
  }, [token, orgId, fetchOrders]);

  const handleBulkApprove = async () => {
    await Promise.all(Array.from(selectedIds).map(id => handleApprove(id)));
    setSelectedIds(new Set());
  };

  const handleBulkCancel = async () => {
    await Promise.all(Array.from(selectedIds).map(id => handleCancel(id)));
    setSelectedIds(new Set());
  };

  const [bulkInvoiceLoading, setBulkInvoiceLoading] = useState(false);

  const handleBulkGenerateInvoices = async () => {
    if (!token || !orgId || selectedIds.size === 0) return;
    setBulkInvoiceLoading(true);
    try {
      const res  = await fetch("/api/v1/sales_invoices/bulk_generate", {
        method:  "POST",
        headers: {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId,
          "Content-Type":      "application/json",
        },
        body: JSON.stringify({ order_ids: Array.from(selectedIds) }),
      });
      const json = await res.json();
      if (res.ok) {
        const { generated, skipped, errors: errs } = json.data ?? {};
        const msg = `Generated: ${generated}, Skipped: ${skipped}${(errs ?? []).length > 0 ? ` (${errs.length} error(s))` : ""}`;
        showToast("success", msg);
        setSelectedIds(new Set());
        fetchOrders();
      } else {
        showToast("error", json.errors?.[0] ?? "Bulk invoice generation failed");
      }
    } catch (e) {
      showToast("error", e instanceof Error ? e.message : "Unknown error");
    } finally {
      setBulkInvoiceLoading(false);
    }
  };

  // ─── Sort ───────────────────────────────────────────────────────────────────
  const handleSort = (key: string) => {
    if (sortBy === key) setSortDir(d => d === "asc" ? "desc" : "asc");
    else { setSortBy(key); setSortDir("desc"); }
    setPage(1);
  };

  // ─── Current user from JWT ───────────────────────────────────────────────
  const currentUserId = (() => {
    if (!token) return null;
    try { return String(JSON.parse(atob(token.split(".")[1])).sub); } catch { return null; }
  })();

  // ─── Quick chips ─────────────────────────────────────────────────────────
  const applyChip = (chip: string) => {
    if (activeChip === chip) { clearAll(); return; }
    setSearch(""); setBranchFilter(""); setMinValue(""); setMaxValue("");
    setDateFrom(""); setDateTo(""); setCreatedByFilter(""); setDeliveryOverdue(false); setTab("");
    setActiveChip(chip); setPage(1);
    if (chip === "mine"   && currentUserId) setCreatedByFilter(currentUserId);
    if (chip === "attn")    setTab("on_hold");
    if (chip === "high")    setMinValue("50000");
    if (chip === "overdue") setDeliveryOverdue(true);
  };

  // ─── Export CSV (current page) ───────────────────────────────────────────
  const exportCsv = () => {
    const dateRange = dateFrom || dateTo ? `${dateFrom ?? ""} to ${dateTo ?? ""}` : "all";

    const hdrs = [
      "Order #",
      "Customer",
      "Branch",
      "Product Name",
      "Product Code",
      "Quantity",
      "Item Price (₹)",
      "Item Discount (₹)",
      "Status",
      "Delivery Date",
      "Sales Rep",
      "Created",
    ];

    const rows = orders.flatMap((o: OrderSummary) => {
      const items: LineItem[] = o.line_items ?? o.lines ?? o.items ?? [];
      if (!items || items.length === 0) {
        return [[
          o.order_number,
          o.customer.name,
          o.branch.name,
          "",
          "",
          "",
          "",
          "",
          o.status,
          o.delivery_date ?? "",
          o.created_by?.name ?? "",
          new Date(o.created_at).toLocaleDateString("en-IN"),
        ]];
      }

      return items.map((it: LineItem) => {
        const itemPrice = it.unit_price ?? it.price ?? it.rate ?? it.product?.price ?? "";
        const itemDiscount = it.discount_amount ?? it.item_discount ?? it.discount ?? it.line_discount ?? "";
        return [
          o.order_number,
          o.customer.name,
          o.branch.name,
          it.product_name || it.name || it.product?.name || "",
          it.product_sku || it.name || it.product?.sku || "",
          it.quantity ?? it.qty ?? it.quantity_ordered ?? "",
          itemPrice,
          itemDiscount,
          o.status,
          o.delivery_date ?? "",
          o.created_by?.name ?? "",
          new Date(o.created_at).toLocaleDateString("en-IN"),
        ];
      });
    });

    // Track export event (rows exported)
    orderEvents.export("csv", rows.length, dateRange);

    const csv = [hdrs, ...rows]
      .map((r: any[]) => r.map((v: any) => `"${String(v ?? "").replace(/"/g, '""')}"`).join(","))
      .join("\n");
    const url = URL.createObjectURL(new Blob([csv], { type: "text/csv" }));
    const a = document.createElement("a"); a.href = url; a.download = "orders.csv"; a.click();
    URL.revokeObjectURL(url);
  };

  // ─── Selection helpers ───────────────────────────────────────────────────
  const toggleSelect = (id: number) => {
    setSelectedIds(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  };

  const allSelected = orders.length > 0 && orders.every(o => selectedIds.has(o.id));

  const toggleAll = () => {
    if (allSelected) setSelectedIds(new Set());
    else             setSelectedIds(new Set(orders.map(o => o.id)));
  };

  // ─── Columns ────────────────────────────────────────────────────────────────
  const columns: Column<OrderSummary>[] = [
    {
      key:       "select",
      header:    "",
      className: "w-10",
      render:    (_, o) => (
        <div onClick={e => e.stopPropagation()} className="flex justify-center">
          <button onClick={() => toggleSelect(o.id)} className="text-text-secondary hover:text-primary">
            {selectedIds.has(o.id)
              ? <CheckSquare className="h-4 w-4 text-primary" />
              : <Square      className="h-4 w-4" />}
          </button>
        </div>
      ),
    },
    // {
    //   key:       "risk",
    //   header:    "Risk",
    //   className: "w-28",
    //   render:    (_, o) => {
    //     if (!o.credit_decision || o.credit_decision === "ok") {
    //       return <span className="text-text-secondary text-xs">—</span>;
    //     }
    //     const cfg     = RISK_CONFIG[o.credit_decision];
    //     const reasons = o.credit_reasons ?? [];
    //     return (
    //       <div className="flex items-center gap-1.5 group relative cursor-help">
    //         <span className={`inline-block h-2 w-2 rounded-full ${cfg?.color ?? "bg-text-secondary"}`} />
    //         <span className="text-xs text-text-secondary capitalize">{o.credit_decision.replace("_", " ")}</span>
    //         {reasons.length > 0 && (
    //           <div className="absolute left-0 top-full z-50 mt-1 hidden group-hover:block w-60 rounded-lg border border-border bg-white p-2.5 shadow-xl text-xs leading-relaxed pointer-events-none">
    //             <p className="font-semibold text-text-primary mb-1.5">{cfg?.label}</p>
    //             {reasons.map((r, i) => <p key={i} className="text-text-secondary">{r}</p>)}
    //           </div>
    //         )}
    //       </div>
    //     );
    //   },
    // },
    {
      key:      "order_number",
      header:   "Order #",
      sortable: true,
      render: (_, o) => (
        <button
          onClick={() => router.push(`/orders/${o.id}`)}
          className="font-mono text-sm text-primary hover:underline"
        >
          {o.order_number}
        </button>
      ),
    },
    {
      key:    "customer",
      header: "Customer / Branch",
      render: (_, o) => (
        <div>
          <p className="text-sm font-medium">{o.customer.name}</p>
          <p className="text-xs text-text-secondary">{o.customer.code} · {o.branch.name}</p>
        </div>
      ),
    },
    {
      key:    "status",
      header: "Status",
      render: (_, o) => {
        const pendingMs   = o.submitted_at ? Date.now() - new Date(o.submitted_at).getTime() : 0;
        const pendingDays = Math.floor(pendingMs / 86_400_000);
        const isStale     = ["submitted", "on_hold"].includes(o.status) && pendingDays >= 1;
        return (
          <div className="flex flex-col gap-0.5">
            <Badge variant={STATUS_VARIANT[o.status] ?? "secondary"}>
              {o.status.replace("_", " ")}
            </Badge>
            {isStale && (
              <span className={`text-[10px] font-medium ${pendingDays >= 3 ? "text-danger" : "text-warning"}`}>
                ⏱ {pendingDays}d pending
              </span>
            )}
            {o.status === "rejected" && o.cancellation_reason && (
              <span
                className="text-[10px] text-danger italic max-w-[140px] truncate"
                title={o.cancellation_reason}
              >
                {o.cancellation_reason}
              </span>
            )}
          </div>
        );
      },
    },
    {
      key:      "total_amount",
      header:   "Total",
      sortable: true,
      render: (_, o) => {
        const discPct = o.total_amount > 0 && o.discount_amount > 0
          ? Math.round((o.discount_amount / (o.total_amount + o.discount_amount)) * 100)
          : 0;
        return (
          <div>
            <span className={`text-sm ${o.total_amount >= 10000 ? "font-bold text-text-primary" : "font-medium"}`}>
              {fmtINR(o.total_amount)}
            </span>
            {discPct > 0 && (
              <span className="block text-[10px] text-success font-medium">-{discPct}% disc</span>
            )}
          </div>
        );
      },
    },
    {
      key:      "delivery_date",
      header:   "Delivery",
      sortable: true,
      render: (_, o) => {
        if (!o.delivery_date) return <span className="text-xs text-text-secondary italic">Not scheduled</span>;
        const today    = new Date(); today.setHours(0, 0, 0, 0);
        const delDate  = new Date(o.delivery_date); delDate.setHours(0, 0, 0, 0);
        const terminal = ["cancelled", "rejected", "delivered", "partial_delivery"].includes(o.status);
        const isOverdue = !terminal && delDate < today;
        const isToday   = !terminal && delDate.getTime() === today.getTime();
        return (
          <div>
            <span className={`text-sm ${isOverdue ? "text-danger font-medium" : isToday ? "text-warning font-medium" : ""}`}>
              {fmtDate(o.delivery_date)}
            </span>
            {isOverdue && <span className="block text-[10px] font-semibold text-danger">Overdue</span>}
            {isToday   && <span className="block text-[10px] font-semibold text-warning">Today</span>}
          </div>
        );
      },
    },
    {
      key:    "created_by",
      header: "Sales Rep",
      render: (_, o) => <span className="text-sm">{o.created_by?.name ?? "—"}</span>,
    },
    {
      key:      "created_at",
      header:   "Created",
      sortable: true,
      render: (_, o) => (
        <span className="text-sm text-text-secondary" title={fmtDate(o.created_at)}>
          {relativeTime(o.created_at)}
        </span>
      ),
    },
    {
      key:       "actions",
      header:    "",
      className: "w-12",
      render:    (_, o) => (
        <div
          className="relative flex items-center gap-1"
          data-action-menu
          onClick={e => e.stopPropagation()}
        >
          {["submitted", "on_hold"].includes(o.status) && (
            <button
              onClick={() => handleApprove(o.id)}
              className="inline-flex items-center gap-1 rounded-md px-1.5 py-1 text-[11px] font-medium text-success bg-success/10 hover:bg-success/20 transition-colors"
              title="Quick approve"
            >
              <Zap className="h-3 w-3" /> Approve
            </button>
          )}
          <button
            onClick={() => setActionMenuId(actionMenuId === o.id ? null : o.id)}
            className="inline-flex h-7 w-7 items-center justify-center rounded-md hover:bg-background-subtle text-text-secondary"
            title="Actions"
          >
            <MoreHorizontal className="h-4 w-4" />
          </button>

          {actionMenuId === o.id && (
            <div className="absolute right-0 z-30 mt-1 w-44 rounded-lg border border-border bg-white shadow-lg py-1 text-sm">
              <button
                onClick={() => { router.push(`/orders/${o.id}`); setActionMenuId(null); }}
                className="w-full text-left px-3 py-2 hover:bg-background-subtle"
              >
                View order
              </button>

              {o.status === "draft" && (
                <button
                  onClick={() => { router.push(`/orders/${o.id}/edit`); setActionMenuId(null); }}
                  className="w-full text-left px-3 py-2 hover:bg-background-subtle"
                >
                  Edit draft
                </button>
              )}

              {["submitted", "on_hold"].includes(o.status) && (
                <button
                  onClick={() => handleApprove(o.id)}
                  className="w-full text-left px-3 py-2 hover:bg-background-subtle text-success font-medium"
                >
                  Approve
                </button>
              )}

              {o.status === "submitted" && (
                <button
                  onClick={() => handleHold(o.id)}
                  className="w-full text-left px-3 py-2 hover:bg-background-subtle text-warning font-medium"
                >
                  Put on hold
                </button>
              )}

              {!["cancelled", "rejected", "approved", "delivered"].includes(o.status) && (
                <>
                  <div className="my-1 border-t border-border" />
                  <button
                    onClick={() => handleCancel(o.id)}
                    className="w-full text-left px-3 py-2 hover:bg-background-subtle text-danger"
                  >
                    Cancel order
                  </button>
                </>
              )}
            </div>
          )}
        </div>
      ),
    },
  ];

  const counts  = meta?.counts  ?? {};
  const metrics = meta?.metrics;

  // Calculate total count from sum of all status counts (not from total_count which changes per filter)
  const allTabCount = Object.values(counts).reduce((sum, count) => (sum || 0) + (count || 0), 0);

  const tabCount = (key: string): number | undefined => {
    if (!key)           return allTabCount;
    return counts[key];
  };

  const dateScope = searchParams.get("date");
  const filterScope = searchParams.get("filter");
  const scopedLabel =
    dateScope === "today"
      ? "Scope: Orders Today"
      : dateScope === "mtd"
      ? "Scope: Sales MTD"
      : filterScope === "credit_hold"
      ? "Scope: Credit Hold Orders"
      : filterScope
      ? `Scope: ${filterScope.replace("_", " ")}`
      : undefined;

  return (
    <AppShell>
      {/* Toast */}
      {toast && (
        <div className={`fixed top-4 right-4 z-50 rounded-lg px-4 py-3 text-sm text-white shadow-lg ${
          toast.type === "success" ? "bg-success" : "bg-danger"
        }`}>
          {toast.msg}
        </div>
      )}

      <PageHeader
        title="Sales Orders"
        description="Create, manage, and track sales orders. Review pending approvals, handle credit decisions, and monitor order fulfillment across all branches."
        actions={[
          // { label: "Sales Control Center", icon: ArrowLeft, variant: "outline", onClick: () => router.push("/sales") },
          { label: "Export CSV", icon: Download, variant: "outline" as const, onClick: exportCsv },
          { label: "New Order", icon: Plus, onClick: () => router.push("/orders/new") },
        ]}
      />

      {/* Quick filters + View mode toggle — single row */}
      <div className="flex items-center justify-between gap-2 mb-4 flex-wrap">
        <div className="flex items-center gap-2 flex-wrap">
          <span className="text-xs text-text-secondary">Quick:</span>
          {([
            { key: "mine",    label: "My Orders" },
            { key: "attn",    label: "Needs Attention" },
            { key: "overdue", label: "Overdue Delivery" },
            { key: "high",    label: "High Value >\u20b950k" },
          ] as const).map(chip => (
            <button
              key={chip.key}
              onClick={() => applyChip(chip.key)}
              className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-medium border transition-colors ${
                activeChip === chip.key
                  ? "bg-primary text-white border-primary"
                  : "bg-white text-text-secondary border-border hover:border-primary/40 hover:text-text-primary"
              }`}
            >
              {chip.label}
            </button>
          ))}
          {activeChip && (
            <button onClick={clearAll} className="text-xs text-text-secondary hover:text-danger">
              × Clear
            </button>
          )}
        </div>

        <div className="inline-flex rounded-lg border border-border overflow-hidden shrink-0">
          <button
            onClick={() => setViewMode("list")}
            title="List view"
            className={`inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium transition-colors ${
              viewMode === "list"
                ? "bg-primary text-white"
                : "bg-white text-text-secondary hover:bg-background-subtle"
            }`}
          >
            <LayoutList className="h-3.5 w-3.5" />
            List
          </button>
          <button
            onClick={() => { setViewMode("board"); setPage(1); }}
            title="Kanban board"
            className={`inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium border-l border-border transition-colors ${
              viewMode === "board"
                ? "bg-primary text-white"
                : "bg-white text-text-secondary hover:bg-background-subtle"
            }`}
          >
            <LayoutDashboard className="h-3.5 w-3.5" />
            Board
          </button>
        </div>
      </div>

      {scopedLabel && (
        <div className="mb-2">
          <Badge variant="outline">{scopedLabel}</Badge>
        </div>
      )}

      {/* Summary bar */}
      {metrics && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-5">
          <StatCard
            label="Orders Today"
            value={metrics.today_orders}
            icon={ClipboardList}
            accent="bg-primary/10 text-primary"
          />
          <StatCard
            label="Pending Approval"
            value={metrics.pending_approvals}
            sub="submitted + on hold"
            icon={Clock}
            accent="bg-warning/10 text-warning"
          />
          <StatCard
            label="On Hold"
            value={metrics.on_hold}
            sub="credit review"
            icon={AlertTriangle}
            accent="bg-danger/10 text-danger"
          />
          <StatCard
            label="Today's Value"
            value={fmtINR(metrics.today_value)}
            icon={TrendingUp}
            accent="bg-success/10 text-success"
          />
        </div>
      )}

      {/* Status tabs */}
      <div className="flex items-center gap-1 border-b border-border mb-4 overflow-x-auto">
        {STATUS_TABS.map((t) => {
          const n = tabCount(t.key);
          return (
            <button
              key={t.key}
              onClick={() => { setTab(t.key); setPage(1); setSelectedIds(new Set()); }}
              className={`flex items-center gap-1.5 px-4 py-2 text-sm font-medium whitespace-nowrap transition-colors ${
                tab === t.key
                  ? "border-b-2 border-primary text-primary"
                  : "text-text-secondary hover:text-text-primary"
              }`}
            >
              {t.label}
              {n !== undefined && n > 0 && (
                <span className={`inline-flex items-center justify-center rounded-full min-w-[18px] px-1 py-0.5 text-[10px] font-medium ${
                  tab === t.key
                    ? "bg-primary/10 text-primary"
                    : "bg-background-subtle text-text-secondary"
                }`}>
                  {n}
                </span>
              )}
            </button>
          );
        })}
      </div>

      {/* Search + filter toggle */}
      <div className="flex items-center gap-2 mb-3 flex-wrap">
        <div className="relative flex-1 min-w-[180px] max-w-sm">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary" />
          <Input
            placeholder="Search order # or customer…"
            value={search}
            onChange={(e) => {
              const query = e.target.value;
              setSearch(query);
              setPage(1);
              if (query.trim()) {
                // Track search only if there's a query
                // We'll track after results are fetched
              }
            }}
            className="pl-9"
          />
        </div>

        <Button
          variant={showFilters ? "default" : "outline"}
          size="sm"
          onClick={() => setShowFilters(v => !v)}
          className="gap-1.5"
        >
          <SlidersHorizontal className="h-4 w-4" />
          Filters
          {hasActiveFilters && (
            <span className="ml-1 inline-flex h-4 w-4 items-center justify-center rounded-full bg-white/30 text-[10px] font-bold">●</span>
          )}
        </Button>

        {(search || hasActiveFilters) && (
          <Button variant="ghost" size="sm" onClick={clearAll} className="gap-1 text-text-secondary">
            <X className="h-3.5 w-3.5" /> Clear all
          </Button>
        )}
      </div>

      {/* Expanded filter bar */}
      {showFilters && (
        <div className="flex items-end gap-3 mb-4 p-3 rounded-lg border border-border bg-background-subtle flex-wrap">
          <div className="min-w-[180px]">
            <label className="text-xs font-medium text-text-secondary mb-1 block">Branch</label>
            <select
              value={branchFilter}
              onChange={e => { setBranchFilter(e.target.value); setPage(1); }}
              className="w-full rounded-md border border-border px-2 py-1.5 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-primary"
            >
              <option value="">All branches</option>
              {branches.map(b => (
                <option key={b.id} value={String(b.id)}>{b.name}</option>
              ))}
            </select>
          </div>

          <div className="min-w-[120px]">
            <label className="text-xs font-medium text-text-secondary mb-1 block">Min value (₹)</label>
            <Input
              type="number"
              placeholder="0"
              value={minValue}
              onChange={e => { setMinValue(e.target.value); setPage(1); }}
              className="text-sm"
            />
          </div>

          <div className="min-w-[120px]">
            <label className="text-xs font-medium text-text-secondary mb-1 block">Max value (₹)</label>
            <Input
              type="number"
              placeholder="∞"
              value={maxValue}
              onChange={e => { setMaxValue(e.target.value); setPage(1); }}
              className="text-sm"
            />
          </div>

          <div className="min-w-[150px]">
            <label className="text-xs font-medium text-text-secondary mb-1 block">From date</label>
            <Input
              type="date"
              value={dateFrom}
              onChange={e => { setDateFrom(e.target.value); setPage(1); }}
              className="text-sm"
            />
          </div>

          <div className="min-w-[150px]">
            <label className="text-xs font-medium text-text-secondary mb-1 block">To date</label>
            <Input
              type="date"
              value={dateTo}
              onChange={e => { setDateTo(e.target.value); setPage(1); }}
              className="text-sm"
            />
          </div>

          {hasActiveFilters && (
            <Button
              variant="ghost"
              size="sm"
              className="text-text-secondary self-end"
              onClick={() => { setBranchFilter(""); setMinValue(""); setMaxValue(""); setDateFrom(""); setDateTo(""); setPage(1); }}
            >
              <X className="h-3.5 w-3.5 mr-1" /> Reset
            </Button>
          )}
        </div>
      )}

      {/* Bulk action bar */}
      {selectedIds.size > 0 && (
        <div className="flex items-center gap-3 rounded-lg border border-primary/20 bg-primary/5 px-4 py-2.5 mb-3 text-sm">
          <CheckSquare className="h-4 w-4 text-primary shrink-0" />
          <span className="font-medium text-primary">{selectedIds.size} selected</span>
          <div className="h-4 w-px bg-border" />
          <Button size="sm" onClick={handleBulkApprove}>Approve selected</Button>
          <Button size="sm" variant="outline" onClick={handleBulkCancel}>Cancel selected</Button>
          <Button
            size="sm"
            variant="outline"
            disabled={bulkInvoiceLoading}
            onClick={handleBulkGenerateInvoices}
          >
            {bulkInvoiceLoading ? "Generating…" : "Generate Invoices"}
          </Button>
          <Button
            size="sm"
            variant="ghost"
            className="text-text-secondary ml-auto"
            onClick={() => setSelectedIds(new Set())}
          >
            Clear selection
          </Button>
        </div>
      )}

      {/* Select-all hint */}
      {orders.length > 0 && (
        <div className="flex items-center gap-2 mb-1 px-1">
          <button
            onClick={toggleAll}
            className="flex items-center gap-1.5 text-xs text-text-secondary hover:text-primary"
          >
            {allSelected
              ? <CheckSquare className="h-3.5 w-3.5 text-primary" />
              : <Square      className="h-3.5 w-3.5" />
            }
            {allSelected ? "Deselect all" : `Select all ${orders.length}`}
          </button>
        </div>
      )}

      {/* Table, Board, or empty state */}
      {viewMode === "board" ? (
        <KanbanBoard orders={orders} loading={loading} onNavigate={(id) => router.push(`/orders/${id}`)} />
      ) : !loading && orders.length === 0 ? (
        <EmptyState
          icon={ClipboardList}
          title={tab ? `No ${tab.replace("_", " ")} orders` : "No orders yet"}
          description={
            search || hasActiveFilters
              ? "No orders match your current filters."
              : tab
              ? `There are no orders with status "${tab.replace("_", " ")}".`
              : "Create your first sales order to get started."
          }
          action={
            !tab && !search && !hasActiveFilters
              ? { label: "New Order", onClick: () => router.push("/orders/new") }
              : undefined
          }
        />
      ) : (
        <DataTable
          columns={columns}
          data={orders}
          isLoading={loading}
          onRowClick={(o) => router.push(`/orders/${o.id}`)}
          sortBy={sortBy}
          sortDir={sortDir}
          onSort={handleSort}
          rowClassName={(o) => {
            if (!o.delivery_date) return undefined;
            const today   = new Date(); today.setHours(0, 0, 0, 0);
            const delDate = new Date(o.delivery_date); delDate.setHours(0, 0, 0, 0);
            const terminal = ["cancelled", "rejected", "delivered", "partial_delivery"].includes(o.status);
            if (!terminal && delDate < today)  return "bg-danger/5";
            if (!terminal && delDate.getTime() === today.getTime()) return "bg-warning/5";
            return undefined;
          }}
        />
      )}

      {/* Pagination — list view only */}
      {viewMode === "list" && meta && meta.total_pages >= 1 && orders.length > 0 && (
        <div className="mt-6 flex items-center justify-center gap-1">
          {/* Previous arrow */}
          <button
            onClick={() => setPage(page - 1)}
            disabled={meta.current_page <= 1}
            className="flex h-8 w-8 items-center justify-center rounded border border-border text-text-secondary hover:bg-background-subtle disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            aria-label="Previous page"
          >
            <ArrowLeft className="h-4 w-4" />
          </button>

          {/* Page numbers */}
          <div className="flex items-center gap-0.5">
            {Array.from({ length: meta.total_pages }, (_, i) => i + 1)
              .filter((p) => {
                // Show current page ± 2 pages, always show first & last
                const delta = Math.abs(p - meta.current_page);
                return delta <= 2 || p === 1 || p === meta.total_pages;
              })
              .reduce((acc: (number | string)[], p) => {
                // Add ellipsis if there's a gap
                if (acc.length > 0 && typeof acc[acc.length - 1] === 'number') {
                  const last = acc[acc.length - 1] as number;
                  if (p - last > 1) acc.push('...');
                }
                acc.push(p);
                return acc;
              }, [])
              .map((p, idx) => (
                p === '...' ? (
                  <span key={`ellipsis-${idx}`} className="px-1 text-text-secondary">…</span>
                ) : (
                  <button
                    key={p}
                    onClick={() => setPage(p as number)}
                    className={`flex h-8 min-w-8 items-center justify-center rounded border text-sm font-medium transition-colors ${
                      meta.current_page === p
                        ? 'bg-primary text-white border-primary'
                        : 'border-border text-text-secondary hover:bg-background-subtle'
                    }`}
                  >
                    {p}
                  </button>
                )
              ))
            }
          </div>

          {/* Next arrow */}
          <button
            onClick={() => setPage(page + 1)}
            disabled={meta.current_page >= meta.total_pages}
            className="flex h-8 w-8 items-center justify-center rounded border border-border text-text-secondary hover:bg-background-subtle disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            aria-label="Next page"
          >
            <ArrowLeft className="h-4 w-4 rotate-180" />
          </button>

          {/* Info text */}
          {/* <span className="ml-4 text-xs text-text-secondary">
            {meta.total_count} orders
          </span> */}
        </div>
      )}
    </AppShell>
  );
}

export default function OrdersPage() {
  return (
    <Suspense fallback={<div className="min-h-screen bg-background-subtle" />}>
      <OrdersPageContent />
    </Suspense>
  );
}
