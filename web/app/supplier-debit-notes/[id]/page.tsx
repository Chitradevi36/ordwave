"use client";

import { useState, useEffect, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { AccessDeniedError } from "@/components/errors/access-denied-error";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Modal } from "@/components/ui/modal";
import { Input } from "@/components/ui/input";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";
import { Ban, CheckCircle2 } from "lucide-react";

// ── Types ─────────────────────────────────────────────────────────────────────

interface DebitNoteLine {
  id:            number;
  product_name:  string;
  product_sku:   string;
  hsn_code:      string | null;
  qty:           number;
  unit_price:    number;
  taxable_value: number;
  gst_rate:      number;
  tax_amount:    number;
  line_total:    number;
  reason_code:   string | null;
}

interface DebitNoteDetail {
  id:             number;
  note_number:    string;
  note_date:      string;
  status:         "draft" | "issued" | "void";
  reason:         string | null;
  void_reason:    string | null;
  subtotal:       number;
  tax_total:      number;
  total_amount:   number;
  currency:       string;
  notes:          string | null;
  issued_at:      string | null;
  voided_at:      string | null;
  created_at:     string;
  supplier:       { id: number; name: string; code: string; gstin: string | null };
  branch:         { id: number; name: string };
  purchase_invoice: { id: number; invoice_number: string; invoice_date: string } | null;
  lines:          DebitNoteLine[];
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const STATUS_VARIANT: Record<string, "secondary" | "warning" | "success" | "danger"> = {
  draft:  "secondary",
  issued: "success",
  void:   "danger",
};

const fmt     = (n: number) => `₹ ${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2 })}`;
const fmtDate = (d: string | null) =>
  d ? new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" }) : "—";
const fmtDt   = (d: string | null) =>
  d ? new Date(d).toLocaleString("en-IN", { day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" }) : "—";

const REASON_LABELS: Record<string, string> = {
  quality_issue:      "Quality Issue",
  short_supply:       "Short Supply",
  price_discrepancy:  "Price Discrepancy",
  expired_goods:      "Expired Goods",
  damaged_goods:      "Damaged Goods",
  wrong_product:      "Wrong Product",
  other:              "Other",
};

// ── Page ──────────────────────────────────────────────────────────────────────

export default function SupplierDebitNoteDetailPage() {
  const params           = useParams<{ id: string }>();
  const router           = useRouter();
  const { token, orgId } = useOrgBranch();

  const [note, setNote]           = useState<DebitNoteDetail | null>(null);
  const [loading, setLoading]     = useState(true);
  const [error, setError]         = useState<{ status: number; message: string } | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [issuing, setIssuing]     = useState(false);
  const [voidModal, setVoidModal] = useState(false);
  const [voidReason, setVoidReason] = useState("");
  const [voiding, setVoiding]     = useState(false);

  const authHeaders = {
    Authorization: `Bearer ${token}`,
    "X-Organization-Id": orgId ?? "",
    "Content-Type": "application/json",
  } as Record<string, string>;

  const fetchNote = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`${API_URL}/api/v1/supplier_debit_notes/${params.id}`, {
        headers: authHeaders,
      });
      if (!res.ok) {
        const body = await res.json();
        setError({
          status: res.status,
          message: body.errors?.[0] ?? "Failed to load debit note"
        });
        return;
      }
      const body = await res.json();
      setNote(body.data);
    } catch (e) {
      setError({
        status: 500,
        message: e instanceof Error ? e.message : "Unknown error"
      });
    } finally {
      setLoading(false);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, orgId, params.id]);

  useEffect(() => { fetchNote(); }, [fetchNote]);

