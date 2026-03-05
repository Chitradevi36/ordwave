"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Breadcrumb, BreadcrumbItem } from "@/components/ui/breadcrumb";
import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useOrgBranch } from "@/lib/org-branch-context";
import { Search, Download, Plus } from "lucide-react";
import CreateInvoiceModal from "@/components/invoices/create-invoice-modal";

// ── Constants ─────────────────────────────────────────────────────────────────

const STATUS_TABS = [
  { key: "",       label: "All" },
  { key: "draft",  label: "Draft" },
  { key: "issued", label: "Issued" },
  { key: "void",   label: "Void" },
];

const STATUS_VARIANT: Record<string, "secondary" | "warning" | "default" | "success" | "danger"> = {
  draft:  "secondary",
  issued: "success",
  void:   "danger",
};

// ── Types ─────────────────────────────────────────────────────────────────────

interface InvoiceSummary {
  id:             number;
  invoice_number: string;
  invoice_date:   string;
  due_date:       string | null;
  status:         string;
  subtotal:       number;
  tax_total:      number;
  grand_total:    number;
  currency:       string;
  issued_at:      string | null;
  created_at:     string;
  has_pdf:        boolean;
  customer:       { id: number; name: string; code: string };
  branch:         { id: number; name: string };
  sales_order:    { id: number; order_number: string } | null;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const fmtCurrency = (n: number) =>
  `₹ ${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2 })}`;

const fmtDate = (d: string | null) =>
  d ? new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" }) : "—";

// ── Page ──────────────────────────────────────────────────────────────────────

export default function SalesInvoicesPage() {
  const router           = useRouter();
  const { token, orgId } = useOrgBranch();

  const [invoices, setInvoices]     = useState<InvoiceSummary[]>([]);
  const [loading, setLoading]       = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [activeTab, setActiveTab]   = useState("");
  const [search, setSearch]         = useState("");
  const [page, setPage]             = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [counts, setCounts]         = useState<Record<string, number>>({});

  const fetchInvoices = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const params = new URLSearchParams({ page: String(page), per_page: "25" });
      if (activeTab) params.set("status", activeTab);
      if (search)    params.set("q", search);

      const res = await fetch(`/api/v1/sales_invoices?${params}`, {
        headers: {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
      });
      if (!res.ok) throw new Error("Failed to fetch invoices");
      const body = await res.json();
      setInvoices(body.data ?? []);
      setTotalPages(body.meta?.total_pages ?? 1);
      setCounts(body.meta?.counts ?? {});
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  }, [token, orgId, page, activeTab, search]);

  useEffect(() => { fetchInvoices(); }, [fetchInvoices]);
  useEffect(() => { setPage(1); }, [activeTab, search]);

  const totalCount = Object.values(counts).reduce((s, v) => s + v, 0);

  const handleDownloadPdf = async (inv: InvoiceSummary, e: React.MouseEvent) => {
    e.stopPropagation();
    if (!token || !orgId) return;
    const res = await fetch(`/api/v1/sales_invoices/${inv.id}/pdf`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    });
    if (res.ok) {
      const body = await res.json();
      if (body.data?.download_url) {
        window.open(body.data.download_url, "_blank");
      }
    }
  };

  const columns: Column<InvoiceSummary>[] = [
    {
      key:    "invoice_number",
      header: "Invoice #",
      render: (_, row) => (
        <span className="font-mono text-sm font-medium text-primary">
          {row.invoice_number}
        </span>
      ),
    },
    {
      key:    "customer",
      header: "Customer",
      render: (_, row) => (
        <div>
          <div className="font-medium text-sm">{row.customer.name}</div>
          <div className="text-xs text-muted-foreground">{row.customer.code}</div>
        </div>
      ),
    },
    {
      key:    "invoice_date",
      header: "Date",
      render: (_, row) => (
        <div>
          <div className="text-sm">{fmtDate(row.invoice_date)}</div>
          {row.due_date && (
            <div className="text-xs text-muted-foreground">
              Due {fmtDate(row.due_date)}
            </div>
          )}
        </div>
      ),
    },
    {
      key:    "status",
      header: "Status",
      render: (_, row) => (
        <Badge variant={STATUS_VARIANT[row.status] ?? "secondary"}>
          {row.status.toUpperCase()}
        </Badge>
      ),
    },
    {
      key:    "grand_total",
      header: "Amount",
      render: (_, row) => (
        <div className="text-right">
          <div className="font-semibold text-sm">{fmtCurrency(row.grand_total)}</div>
          <div className="text-xs text-muted-foreground">
            Tax: {fmtCurrency(row.tax_total)}
          </div>
        </div>
      ),
    },
    {
      key:    "branch",
      header: "Branch",
      render: (_, row) => (
        <span className="text-sm text-muted-foreground">{row.branch.name}</span>
      ),
    },
    {
      key:    "actions",
      header: "",
      render: (_, row) => (
        <div className="flex items-center gap-1">
          <Button
            size="sm"
            variant="ghost"
            onClick={(e) => handleDownloadPdf(row, e)}
            title="Download PDF"
          >
            <Download className="h-4 w-4" />
          </Button>
        </div>
      ),
    },
  ];

  return (
    <>
    <AppShell>
      <div className="p-6 space-y-4">
        {/* Breadcrumb */}
        <Breadcrumb items={[{ label: "Home", href: "/dashboard" }, { label: "Sales Invoices" }]} />

        {/* Header */}
        <PageHeader
          title="Sales Invoices"
          subtitle={`${totalCount} invoice${totalCount !== 1 ? "s" : ""} total`}
          actions={[{ label: "New Invoice", onClick: () => setShowCreate(true), icon: Plus }]}
        />

        {/* Tabs */}
        <div className="border-b flex gap-1">
          {STATUS_TABS.map((tab) => {
            const count = tab.key ? (counts[tab.key] ?? 0) : totalCount;
            return (
              <button
                key={tab.key}
                onClick={() => setActiveTab(tab.key)}
                className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors ${
                  activeTab === tab.key
                    ? "border-primary text-primary"
                    : "border-transparent text-muted-foreground hover:text-foreground"
                }`}
              >
                {tab.label}
                {count > 0 && (
                  <span className="ml-1.5 text-xs bg-muted rounded-full px-1.5 py-0.5">
                    {count}
                  </span>
                )}
              </button>
            );
          })}
        </div>

        {/* Search */}
        <div className="relative w-80">
          <Search className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Search by invoice # or customer…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9"
          />
        </div>

        {/* Table */}
        <DataTable
          columns={columns}
          data={invoices}
          isLoading={loading}
          onRowClick={(row) => router.push(`/sales-invoices/${row.id}`)}
          emptyMessage="No invoices yet"
        />

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="flex justify-end gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => setPage((p) => Math.max(1, p - 1))}
              disabled={page === 1}
            >
              Previous
            </Button>
            <span className="text-sm text-muted-foreground self-center">
              Page {page} of {totalPages}
            </span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
              disabled={page === totalPages}
            >
              Next
            </Button>
          </div>
        )}
      </div>
    </AppShell>

    {showCreate && (
      <CreateInvoiceModal
        onClose={() => setShowCreate(false)}
        onCreated={(id) => { setShowCreate(false); router.push(`/sales-invoices/${id}`); }}
      />
    )}
    </>
  );
}
