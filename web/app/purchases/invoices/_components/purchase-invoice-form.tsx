"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Plus, Trash2 } from "lucide-react";
import { API_URL } from "@/lib/api/client";

// ─── Types ─────────────────────────────────────────────────────────────────────
export interface LineItem {
  id?: number;
  product_id:    string;
  hsn_sac_code_id: string;
  qty:           string;
  unit_price:    string;
  discount_pct:  string;
  tax_rate:      string;
  notes:         string;
  _destroy?:     boolean;
  // read-only computed
  _line_total?: number;
  _tax_amount?: number;
}

export interface PurchaseInvoiceFormData {
  supplier_id:    string;
  branch_id:      string;
  invoice_number: string;
  invoice_date:   string;
  due_date:       string;
  currency:       string;
  notes:          string;
  lines:          LineItem[];
}

interface Product { id: number; name: string; sku: string; purchase_price: number | null; gst_rate: number | null; hsn_sac_code_id: number | null; }
interface Supplier { id: number; name: string; code: string; }
interface Branch   { id: number; name: string; }
interface HsnSacCode { id: number; code: string; gst_rate: number; }

const EMPTY_LINE = (): LineItem => ({
  product_id: "", hsn_sac_code_id: "", qty: "1", unit_price: "",
  discount_pct: "0", tax_rate: "0", notes: "",
});

const CURRENCIES = ["INR", "USD", "EUR"];

function computeLine(line: LineItem): { subtotal: number; tax_amount: number; line_total: number } {
  const qty  = parseFloat(line.qty)          || 0;
  const up   = parseFloat(line.unit_price)   || 0;
  const disc = parseFloat(line.discount_pct) || 0;
  const rate = parseFloat(line.tax_rate)     || 0;
  const base = qty * up * (1 - disc / 100);
  const tax  = parseFloat((base * rate / 100).toFixed(2));
  const total = parseFloat((base + tax).toFixed(2));
  return { subtotal: parseFloat(base.toFixed(2)), tax_amount: tax, line_total: total };
}

