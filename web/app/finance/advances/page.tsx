"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { DataTable, Column } from "@/components/ui/data-table";
import { useOrgBranch } from "@/lib/org-branch-context";
import { RefreshCw, ArrowRight, RotateCcw } from "lucide-react";

// ── Types ──────────────────────────────────────────────────────────────────────

interface AdvancePayment {
  id:              number;
  original_amount: number;
  balance:         number;
  status:          string;
  refunded_at:     string | null;
  notes:           string | null;
  created_at:      string;
  customer:        { id: number; name: string };
  source_payment:  { id: number; number: string };
}

interface OpenInvoice {
  id:              number;
  invoice_number:  string;
  grand_total:     number;
  outstanding:     number;
}

// ── Helpers ────────────────────────────────────────────────────────────────────

const fmt = (n: number) =>
  `₹ ${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2 })}`;

const fmtDate = (d: string | null) =>
  d ? new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" }) : "—";

const STATUS_VARIANT: Record<string, "secondary" | "success" | "warning" | "danger"> = {
  unapplied:         "warning",
  partially_applied: "warning",
  applied:           "success",
  refunded:          "secondary",
};

const STATUS_TABS = [
  { key: "",                 label: "All" },
  { key: "unapplied",        label: "Unapplied" },
  { key: "partially_applied", label: "Partial" },
  { key: "applied",          label: "Applied" },
  { key: "refunded",         label: "Refunded" },
];

// ── Page ───────────────────────────────────────────────────────────────────────

