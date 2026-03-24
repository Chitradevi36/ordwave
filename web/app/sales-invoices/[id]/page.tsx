"use client";

import { useState, useEffect, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Modal } from "@/components/ui/modal";
import { Input } from "@/components/ui/input";
import { useOrgBranch } from "@/lib/org-branch-context";
import { AccessDeniedError } from "@/components/errors/access-denied-error";
import { Download, Ban, CheckCircle2, ExternalLink, FileCheck, Truck, Eye } from "lucide-react";

// ── Types ─────────────────────────────────────────────────────────────────────

interface InvoiceLine {
  id:            number;
  product_id:    number;
  product_name:  string;
  product_sku:   string;
  hsn_code:      string | null;
  qty:           number;
  unit_price:    number;
  discount_pct:  number;
  taxable_value: number;
  gst_rate:      number;
  cgst_rate:     number;
  sgst_rate:     number;
  igst_rate:     number;
  cgst_amount:   number;
  sgst_amount:   number;
  igst_amount:   number;
  tax_amount:    number;
  line_total:    number;
}

interface TaxBreakup {
  cgst_total:  number;
  sgst_total:  number;
  igst_total:  number;
  hsn_summary: Record<string, { taxable_value: number; gst_rate: number; tax_amount: number }>;
}

interface AuditEntry {
  action:     string;
  actor:      { id: number; name: string } | null;
  changes:    Record<string, unknown>;
  reason:     string | null;
  created_at: string;
}

interface InvoiceDetail {
  id:                number;
  invoice_number:    string;
  invoice_date:      string;
  due_date:          string | null;
  status:            string;
  subtotal:          number;
  tax_total:         number;
  grand_total:       number;
  currency:          string;
  notes:             string | null;
  generation_source: string;
  issued_at:         string | null;
  voided_at:         string | null;
  void_reason:       string | null;
  pdf_generated_at:  string | null;
  has_pdf:           boolean;
  pdf_url:           string | null;
  einvoice_status:   string | null;
  irn:               string | null;
  ack_number:        string | null;
  ack_datetime:      string | null;
  einvoice_qr_code:  string | null;
  irn_generated_at:    string | null;
  ewaybill_number:      string | null;
  ewaybill_status:      string | null;
  ewaybill_valid_upto:  string | null;
  ewaybill_generated_at: string | null;
  created_at:           string;
  customer:          { id: number; name: string; code: string; gstin: string | null };
  branch:            { id: number; name: string; code: string };
  sales_order:       { id: number; order_number: string } | null;
  lines:             InvoiceLine[];
  tax_breakup:       TaxBreakup;
  audit_trail:       AuditEntry[];
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const STATUS_VARIANT: Record<string, "secondary" | "warning" | "success" | "danger"> = {
  draft:  "secondary",
  issued: "success",
  void:   "danger",
};

const fmt = (n: number | string) =>
  `₹ ${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2 })}`;

const fmtDate = (d: string | null) =>
  d ? new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" }) : "—";

const fmtDatetime = (d: string | null) =>
  d ? new Date(d).toLocaleString("en-IN", { day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" }) : "—";

const ACTION_LABEL: Record<string, string> = {
  invoice_created:       "Invoice Created",
  invoice_issued:        "Invoice Issued",
  invoice_voided:        "Invoice Voided",
  invoice_pdf_generated: "PDF Generated",
  invoice_irn_generated:  "IRN Generated",
};

const SOURCE_LABEL: Record<string, string> = {
  auto_on_delivery:  "Auto (on delivery)",
  manual_from_order: "Manual (from order)",
  manual_direct:     "Manual (direct)",
};

// ── Page ──────────────────────────────────────────────────────────────────────

export default function SalesInvoiceDetailPage() {
  const params           = useParams<{ id: string }>();
  const router           = useRouter();
  const { token, orgId } = useOrgBranch();

  const [invoice, setInvoice]         = useState<InvoiceDetail | null>(null);
  const [loading, setLoading]         = useState(true);
  const [error, setError]             = useState<{ status: number; message: string } | null>(null);
  const [voidModal, setVoidModal]     = useState(false);
  const [voidReason, setVoidReason]   = useState("");
  const [saving, setSaving]           = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [pdfLoading, setPdfLoading]         = useState(false);
  const [einvoiceLoading, setEinvoiceLoading] = useState(false);
  const [showPdfPreview, setShowPdfPreview] = useState(false);
  const [previewUrl, setPreviewUrl]         = useState<string | null>(null);
  const [activeTab, setActiveTab]     = useState<"summary" | "lines" | "tax" | "activity" | "linked">("summary");

  // e-Waybill state
  const [ewayModal, setEwayModal]         = useState(false);
  const [ewayVehicle, setEwayVehicle]     = useState("");
  const [ewayTransporter, setEwayTransporter] = useState("");
  const [ewayTransId, setEwayTransId]     = useState("");
  const [ewayDistance, setEwayDistance]   = useState("");
  const [ewayMode, setEwayMode]           = useState("1"); // 1=Road
  const [ewayLoading, setEwayLoading]     = useState(false);
  const [ewayError, setEwayError]         = useState<string | null>(null);

  const fetchInvoice = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`/api/v1/sales_invoices/${params.id}`, {
        headers: {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
      });
      if (!res.ok) {
        const body = await res.json();
        setError({
          status: res.status,
          message: body.errors?.[0] ?? "Failed to load sales invoice"
        });
        return;
      }
      const body = await res.json();
      setInvoice(body.data);
    } catch (e) {
      setError({
        status: 500,
        message: e instanceof Error ? e.message : "An error occurred"
      });
    } finally {
      setLoading(false);
    }
  }, [token, orgId, params.id]);