function fmt(n: number) {
  return `₹${n.toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

// ─── Props ─────────────────────────────────────────────────────────────────────
interface PurchaseInvoiceFormProps {
  initial?:   Partial<PurchaseInvoiceFormData> & { lines?: LineItem[] };
  invoiceId?: number;
  token:      string | null;
  orgId:      string | null;
}

// ─── Component ──────────────────────────────────────────────────────────────────
export function PurchaseInvoiceForm({ initial, invoiceId, token, orgId }: PurchaseInvoiceFormProps) {
  const router = useRouter();
  const isEdit = !!invoiceId;

  const today = new Date().toISOString().split("T")[0];

  const [form, setForm] = useState<PurchaseInvoiceFormData>({
    supplier_id:    initial?.supplier_id    ?? "",
    branch_id:      initial?.branch_id      ?? "",
    invoice_number: initial?.invoice_number ?? "",
    invoice_date:   initial?.invoice_date   ?? today,
    due_date:       initial?.due_date       ?? "",
    currency:       initial?.currency       ?? "INR",
    notes:          initial?.notes          ?? "",
    lines:          initial?.lines          ?? [EMPTY_LINE()],
  });

  const [saving,    setSaving]    = useState(false);
  const [errors,    setErrors]    = useState<string[]>([]);
  const [suppliers, setSuppliers] = useState<Supplier[]>([]);
  const [branches,  setBranches]  = useState<Branch[]>([]);
  const [products,  setProducts]  = useState<Product[]>([]);
  const [hsnCodes,  setHsnCodes]  = useState<HsnSacCode[]>([]);

  // Load reference data
  useEffect(() => {
    if (!token || !orgId) return;
    const headers = { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId };
    Promise.all([
      fetch(`${API_URL}/api/v1/suppliers?per_page=200&status=active`, { headers }).then((r) => r.json()),
      fetch(`${API_URL}/api/v1/branches?per_page=200`, { headers }).then((r) => r.json()),
      fetch(`${API_URL}/api/v1/products?per_page=500`, { headers }).then((r) => r.json()),
      fetch(`${API_URL}/api/v1/hsn_sac_codes?per_page=500`, { headers }).then((r) => r.json()),
    ]).then(([sup, br, prod, hsn]) => {
      setSuppliers(sup.data ?? []);
      setBranches(br.data  ?? []);
      setProducts(prod.data ?? []);
      setHsnCodes(hsn.data  ?? []);
    });
  }, [token, orgId]);

  const set = useCallback(
    (key: keyof Omit<PurchaseInvoiceFormData, "lines">) =>
      (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) =>
        setForm((f) => ({ ...f, [key]: e.target.value })),
    []
  );

  // ── Line helpers ────────────────────────────────────────────────────────────
  const updateLine = (idx: number, key: keyof LineItem, value: string) => {
    setForm((f) => {
      const lines = [...f.lines];
      lines[idx] = { ...lines[idx], [key]: value };

      // Auto-fill unit_price and tax_rate from product if product changed
      if (key === "product_id") {
        const prod = products.find((p) => String(p.id) === value);
        if (prod) {
          lines[idx].unit_price        = prod.purchase_price != null ? String(prod.purchase_price) : lines[idx].unit_price;
          lines[idx].tax_rate          = prod.gst_rate        != null ? String(prod.gst_rate)        : lines[idx].tax_rate;
          lines[idx].hsn_sac_code_id   = prod.hsn_sac_code_id != null ? String(prod.hsn_sac_code_id) : lines[idx].hsn_sac_code_id;
        }
      }

      return { ...f, lines };
    });
  };

  const addLine    = () => setForm((f) => ({ ...f, lines: [...f.lines, EMPTY_LINE()] }));
  const removeLine = (idx: number) =>
    setForm((f) => {
      const lines = [...f.lines];
      if (lines[idx].id) {
        lines[idx] = { ...lines[idx], _destroy: true };
      } else {
        lines.splice(idx, 1);
      }
      return { ...f, lines };
    });

  // ── Totals ──────────────────────────────────────────────────────────────────
  const activeLines = form.lines.filter((l) => !l._destroy);
  const subtotalSum = activeLines.reduce((s, l) => s + computeLine(l).subtotal, 0);
  const taxSum      = activeLines.reduce((s, l) => s + computeLine(l).tax_amount, 0);
  const grandTotal  = subtotalSum + taxSum;

  // ── Submit ──────────────────────────────────────────────────────────────────
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!token || !orgId) return;
    setSaving(true); setErrors([]);

    const linesPayload = form.lines
      .filter((l) => l.id || !l._destroy) // keep existing marked _destroy, skip new empty rows
      .filter((l) => l._destroy || l.product_id)  // skip completely empty new rows
      .map((l) => ({
        ...(l.id ? { id: l.id } : {}),
        ...(l._destroy ? { _destroy: "1" } : {}),
        product_id:      Number(l.product_id),
        hsn_sac_code_id: l.hsn_sac_code_id ? Number(l.hsn_sac_code_id) : null,
        qty:             parseFloat(l.qty)          || 0,
        unit_price:      parseFloat(l.unit_price)   || 0,
        discount_pct:    parseFloat(l.discount_pct) || 0,
        tax_rate:        parseFloat(l.tax_rate)      || 0,
        notes:           l.notes || null,
      }));

    const body = {
      purchase_invoice: {
        supplier_id:    Number(form.supplier_id),
        branch_id:      form.branch_id ? Number(form.branch_id) : undefined,
        invoice_number: form.invoice_number,
        invoice_date:   form.invoice_date,
        due_date:       form.due_date || null,
        currency:       form.currency,
        notes:          form.notes || null,
        lines_attributes: linesPayload,
      },
    };

    const url    = isEdit
      ? `${API_URL}/api/v1/purchase_invoices/${invoiceId}`
      : `${API_URL}/api/v1/purchase_invoices`;
    const method = isEdit ? "PATCH" : "POST";

    const res  = await fetch(url, {
      method,
      headers: {
        "Content-Type":      "application/json",
        Authorization:       `Bearer ${token}`,
        "X-Organization-Id": orgId,
      },
      body: JSON.stringify(body),
    });
    const json = await res.json();
    if (res.ok) {
      router.push(`/purchases/invoices/${json.data.id}`);
    } else {
      setErrors(json.errors ?? ["Failed to save invoice"]);
      setSaving(false);
    }
  };

  // ── Render ──────────────────────────────────────────────────────────────────
  const field = (label: string, required = false, children: React.ReactNode) => (
    <div className="space-y-1.5">
      <label className="text-sm font-medium text-text-primary">
        {label}{required && <span className="text-danger ml-0.5">*</span>}
      </label>
      {children}
    </div>
  );

  const inputCls = "h-9 w-full rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent";

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      {errors.length > 0 && (
        <div className="rounded-md bg-danger/8 border border-danger/20 px-4 py-3 text-sm text-danger">
          <ul className="list-disc list-inside space-y-1">
            {errors.map((e, i) => <li key={i}>{e}</li>)}
          </ul>
        </div>
      )}

      {/* Header fields */}
      <div className="rounded-lg border border-border bg-background p-5 space-y-4">
        <p className="text-sm font-semibold text-text-primary">Invoice Details</p>

        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {field("Supplier", true,
            <select className={inputCls} value={form.supplier_id} onChange={set("supplier_id")} required>
              <option value="">Select supplier…</option>
              {suppliers.map((s) => (
                <option key={s.id} value={String(s.id)}>{s.name} ({s.code})</option>
              ))}
            </select>
          )}

          {field("Branch",
            false,
            <select className={inputCls} value={form.branch_id} onChange={set("branch_id")}>
              <option value="">Select branch…</option>
              {branches.map((b) => (
                <option key={b.id} value={String(b.id)}>{b.name}</option>
              ))}
            </select>
          )}

          {field("Invoice Number", true,
            <Input
              value={form.invoice_number}
              onChange={set("invoice_number")}
              placeholder="INV-001"
              required
            />
          )}

          {field("Invoice Date", true,
            <input type="date" className={inputCls} value={form.invoice_date} onChange={set("invoice_date")} required />
          )}

          {field("Due Date", false,
            <input type="date" className={inputCls} value={form.due_date} onChange={set("due_date")} />
          )}

          {field("Currency", true,
            <select className={inputCls} value={form.currency} onChange={set("currency")}>
              {CURRENCIES.map((c) => <option key={c} value={c}>{c}</option>)}
            </select>
          )}
        </div>

        {field("Notes", false,
          <textarea
            className="w-full rounded-md border border-border bg-background px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent resize-none"
            rows={2}
            value={form.notes}
            onChange={set("notes")}
            placeholder="Internal notes…"
          />
        )}
      </div>

      {/* Line items */}
      <div className="rounded-lg border border-border bg-background p-5 space-y-3">
        <p className="text-sm font-semibold text-text-primary">Line Items</p>

        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-xs font-medium text-text-secondary uppercase tracking-wide border-b border-border">
                <th className="py-2 pr-3 w-[200px]">Product</th>
                <th className="py-2 pr-3 w-[140px]">HSN/SAC</th>
                <th className="py-2 pr-3 w-[80px]">Qty</th>
                <th className="py-2 pr-3 w-[110px]">Unit Price</th>
                <th className="py-2 pr-3 w-[80px]">Disc %</th>
                <th className="py-2 pr-3 w-[80px]">Tax %</th>
                <th className="py-2 pr-3 w-[110px] text-right">Line Total</th>
                <th className="py-2 w-[36px]"></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {form.lines.map((line, idx) => {
                if (line._destroy) return null;
                const { line_total } = computeLine(line);
                return (
                  <tr key={idx}>
                    <td className="py-1.5 pr-3">
                      <select
                        className="h-8 w-full rounded-md border border-border bg-background px-2 text-sm focus:outline-none focus:ring-1 focus:ring-accent"
                        value={line.product_id}
                        onChange={(e) => updateLine(idx, "product_id", e.target.value)}
                        required
                      >
                        <option value="">Select…</option>
                        {products.map((p) => (
                          <option key={p.id} value={String(p.id)}>{p.name}</option>
                        ))}
                      </select>
                    </td>
                    <td className="py-1.5 pr-3">
                      <select
                        className="h-8 w-full rounded-md border border-border bg-background px-2 text-sm focus:outline-none focus:ring-1 focus:ring-accent"
                        value={line.hsn_sac_code_id}
                        onChange={(e) => updateLine(idx, "hsn_sac_code_id", e.target.value)}
                      >
                        <option value="">— none —</option>
                        {hsnCodes.map((h) => (
                          <option key={h.id} value={String(h.id)}>{h.code} ({h.gst_rate}%)</option>
                        ))}
                      </select>
                    </td>
                    <td className="py-1.5 pr-3">
                      <input
                        type="number" min="0.001" step="0.001"
                        className="h-8 w-full rounded-md border border-border bg-background px-2 text-sm focus:outline-none focus:ring-1 focus:ring-accent"
                        value={line.qty}
                        onChange={(e) => updateLine(idx, "qty", e.target.value)}
                        required
                      />
                    </td>
                    <td className="py-1.5 pr-3">
                      <input
                        type="number" min="0" step="0.01"
                        className="h-8 w-full rounded-md border border-border bg-background px-2 text-sm focus:outline-none focus:ring-1 focus:ring-accent"
                        value={line.unit_price}
                        onChange={(e) => updateLine(idx, "unit_price", e.target.value)}
                        required
                      />
                    </td>
                    <td className="py-1.5 pr-3">
                      <input
                        type="number" min="0" max="100" step="0.01"
                        className="h-8 w-full rounded-md border border-border bg-background px-2 text-sm focus:outline-none focus:ring-1 focus:ring-accent"
                        value={line.discount_pct}
                        onChange={(e) => updateLine(idx, "discount_pct", e.target.value)}
                      />
                    </td>
                    <td className="py-1.5 pr-3">
                      <input
                        type="number" min="0" max="100" step="0.01"
                        className="h-8 w-full rounded-md border border-border bg-background px-2 text-sm focus:outline-none focus:ring-1 focus:ring-accent"
                        value={line.tax_rate}
                        onChange={(e) => updateLine(idx, "tax_rate", e.target.value)}
                      />
                    </td>
                    <td className="py-1.5 pr-3 text-right font-medium text-text-primary">
                      {fmt(line_total)}
                    </td>
                    <td className="py-1.5">
                      {activeLines.length > 1 && (
                        <button
                          type="button"
                          onClick={() => removeLine(idx)}
                          className="p-1 rounded hover:bg-muted text-text-secondary hover:text-danger transition-colors"
                        >
                          <Trash2 className="h-3.5 w-3.5" />
                        </button>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        <Button type="button" variant="outline" size="sm" onClick={addLine}>
          <Plus className="h-4 w-4 mr-1" /> Add Line
        </Button>

        {/* Totals summary */}
        <div className="flex justify-end mt-4">
          <dl className="space-y-1.5 text-sm min-w-[220px]">
            <div className="flex justify-between gap-8">
              <dt className="text-text-secondary">Subtotal</dt>
              <dd className="font-medium text-text-primary">{fmt(subtotalSum)}</dd>
            </div>
            <div className="flex justify-between gap-8">
              <dt className="text-text-secondary">Tax</dt>
              <dd className="font-medium text-text-primary">{fmt(taxSum)}</dd>
            </div>
            <div className="flex justify-between gap-8 border-t border-border pt-1.5">
              <dt className="font-semibold text-text-primary">Grand Total</dt>
              <dd className="font-bold text-text-primary">{fmt(grandTotal)}</dd>
            </div>
          </dl>
        </div>
      </div>

      {/* Actions */}
      <div className="flex items-center justify-end gap-3">
        <Button type="button" variant="outline" onClick={() => router.back()} disabled={saving}>
          Cancel
        </Button>
        <Button type="submit" disabled={saving}>
          {saving ? "Saving…" : isEdit ? "Update Invoice" : "Create Invoice"}
        </Button>
      </div>
    </form>
  );
}
