"use client";

import { useState, useEffect, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { AccessDeniedError } from "@/components/errors/access-denied-error";
import { Tabs } from "@/components/ui/tabs";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Modal } from "@/components/ui/modal";
import { Input } from "@/components/ui/input";
import { DataTable, Column } from "@/components/ui/data-table";
import { Pencil, CheckCircle2, XCircle } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";

// ─── Types ────────────────────────────────────────────────────────────────────
interface InvoiceLine {
  id: number;
  product_id: number;
  product_name: string | null;
  product_sku:  string | null;
  qty:          number;
  unit_price:   number;
  discount_pct: number;
  tax_rate:     number;
  tax_amount:   number;
  line_total:   number;
  hsn_sac_code: { id: number; code: string; gst_rate: number } | null;
  notes:        string | null;
}

interface StockMovement {
  id:            number;
  movement_type: string;
  direction:     string;
  product_id:    number;
  qty:           number;
  unit_cost:     number;
  created_at:    string;
}

interface InvoiceDetail {
  id:                  number;
  invoice_number:      string;
  invoice_date:        string;
  due_date:            string | null;
  status:              string;
  currency:            string;
  total_amount:        number;
  tax_amount:          number;
  grand_total:         number;
  notes:               string | null;
  posted_at:           string | null;
  cancelled_at:        string | null;
  cancellation_reason: string | null;
  is_reverse_charge:   boolean;
  rcm_tax_amount:      number | null;
  supplier_gstin:      string | null;
  place_of_supply:     string | null;
  created_at:          string;
  supplier:    { id: number; name: string; code: string } | null;
  branch:      { id: number; name: string } | null;
  created_by:  { id: number; name: string } | null;
  lines:           InvoiceLine[];
  stock_movements: StockMovement[];
}

const STATUS_VARIANT: Record<string, "success" | "secondary" | "danger"> = {
  draft:     "secondary",
  posted:    "success",
  cancelled: "danger",
};