  useEffect(() => { fetchInvoice(); }, [fetchInvoice]);

  const handleDownloadPdf = async () => {
    if (!invoice || !token || !orgId) return;
    setPdfLoading(true);
    setActionError(null);
    try {
      const res = await fetch(`/api/v1/sales_invoices/${invoice.id}/pdf`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "PDF generation failed");
      if (body.data?.download_url) {
        window.open(body.data.download_url, "_blank");
        // Refresh to show updated pdf_generated_at
        fetchInvoice();
      }
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setPdfLoading(false);
    }
  };

  const handlePreviewPdf = async () => {
    if (!invoice || !token || !orgId) return;
    // Use already-fetched pdf_url if available; otherwise fetch it
    if (invoice.pdf_url) {
      setPreviewUrl(invoice.pdf_url);
      setShowPdfPreview(true);
      return;
    }
    setPdfLoading(true);
    setActionError(null);
    try {
      const res  = await fetch(`/api/v1/sales_invoices/${invoice.id}/pdf`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "PDF generation failed");
      if (body.data?.download_url) {
        setPreviewUrl(body.data.download_url);
        setShowPdfPreview(true);
        fetchInvoice();
      }
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setPdfLoading(false);
    }
  };

  const handleVoid = async () => {
    if (!invoice || !voidReason.trim()) return;
    setSaving(true);
    setActionError(null);
    try {
      const res = await fetch(`/api/v1/sales_invoices/${invoice.id}/void`, {
        method:  "POST",
        headers: {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId!,
          "Content-Type":      "application/json",
        },
        body: JSON.stringify({ reason: voidReason }),
      });
      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "Void failed");
      setInvoice(body.data);
      setVoidModal(false);
      setVoidReason("");
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setSaving(false);
    }
  };

  const handleGenerateEwaybill = async () => {
    if (!invoice || !token || !orgId) return;
    setEwayLoading(true);
    setEwayError(null);
    try {
      const res = await fetch(`/api/v1/sales_invoices/${invoice.id}/ewaybill`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          transport_mode:   ewayMode,
          vehicle_number:   ewayVehicle,
          transporter_name: ewayTransporter,
          transporter_id:   ewayTransId,
          distance_km:      ewayDistance ? Number(ewayDistance) : undefined,
        }),
      });
      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "E-Way Bill generation failed");
      setInvoice(body.data);
      setEwayModal(false);
    } catch (e) {
      setEwayError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setEwayLoading(false);
    }
  };

  const handleGenerateEinvoice = async () => {
    if (!invoice || !token || !orgId) return;
    setEinvoiceLoading(true);
    setActionError(null);
    try {
      const res = await fetch(`/api/v1/sales_invoices/${invoice.id}/einvoice`, {
        method:  "POST",
        headers: {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
      });
      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "e-Invoice generation failed");
      setInvoice(body.data);
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setEinvoiceLoading(false);
    }
  };

  // ── Loading/Error ─────────────────────────────────────────────────────────

  if (loading) {
    return (
      <AppShell>
        <div className="p-6 text-sm text-text-secondary">Loading invoice…</div>
      </AppShell>
    );
  }

  if (error) {
    return <AccessDeniedError
      status={error.status}
      message={error.message}
      backLink="/sales-invoices"
      resourceType="Sales Invoice"
    />;
  }

  if (!invoice) {
    return (
      <AppShell>
        <div className="p-6 space-y-3">
          <p className="text-sm text-destructive">Invoice not found</p>
          <Button variant="outline" size="sm" onClick={() => router.push("/sales-invoices")}>
            Back to Invoices
          </Button>
        </div>
      </AppShell>
    );
  }

  const isVoidable     = invoice.status === "issued";
  const isDraft        = invoice.status === "draft";
  const isEinvoiceable   = invoice.status === "issued" && !invoice.irn;
  const isEwaybillable   = invoice.status === "issued" && !invoice.ewaybill_number;

  const headerActions = [
    {
      label:    pdfLoading ? "Loading…" : "Preview PDF",
      onClick:  handlePreviewPdf,
      variant:  "outline" as const,
      icon:     Eye,
      disabled: pdfLoading || isDraft,
    },
    {
      label:    pdfLoading ? "Generating…" : invoice.pdf_generated_at ? "Download PDF" : "Generate PDF",
      onClick:  handleDownloadPdf,
      variant:  "outline" as const,
      icon:     Download,
      disabled: pdfLoading || isDraft,
    },
    ...(isEinvoiceable
      ? [{
          label:    einvoiceLoading ? "Generating IRN…" : "Generate e-Invoice",
          onClick:  handleGenerateEinvoice,
          variant:  "outline" as const,
          icon:     FileCheck,
          disabled: einvoiceLoading,
        }]
      : []),
    ...(isEwaybillable
      ? [{
          label:   "Generate E-Way Bill",
          onClick: () => setEwayModal(true),
          variant: "outline" as const,
          icon:    Truck,
        }]
      : []),
    ...(isVoidable
      ? [{ label: "Void", onClick: () => setVoidModal(true), variant: "danger" as const, icon: Ban }]
      : []),
  ];

  return (
    <AppShell breadcrumbs={[
        { label: "Finance", href: "/finance" },
        { label: "Sales Invoices", href: "/sales-invoices" },
        { label: invoice.invoice_number },
      ]}>
      <div className="max-w-5xl space-y-5">

        {/* Header */}
        <PageHeader
          title={invoice.invoice_number}
          description={
            <span className="flex items-center gap-2 mt-1">
              <Badge variant={STATUS_VARIANT[invoice.status] ?? "secondary"}>
                {invoice.status.toUpperCase()}
              </Badge>
              <span className="text-sm text-text-secondary">
                {invoice.customer.name} · {invoice.branch.name}
              </span>
              <span className="text-xs text-text-secondary">
                {SOURCE_LABEL[invoice.generation_source] ?? invoice.generation_source}
              </span>
            </span>
          }
          actions={headerActions}
        />

        {/* Action error */}
        {actionError && (
          <div className="bg-destructive/10 border border-destructive/20 text-destructive rounded-md px-4 py-3 text-sm">
            {actionError}
          </div>
        )}

        {/* Tabs */}
        <div>
          <div className="border-b flex gap-1 mb-4">
            {(["summary", "lines", "tax", "activity", "linked"] as const).map((key) => {
              const label: Record<typeof key, string> = {
                summary:  "Summary",
                lines:    `Lines (${invoice.lines.length})`,
                tax:      "Tax Breakup",
                activity: "Activity",
                linked:   "Linked Docs",
              };
              return (
                <button
                  key={key}
                  onClick={() => setActiveTab(key)}
                  className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors ${
                    activeTab === key
                      ? "border-primary text-primary"
                      : "border-transparent text-text-secondary hover:text-text-primary"
                  }`}
                >
                  {label[key]}
                </button>
              );
            })}
          </div>

          {/* ── Summary ── */}
          {activeTab === "summary" && (<div className="mt-4 space-y-4">
            <div className="grid grid-cols-2 gap-6">
              {/* Left: meta */}
              <div className="rounded-lg border bg-card p-5 space-y-4">
                <h3 className="text-xs font-semibold text-text-secondary uppercase tracking-wider">
                  Invoice Details
                </h3>
                <dl className="grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
                  {[
                    ["Invoice Date",  fmtDate(invoice.invoice_date)],
                    ["Due Date",      fmtDate(invoice.due_date)],
                    ["Issued At",     fmtDatetime(invoice.issued_at)],
                    ["Customer",      invoice.customer.name],
                    ["GSTIN",         invoice.customer.gstin ?? "Unregistered"],
                    ["Branch",        invoice.branch.name],
                  ].map(([label, value]) => (
                    <div key={label}>
                      <dt className="text-text-secondary">{label}</dt>
                      <dd className="font-medium mt-0.5">{value}</dd>
                    </div>
                  ))}
                  {invoice.voided_at && (
                    <>
                      <div>
                        <dt className="text-text-secondary">Voided At</dt>
                        <dd className="font-medium text-destructive mt-0.5">
                          {fmtDatetime(invoice.voided_at)}
                        </dd>
                      </div>
                      <div className="col-span-2">
                        <dt className="text-text-secondary">Void Reason</dt>
                        <dd className="font-medium text-destructive mt-0.5">
                          {invoice.void_reason}
                        </dd>
                      </div>
                    </>
                  )}
                  {invoice.notes && (
                    <div className="col-span-2">
                      <dt className="text-text-secondary">Notes</dt>
                      <dd className="font-medium mt-0.5">{invoice.notes}</dd>
                    </div>
                  )}
                </dl>
              </div>

              {/* Right: financials */}
              <div className="rounded-lg border bg-card p-5 space-y-3">
                <h3 className="text-xs font-semibold text-text-secondary uppercase tracking-wider">
                  Financials
                </h3>
                <div className="space-y-2 text-sm">
                  {[
                    ["Subtotal (Taxable)", invoice.subtotal],
                    ["CGST",              invoice.tax_breakup.cgst_total],
                    ["SGST",              invoice.tax_breakup.sgst_total],
                    ["IGST",              invoice.tax_breakup.igst_total],
                    ["Total Tax",         invoice.tax_total],
                  ].map(([label, value]) => (
                    <div key={String(label)} className="flex justify-between text-text-secondary">
                      <span>{label}</span>
                      <span>{fmt(value as number)}</span>
                    </div>
                  ))}
                  <div className="flex justify-between font-bold text-base border-t pt-2 mt-1">
                    <span>Grand Total</span>
                    <span className="text-primary">{fmt(invoice.grand_total)}</span>
                  </div>
                </div>
              </div>
            </div>

            {/* e-Invoice / IRN panel */}
            {invoice.status === "issued" && (
              <div className="rounded-lg border bg-card p-5">
                <h3 className="text-xs font-semibold text-text-secondary uppercase tracking-wider mb-4">
                  e-Invoice (IRP)
                </h3>
                {invoice.irn ? (
                  <dl className="grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
                    <div className="col-span-2">
                      <dt className="text-text-secondary">IRN</dt>
                      <dd className="font-mono text-xs mt-0.5 break-all bg-muted/40 px-2 py-1 rounded">
                        {invoice.irn}
                      </dd>
                    </div>
                    {invoice.ack_number && (
                      <div>
                        <dt className="text-text-secondary">ACK Number</dt>
                        <dd className="font-medium mt-0.5">{invoice.ack_number}</dd>
                      </div>
                    )}
                    {invoice.ack_datetime && (
                      <div>
                        <dt className="text-text-secondary">ACK Date / Time</dt>
                        <dd className="font-medium mt-0.5">{fmtDatetime(invoice.ack_datetime)}</dd>
                      </div>
                    )}
                    {invoice.irn_generated_at && (
                      <div>
                        <dt className="text-text-secondary">Generated At</dt>
                        <dd className="font-medium mt-0.5">{fmtDatetime(invoice.irn_generated_at)}</dd>
                      </div>
                    )}
                    {invoice.einvoice_qr_code && (
                      <div className="col-span-2 mt-2">
                        <dt className="text-text-secondary mb-1.5">QR Code</dt>
                        <img
                          src={`data:image/png;base64,${invoice.einvoice_qr_code}`}
                          alt="e-Invoice QR Code"
                          className="h-32 w-32 rounded border"
                          onError={(e) => { (e.target as HTMLImageElement).style.display = "none"; }}
                        />
                      </div>
                    )}
                  </dl>
                ) : (
                  <div className="flex items-center justify-between gap-4">
                    <p className="text-sm">
                      {invoice.einvoice_status === "pending" ? (
                        <span className="text-amber-600 font-medium">IRN generation in progress…</span>
                      ) : invoice.einvoice_status === "failed" ? (
                        <span className="text-destructive font-medium">IRN generation failed. Retry below.</span>
                      ) : (
                        <span className="text-text-secondary">IRN not yet generated.</span>
                      )}
                    </p>
                    <Button
                      size="sm"
                      variant="outline"
                      disabled={einvoiceLoading || invoice.einvoice_status === "pending"}
                      onClick={handleGenerateEinvoice}
                    >
                      <FileCheck className="h-3.5 w-3.5 mr-1.5" />
                      {einvoiceLoading ? "Generating IRN…" : "Generate e-Invoice"}
                    </Button>
                  </div>
                )}
              </div>
            )}
          </div>)}

          {/* e-Way Bill panel */}
          {invoice.status === "issued" && (
            <div className="rounded-lg border bg-card p-5">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-xs font-semibold text-text-secondary uppercase tracking-wider">
                  e-Way Bill
                </h3>
                {!invoice.ewaybill_number && (
                  <Button size="sm" variant="outline" onClick={() => setEwayModal(true)}>
                    <Truck className="h-3.5 w-3.5 mr-1.5" />
                    Generate E-Way Bill
                  </Button>
                )}
              </div>
              {invoice.ewaybill_number ? (
                <dl className="grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
                  <div>
                    <dt className="text-text-secondary">EWB Number</dt>
                    <dd className="font-mono font-medium mt-0.5">{invoice.ewaybill_number}</dd>
                  </div>
                  <div>
                    <dt className="text-text-secondary">Status</dt>
                    <dd className="mt-0.5">
                      <Badge variant={invoice.ewaybill_status === "active" ? "success" : "secondary"}>
                        {invoice.ewaybill_status ?? "—"}
                      </Badge>
                    </dd>
                  </div>
                  {invoice.ewaybill_valid_upto && (
                    <div>
                      <dt className="text-text-secondary">Valid Until</dt>
                      <dd className="font-medium mt-0.5">{fmtDatetime(invoice.ewaybill_valid_upto)}</dd>
                    </div>
                  )}
                  {invoice.ewaybill_generated_at && (
                    <div>
                      <dt className="text-text-secondary">Generated At</dt>
                      <dd className="font-medium mt-0.5">{fmtDatetime(invoice.ewaybill_generated_at)}</dd>
                    </div>
                  )}
                </dl>
              ) : (
                <p className="text-sm text-text-secondary">No e-Way Bill generated yet.</p>
              )}
            </div>
          )}

          {/* ── Lines ── */}
          {activeTab === "lines" && (<div className="mt-4">
            <div className="rounded-lg border overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-muted/40">
                  <tr>
                    {["#", "Product", "HSN", "Qty", "Rate", "Disc%", "Taxable", "GST%", "Tax", "Total"].map((h) => (
                      <th key={h} className="px-3 py-2.5 text-left text-xs font-semibold text-text-secondary">
                        {h}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y">
                  {invoice.lines.map((l, i) => (
                    <tr key={l.id} className="hover:bg-muted/20">
                      <td className="px-3 py-2 text-text-secondary">{i + 1}</td>
                      <td className="px-3 py-2">
                        <div className="font-medium">{l.product_name}</div>
                        <div className="text-xs text-text-secondary">{l.product_sku}</div>
                      </td>
                      <td className="px-3 py-2 font-mono text-xs text-text-secondary">{l.hsn_code ?? "—"}</td>
                      <td className="px-3 py-2 text-right">{Number(l.qty).toFixed(2)}</td>
                      <td className="px-3 py-2 text-right">{fmt(l.unit_price)}</td>
                      <td className="px-3 py-2 text-right">{l.discount_pct ? `${l.discount_pct}%` : "—"}</td>
                      <td className="px-3 py-2 text-right">{fmt(l.taxable_value)}</td>
                      <td className="px-3 py-2 text-right">{l.gst_rate}%</td>
                      <td className="px-3 py-2 text-right">
                        <div>{fmt(l.tax_amount)}</div>
                        {l.cgst_amount > 0 && (
                          <div className="text-xs text-text-secondary">
                            C: {fmt(l.cgst_amount)} S: {fmt(l.sgst_amount)}
                          </div>
                        )}
                        {l.igst_amount > 0 && (
                          <div className="text-xs text-text-secondary">
                            I: {fmt(l.igst_amount)}
                          </div>
                        )}
                      </td>
                      <td className="px-3 py-2 text-right font-semibold">{fmt(l.line_total)}</td>
                    </tr>
                  ))}
                </tbody>
                <tfoot className="bg-muted/30 font-semibold text-sm">
                  <tr>
                    <td colSpan={6} />
                    <td className="px-3 py-2 text-right">{fmt(invoice.subtotal)}</td>
                    <td />
                    <td className="px-3 py-2 text-right">{fmt(invoice.tax_total)}</td>
                    <td className="px-3 py-2 text-right text-primary">{fmt(invoice.grand_total)}</td>
                  </tr>
                </tfoot>
              </table>
            </div>
          </div>)}

          {/* ── Tax Breakup ── */}
          {activeTab === "tax" && (<div className="mt-4 space-y-4">
            <div className="rounded-lg border overflow-hidden">
              <div className="bg-muted/40 px-4 py-2 text-xs font-semibold text-text-secondary uppercase">
                Tax Summary
              </div>
              <div className="p-4 grid grid-cols-3 gap-4 text-sm">
                {[
                  ["CGST Total",   invoice.tax_breakup.cgst_total],
                  ["SGST Total",   invoice.tax_breakup.sgst_total],
                  ["IGST Total",   invoice.tax_breakup.igst_total],
                ].map(([label, value]) => (
                  <div key={String(label)} className="text-center p-3 rounded border">
                    <div className="text-text-secondary text-xs">{label}</div>
                    <div className="font-bold text-lg mt-1">{fmt(value as number)}</div>
                  </div>
                ))}
              </div>
            </div>

            {/* HSN Summary */}
            {Object.keys(invoice.tax_breakup.hsn_summary).length > 0 && (
              <div className="rounded-lg border overflow-hidden">
                <div className="bg-muted/40 px-4 py-2 text-xs font-semibold text-text-secondary uppercase">
                  HSN / SAC Summary
                </div>
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b">
                      {["HSN Code", "Taxable Value", "GST Rate", "Tax Amount"].map((h) => (
                        <th key={h} className="px-4 py-2 text-left text-xs font-semibold text-text-secondary">
                          {h}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody className="divide-y">
                    {Object.entries(invoice.tax_breakup.hsn_summary).map(([code, data]) => (
                      <tr key={code} className="hover:bg-muted/10">
                        <td className="px-4 py-2 font-mono text-xs">{code || "—"}</td>
                        <td className="px-4 py-2 text-right">{fmt(data.taxable_value)}</td>
                        <td className="px-4 py-2 text-right">{data.gst_rate}%</td>
                        <td className="px-4 py-2 text-right font-semibold">{fmt(data.tax_amount)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>)}

          {/* ── Activity ── */}
          {activeTab === "activity" && (<div className="mt-4">
            <div className="rounded-lg border divide-y">
              {invoice.audit_trail.length === 0 ? (
                <div className="px-4 py-8 text-center text-sm text-text-secondary">
                  No activity recorded yet.
                </div>
              ) : (
                invoice.audit_trail.map((entry, i) => (
                  <div key={i} className="flex items-start gap-3 px-4 py-3">
                    <CheckCircle2 className="h-4 w-4 text-primary mt-0.5 shrink-0" />
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center justify-between gap-2">
                        <span className="text-sm font-medium">
                          {ACTION_LABEL[entry.action] ?? entry.action}
                        </span>
                        <span className="text-xs text-text-secondary shrink-0">
                          {fmtDatetime(entry.created_at)}
                        </span>
                      </div>
                      {entry.actor && (
                        <p className="text-xs text-text-secondary mt-0.5">
                          by {entry.actor.name}
                        </p>
                      )}
                      {entry.reason && (
                        <p className="text-xs text-destructive mt-0.5">
                          Reason: {entry.reason}
                        </p>
                      )}
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>)}

          {/* ── Linked Docs ── */}
          {activeTab === "linked" && (<div className="mt-4 space-y-3">
            {invoice.sales_order ? (
              <div className="rounded-lg border p-4 flex items-center justify-between">
                <div>
                  <p className="text-xs text-text-secondary">Sales Order</p>
                  <p className="font-mono text-sm font-medium">{invoice.sales_order.order_number}</p>
                </div>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => router.push(`/orders/${invoice.sales_order!.id}`)}
                >
                  <ExternalLink className="h-3.5 w-3.5 mr-1" />
                  View Order
                </Button>
              </div>
            ) : (
              <div className="rounded-lg border p-4 text-sm text-text-secondary">
                No linked sales order.
              </div>
            )}
          </div>)}
        </div>{/* /Tabs */}

        {/* ── Void Modal ── */}
        <Modal
          open={voidModal}
          onClose={() => { setVoidModal(false); setVoidReason(""); setActionError(null); }}
          title="Void Invoice"
        >
          <div className="space-y-4">
            <p className="text-sm text-text-secondary">
              Voiding <span className="font-semibold">{invoice.invoice_number}</span> is
              irreversible. The invoice will be marked void and its outstanding balance cleared.
            </p>
            <div className="space-y-1.5">
              <label className="text-sm font-medium">
                Void Reason <span className="text-destructive">*</span>
              </label>
              <Input
                placeholder="Enter reason for voiding this invoice…"
                value={voidReason}
                onChange={(e) => setVoidReason(e.target.value)}
              />
            </div>
            {actionError && (
              <p className="text-sm text-destructive">{actionError}</p>
            )}
            <div className="flex justify-end gap-2">
              <Button variant="outline" size="sm" onClick={() => setVoidModal(false)}>
                Cancel
              </Button>
              <Button
                variant="danger"
                size="sm"
                disabled={!voidReason.trim() || saving}
                onClick={handleVoid}
              >
                {saving ? "Voiding…" : "Confirm Void"}
              </Button>
            </div>
          </div>
        </Modal>
      {/* ── E-Way Bill Modal ── */}
      <Modal
        open={ewayModal}
        onClose={() => { setEwayModal(false); setEwayError(null); }}
        title="Generate E-Way Bill"
      >
        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-sm font-medium">Transport Mode</label>
              <select
                className="w-full h-9 rounded-md border border-border bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                value={ewayMode}
                onChange={(e) => setEwayMode(e.target.value)}
              >
                <option value="1">Road</option>
                <option value="2">Rail</option>
                <option value="3">Air</option>
                <option value="4">Ship</option>
              </select>
            </div>
            <Input
              label="Distance (km)"
              type="number"
              min={1}
              placeholder="e.g. 150"
              value={ewayDistance}
              onChange={(e) => setEwayDistance(e.target.value)}
            />
            <Input
              label="Vehicle Number"
              placeholder="e.g. MH12AB1234"
              value={ewayVehicle}
              onChange={(e) => setEwayVehicle(e.target.value)}
            />
            <Input
              label="Transporter Name"
              placeholder="e.g. Fast Logistics"
              value={ewayTransporter}
              onChange={(e) => setEwayTransporter(e.target.value)}
            />
            <div className="col-span-2">
              <Input
                label="Transporter GSTIN / ID"
                placeholder="e.g. 05BBBBB1111B1ZC"
                value={ewayTransId}
                onChange={(e) => setEwayTransId(e.target.value)}
              />
            </div>
          </div>
          {ewayError && <p className="text-sm text-destructive">{ewayError}</p>}
          <div className="flex justify-end gap-2">
            <Button variant="outline" size="sm" onClick={() => setEwayModal(false)}>
              Cancel
            </Button>
            <Button
              size="sm"
              disabled={ewayLoading}
              onClick={handleGenerateEwaybill}
            >
              <Truck className="h-3.5 w-3.5 mr-1.5" />
              {ewayLoading ? "Generating…" : "Generate"}
            </Button>
          </div>
        </div>
      </Modal>

      {/* ── PDF Preview Modal ── */}
      {showPdfPreview && previewUrl && (
        <div className="fixed inset-0 z-50 flex flex-col bg-black/60">
          <div className="flex items-center justify-between px-4 py-3 bg-card border-b shadow-sm">
            <h2 className="text-sm font-semibold">
              Invoice Preview — {invoice.invoice_number}
            </h2>
            <div className="flex items-center gap-2">
              <Button
                size="sm"
                variant="outline"
                onClick={() => window.open(previewUrl, "_blank")}
              >
                <Download className="h-4 w-4 mr-1.5" />
                Download
              </Button>
              <Button
                size="sm"
                variant="outline"
                onClick={() => { setShowPdfPreview(false); setPreviewUrl(null); }}
              >
                Close
              </Button>
            </div>
          </div>
          <div className="flex-1 overflow-hidden">
            <iframe
              src={previewUrl}
              className="w-full h-full border-0"
              title={`Invoice ${invoice.invoice_number} Preview`}
            />
          </div>
        </div>
      )}
      </div>
    </AppShell>
  );
}
