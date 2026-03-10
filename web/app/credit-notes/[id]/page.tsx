"use client";

import { useState, useEffect, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Modal } from "@/components/ui/modal";
import { useOrgBranch } from "@/lib/org-branch-context";
import { Ban, RotateCcw, CreditCard } from "lucide-react";
import { Input } from "@/components/ui/input";

// ── Types ────────────────────────────────────────────────────────────────────

interface CreditNoteLine {
  id:           number;
  product_sku:  string;
  product_name: string;
  qty:          number;
  unit_price:   number;
  gst_rate:     number;
  tax_amount:   number;
  line_total:   number;
  hsn_code:     string | null;
}

interface AuditEntry {
  action:     string;
  actor:      string | null;
  changes:    Record<string, unknown>;
  created_at: string;
}

interface CreditNoteApplication {
  id:             number;
  amount:         number;
  status:         string;
  reversed_at:    string | null;
  reversal_reason: string | null;
  created_at:     string;
  sales_invoice:  { id: number; invoice_number: string; grand_total: number };
  applied_by:     { id: number; name: string } | null;
}

interface CreditNoteDetail {
  id:                 number;
  credit_note_number: string;
  status:             string;
  subtotal:           number;
  tax_total:          number;
  total:              number;
  applied_amount:     number;
  unapplied_amount:   number;
  notes:              string | null;
  issued_at:          string | null;
  voided_at:          string | null;
  void_reason:        string | null;
  created_at:         string;
  customer:           { id: number; name: string };
  branch:             { id: number; name: string };
  return_request:     { id: number; return_number: string };
  lines:              CreditNoteLine[];
  applications:       CreditNoteApplication[];
  audit_trail:        AuditEntry[];
}

// ── Helpers ──────────────────────────────────────────────────────────────────

const STATUS_VARIANT: Record<string, "secondary" | "warning" | "success" | "danger"> = {
  draft:  "secondary",
  issued: "success",
  void:   "danger",
};

const fmt = (n: number) =>
  Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2 });

const fmtDate = (d: string | null) =>
  d ? new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" }) : "—";

const ACTION_LABEL: Record<string, string> = {
  credit_note_issued: "Credit Note Issued",
  credit_note_voided: "Credit Note Voided",
};

interface OpenInvoice {
  id:             number;
  invoice_number: string;
  grand_total:    number;
  outstanding:    number;
  invoice_date:   string;
}