export default function AdvancePaymentsPage() {
  const router           = useRouter();
  const { token, orgId } = useOrgBranch();

  const [advances, setAdvances]   = useState<AdvancePayment[]>([]);
  const [loading, setLoading]     = useState(true);
  const [statusFilter, setStatus] = useState("");
  const [page, setPage]           = useState(1);
  const [totalPages, setTotalPages] = useState(1);

  // Apply to invoice modal
  const [applyModal, setApplyModal]         = useState<AdvancePayment | null>(null);
  const [openInvoices, setOpenInvoices]     = useState<OpenInvoice[]>([]);
  const [selectedInvId, setSelectedInvId]   = useState("");
  const [applyAmount, setApplyAmount]       = useState("");
  const [applyLoading, setApplyLoading]     = useState(false);
  const [applyError, setApplyError]         = useState<string | null>(null);

  // Refund modal
  const [refundModal, setRefundModal]       = useState<AdvancePayment | null>(null);
  const [refundReason, setRefundReason]     = useState("");
  const [refundLoading, setRefundLoading]   = useState(false);
  const [refundError, setRefundError]       = useState<string | null>(null);

  const fetchAdvances = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const params = new URLSearchParams({ page: String(page), per_page: "25" });
      if (statusFilter) params.set("status", statusFilter);
      const res  = await fetch(`/api/v1/advance_payments?${params}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) {
        setAdvances(json.data ?? []);
        setTotalPages(json.meta?.total_pages ?? 1);
      }
    } finally {
      setLoading(false);
    }
  }, [token, orgId, page, statusFilter]);

  useEffect(() => { fetchAdvances(); }, [fetchAdvances]);

  // ── Open Apply Modal ────────────────────────────────────────────────────────

  const openApplyModal = async (adv: AdvancePayment) => {
    setApplyModal(adv);
    setSelectedInvId("");
    setApplyAmount(String(adv.balance));
    setApplyError(null);
    setOpenInvoices([]);

    if (!token || !orgId) return;
    try {
      const res  = await fetch(
        `/api/v1/sales_invoices?status=issued&customer_id=${adv.customer.id}&per_page=50`,
        { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId } }
      );
      const json = await res.json();
      if (res.ok) setOpenInvoices(json.data ?? []);
    } catch { /* ignore */ }
  };

  // ── Handle Apply ────────────────────────────────────────────────────────────

  const handleApply = async () => {
    if (!applyModal || !selectedInvId || !applyAmount || !token || !orgId) return;
    setApplyLoading(true);
    setApplyError(null);
    try {
      const res  = await fetch(`/api/v1/advance_payments/${applyModal.id}/apply`, {
        method:  "POST",
        headers: {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId,
          "Content-Type":      "application/json",
        },
        body: JSON.stringify({
          invoice_id: Number(selectedInvId),
          amount:     parseFloat(applyAmount),
        }),
      });
      const json = await res.json();
      if (!res.ok) throw new Error(json.errors?.join(", ") || "Apply failed");
      setApplyModal(null);
      fetchAdvances();
    } catch (e) {
      setApplyError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setApplyLoading(false);
    }
  };

  // ── Handle Refund ───────────────────────────────────────────────────────────

  const handleRefund = async () => {
    if (!refundModal || !refundReason.trim() || !token || !orgId) return;
    setRefundLoading(true);
    setRefundError(null);
    try {
      const res  = await fetch(`/api/v1/advance_payments/${refundModal.id}/refund`, {
        method:  "POST",
        headers: {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId,
          "Content-Type":      "application/json",
        },
        body: JSON.stringify({ reason: refundReason }),
      });
      const json = await res.json();
      if (!res.ok) throw new Error(json.errors?.join(", ") || "Refund failed");
      setRefundModal(null);
      setRefundReason("");
      fetchAdvances();
    } catch (e) {
      setRefundError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setRefundLoading(false);
    }
  };

  // ── Invoice selection helper ────────────────────────────────────────────────

  const selectedInv = openInvoices.find((i) => String(i.id) === selectedInvId);

  // ── Render ─────────────────────────────────────────────────────────────────

  return (
    <AppShell breadcrumbs={[
      { label: "Finance",           href: "/finance" },
      { label: "Advance Payments" },
    ]}>
      <div className="max-w-6xl space-y-4">

        <PageHeader
          title="Advance Payments"
          description="Overpayments and advance balances available to apply against invoices"
          actions={[
            { label: "Refresh", onClick: fetchAdvances, icon: RefreshCw, variant: "outline" as const },
          ]}
        />

        {/* Status Tabs */}
        <div className="flex items-center gap-1 border-b border-border overflow-x-auto">
          {STATUS_TABS.map((tab) => (
            <button
              key={tab.key}
              onClick={() => { setStatus(tab.key); setPage(1); }}
              className={`px-4 py-2.5 text-sm font-medium whitespace-nowrap transition-colors ${
                statusFilter === tab.key
                  ? "border-b-2 border-primary text-primary"
                  : "text-text-secondary hover:text-text-primary"
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>

        {/* Table */}
        {loading ? (
          <div className="rounded-lg border bg-card p-10 text-center text-text-secondary text-sm">
            Loading advance payments…
          </div>
        ) : advances.length === 0 ? (
          <div className="rounded-lg border bg-card p-10 text-center text-text-secondary text-sm">
            No advance payments found.
          </div>
        ) : (
          <div className="rounded-lg border overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-muted/50">
                <tr>
                  {["Customer", "Source Payment", "Original Amount", "Balance", "Status", "Created", "Actions"].map((h) => (
                    <th key={h} className="px-4 py-3 text-left font-medium text-text-secondary text-xs uppercase tracking-wider">
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {advances.map((adv) => (
                  <tr key={adv.id} className="border-t hover:bg-muted/20">
                    <td className="px-4 py-3">
                      <button
                        onClick={() => router.push(`/customers/${adv.customer.id}`)}
                        className="font-medium text-primary hover:underline"
                      >
                        {adv.customer.name}
                      </button>
                    </td>
                    <td className="px-4 py-3">
                      <button
                        onClick={() => router.push(`/collections/${adv.source_payment.id}`)}
                        className="font-mono text-sm text-primary hover:underline"
                      >
                        {adv.source_payment.number}
                      </button>
                    </td>
                    <td className="px-4 py-3 font-medium">{fmt(adv.original_amount)}</td>
                    <td className="px-4 py-3">
                      <span className={`font-semibold ${adv.balance > 0 ? "text-amber-600" : "text-text-secondary"}`}>
                        {fmt(adv.balance)}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <Badge variant={STATUS_VARIANT[adv.status] ?? "secondary"}>
                        {adv.status.replace("_", " ").replace(/\b\w/g, c => c.toUpperCase())}
                      </Badge>
                    </td>
                    <td className="px-4 py-3 text-text-secondary">{fmtDate(adv.created_at)}</td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-1.5">
                        {(adv.status === "unapplied" || adv.status === "partially_applied") && (
                          <Button
                            size="sm"
                            variant="outline"
                            className="h-7 text-xs px-2"
                            onClick={() => openApplyModal(adv)}
                          >
                            <ArrowRight className="h-3.5 w-3.5 mr-1" />
                            Apply
                          </Button>
                        )}
                        {(adv.status === "unapplied" || adv.status === "partially_applied") && (
                          <Button
                            size="sm"
                            variant="outline"
                            className="h-7 text-xs px-2 text-red-600 border-red-200 hover:bg-red-50"
                            onClick={() => { setRefundModal(adv); setRefundReason(""); }}
                          >
                            <RotateCcw className="h-3.5 w-3.5 mr-1" />
                            Refund
                          </Button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="flex justify-center gap-2 pt-2">
            <Button variant="outline" size="sm" disabled={page === 1} onClick={() => setPage(p => p - 1)}>
              Previous
            </Button>
            <span className="flex items-center text-sm text-text-secondary px-2">
              Page {page} of {totalPages}
            </span>
            <Button variant="outline" size="sm" disabled={page === totalPages} onClick={() => setPage(p => p + 1)}>
              Next
            </Button>
          </div>
        )}
      </div>

      {/* ── Apply to Invoice Modal ── */}
      {applyModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
          <div className="bg-white rounded-lg shadow-lg w-full max-w-md p-6">
            <h2 className="text-lg font-semibold mb-1">Apply Advance to Invoice</h2>
            <p className="text-sm text-text-secondary mb-4">
              {applyModal.customer.name} · Available Balance: {fmt(applyModal.balance)}
            </p>

            <div className="space-y-4">
              <div className="space-y-1">
                <label className="text-sm font-medium">Select Invoice <span className="text-red-500">*</span></label>
                {openInvoices.length === 0 ? (
                  <p className="text-sm text-text-secondary px-3 py-2 border rounded bg-muted/50">
                    No open invoices found for this customer.
                  </p>
                ) : (
                  <select
                    className="w-full border rounded-md px-3 py-2 text-sm bg-background focus:outline-none focus:ring-2 focus:ring-primary"
                    value={selectedInvId}
                    onChange={(e) => {
                      setSelectedInvId(e.target.value);
                      const inv = openInvoices.find((i) => String(i.id) === e.target.value);
                      if (inv) {
                        setApplyAmount(String(Math.min(applyModal.balance, inv.outstanding)));
                      }
                    }}
                  >
                    <option value="">Select invoice…</option>
                    {openInvoices.map((inv) => (
                      <option key={inv.id} value={inv.id}>
                        {inv.invoice_number} — Outstanding: {fmt(inv.outstanding)}
                      </option>
                    ))}
                  </select>
                )}
              </div>

              {selectedInv && (
                <div className="text-xs text-text-secondary bg-muted/50 rounded px-3 py-2">
                  Invoice Total: {fmt(selectedInv.grand_total)} · Outstanding: {fmt(selectedInv.outstanding)}
                </div>
              )}

              <div className="space-y-1">
                <label className="text-sm font-medium">Amount to Apply <span className="text-red-500">*</span></label>
                <Input
                  type="number"
                  step="0.01"
                  min="0.01"
                  max={applyModal.balance}
                  value={applyAmount}
                  onChange={(e) => setApplyAmount(e.target.value)}
                  placeholder="0.00"
                />
                <p className="text-xs text-text-secondary">
                  Max: {fmt(Math.min(applyModal.balance, selectedInv?.outstanding ?? applyModal.balance))}
                </p>
              </div>
            </div>

            {applyError && <p className="text-sm text-red-600 mt-3">{applyError}</p>}

            <div className="flex justify-end gap-2 mt-5">
              <Button variant="outline" onClick={() => setApplyModal(null)}>
                Cancel
              </Button>
              <Button
                disabled={applyLoading || !selectedInvId || !applyAmount}
                onClick={handleApply}
              >
                {applyLoading ? "Applying…" : "Apply"}
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* ── Refund Modal ── */}
      {refundModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
          <div className="bg-white rounded-lg shadow-lg w-full max-w-sm p-6">
            <h2 className="text-lg font-semibold mb-1">Refund Advance</h2>
            <p className="text-sm text-text-secondary mb-4">
              {refundModal.customer.name} · Balance: {fmt(refundModal.balance)}
            </p>
            <div className="space-y-1">
              <label className="text-sm font-medium">Reason <span className="text-red-500">*</span></label>
              <textarea
                className="w-full border rounded-md px-3 py-2 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-primary"
                placeholder="Reason for refund..."
                rows={3}
                value={refundReason}
                onChange={(e) => setRefundReason(e.target.value)}
              />
            </div>
            {refundError && <p className="text-sm text-red-600 mt-2">{refundError}</p>}
            <div className="flex justify-end gap-2 mt-4">
              <Button variant="outline" onClick={() => setRefundModal(null)}>
                Cancel
              </Button>
              <Button
                className="bg-red-600 hover:bg-red-700 text-white"
                disabled={refundLoading || !refundReason.trim()}
                onClick={handleRefund}
              >
                {refundLoading ? "Refunding…" : "Refund"}
              </Button>
            </div>
          </div>
        </div>
      )}
    </AppShell>
  );
}
