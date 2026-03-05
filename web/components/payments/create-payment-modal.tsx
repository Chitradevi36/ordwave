"use client";

import { useState, useEffect } from "react";
import { Modal } from "@/components/ui/modal";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Loader2 } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";

// ── Types ─────────────────────────────────────────────────────────────────────

interface Customer { id: number; name: string; code: string }
interface Branch   { id: number; name: string; code: string }

interface Form {
  customer_id:      string;
  branch_id:        string;
  amount:           string;
  payment_mode:     string;
  reference_number: string;
  received_date:    string;
  notes:            string;
}

const BLANK: Form = {
  customer_id:      "",
  branch_id:        "",
  amount:           "",
  payment_mode:     "cash",
  reference_number: "",
  received_date:    new Date().toISOString().split("T")[0],
  notes:            "",
};

const PAYMENT_MODES = [
  { value: "cash",          label: "Cash" },
  { value: "bank_transfer", label: "Bank Transfer" },
  { value: "upi",           label: "UPI" },
  { value: "cheque",        label: "Cheque" },
  { value: "neft",          label: "NEFT" },
  { value: "rtgs",          label: "RTGS" },
  { value: "adjustment",    label: "Adjustment" },
];

// ── Props ─────────────────────────────────────────────────────────────────────

interface Props {
  onClose:   () => void;
  onCreated: () => void;
  /** Pre-fill customer when opened from a customer context */
  prefilledCustomer?: { id: number; name: string };
}

// ── Component ─────────────────────────────────────────────────────────────────

export default function CreatePaymentModal({ onClose, onCreated, prefilledCustomer }: Props) {
  const { token, orgId } = useOrgBranch();

  const [form, setForm]         = useState<Form>({
    ...BLANK,
    customer_id: prefilledCustomer ? String(prefilledCustomer.id) : "",
  });
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [branches, setBranches]   = useState<Branch[]>([]);
  const [saving, setSaving]       = useState(false);
  const [error, setError]         = useState<string | null>(null);

  const set = (key: keyof Form, value: string) =>
    setForm((f) => ({ ...f, [key]: value }));

  // Fetch customers and branches
  useEffect(() => {
    if (!token || !orgId) return;
    const headers = { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId };

    Promise.all([
      fetch("/api/v1/customers?per_page=200&status=active", { headers }).then((r) => r.json()),
      fetch("/api/v1/branches?per_page=50",                  { headers }).then((r) => r.json()),
    ]).then(([cJson, bJson]) => {
      setCustomers(cJson.data ?? []);
      setBranches(bJson.data ?? []);
      // Pre-fill branch if there's only one
      if ((bJson.data ?? []).length === 1) {
        setForm((f) => ({ ...f, branch_id: String(bJson.data[0].id) }));
      }
    });
  }, [token, orgId]);

  const handleSubmit = async () => {
    if (!form.customer_id || !form.branch_id || !form.amount || !form.received_date) {
      setError("Customer, branch, amount, and received date are required.");
      return;
    }
    setSaving(true);
    setError(null);
    try {
      const res = await fetch("/api/v1/payments", {
        method:  "POST",
        headers: {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId!,
          "Content-Type":      "application/json",
        },
        body: JSON.stringify({
          payment: {
            customer_id:      Number(form.customer_id),
            branch_id:        Number(form.branch_id),
            amount:           parseFloat(form.amount),
            payment_mode:     form.payment_mode,
            reference_number: form.reference_number || null,
            received_date:    form.received_date,
            notes:            form.notes || null,
          },
        }),
      });
      const json = await res.json();
      if (res.ok) {
        onCreated();
      } else {
        setError(json.errors?.join(", ") ?? "Failed to create payment");
      }
    } finally {
      setSaving(false);
    }
  };

  const needsRef = ["bank_transfer", "upi", "cheque", "neft", "rtgs"].includes(form.payment_mode);

  return (
    <Modal open onClose={onClose} title="Record Payment" size="md">
      <div className="space-y-4">

        {/* Retailer */}
        {prefilledCustomer ? (
          <div>
            <label className="block text-sm font-medium mb-1">Retailer</label>
            <p className="px-3 py-2 rounded border bg-muted text-sm">{prefilledCustomer.name}</p>
          </div>
        ) : (
          <div>
            <label className="block text-sm font-medium mb-1">Retailer <span className="text-red-500">*</span></label>
            <select
              className="w-full rounded border px-3 py-2 text-sm bg-background"
              value={form.customer_id}
              onChange={(e) => set("customer_id", e.target.value)}
            >
              <option value="">Select retailer...</option>
              {customers.map((c) => (
                <option key={c.id} value={c.id}>{c.name} ({c.code})</option>
              ))}
            </select>
          </div>
        )}

        {/* Branch */}
        <div>
          <label className="block text-sm font-medium mb-1">Branch <span className="text-red-500">*</span></label>
          <select
            className="w-full rounded border px-3 py-2 text-sm bg-background"
            value={form.branch_id}
            onChange={(e) => set("branch_id", e.target.value)}
          >
            <option value="">Select branch...</option>
            {branches.map((b) => (
              <option key={b.id} value={b.id}>{b.name} ({b.code})</option>
            ))}
          </select>
        </div>

        {/* Amount + Mode row */}
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="block text-sm font-medium mb-1">Amount (₹) <span className="text-red-500">*</span></label>
            <Input
              type="number"
              min="0.01"
              step="0.01"
              placeholder="0.00"
              value={form.amount}
              onChange={(e) => set("amount", e.target.value)}
            />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">Payment Mode <span className="text-red-500">*</span></label>
            <select
              className="w-full rounded border px-3 py-2 text-sm bg-background"
              value={form.payment_mode}
              onChange={(e) => set("payment_mode", e.target.value)}
            >
              {PAYMENT_MODES.map((m) => (
                <option key={m.value} value={m.value}>{m.label}</option>
              ))}
            </select>
          </div>
        </div>

        {/* Reference # — shown for non-cash modes */}
        {needsRef && (
          <div>
            <label className="block text-sm font-medium mb-1">
              Reference / Transaction # {needsRef && <span className="text-red-500">*</span>}
            </label>
            <Input
              placeholder={
                form.payment_mode === "cheque" ? "Cheque number" :
                form.payment_mode === "upi"    ? "UPI transaction ID" :
                "Transaction / UTR number"
              }
              value={form.reference_number}
              onChange={(e) => set("reference_number", e.target.value)}
            />
          </div>
        )}

        {/* Received Date */}
        <div>
          <label className="block text-sm font-medium mb-1">Received Date <span className="text-red-500">*</span></label>
          <Input
            type="date"
            value={form.received_date}
            onChange={(e) => set("received_date", e.target.value)}
          />
        </div>

        {/* Notes */}
        <div>
          <label className="block text-sm font-medium mb-1">Notes</label>
          <textarea
            className="w-full rounded border px-3 py-2 text-sm bg-background resize-none"
            rows={2}
            placeholder="Optional notes..."
            value={form.notes}
            onChange={(e) => set("notes", e.target.value)}
          />
        </div>

        {error && (
          <p className="text-sm text-red-600 bg-red-50 rounded px-3 py-2">{error}</p>
        )}

        <div className="flex justify-end gap-3 pt-2">
          <Button variant="outline" onClick={onClose} disabled={saving}>
            Cancel
          </Button>
          <Button onClick={handleSubmit} disabled={saving}>
            {saving ? <><Loader2 className="h-4 w-4 mr-2 animate-spin" /> Saving...</> : "Record Payment"}
          </Button>
        </div>
      </div>
    </Modal>
  );
}