function fmt(n: number) {
  return `₹${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function fmtDate(d: string | null) {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

// ─── Cancel Modal ─────────────────────────────────────────────────────────────
function CancelModal({
  onConfirm, onClose, loading,
}: { onConfirm: (reason: string) => void; onClose: () => void; loading: boolean }) {
  const [reason, setReason] = useState("");
  return (
    <Modal open onClose={onClose} title="Cancel Invoice">
      <div className="space-y-4">
        <p className="text-sm text-text-secondary">
          Are you sure you want to cancel this invoice? If it is posted, stock will be reversed.
        </p>
        <div className="space-y-1.5">
          <label className="text-sm font-medium text-text-primary">Reason (optional)</label>
          <Input
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder="Reason for cancellation…"
          />
        </div>
        <div className="flex justify-end gap-2 border-t border-border pt-3">
          <Button variant="outline" onClick={onClose} disabled={loading}>Keep Invoice</Button>
          <Button variant="danger" onClick={() => onConfirm(reason)} disabled={loading}>
            {loading ? "Cancelling…" : "Cancel Invoice"}
          </Button>
        </div>
      </div>
    </Modal>
  );
}

// ─── Summary Tab ──────────────────────────────────────────────────────────────
function SummaryTab({ inv }: { inv: InvoiceDetail }) {
  const field = (label: string, value: React.ReactNode) => (
    <div key={label}>
      <dt className="text-xs font-medium text-text-secondary uppercase tracking-wide">{label}</dt>
      <dd className="mt-0.5 text-sm text-text-primary">{value ?? <span className="text-text-secondary">—</span>}</dd>
    </div>
  );

  return (
    <div className="space-y-5">
      <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3 rounded-lg border border-border bg-background p-5">
        <div>
          <p className="text-xs font-semibold text-text-secondary uppercase tracking-wide mb-3">Invoice</p>
          <dl className="space-y-3">
            {field("Invoice #",    inv.invoice_number)}
            {field("Invoice Date", fmtDate(inv.invoice_date))}
            {field("Due Date",     fmtDate(inv.due_date))}
            {field("Currency",     inv.currency)}
          </dl>
        </div>
        <div>
          <p className="text-xs font-semibold text-text-secondary uppercase tracking-wide mb-3">Supplier</p>
          <dl className="space-y-3">
            {field("Name",   inv.supplier?.name)}
            {field("Code",   inv.supplier?.code)}
            {field("Branch", inv.branch?.name)}
          </dl>
        </div>
        <div>
          <p className="text-xs font-semibold text-text-secondary uppercase tracking-wide mb-3">Amounts</p>
          <dl className="space-y-3">
            {field("Subtotal",    fmt(inv.total_amount))}
            {field("Tax",         fmt(inv.tax_amount))}
            {field("Grand Total", <span className="font-bold text-text-primary">{fmt(inv.grand_total)}</span>)}
          </dl>
        </div>
        {inv.status === "cancelled" && (
          <div className="sm:col-span-2 lg:col-span-3">
            <p className="text-xs font-semibold text-text-secondary uppercase tracking-wide mb-2">Cancellation</p>
            <dl className="space-y-3 grid grid-cols-2 gap-4">
              {field("Cancelled At", fmtDate(inv.cancelled_at))}
              {field("Reason",       inv.cancellation_reason ?? "—")}
            </dl>
          </div>
        )}
        {inv.status === "posted" && (
          <div>
            <p className="text-xs font-semibold text-text-secondary uppercase tracking-wide mb-2">Posting</p>
            <dl className="space-y-3">
              {field("Posted At",  fmtDate(inv.posted_at))}
              {field("Posted By",  inv.created_by?.name)}
            </dl>
          </div>
        )}
        {inv.notes && (
          <div className="sm:col-span-2 lg:col-span-3">
            <p className="text-xs font-semibold text-text-secondary uppercase tracking-wide mb-2">Notes</p>
            <p className="text-sm text-text-primary whitespace-pre-line">{inv.notes}</p>
          </div>
        )}
        {/* RCM Banner */}
        {inv.is_reverse_charge && (
          <div className="sm:col-span-2 lg:col-span-3 rounded-md border border-amber-200 bg-amber-50 dark:bg-amber-950/20 dark:border-amber-800 px-4 py-3">
            <p className="text-xs font-bold text-amber-700 dark:text-amber-400 uppercase tracking-wide mb-2">Reverse Charge Mechanism (RCM)</p>
            <div className="grid grid-cols-3 gap-4 text-sm">
              <div>
                <dt className="text-xs font-medium text-text-secondary uppercase">RCM Tax Payable</dt>
                <dd className="mt-0.5 font-semibold text-amber-700">{fmt(inv.rcm_tax_amount ?? 0)}</dd>
              </div>
              <div>
                <dt className="text-xs font-medium text-text-secondary uppercase">Supplier GSTIN</dt>
                <dd className="mt-0.5 font-mono text-sm">{inv.supplier_gstin ?? "—"}</dd>
              </div>
              <div>
                <dt className="text-xs font-medium text-text-secondary uppercase">Place of Supply</dt>
                <dd className="mt-0.5 text-sm">{inv.place_of_supply ?? "—"}</dd>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

// ─── Lines Tab ────────────────────────────────────────────────────────────────
function LinesTab({ inv }: { inv: InvoiceDetail }) {
  const columns: Column<InvoiceLine>[] = [
    {
      key:    "product_name",
      header: "Product",
      render: (_: unknown, row: InvoiceLine) => (
        <div>
          <p className="text-sm font-medium text-text-primary">{row.product_name ?? "—"}</p>
          <p className="text-xs text-text-secondary font-mono">{row.product_sku ?? ""}</p>
        </div>
      ),
    },
    {
      key:    "hsn_sac_code",
      header: "HSN/SAC",
      render: (_: unknown, row: InvoiceLine) => (
        <span className="text-sm font-mono text-text-secondary">{row.hsn_sac_code?.code ?? "—"}</span>
      ),
    },
    {
      key:    "qty",
      header: "Qty",
      render: (v) => <span className="text-sm text-text-primary">{Number(v).toLocaleString("en-IN")}</span>,
    },
    {
      key:    "unit_price",
      header: "Unit Price",
      render: (v) => <span className="text-sm text-text-primary">{fmt(Number(v))}</span>,
    },
    {
      key:    "discount_pct",
      header: "Disc %",
      render: (v) => <span className="text-sm text-text-secondary">{Number(v)}%</span>,
    },
    {
      key:    "tax_rate",
      header: "GST %",
      render: (_: unknown, row: InvoiceLine) => (
        <span className="text-sm text-text-secondary">{Number(row.tax_rate)}% ({fmt(row.tax_amount)})</span>
      ),
    },
    {
      key:    "line_total",
      header: "Line Total",
      render: (v) => <span className="text-sm font-medium text-text-primary">{fmt(Number(v))}</span>,
    },
  ];

  return (
    <DataTable
      columns={columns}
      data={inv.lines}
      emptyMessage="No line items."
    />
  );
}

// ─── Movements Tab ────────────────────────────────────────────────────────────
function MovementsTab({ inv }: { inv: InvoiceDetail }) {
  if (inv.stock_movements.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-12 text-text-secondary text-sm">
        No inventory movements yet. Post the invoice to record stock entries.
      </div>
    );
  }

  const columns: Column<StockMovement>[] = [
    {
      key:    "movement_type",
      header: "Type",
      render: (v) => (
        <Badge variant={(v as string) === "reversal" ? "danger" : "success"}>
          {(v as string).charAt(0).toUpperCase() + (v as string).slice(1)}
        </Badge>
      ),
    },
    {
      key:    "direction",
      header: "Direction",
      render: (v) => (
        <span className={`text-sm font-medium ${(v as string) === "in" ? "text-success" : "text-danger"}`}>
          {(v as string).toUpperCase()}
        </span>
      ),
    },
    {
      key:    "qty",
      header: "Qty",
      render: (v) => <span className="text-sm text-text-primary">{Number(v).toLocaleString("en-IN")}</span>,
    },
    {
      key:    "unit_cost",
      header: "Unit Cost",
      render: (v) => <span className="text-sm text-text-secondary">{fmt(Number(v))}</span>,
    },
    {
      key:    "created_at",
      header: "Date",
      render: (v) => <span className="text-sm text-text-secondary">{fmtDate(v as string)}</span>,
    },
  ];

  return (
    <DataTable
      columns={columns}
      data={inv.stock_movements}
      emptyMessage="No movements."
    />
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function PurchaseInvoiceDetailPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const { token, orgId } = useOrgBranch();

  const [invoice,       setInvoice]       = useState<InvoiceDetail | null>(null);
  const [loading,       setLoading]       = useState(true);
  const [error,         setError]         = useState<{ status: number; message: string } | null>(null);
  const [actionLoading, setActionLoading] = useState(false);
  const [showCancel,    setShowCancel]    = useState(false);

  const fetchInvoice = useCallback(async () => {
    if (!token || !orgId || !params.id) return;
    setLoading(true);
    setError(null);
    try {
      const res  = await fetch(`${API_URL}/api/v1/purchase_invoices/${params.id}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      if (!res.ok) {
        const json = await res.json();
        setError({
          status: res.status,
          message: json.errors?.[0] ?? "Failed to load purchase invoice"
        });
        return;
      }
      const json = await res.json();
      setInvoice(json.data);
    } catch (e) {
      setError({
        status: 500,
        message: e instanceof Error ? e.message : "Unknown error"
      });
    } finally {
      setLoading(false);
    }
  }, [token, orgId, params.id]);

  useEffect(() => { fetchInvoice(); }, [fetchInvoice]);

  const handlePost = async () => {
    if (!token || !orgId || !invoice) return;
    setActionLoading(true);
    const res = await fetch(`${API_URL}/api/v1/purchase_invoices/${invoice.id}/post`, {
      method:  "POST",
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    });
    if (res.ok) fetchInvoice();
    setActionLoading(false);
  };

  if (loading) {
    return (
      <AppShell>
        <div className="flex items-center justify-center h-64 text-text-secondary">Loading…</div>
      </AppShell>
    );
  }

  if (error) {
    return <AccessDeniedError
      status={error.status}
      message={error.message}
      backLink="/purchases/invoices"
      resourceType="Purchase Invoice"
    />;
  }

  if (!invoice) {
    return (
      <AppShell>
        <div className="flex items-center justify-center h-64 text-text-secondary">Invoice not found</div>
      </AppShell>
    );
  }

  const handleCancel = async (reason: string) => {
    if (!token || !orgId || !invoice) return;
    setActionLoading(true);
    const res = await fetch(`${API_URL}/api/v1/purchase_invoices/${invoice.id}/cancel`, {
      method:  "POST",
      headers: {
        "Content-Type":      "application/json",
        Authorization:       `Bearer ${token}`,
        "X-Organization-Id": orgId,
      },
      body: JSON.stringify({ reason }),
    });
    if (res.ok) { setShowCancel(false); fetchInvoice(); }
    setActionLoading(false);
  };

  if (loading) {
    return (
      <AppShell title="Purchase Invoice">
        <div className="flex items-center justify-center h-48">
          <div className="h-6 w-6 animate-spin rounded-full border-2 border-accent border-t-transparent" />
        </div>
      </AppShell>
    );
  }

  if (error) {
    const { status, message } = error;
    return <AccessDeniedError status={status} message={message} backLink="/purchases/invoices" resourceType="Purchase Invoice" />;
  }

  if (!invoice) {
    return (
      <AppShell title="Not Found">
        <div className="flex items-center justify-center h-48 text-text-secondary text-sm">
          Invoice not found.
        </div>
      </AppShell>
    );
  }

  const actions = [
    ...(invoice.status === "draft"
      ? [
          {
            label:    "Edit",
            onClick:  () => router.push(`/purchases/invoices/${invoice.id}/edit`),
            icon:     Pencil,
            variant:  "outline" as const,
          },
          {
            label:    "Post Invoice",
            onClick:  handlePost,
            icon:     CheckCircle2,
            disabled: actionLoading,
          },
        ]
      : []),
    ...(invoice.status !== "cancelled"
      ? [{
          label:    "Cancel",
          onClick:  () => setShowCancel(true),
          icon:     XCircle,
          variant:  "danger" as const,
          disabled: actionLoading,
        }]
      : []),
  ];

  const tabs = [
    {
      value:   "summary",
      label:   "Summary",
      content: <SummaryTab inv={invoice} />,
    },
    {
      value:   "lines",
      label:   `Lines (${invoice.lines.length})`,
      content: <LinesTab inv={invoice} />,
    },
    {
      value:   "movements",
      label:   `Inventory Movements (${invoice.stock_movements.length})`,
      content: <MovementsTab inv={invoice} />,
    },
  ];

  return (
    <AppShell breadcrumbs={[
        { label: "Purchases", href: "/purchases/invoices" },
        { label: invoice.invoice_number },
      ]}>
      <PageHeader
        title={invoice.invoice_number}
        description={
          <span className="flex items-center gap-2">
            <span className="text-text-secondary text-sm">
              {invoice.supplier?.name} · {fmtDate(invoice.invoice_date)}
            </span>
            <Badge variant={STATUS_VARIANT[invoice.status] ?? "secondary"}>
              {invoice.status.charAt(0).toUpperCase() + invoice.status.slice(1)}
            </Badge>
          </span>
        }
        actions={actions}
      />

      <div className="mt-6">
        <Tabs items={tabs} />
      </div>

      {showCancel && (
        <CancelModal
          onConfirm={handleCancel}
          onClose={() => setShowCancel(false)}
          loading={actionLoading}
        />
      )}
    </AppShell>
  );
}
