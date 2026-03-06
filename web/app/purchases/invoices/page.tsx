"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Plus, Search, X } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";

// ─── Types ────────────────────────────────────────────────────────────────────
interface PurchaseInvoice {
  id: number;
  invoice_number: string;
  invoice_date: string;
  due_date: string | null;
  status: string;
  grand_total: number;
  currency: string;
  supplier: { id: number; name: string; code: string } | null;
  branch: { id: number; name: string } | null;
  created_at: string;
}

interface Supplier { id: number; name: string; code: string; }

const STATUS_VARIANT: Record<string, "success" | "secondary" | "danger" | "warning"> = {
  draft:     "secondary",
  posted:    "success",
  cancelled: "danger",
};

const STATUS_TABS = [
  { value: "",          label: "All" },
  { value: "draft",     label: "Draft" },
  { value: "posted",    label: "Posted" },
  { value: "cancelled", label: "Cancelled" },
];

function fmt(n: number, currency = "INR") {
  return `₹${n.toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function fmtDate(d: string) {
  return new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function PurchaseInvoicesPage() {
  const router = useRouter();
  const { token, orgId } = useOrgBranch();

  const [invoices,   setInvoices]   = useState<PurchaseInvoice[]>([]);
  const [suppliers,  setSuppliers]  = useState<Supplier[]>([]);
  const [loading,    setLoading]    = useState(false);
  const [search,     setSearch]     = useState("");
  const [status,     setStatus]     = useState("");
  const [supplierId, setSupplierId] = useState("");
  const [dateFrom,   setDateFrom]   = useState("");
  const [dateTo,     setDateTo]     = useState("");
  const [page,       setPage]       = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalCount, setTotalCount] = useState(0);

  // Fetch supplier list for filter dropdown
  useEffect(() => {
    if (!token || !orgId) return;
    fetch(`${API_URL}/api/v1/suppliers?per_page=200&status=active`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then((r) => r.json())
      .then((j) => setSuppliers(j.data ?? []));
  }, [token, orgId]);

  const fetchInvoices = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const qs = new URLSearchParams({ page: String(page), per_page: "25" });
      if (search)     qs.set("q",           search);
      if (status)     qs.set("status",      status);
      if (supplierId) qs.set("supplier_id", supplierId);
      if (dateFrom)   qs.set("date_from",   dateFrom);
      if (dateTo)     qs.set("date_to",     dateTo);

      const res  = await fetch(`${API_URL}/api/v1/purchase_invoices?${qs}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) {
        setInvoices(json.data);
        setTotalPages(json.meta?.total_pages ?? 1);
        setTotalCount(json.meta?.total_count  ?? 0);
      }
    } finally {
      setLoading(false);
    }
  }, [token, orgId, page, search, status, supplierId, dateFrom, dateTo]);

  useEffect(() => { fetchInvoices(); }, [fetchInvoices]);

  // Reset page when filters change
  useEffect(() => { setPage(1); }, [search, status, supplierId, dateFrom, dateTo]);

  const columns: Column<PurchaseInvoice>[] = [
    {
      key:    "invoice_number",
      header: "Invoice #",
      render: (_: unknown, row: PurchaseInvoice) => (
        <div>
          <p className="font-medium text-text-primary font-mono">{row.invoice_number}</p>
          <p className="text-xs text-text-secondary">{fmtDate(row.invoice_date)}</p>
        </div>
      ),
    },
    {
      key:    "supplier",
      header: "Supplier",
      render: (_: unknown, row: PurchaseInvoice) => (
        <div>
          <p className="text-sm text-text-primary">{row.supplier?.name ?? "—"}</p>
          <p className="text-xs text-text-secondary font-mono">{row.supplier?.code}</p>
        </div>
      ),
    },
    {
      key:    "status",
      header: "Status",
      render: (_: unknown, row: PurchaseInvoice) => (
        <Badge variant={STATUS_VARIANT[row.status] ?? "secondary"}>
          {row.status.charAt(0).toUpperCase() + row.status.slice(1)}
        </Badge>
      ),
    },
    {
      key:    "grand_total",
      header: "Grand Total",
      render: (_: unknown, row: PurchaseInvoice) => (
        <span className="text-sm font-medium text-text-primary">{fmt(row.grand_total)}</span>
      ),
    },
    {
      key:    "due_date",
      header: "Due Date",
      render: (_: unknown, row: PurchaseInvoice) => (
        <span className="text-sm text-text-secondary">
          {row.due_date ? fmtDate(row.due_date) : "—"}
        </span>
      ),
    },
    {
      key:    "branch",
      header: "Branch",
      render: (_: unknown, row: PurchaseInvoice) => (
        <span className="text-sm text-text-secondary">{row.branch?.name ?? "—"}</span>
      ),
    },
  ];

  const clearFilters = () => {
    setSearch(""); setStatus(""); setSupplierId(""); setDateFrom(""); setDateTo("");
  };
  const hasFilters = !!(search || status || supplierId || dateFrom || dateTo);

  return (
    <AppShell title="Purchase Invoices">
      <PageHeader
        title="Purchase Invoices"
        description={`${totalCount} invoice${totalCount !== 1 ? "s" : ""} found`}
        actions={[{
          label:   "New Invoice",
          onClick: () => router.push("/purchases/invoices/new"),
          icon:    Plus,
        }]}
      />

      {/* Status tabs */}
      <div className="mt-4 flex gap-1 border-b border-border">
        {STATUS_TABS.map((tab) => (
          <button
            key={tab.value}
            onClick={() => setStatus(tab.value)}
            className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors ${
              status === tab.value
                ? "border-primary text-primary"
                : "border-transparent text-text-secondary hover:text-text-primary"
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Filters */}
      <div className="mt-4 flex flex-wrap items-center gap-3">
        <div className="relative flex-1 min-w-[200px]">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary" />
          <Input
            className="pl-9"
            placeholder="Search invoice #…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>

        <select
          className="h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
          value={supplierId}
          onChange={(e) => setSupplierId(e.target.value)}
        >
          <option value="">All suppliers</option>
          {suppliers.map((s) => (
            <option key={s.id} value={String(s.id)}>{s.name}</option>
          ))}
        </select>

        <input
          type="date"
          className="h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
          value={dateFrom}
          onChange={(e) => setDateFrom(e.target.value)}
          title="From date"
        />
        <input
          type="date"
          className="h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
          value={dateTo}
          onChange={(e) => setDateTo(e.target.value)}
          title="To date"
        />

        {hasFilters && (
          <Button variant="ghost" size="sm" onClick={clearFilters}>
            <X className="h-3.5 w-3.5 mr-1" /> Clear
          </Button>
        )}
      </div>

      <div className="mt-4">
        <DataTable
          columns={columns}
          data={invoices}
          isLoading={loading}
          onRowClick={(row) => router.push(`/purchases/invoices/${row.id}`)}
          emptyMessage="No purchase invoices found."
        />
      </div>

      {totalPages > 1 && (
        <div className="flex justify-center gap-2 mt-6">
          <Button variant="outline" size="sm" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
            Previous
          </Button>
          <span className="px-3 py-1.5 text-sm text-text-secondary">
            Page {page} of {totalPages}
          </span>
          <Button variant="outline" size="sm" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>
            Next
          </Button>
        </div>
      )}
    </AppShell>
  );
}
