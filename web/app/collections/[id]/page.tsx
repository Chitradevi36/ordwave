"use client";

import React, { useState, useEffect, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Breadcrumb, BreadcrumbItem } from "@/components/ui/breadcrumb";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui";
import { useOrgBranch } from "@/lib/org-branch-context";
import {
  CheckCircle2,
  RotateCcw,
  AlertTriangle,
} from "lucide-react";

// ── Types ─────────────────────────────────────────────────────────────────────

interface Allocation {
  id:               number;
  status:           string;
  allocated_amount: number;
  invoice: {
    id:             number;
    invoice_number: string;
    invoice_date:   string;
    grand_total:    number;
    outstanding:    number;
  } | null;
}

interface AuditEntry {
  action:  string;
  actor:   string | null;
  at:      string;
  changes: Record<string, unknown>;
  reason:  string | null;
}

interface PaymentDetail {
  id:                 number;
  payment_number:     string;
  received_date:      string;
  status:             string;
  payment_mode:       string;
  amount:             number;
  allocated_amount:   number;
  unallocated_amount: number;
  reference_number:   string | null;
  notes:              string | null;
  confirmed_at:       string | null;
  reversed_at:        string | null;
  reversal_reason:    string | null;
  created_by:         string | null;
  created_at:         string;
  customer:           { id: number; name: string };
  branch:             { id: number; code: string };
  allocations:        Allocation[];
  audit_trail:        AuditEntry[];
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const fmtCurrency = (n: number) =>
  `₹ ${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2 })}`;

const fmtDate = (d: string | null) =>
  d ? new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" }) : "—";

const fmtDateTime = (d: string | null) =>
  d ? new Date(d).toLocaleString("en-IN") : "—";

const PAYMENT_MODE_LABELS: Record<string, string> = {
  cash:          "Cash",
  bank_transfer: "Bank Transfer",
  upi:           "UPI",
  cheque:        "Cheque",
  neft:          "NEFT",
  rtgs:          "RTGS",
  adjustment:    "Adjustment",
};

const STATUS_VARIANT: Record<string, "secondary" | "success" | "danger"> = {
  draft:     "secondary",
  confirmed: "success",
  reversed:  "danger",
};

const ALLOC_STATUS_VARIANT: Record<string, "success" | "secondary"> = {
  active:   "success",
  reversed: "secondary",
};

// ── Page ──────────────────────────────────────────────────────────────────────

export default function PaymentDetailPage() {
  const { id }           = useParams<{ id: string }>();
  const router           = useRouter();
  const { token, orgId } = useOrgBranch();

  const [payment, setPayment]           = useState<PaymentDetail | null>(null);
  const [loading, setLoading]           = useState(true);
  const [activeTab, setActiveTab]       = useState<"summary" | "allocations" | "activity">("summary");
  const [showReverse, setShowReverse]   = useState(false);
  const [reversalReason, setReversalReason] = useState("");
  const [submitting, setSubmitting]     = useState(false);
  const [error, setError]               = useState<string | null>(null);

  const fetchPayment = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const res = await fetch(`/api/v1/payments/${id}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) setPayment(json.data);
    } finally {
      setLoading(false);
    }
  }, [token, orgId, id]);

  useEffect(() => { fetchPayment(); }, [fetchPayment]);

  const handleConfirm = async () => {
    if (!token || !orgId || !payment) return;
    setSubmitting(true);
    setError(null);
    try {
      const res = await fetch(`/api/v1/payments/${id}/confirm`, {
        method:  "POST",
        headers: {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId,
          "Content-Type":      "application/json",
        },
      });
      const json = await res.json();
      if (res.ok) {
        fetchPayment();
      } else {
        setError(json.errors?.join(", ") ?? "Failed to confirm payment");
      }
    } finally {
      setSubmitting(false);
    }
  };

  const handleReverse = async () => {
    if (!token || !orgId || !payment || !reversalReason.trim()) return;
    setSubmitting(true);
    setError(null);
    try {
      const res = await fetch(`/api/v1/payments/${id}/reverse`, {
        method:  "POST",
        headers: {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId,
          "Content-Type":      "application/json",
        },
        body: JSON.stringify({ reason: reversalReason }),
      });
      const json = await res.json();
      if (res.ok) {
        setShowReverse(false);
        setReversalReason("");
        fetchPayment();
      } else {
        setError(json.errors?.join(", ") ?? "Failed to reverse payment");
      }
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) {
    return (
      <AppShell>
        <div className="flex items-center justify-center h-64 text-muted-foreground">
          Loading payment...
        </div>
      </AppShell>
    );
  }

  if (!payment) {
    return (
      <AppShell>
        <div className="flex items-center justify-center h-64 text-muted-foreground">
          Payment not found.
        </div>
      </AppShell>
    );
  }

  const tabs = [
    { key: "summary",     label: "Summary" },
    { key: "allocations", label: `Allocations (${payment.allocations.length})` },
    { key: "activity",    label: "Activity" },
  ] as const;

  return (
    <AppShell>
      <div className="flex flex-col h-full">
        {/* Header */}
        <div className="px-6 py-4 border-b bg-background">
          <div className="flex items-start justify-between gap-4">
            <div>
              <Breadcrumb items={[{ label: "Collections", href: "/collections" }, { label: payment.payment_number }]} />
              <div className="flex items-center gap-3 mt-1">
                <h1 className="text-2xl font-bold font-mono">{payment.payment_number}</h1>
                <Badge variant={STATUS_VARIANT[payment.status] ?? "secondary"}>
                  {payment.status.charAt(0).toUpperCase() + payment.status.slice(1)}
                </Badge>
              </div>
              <p className="text-muted-foreground mt-0.5">
                {payment.customer.name} · {fmtCurrency(payment.amount)} · {PAYMENT_MODE_LABELS[payment.payment_mode] ?? payment.payment_mode}
              </p>
            </div>

            <div className="flex items-center gap-2">
              {payment.status === "draft" && (
                <Button onClick={handleConfirm} disabled={submitting}>
                  <CheckCircle2 className="h-4 w-4 mr-2" />
                  Confirm Payment
                </Button>
              )}
              {payment.status === "confirmed" && (
                <Button
                  variant="outline"
                  className="text-red-600 border-red-200 hover:bg-red-50"
                  onClick={() => setShowReverse(true)}
                  disabled={submitting}
                >
                  <RotateCcw className="h-4 w-4 mr-2" />
                  Reverse
                </Button>
              )}
            </div>
          </div>

          {error && (
            <div className="mt-2 flex items-center gap-2 text-sm text-red-600 bg-red-50 rounded px-3 py-2">
              <AlertTriangle className="h-4 w-4 shrink-0" />
              {error}
            </div>
          )}
        </div>

        {/* Tabs */}
        <div className="border-b bg-background px-6">
          <div className="flex gap-0">
            {tabs.map((tab) => (
              <button
                key={tab.key}
                onClick={() => setActiveTab(tab.key)}
                className={`px-4 py-3 text-sm font-medium border-b-2 transition-colors ${
                  activeTab === tab.key
                    ? "border-primary text-primary"
                    : "border-transparent text-muted-foreground hover:text-foreground"
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>
        </div>

        {/* Tab Content */}
        <div className="flex-1 overflow-auto px-6 py-6">

          {/* Summary Tab */}
          {activeTab === "summary" && (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* Payment Details */}
              <div className="rounded-lg border bg-card p-5">
                <h3 className="font-semibold mb-4">Payment Details</h3>
                <dl className="space-y-3 text-sm">
                  {[
                    ["Payment #",    payment.payment_number],
                    ["Retailer",     payment.customer.name],
                    ["Branch",       payment.branch.code],
                    ["Mode",         PAYMENT_MODE_LABELS[payment.payment_mode] ?? payment.payment_mode],
                    ["Reference #",  payment.reference_number ?? "—"],
                    ["Received On",  fmtDate(payment.received_date)],
                    ["Confirmed At", fmtDateTime(payment.confirmed_at)],
                    ["Recorded By",  payment.created_by ?? "—"],
                  ].map(([label, value]) => (
                    <div key={label} className="flex justify-between">
                      <dt className="text-muted-foreground">{label}</dt>
                      <dd className="font-medium text-right">{value}</dd>
                    </div>
                  ))}
                  {payment.notes && (
                    <div className="pt-2 border-t">
                      <dt className="text-muted-foreground mb-1">Notes</dt>
                      <dd className="text-sm">{payment.notes}</dd>
                    </div>
                  )}
                </dl>
              </div>

              {/* Financial Summary */}
              <div className="rounded-lg border bg-card p-5">
                <h3 className="font-semibold mb-4">Financial Summary</h3>
                <dl className="space-y-3 text-sm">
                  {[
                    ["Total Amount",     fmtCurrency(payment.amount)],
                    ["Allocated",        fmtCurrency(payment.allocated_amount)],
                    ["Unallocated",      fmtCurrency(payment.unallocated_amount)],
                  ].map(([label, value]) => (
                    <div key={label} className="flex justify-between">
                      <dt className="text-muted-foreground">{label}</dt>
                      <dd className="font-semibold">{value}</dd>
                    </div>
                  ))}
                </dl>

                {payment.status === "reversed" && (
                  <div className="mt-4 p-3 rounded bg-red-50 border border-red-200 text-sm">
                    <p className="font-medium text-red-700">Payment Reversed</p>
                    <p className="text-red-600 mt-1">{payment.reversal_reason}</p>
                    <p className="text-red-500 text-xs mt-1">{fmtDateTime(payment.reversed_at)}</p>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Allocations Tab */}
          {activeTab === "allocations" && (
            <div className="rounded-lg border overflow-hidden">
              <table className="w-full text-sm">
                <thead className="bg-muted/50">
                  <tr>
                    {["Invoice #", "Invoice Date", "Invoice Total", "Allocated", "Outstanding (After)", "Status"].map((h) => (
                      <th key={h} className="px-4 py-3 text-left font-medium text-muted-foreground">
                        {h}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {payment.allocations.length === 0 ? (
                    <tr>
                      <td colSpan={6} className="px-4 py-8 text-center text-muted-foreground">
                        No allocations yet. Confirm the payment to allocate automatically.
                      </td>
                    </tr>
                  ) : (
                    payment.allocations.map((alloc) => (
                      <tr key={alloc.id} className="border-t hover:bg-muted/30">
                        <td className="px-4 py-3 font-mono font-medium">
                          {alloc.invoice ? (
                            <button
                              onClick={() => router.push(`/sales-invoices/${alloc.invoice!.id}`)}
                              className="text-primary hover:underline"
                            >
                              {alloc.invoice.invoice_number}
                            </button>
                          ) : "—"}
                        </td>
                        <td className="px-4 py-3 text-muted-foreground">
                          {alloc.invoice ? fmtDate(alloc.invoice.invoice_date) : "—"}
                        </td>
                        <td className="px-4 py-3">
                          {alloc.invoice ? fmtCurrency(alloc.invoice.grand_total) : "—"}
                        </td>
                        <td className="px-4 py-3 font-semibold">
                          {fmtCurrency(alloc.allocated_amount)}
                        </td>
                        <td className="px-4 py-3">
                          {alloc.invoice ? fmtCurrency(alloc.invoice.outstanding) : "—"}
                        </td>
                        <td className="px-4 py-3">
                          <Badge variant={ALLOC_STATUS_VARIANT[alloc.status] ?? "secondary"}>
                            {alloc.status}
                          </Badge>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          )}

          {/* Activity Tab */}
          {activeTab === "activity" && (
            <div className="rounded-lg border divide-y">
              {payment.audit_trail.length === 0 ? (
                <p className="px-4 py-8 text-center text-muted-foreground text-sm">No activity yet.</p>
              ) : (
                payment.audit_trail.map((entry, i) => (
                  <div key={i} className="px-4 py-3">
                    <div className="flex items-center justify-between">
                      <span className="font-medium text-sm">{entry.action.replace(/_/g, " ")}</span>
                      <span className="text-xs text-muted-foreground">{fmtDateTime(entry.at)}</span>
                    </div>
                    {entry.actor && (
                      <p className="text-xs text-muted-foreground mt-0.5">by {entry.actor}</p>
                    )}
                    {entry.reason && (
                      <p className="text-xs italic text-muted-foreground mt-0.5">"{entry.reason}"</p>
                    )}
                  </div>
                ))
              )}
            </div>
          )}
        </div>
      </div>

      {/* Reversal Modal */}
      {showReverse && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
          <div className="bg-white rounded-lg shadow-lg w-full max-w-md p-6">
            <h2 className="text-lg font-semibold mb-1">Reverse Payment</h2>
            <p className="text-sm text-muted-foreground mb-4">
              This will reverse all allocations and restore invoice outstanding balances.
            </p>
            <Textarea
              placeholder="Reason for reversal (required)..."
              value={reversalReason}
              onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) => setReversalReason(e.target.value)}
              rows={3}
            />
            {error && <p className="text-sm text-red-600 mt-2">{error}</p>}
            <div className="flex justify-end gap-3 mt-4">
              <Button variant="outline" onClick={() => { setShowReverse(false); setReversalReason(""); }}>
                Cancel
              </Button>
              <Button
                className="bg-red-600 hover:bg-red-700 text-white"
                onClick={handleReverse}
                disabled={submitting || !reversalReason.trim()}
              >
                Confirm Reversal
              </Button>
            </div>
          </div>
        </div>
      )}
    </AppShell>
  );
}