  const handleIssue = async () => {
    if (!note) return;
    setIssuing(true);
    setActionError(null);
    try {
      const res = await fetch(`${API_URL}/api/v1/supplier_debit_notes/${note.id}/issue`, {
        method: "POST", headers: authHeaders,
      });
      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "Issue failed");
      setNote(body.data);
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setIssuing(false);
    }
  };

  const handleVoid = async () => {
    if (!note || !voidReason.trim()) return;
    setVoiding(true);
    setActionError(null);
    try {
      const res = await fetch(`${API_URL}/api/v1/supplier_debit_notes/${note.id}/void`, {
        method: "POST", headers: authHeaders,
        body: JSON.stringify({ reason: voidReason }),
      });
      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "Void failed");
      setNote(body.data);
      setVoidModal(false);
      setVoidReason("");
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setVoiding(false);
    }
  };

  if (loading) return <AppShell><div className="p-6 text-sm text-text-secondary">Loading…</div></AppShell>;

  if (error) {
    return <AccessDeniedError
      status={error.status}
      message={error.message}
      backLink="/supplier-debit-notes"
      resourceType="Supplier Debit Note"
    />;
  }

  if (!note) return (
    <AppShell>
      <div className="p-6 space-y-3">
        <p className="text-sm text-destructive">Debit note not found</p>
        <Button variant="outline" size="sm" onClick={() => router.push("/supplier-debit-notes")}>
          Back
        </Button>
      </div>
    </AppShell>
  );

  const actions = [
    ...(note.status === "draft"
      ? [{ label: issuing ? "Issuing…" : "Issue Debit Note", onClick: handleIssue, icon: CheckCircle2, disabled: issuing }]
      : []),
    ...(note.status !== "void"
      ? [{ label: "Void", onClick: () => setVoidModal(true), variant: "danger" as const, icon: Ban }]
      : []),
  ];

  return (
    <AppShell breadcrumbs={[
      { label: "Finance",               href: "/finance" },
      { label: "Supplier Debit Notes",  href: "/supplier-debit-notes" },
      { label: note.note_number },
    ]}>
      <PageHeader
        title={note.note_number}
        subtitle={`${note.supplier.name} · ${fmtDate(note.note_date)}`}
        actions={actions}
      />

      {actionError && (
        <div className="rounded-md bg-destructive/10 border border-destructive/30 px-4 py-3 text-sm text-destructive">
          {actionError}
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Details */}
        <div className="lg:col-span-2 rounded-lg border bg-card p-5">
          <h3 className="text-xs font-semibold text-text-secondary uppercase tracking-wider mb-4">Details</h3>
          <dl className="grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
            {[
              ["Note Number",       note.note_number],
              ["Note Date",         fmtDate(note.note_date)],
              ["Supplier",          `${note.supplier.name} (${note.supplier.code})`],
              ["GSTIN",             note.supplier.gstin ?? "—"],
              ["Branch",            note.branch.name],
              ["Purchase Invoice",  note.purchase_invoice?.invoice_number ?? "—"],
              ["Issued At",         fmtDt(note.issued_at)],
              ["Reason",            note.reason ?? "—"],
            ].map(([label, value]) => (
              <div key={label}>
                <dt className="text-text-secondary">{label}</dt>
                <dd className="font-medium mt-0.5">{value}</dd>
              </div>
            ))}
            {note.voided_at && (
              <>
                <div>
                  <dt className="text-text-secondary">Voided At</dt>
                  <dd className="font-medium text-destructive mt-0.5">{fmtDt(note.voided_at)}</dd>
                </div>
                <div>
                  <dt className="text-text-secondary">Void Reason</dt>
                  <dd className="font-medium text-destructive mt-0.5">{note.void_reason}</dd>
                </div>
              </>
            )}
            {note.notes && (
              <div className="col-span-2">
                <dt className="text-text-secondary">Notes</dt>
                <dd className="font-medium mt-0.5">{note.notes}</dd>
              </div>
            )}
          </dl>
        </div>

        {/* Financials */}
        <div className="rounded-lg border bg-card p-5 space-y-3">
          <h3 className="text-xs font-semibold text-text-secondary uppercase tracking-wider">Financials</h3>
          <div className="space-y-2 text-sm">
            {[
              ["Subtotal",  note.subtotal],
              ["Tax Total", note.tax_total],
            ].map(([label, value]) => (
              <div key={String(label)} className="flex justify-between text-text-secondary">
                <span>{label}</span>
                <span>{fmt(value as number)}</span>
              </div>
            ))}
            <div className="flex justify-between font-bold text-base border-t pt-2">
              <span>Total Amount</span>
              <span className="text-primary">{fmt(note.total_amount)}</span>
            </div>
          </div>
        </div>
      </div>

      {/* Lines */}
      <div className="rounded-lg border overflow-x-auto">
        <div className="px-4 py-3 bg-muted/40 border-b">
          <p className="text-xs font-semibold text-text-secondary uppercase tracking-wider">Line Items</p>
        </div>
        <table className="w-full text-sm">
          <thead>
            <tr className="bg-muted/20">
              {["#", "Product", "HSN", "Reason", "Qty", "Rate", "Taxable", "GST%", "Tax", "Total"].map((h) => (
                <th key={h} className="px-3 py-2.5 text-left text-xs font-semibold text-text-secondary">{h}</th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y">
            {note.lines.map((l, i) => (
              <tr key={l.id} className="hover:bg-muted/20">
                <td className="px-3 py-2 text-text-secondary">{i + 1}</td>
                <td className="px-3 py-2">
                  <div className="font-medium">{l.product_name}</div>
                  <div className="text-xs text-text-secondary">{l.product_sku}</div>
                </td>
                <td className="px-3 py-2 font-mono text-xs text-text-secondary">{l.hsn_code ?? "—"}</td>
                <td className="px-3 py-2 text-xs text-text-secondary">
                  {l.reason_code ? (REASON_LABELS[l.reason_code] ?? l.reason_code) : "—"}
                </td>
                <td className="px-3 py-2 text-right">{Number(l.qty).toFixed(2)}</td>
                <td className="px-3 py-2 text-right">{fmt(l.unit_price)}</td>
                <td className="px-3 py-2 text-right">{fmt(l.taxable_value)}</td>
                <td className="px-3 py-2 text-right">{l.gst_rate}%</td>
                <td className="px-3 py-2 text-right">{fmt(l.tax_amount)}</td>
                <td className="px-3 py-2 text-right font-semibold">{fmt(l.line_total)}</td>
              </tr>
            ))}
          </tbody>
          <tfoot className="bg-muted/30 font-semibold">
            <tr>
              <td colSpan={6} />
              <td className="px-3 py-2 text-right">{fmt(note.subtotal)}</td>
              <td />
              <td className="px-3 py-2 text-right">{fmt(note.tax_total)}</td>
              <td className="px-3 py-2 text-right text-primary">{fmt(note.total_amount)}</td>
            </tr>
          </tfoot>
        </table>
      </div>

      {/* Void Modal */}
      <Modal
        open={voidModal}
        onClose={() => { setVoidModal(false); setVoidReason(""); }}
        title="Void Debit Note"
      >
        <div className="space-y-4">
          <p className="text-sm text-text-secondary">
            Voiding <span className="font-semibold">{note.note_number}</span> is irreversible.
          </p>
          <Input
            label="Void Reason *"
            placeholder="Enter reason for voiding…"
            value={voidReason}
            onChange={(e) => setVoidReason(e.target.value)}
          />
          {actionError && <p className="text-sm text-destructive">{actionError}</p>}
          <div className="flex justify-end gap-2">
            <Button variant="outline" size="sm" onClick={() => setVoidModal(false)}>Cancel</Button>
            <Button
              variant="danger"
              size="sm"
              disabled={!voidReason.trim() || voiding}
              onClick={handleVoid}
            >
              {voiding ? "Voiding…" : "Confirm Void"}
            </Button>
          </div>
        </div>
      </Modal>
    </AppShell>
  );
}
