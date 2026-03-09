"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { API_URL } from "@/lib/api/client";
import { useOrgBranch } from "@/lib/org-branch-context";
import { Plus, Trash2 } from "lucide-react";

// ── Types ─────────────────────────────────────────────────────────────────────

interface LineItem {
  product_id:  string;
  qty:         string;
  unit_price:  string;
  gst_rate:    string;
  hsn_code:    string;
  notes:       string;
}

const REASONS = [
  { value: "quality_issue",  label: "Quality Issue" },
  { value: "expired",        label: "Expired" },
  { value: "short_supply",   label: "Short Supply" },
  { value: "damaged",        label: "Damaged" },
  { value: "wrong_item",     label: "Wrong Item" },
  { value: "other",          label: "Other" },
];

const emptyLine = (): LineItem => ({
  product_id: "", qty: "", unit_price: "", gst_rate: "18", hsn_code: "", notes: "",
});

// ── Page ──────────────────────────────────────────────────────────────────────

export default function NewSupplierDebitNotePage() {
  const router = useRouter();
  const { token, orgId, branches } = useOrgBranch();

  const [branchId, setBranchId]   = useState("");
  const [supplierId, setSupplierId] = useState("");
  const [suppliers, setSuppliers] = useState<{ id: number; name: string; code: string }[]>([]);
  const [noteDate, setNoteDate]   = useState(new Date().toISOString().slice(0, 10));
  const [reason, setReason]       = useState("quality_issue");
  const [notes, setNotes]         = useState("");
  const [lines, setLines]         = useState<LineItem[]>([emptyLine()]);
  const [saving, setSaving]       = useState(false);
  const [error, setError]         = useState<string | null>(null);

  const headers = {
    Authorization:       `Bearer ${token}`,
    "X-Organization-Id": orgId!,
    "Content-Type":      "application/json",
  };

  // Load suppliers
  useEffect(() => {
    if (!token || !orgId) return;
    fetch(`${API_URL}/api/v1/suppliers?per_page=200`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then((r) => r.json())
      .then((body) => setSuppliers(body.data ?? []))
      .catch(() => {});
  }, [token, orgId]);

  // Pre-select single branch
  useEffect(() => {
    if (branches?.length === 1) setBranchId(String(branches[0].id));
  }, [branches]);

  const updateLine = (idx: number, key: keyof LineItem, value: string) => {
    setLines((prev) => prev.map((l, i) => i === idx ? { ...l, [key]: value } : l));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!branchId || !supplierId || !reason) {
      setError("Branch, supplier and reason are required.");
      return;
    }
    const validLines = lines.filter((l) => l.product_id && l.qty && l.unit_price);
    if (validLines.length === 0) {
      setError("At least one line item with product, qty and unit price is required.");
      return;
    }

    setSaving(true);
    setError(null);
    try {
      const res = await fetch(`${API_URL}/api/v1/supplier_debit_notes`, {
        method:  "POST",
        headers,
        body: JSON.stringify({
          branch_id:        Number(branchId),
          supplier_id:      Number(supplierId),
          debit_note_date:  noteDate,
          reason,
          notes:            notes || undefined,
          lines_attributes: validLines.map((l) => ({
            product_id:  Number(l.product_id),
            qty:         Number(l.qty),
            unit_price:  Number(l.unit_price),
            gst_rate:    Number(l.gst_rate),
            hsn_code:    l.hsn_code || undefined,
            notes:       l.notes || undefined,
          })),
        }),
      });
      const body = await res.json();
      if (!res.ok) throw new Error((body.errors ?? ["Failed to create"]).join(", "));
      router.push(`/supplier-debit-notes/${body.data.id}`);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unknown error");
    } finally {
      setSaving(false);
    }
  };

  const inputCls = "w-full h-9 rounded-md border border-border bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary";

  return (
    <AppShell breadcrumbs={[
      { label: "Supplier Debit Notes", href: "/supplier-debit-notes" },
      { label: "New Debit Note" },
    ]}>
      <PageHeader
        title="New Supplier Debit Note"
        subtitle="Raise a debit note against a supplier for returns or quality issues"
      />

      <form onSubmit={handleSubmit} className="space-y-6 max-w-3xl">
        {error && (
          <div className="rounded-md bg-destructive/10 border border-destructive/30 px-4 py-3 text-sm text-destructive">
            {error}
          </div>
        )}

        {/* Header fields */}
        <div className="rounded-lg border bg-card p-5 space-y-4">
          <h3 className="text-sm font-semibold">Details</h3>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-medium text-text-secondary mb-1.5">
                Branch <span className="text-destructive">*</span>
              </label>
              <select className={inputCls} value={branchId} onChange={(e) => setBranchId(e.target.value)}>
                <option value="">— Select branch —</option>
                {(branches ?? []).map((b: { id: number; name: string }) => (
                  <option key={b.id} value={b.id}>{b.name}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-xs font-medium text-text-secondary mb-1.5">
                Supplier <span className="text-destructive">*</span>
              </label>
              <select className={inputCls} value={supplierId} onChange={(e) => setSupplierId(e.target.value)}>
                <option value="">— Select supplier —</option>
                {suppliers.map((s) => (
                  <option key={s.id} value={s.id}>{s.name} ({s.code})</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-xs font-medium text-text-secondary mb-1.5">
                Debit Note Date <span className="text-destructive">*</span>
              </label>
              <input
                type="date"
                className={inputCls}
                value={noteDate}
                onChange={(e) => setNoteDate(e.target.value)}
                required
              />
            </div>

            <div>
              <label className="block text-xs font-medium text-text-secondary mb-1.5">
                Reason <span className="text-destructive">*</span>
              </label>
              <select className={inputCls} value={reason} onChange={(e) => setReason(e.target.value)}>
                {REASONS.map((r) => (
                  <option key={r.value} value={r.value}>{r.label}</option>
                ))}
              </select>
            </div>
          </div>

          <div>
            <label className="block text-xs font-medium text-text-secondary mb-1.5">Notes</label>
            <textarea
              rows={2}
              className={`${inputCls} h-auto py-2 resize-none`}
              placeholder="Optional notes"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
            />
          </div>
        </div>

        {/* Line items */}
        <div className="rounded-lg border bg-card overflow-hidden">
          <div className="px-5 py-3 bg-muted/40 border-b flex items-center justify-between">
            <h3 className="text-sm font-semibold">Line Items</h3>
            <Button
              type="button"
              size="sm"
              variant="outline"
              onClick={() => setLines((prev) => [...prev, emptyLine()])}
            >
              <Plus className="h-3.5 w-3.5 mr-1.5" />
              Add Line
            </Button>
          </div>

          <div className="divide-y">
            {lines.map((line, idx) => (
              <div key={idx} className="px-5 py-4 space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-medium text-text-secondary">Line {idx + 1}</span>
                  {lines.length > 1 && (
                    <Button
                      type="button"
                      size="sm"
                      variant="ghost"
                      className="text-destructive h-7 w-7 p-0"
                      onClick={() => setLines((prev) => prev.filter((_, i) => i !== idx))}
                    >
                      <Trash2 className="h-3.5 w-3.5" />
                    </Button>
                  )}
                </div>
                <div className="grid grid-cols-3 gap-3">
                  <div>
                    <label className="block text-xs text-text-secondary mb-1">Product ID *</label>
                    <Input
                      type="number"
                      placeholder="e.g. 42"
                      value={line.product_id}
                      onChange={(e) => updateLine(idx, "product_id", e.target.value)}
                    />
                  </div>
                  <div>
                    <label className="block text-xs text-text-secondary mb-1">Qty *</label>
                    <Input
                      type="number"
                      step="0.001"
                      min="0.001"
                      placeholder="e.g. 10"
                      value={line.qty}
                      onChange={(e) => updateLine(idx, "qty", e.target.value)}
                    />
                  </div>
                  <div>
                    <label className="block text-xs text-text-secondary mb-1">Unit Price *</label>
                    <Input
                      type="number"
                      step="0.01"
                      min="0"
                      placeholder="e.g. 250.00"
                      value={line.unit_price}
                      onChange={(e) => updateLine(idx, "unit_price", e.target.value)}
                    />
                  </div>
                  <div>
                    <label className="block text-xs text-text-secondary mb-1">GST Rate %</label>
                    <Input
                      type="number"
                      step="0.01"
                      min="0"
                      placeholder="18"
                      value={line.gst_rate}
                      onChange={(e) => updateLine(idx, "gst_rate", e.target.value)}
                    />
                  </div>
                  <div>
                    <label className="block text-xs text-text-secondary mb-1">HSN Code</label>
                    <Input
                      placeholder="e.g. 190190"
                      value={line.hsn_code}
                      onChange={(e) => updateLine(idx, "hsn_code", e.target.value)}
                    />
                  </div>
                  <div>
                    <label className="block text-xs text-text-secondary mb-1">Line Notes</label>
                    <Input
                      placeholder="Optional"
                      value={line.notes}
                      onChange={(e) => updateLine(idx, "notes", e.target.value)}
                    />
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Actions */}
        <div className="flex items-center gap-3 justify-end">
          <Button type="button" variant="outline" onClick={() => router.push("/supplier-debit-notes")}>
            Cancel
          </Button>
          <Button type="submit" disabled={saving}>
            {saving ? "Creating…" : "Create Debit Note"}
          </Button>
        </div>
      </form>
    </AppShell>
  );
}