export default function CreditNoteDetailPage() {
  const params  = useParams<{ id: string }>();
  const router  = useRouter();
  const { token, orgId } = useOrgBranch();

  const [cn, setCn]             = useState<CreditNoteDetail | null>(null);
  const [loading, setLoading]   = useState(true);
  const [error, setError]       = useState<string | null>(null);
  const [voidModal, setVoidModal] = useState(false);
  const [voidReason, setVoidReason] = useState("");
  const [saving, setSaving]     = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);

  // Apply to invoice state
  const [applyModal, setApplyModal]       = useState(false);
  const [openInvoices, setOpenInvoices]   = useState<OpenInvoice[]>([]);
  const [selectedInvId, setSelectedInvId] = useState("");
  const [applyAmount, setApplyAmount]     = useState("");
  const [applying, setApplying]           = useState(false);
  const [applyError, setApplyError]       = useState<string | null>(null);

  const fetchCn = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`/api/v1/credit_notes/${params.id}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      if (!res.ok) throw new Error("Failed to load credit note");
      const body = await res.json();
      setCn(body.data);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  }, [token, orgId, params.id]);

  useEffect(() => { fetchCn(); }, [fetchCn]);

  const openApplyModal = async () => {
    if (!cn || !token || !orgId) return;
    setApplyError(null);
    setApplyAmount("");
    setSelectedInvId("");
    try {
      const res = await fetch(
        `/api/v1/sales_invoices?status=issued&customer_id=${cn.customer.id}&per_page=50`,
        { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId } }
      );
      const body = await res.json();
      setOpenInvoices(
        (body.data ?? []).map((inv: any) => ({
          id:             inv.id,
          invoice_number: inv.invoice_number,
          grand_total:    inv.grand_total,
          outstanding:    inv.outstanding_amount ?? inv.grand_total,
          invoice_date:   inv.invoice_date,
        }))
      );
    } catch {
      setOpenInvoices([]);
    }
    setApplyModal(true);
  };

  const handleApply = async () => {
    if (!cn || !selectedInvId || !applyAmount) return;
    setApplying(true);
    setApplyError(null);
    try {
      const res = await fetch(`/api/v1/credit_notes/${cn.id}/apply`, {
        method: "POST",
        headers: {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId!,
          "Content-Type":      "application/json",
        },
        body: JSON.stringify({
          applications: [{ sales_invoice_id: Number(selectedInvId), amount: Number(applyAmount) }],
        }),
      });
      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "Apply failed");
      await fetchCn();
      setApplyModal(false);
    } catch (e) {
      setApplyError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setApplying(false);
    }
  };

  const handleVoid = async () => {
    if (!cn || !voidReason.trim()) return;
    setSaving(true);
    setActionError(null);
    try {
      const res = await fetch(`/api/v1/credit_notes/${cn.id}/void`, {
        method:  "POST",
        headers: {
          Authorization:      `Bearer ${token}`,
          "X-Organization-Id": orgId!,
          "Content-Type":     "application/json",
        },
        body: JSON.stringify({ reason: voidReason }),
      });
      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "Void failed");
      setCn(body.data);
      setVoidModal(false);
      setVoidReason("");
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setSaving(false);
    }
  };

  // ── Loading / error states ─────────────────────────────────────────────────

  if (loading) {
    return (
      <AppShell>
        <div className="text-sm text-text-secondary">Loading credit note…</div>
      </AppShell>
    );
  }

  if (error || !cn) {
    return (
      <AppShell>
        <div>
          <p className="text-danger text-sm">{error ?? "Credit note not found"}</p>
          <Button variant="outline" className="mt-4" onClick={() => router.push("/credit-notes")}>
            Back to Credit Notes
          </Button>
        </div>
      </AppShell>
    );
  }

  const isVoidable = cn.status === "issued";

  return (
    <AppShell breadcrumbs={[
      { label: "Finance",      href: "/finance" },
      { label: "Credit Notes", href: "/credit-notes" },
      { label: cn.credit_note_number },
    ]}>
      <div className="max-w-4xl space-y-6">

        <PageHeader
          title={cn.credit_note_number}
          description={
            <span className="flex items-center gap-2 mt-1">
              <Badge variant={STATUS_VARIANT[cn.status] ?? "secondary"}>
                {cn.status}
              </Badge>
              <span className="text-text-secondary text-sm">
                {cn.customer.name} · {cn.branch.name}
              </span>
            </span>
          }
          actions={
            isVoidable
              ? [
                  { label: "Apply to Invoice", onClick: openApplyModal, icon: <CreditCard className="w-4 h-4" />, variant: "default" as const },
                  { label: "Void", onClick: () => setVoidModal(true), icon: <Ban className="w-4 h-4" />, variant: "danger" as const },
                ]
              : undefined
          }
        />

        {actionError && (
          <div className="bg-danger/5 border border-danger/20 text-danger rounded-md px-4 py-3 text-sm">
            {actionError}
          </div>
        )}

        {/* ── Summary Card ── */}
        <div className="rounded-lg border bg-white p-5 space-y-4">
          <h3 className="text-sm font-semibold text-text-secondary uppercase tracking-wide">
            Summary
          </h3>
          <div className="grid grid-cols-2 gap-x-8 gap-y-3 text-sm">
            <div>
              <p className="text-text-secondary">Customer</p>
              <p className="font-medium">{cn.customer.name}</p>
            </div>
            <div>
              <p className="text-text-secondary">Branch</p>
              <p className="font-medium">{cn.branch.name}</p>
            </div>
            <div>
              <p className="text-text-secondary">Return Request</p>
              <button
                className="font-mono text-xs text-blue-600 hover:underline"
                onClick={() => router.push(`/returns/${cn.return_request.id}`)}
              >
                {cn.return_request.return_number}
              </button>
            </div>
            <div>
              <p className="text-text-secondary">Issued At</p>
              <p className="font-medium">{fmtDate(cn.issued_at)}</p>
            </div>
            {cn.voided_at && (
              <>
                <div>
                  <p className="text-text-secondary">Voided At</p>
                  <p className="font-medium text-danger">{fmtDate(cn.voided_at)}</p>
                </div>
                <div>
                  <p className="text-text-secondary">Void Reason</p>
                  <p className="font-medium text-danger">{cn.void_reason}</p>
                </div>
              </>
            )}
            {cn.notes && (
              <div className="col-span-2">
                <p className="text-text-secondary">Notes</p>
                <p className="font-medium">{cn.notes}</p>
              </div>
            )}
          </div>

          {/* Financials */}
          <div className="border-t pt-4 space-y-1 text-sm">
            <div className="flex justify-between text-text-secondary">
              <span>Subtotal</span>
              <span>₹ {fmt(cn.subtotal)}</span>
            </div>
            <div className="flex justify-between text-text-secondary">
              <span>Tax</span>
              <span>₹ {fmt(cn.tax_total)}</span>
            </div>
            <div className="flex justify-between font-semibold text-base border-t pt-2 mt-1">
              <span>Total Credit</span>
              <span className="text-success">₹ {fmt(cn.total)}</span>
            </div>
            {cn.applied_amount > 0 && (
              <div className="flex justify-between text-text-secondary">
                <span>Applied</span>
                <span className="text-amber-600">− ₹ {fmt(cn.applied_amount)}</span>
              </div>
            )}
            <div className="flex justify-between font-semibold border-t pt-1 mt-1">
              <span>Unapplied Balance</span>
              <span className={cn.unapplied_amount > 0 ? "text-primary" : "text-text-secondary"}>
                ₹ {fmt(cn.unapplied_amount ?? cn.total)}
              </span>
            </div>
          </div>
        </div>

        {/* ── Lines Table ── */}
        <div className="rounded-lg border bg-white overflow-hidden">
          <div className="px-5 py-3 border-b bg-background-subtle">
            <h3 className="text-sm font-semibold text-text-secondary uppercase tracking-wide">
              Line Items
            </h3>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-background-subtle text-text-secondary border-b">
                <tr>
                  <th className="px-4 py-2 text-left font-medium">Product</th>
                  <th className="px-4 py-2 text-left font-medium">HSN</th>
                  <th className="px-4 py-2 text-right font-medium">Qty</th>
                  <th className="px-4 py-2 text-right font-medium">Unit Price</th>
                  <th className="px-4 py-2 text-right font-medium">GST %</th>
                  <th className="px-4 py-2 text-right font-medium">Tax</th>
                  <th className="px-4 py-2 text-right font-medium">Line Total</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {cn.lines.map((line) => (
                  <tr key={line.id} className="hover:bg-background-subtle/50">
                    <td className="px-4 py-3">
                      <p className="font-medium">{line.product_name}</p>
                      <p className="text-xs text-text-secondary font-mono">{line.product_sku}</p>
                    </td>
                    <td className="px-4 py-3 font-mono text-xs text-text-secondary">
                      {line.hsn_code ?? "—"}
                    </td>
                    <td className="px-4 py-3 text-right">{Number(line.qty)}</td>
                    <td className="px-4 py-3 text-right">₹ {fmt(line.unit_price)}</td>
                    <td className="px-4 py-3 text-right">{Number(line.gst_rate)}%</td>
                    <td className="px-4 py-3 text-right">₹ {fmt(line.tax_amount)}</td>
                    <td className="px-4 py-3 text-right font-semibold">₹ {fmt(line.line_total)}</td>
                  </tr>
                ))}
              </tbody>
              <tfoot className="border-t bg-background-subtle">
                <tr>
                  <td colSpan={6} className="px-4 py-3 text-right text-sm font-semibold text-text-secondary">
                    Total Credit
                  </td>
                  <td className="px-4 py-3 text-right font-bold text-success">
                    ₹ {fmt(cn.total)}
                  </td>
                </tr>
              </tfoot>
            </table>
          </div>
        </div>

        {/* ── Application History ── */}
        <div className="rounded-lg border bg-white overflow-hidden">
          <div className="px-5 py-3 border-b bg-background-subtle flex items-center justify-between">
            <h3 className="text-sm font-semibold text-text-secondary uppercase tracking-wide">
              Application History
            </h3>
            <span className="text-xs text-text-secondary">
              {(cn.applications ?? []).filter(a => a.status === "active").length} active application(s)
            </span>
          </div>
          {(cn.applications ?? []).length === 0 ? (
            <div className="px-5 py-6 text-center text-sm text-text-secondary">
              No applications yet. Use "Apply to Invoice" to allocate this credit note.
            </div>
          ) : (
            <table className="w-full text-sm">
              <thead className="bg-background-subtle text-text-secondary border-b">
                <tr>
                  <th className="px-4 py-2.5 text-left font-medium">Invoice #</th>
                  <th className="px-4 py-2.5 text-right font-medium">Applied Amount</th>
                  <th className="px-4 py-2.5 text-left font-medium">Status</th>
                  <th className="px-4 py-2.5 text-left font-medium">Applied By</th>
                  <th className="px-4 py-2.5 text-left font-medium">Date</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {(cn.applications ?? []).map((app) => (
                  <tr key={app.id} className={`hover:bg-background-subtle/50 ${app.status === "reversed" ? "opacity-60" : ""}`}>
                    <td className="px-4 py-3">
                      <button
                        onClick={() => router.push(`/sales-invoices/${app.sales_invoice.id}`)}
                        className="font-mono text-sm text-primary hover:underline"
                      >
                        {app.sales_invoice.invoice_number}
                      </button>
                    </td>
                    <td className="px-4 py-3 text-right font-semibold">₹ {fmt(app.amount)}</td>
                    <td className="px-4 py-3">
                      <Badge variant={app.status === "active" ? "success" : "secondary"}>
                        {app.status.charAt(0).toUpperCase() + app.status.slice(1)}
                      </Badge>
                      {app.reversal_reason && (
                        <p className="text-xs text-text-secondary italic mt-0.5">{app.reversal_reason}</p>
                      )}
                    </td>
                    <td className="px-4 py-3 text-text-secondary text-xs">
                      {app.applied_by?.name ?? "—"}
                    </td>
                    <td className="px-4 py-3 text-text-secondary text-xs">
                      {fmtDate(app.created_at)}
                      {app.reversed_at && (
                        <span className="ml-1 text-danger">(reversed {fmtDate(app.reversed_at)})</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {/* ── Audit Trail ── */}
        {cn.audit_trail.length > 0 && (
          <div className="rounded-lg border bg-white overflow-hidden">
            <div className="px-5 py-3 border-b bg-background-subtle">
              <h3 className="text-sm font-semibold text-text-secondary uppercase tracking-wide">
                Timeline
              </h3>
            </div>
            <ul className="divide-y">
              {cn.audit_trail.map((entry, idx) => (
                <li key={idx} className="px-5 py-3 flex items-start gap-3">
                  <div className="mt-0.5 h-2 w-2 rounded-full bg-gray-400 shrink-0 mt-2" />
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium">
                      {ACTION_LABEL[entry.action] ?? entry.action.replace(/_/g, " ")}
                    </p>
                    <p className="text-xs text-text-secondary mt-0.5">
                      {entry.actor ?? "System"} · {fmtDate(entry.created_at)}
                    </p>
                  </div>
                </li>
              ))}
            </ul>
          </div>
        )}

        {/* ── View Return Link ── */}
        <div className="flex items-center gap-2 pt-2">
          <Button
            variant="outline"
            onClick={() => router.push(`/returns/${cn.return_request.id}`)}
          >
            <RotateCcw className="w-4 h-4 mr-2" />
            View Return {cn.return_request.return_number}
          </Button>
        </div>
      </div>

      {/* ── Void Modal ── */}
      <Modal
        open={voidModal}
        onClose={() => { setVoidModal(false); setVoidReason(""); setActionError(null); }}
        title="Void Credit Note"
      >
        <div className="space-y-4">
          <p className="text-sm text-text-secondary">
            Voiding <span className="font-semibold font-mono">{cn.credit_note_number}</span> is
            permanent. The credit will no longer be valid. Provide a reason below.
          </p>
          <div>
            <label className="block text-sm font-medium mb-1">Reason <span className="text-red-500">*</span></label>
            <textarea
              className="w-full rounded-md border border-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-gray-900 resize-none"
              rows={3}
              value={voidReason}
              onChange={(e) => setVoidReason(e.target.value)}
              placeholder="e.g. Issued in error, duplicate credit note…"
            />
          </div>
          {actionError && (
            <p className="text-sm text-danger">{actionError}</p>
          )}
          <div className="flex justify-end gap-2">
            <Button
              variant="outline"
              onClick={() => { setVoidModal(false); setVoidReason(""); setActionError(null); }}
              disabled={saving}
            >
              Cancel
            </Button>
            <Button
              variant="danger"
              onClick={handleVoid}
              disabled={saving || !voidReason.trim()}
            >
              {saving ? "Voiding…" : "Void Credit Note"}
            </Button>
          </div>
        </div>
      </Modal>

      {/* ── Apply to Invoice Modal ── */}
      <Modal
        open={applyModal}
        onClose={() => { setApplyModal(false); setApplyError(null); }}
        title="Apply Credit Note to Invoice"
      >
        <div className="space-y-4">
          <p className="text-sm text-text-secondary">
            Apply part or all of <span className="font-mono font-semibold">{cn.credit_note_number}</span> to an outstanding invoice for {cn.customer.name}.
          </p>
          <div className="space-y-1.5">
            <label className="block text-sm font-medium">Select Invoice</label>
            <select
              value={selectedInvId}
              onChange={(e) => {
                setSelectedInvId(e.target.value);
                const inv = openInvoices.find(i => String(i.id) === e.target.value);
                if (inv) setApplyAmount(String(Math.min(inv.outstanding, cn.total)));
              }}
              className="w-full h-9 rounded-md border border-border bg-background px-3 text-sm focus:outline-none focus:ring-1 focus:ring-accent"
            >
              <option value="">Choose an invoice…</option>
              {openInvoices.map(inv => (
                <option key={inv.id} value={String(inv.id)}>
                  {inv.invoice_number} — ₹{Number(inv.outstanding).toLocaleString("en-IN", { minimumFractionDigits: 2 })} outstanding
                </option>
              ))}
            </select>
          </div>
          <div className="space-y-1.5">
            <label className="block text-sm font-medium">Amount to Apply</label>
            <Input
              type="number"
              min="0.01"
              step="0.01"
              value={applyAmount}
              onChange={(e) => setApplyAmount(e.target.value)}
              placeholder="0.00"
            />
            <p className="text-xs text-text-secondary">
              CN balance: ₹{fmt(cn.total)}
            </p>
          </div>
          {applyError && <p className="text-sm text-danger">{applyError}</p>}
          <div className="flex justify-end gap-2">
            <Button variant="outline" onClick={() => setApplyModal(false)} disabled={applying}>Cancel</Button>
            <Button
              onClick={handleApply}
              disabled={applying || !selectedInvId || !applyAmount}
            >
              {applying ? "Applying…" : "Apply"}
            </Button>
          </div>
        </div>
      </Modal>
    </AppShell>
  );
}
