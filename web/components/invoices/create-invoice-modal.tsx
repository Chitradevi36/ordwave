"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { Modal } from "@/components/ui/modal";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Loader2, Plus, Trash2, Search } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";

// ── Types ─────────────────────────────────────────────────────────────────────

interface Customer { id: number; name: string; code: string }
interface ProductOption {
  id:       number;
  name:     string;
  sku:      string;
  gst_rate: number;
  hsn:      { code: string | null };
}

interface LineItem {
  key:          number; // local-only stable key
  product_id:   string;
  product_name: string;
  hsn_code:     string;
  gst_rate:     string;
  qty:          string;
  unit_price:   string;
  discount_pct: string;
}

interface Props {
  onClose:   () => void;
  onCreated: (id: number) => void;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const today = () => new Date().toISOString().split("T")[0];

const calcLine = (l: LineItem) => {
  const qty  = parseFloat(l.qty)          || 0;
  const up   = parseFloat(l.unit_price)   || 0;
  const disc = parseFloat(l.discount_pct) || 0;
  const gst  = parseFloat(l.gst_rate)     || 0;
  const taxable = qty * up * (1 - disc / 100);
  const tax     = taxable * gst / 100;
  return {
    taxable: Math.round(taxable * 100) / 100,
    tax:     Math.round(tax     * 100) / 100,
    total:   Math.round((taxable + tax) * 100) / 100,
  };
};

const fmtINR = (n: number) =>
  `₹ ${n.toLocaleString("en-IN", { minimumFractionDigits: 2 })}`;

const blankLine = (): LineItem => ({
  key:          Date.now() + Math.random(),
  product_id:   "",
  product_name: "",
  hsn_code:     "",
  gst_rate:     "",
  qty:          "",
  unit_price:   "",
  discount_pct: "0",
});

// ── Product search combobox ───────────────────────────────────────────────────

interface ProductSearchProps {
  token:      string;
  orgId:      string;
  value:      string;   // product_name (display)
  onSelect:   (p: ProductOption) => void;
}

function ProductSearch({ token, orgId, value, onSelect }: ProductSearchProps) {
  const [query, setQuery]     = useState(value);
  const [results, setResults] = useState<ProductOption[]>([]);
  const [open, setOpen]       = useState(false);
  const [loading, setLoading] = useState(false);
  const debounceRef           = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Sync external value (e.g. when line is cleared)
  useEffect(() => { setQuery(value); }, [value]);

  const search = useCallback((q: string) => {
    if (!q.trim()) { setResults([]); setOpen(false); return; }
    setLoading(true);
    fetch(`/api/v1/products?q=${encodeURIComponent(q)}&status=active&per_page=20`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then((r) => r.json())
      .then((j) => { setResults(j.data ?? []); setOpen(true); })
      .finally(() => setLoading(false));
  }, [token, orgId]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setQuery(e.target.value);
    clearTimeout(debounceRef.current ?? undefined);
    debounceRef.current = setTimeout(() => search(e.target.value), 300);
  };

  const handleSelect = (p: ProductOption) => {
    setQuery(p.name);
    setOpen(false);
    setResults([]);
    onSelect(p);
  };

  return (
    <div className="relative">
      <div className="relative">
        <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground pointer-events-none" />
        <input
          type="text"
          className="w-full pl-8 pr-2 py-1.5 text-sm rounded border border-input bg-background focus:outline-none focus:ring-1 focus:ring-ring"
          placeholder="Search product…"
          value={query}
          onChange={handleChange}
          onFocus={() => query && results.length && setOpen(true)}
          onBlur={() => setTimeout(() => setOpen(false), 150)}
        />
        {loading && <Loader2 className="absolute right-2 top-1/2 -translate-y-1/2 h-3.5 w-3.5 animate-spin text-muted-foreground" />}
      </div>
      {open && results.length > 0 && (
        <ul className="absolute z-50 left-0 right-0 mt-1 rounded-md border border-border bg-background shadow-lg max-h-52 overflow-auto text-sm">
          {results.map((p) => (
            <li
              key={p.id}
              className="px-3 py-2 cursor-pointer hover:bg-muted flex justify-between items-baseline gap-2"
              onMouseDown={() => handleSelect(p)}
            >
              <span className="font-medium truncate">{p.name}</span>
              <span className="text-xs text-muted-foreground shrink-0">{p.sku} · GST {p.gst_rate}%</span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

// ── Main Component ────────────────────────────────────────────────────────────

export default function CreateInvoiceModal({ onClose, onCreated }: Props) {
  const { token, orgId, branches, branchId } = useOrgBranch();

  // Header fields
  const [customerId,   setCustomerId]   = useState("");
  const [branchSel,    setBranchSel]    = useState(branchId || "");
  const [invoiceDate,  setInvoiceDate]  = useState(today());
  const [notes,        setNotes]        = useState("");
  const [customers,    setCustomers]    = useState<Customer[]>([]);

  // Lines
  const [lines, setLines] = useState<LineItem[]>([blankLine()]);

  // UI state
  const [saving, setSaving] = useState(false);
  const [error,  setError]  = useState<string | null>(null);

  // Fetch customers on open
  useEffect(() => {
    if (!token || !orgId) return;
    fetch("/api/v1/customers?per_page=200&status=active", {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then((r) => r.json())
      .then((j) => setCustomers(j.data ?? []));
  }, [token, orgId]);

  // Fetch effective price for a single line and update state
  const fetchPrice = useCallback(
    async (lineKey: number, productId: number, branch: string, customer: string) => {
      if (!branch) return;
      const qs = new URLSearchParams({ branch_id: branch });
      if (customer) qs.set("retailer_id", customer);
      try {
        const res = await fetch(`/api/v1/products/${productId}/price?${qs}`, {
          headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId! },
        });
        if (res.ok) {
          const j = await res.json();
          const up   = j.data?.unit_price;
          const disc = j.data?.discount_pct;
          setLines((prev) =>
            prev.map((l) =>
              l.key !== lineKey
                ? l
                : {
                    ...l,
                    unit_price:   up   != null ? String(up)   : l.unit_price,
                    discount_pct: disc != null ? String(disc) : l.discount_pct,
                  }
            )
          );
        }
      } catch {
        // price fetch failed — user can enter manually
      }
    },
    [token, orgId]
  );

  // When branch or customer changes, re-fetch prices for all lines that already have a product
  useEffect(() => {
    if (!branchSel) return;
    setLines((prev) => {
      prev.forEach((l) => {
        if (l.product_id) fetchPrice(l.key, Number(l.product_id), branchSel, customerId);
      });
      return prev; // no structural change — price updates come via fetchPrice's own setLines
    });
  }, [branchSel, customerId, fetchPrice]);

  // When a product is selected in a line, fill meta immediately then fetch price
  const handleProductSelect = useCallback(
    (lineKey: number, product: ProductOption) => {
      // Immediately fill product meta
      setLines((prev) =>
        prev.map((l) =>
          l.key !== lineKey
            ? l
            : {
                ...l,
                product_id:   String(product.id),
                product_name: product.name,
                hsn_code:     product.hsn?.code ?? "",
                gst_rate:     String(product.gst_rate ?? 0),
                // clear stale price so the user sees it's being resolved
                unit_price:   "",
                discount_pct: "0",
              }
        )
      );
      // Fetch effective price (uses current branchSel / customerId at call time)
      fetchPrice(lineKey, product.id, branchSel, customerId);
    },
    [branchSel, customerId, fetchPrice]
  );

  const updateLine = (key: number, field: keyof LineItem, val: string) =>
    setLines((prev) => prev.map((l) => (l.key === key ? { ...l, [field]: val } : l)));

  const addLine = () => setLines((prev) => [...prev, blankLine()]);
  const removeLine = (key: number) =>
    setLines((prev) => (prev.length > 1 ? prev.filter((l) => l.key !== key) : prev));

  // Totals
  const totals = lines.reduce(
    (acc, l) => {
      const { taxable, tax, total } = calcLine(l);
      return { subtotal: acc.subtotal + taxable, tax: acc.tax + tax, grand: acc.grand + total };
    },
    { subtotal: 0, tax: 0, grand: 0 }
  );

  const handleSubmit = async () => {
    if (!customerId || !branchSel || !invoiceDate) {
      setError("Customer, branch, and invoice date are required.");
      return;
    }
    const validLines = lines.filter((l) => l.product_id && parseFloat(l.qty) > 0);
    if (validLines.length === 0) {
      setError("Add at least one line item with a product and quantity.");
      return;
    }
    setSaving(true);
    setError(null);
    try {
      const res = await fetch("/api/v1/sales_invoices", {
        method:  "POST",
        headers: {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId!,
          "Content-Type":      "application/json",
        },
        body: JSON.stringify({
          customer_id:        Number(customerId),
          branch_id:          Number(branchSel),
          invoice_date:       invoiceDate,
          generation_source:  "manual_direct",
          notes:              notes || null,
          delivered_lines:    validLines.map((l) => ({
            product_id:   Number(l.product_id),
            qty:          parseFloat(l.qty),
            unit_price:   parseFloat(l.unit_price),
            discount_pct: parseFloat(l.discount_pct) || 0,
            hsn_code:     l.hsn_code || null,
            gst_rate:     parseFloat(l.gst_rate) || 0,
          })),
        }),
      });
      const json = await res.json();
      if (res.ok) {
        onCreated(json.data?.id);
      } else {
        setError(json.errors?.join(", ") ?? "Failed to create invoice");
      }
    } finally {
      setSaving(false);
    }
  };

  return (
    <Modal
      open
      onClose={onClose}
      title="New Sales Invoice"
      size="xl"
      className="max-w-4xl max-h-[90vh] overflow-hidden flex flex-col"
    >
      <div className="flex-1 overflow-y-auto -mx-6 px-6 space-y-5 pb-2">

        {/* ── Header fields ── */}
        <div className="grid grid-cols-2 gap-4">
          {/* Customer */}
          <div className="space-y-1">
            <label className="text-sm font-medium">Customer <span className="text-red-500">*</span></label>
            <select
              className="w-full rounded border border-input px-3 py-2 text-sm bg-background focus:outline-none focus:ring-1 focus:ring-ring"
              value={customerId}
              onChange={(e) => setCustomerId(e.target.value)}
            >
              <option value="">Select customer…</option>
              {customers.map((c) => (
                <option key={c.id} value={c.id}>{c.name} ({c.code})</option>
              ))}
            </select>
          </div>

          {/* Branch */}
          <div className="space-y-1">
            <label className="text-sm font-medium">Branch <span className="text-red-500">*</span></label>
            <select
              className="w-full rounded border border-input px-3 py-2 text-sm bg-background focus:outline-none focus:ring-1 focus:ring-ring"
              value={branchSel}
              onChange={(e) => setBranchSel(e.target.value)}
            >
              <option value="">Select branch…</option>
              {branches.map((b) => (
                <option key={b.id} value={b.id}>{b.name} ({b.code})</option>
              ))}
            </select>
          </div>

          {/* Invoice date */}
          <div className="space-y-1">
            <label className="text-sm font-medium">Invoice Date <span className="text-red-500">*</span></label>
            <Input
              type="date"
              value={invoiceDate}
              onChange={(e) => setInvoiceDate(e.target.value)}
            />
          </div>

          {/* Notes */}
          <div className="space-y-1">
            <label className="text-sm font-medium">Notes</label>
            <Input
              placeholder="Optional notes…"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
            />
          </div>
        </div>

        {/* ── Line items ── */}
        <div>
          <div className="flex items-center justify-between mb-2">
            <h3 className="text-sm font-semibold">Line Items</h3>
            <Button size="sm" variant="outline" onClick={addLine}>
              <Plus className="h-3.5 w-3.5 mr-1" />
              Add Line
            </Button>
          </div>

          {/* Table header */}
          <div className="grid grid-cols-[2fr_1fr_1fr_1fr_1fr_1fr_auto] gap-2 px-2 py-1.5 bg-muted rounded-t-md text-xs font-semibold text-muted-foreground">
            <span>Product</span>
            <span>Qty</span>
            <span>Unit Price</span>
            <span>Disc %</span>
            <span>GST %</span>
            <span className="text-right">Total</span>
            <span />
          </div>

          {/* Lines */}
          <div className="border border-t-0 rounded-b-md divide-y">
            {lines.map((line) => {
              const { total } = calcLine(line);
              return (
                <div
                  key={line.key}
                  className="grid grid-cols-[2fr_1fr_1fr_1fr_1fr_1fr_auto] gap-2 px-2 py-2 items-center"
                >
                  {/* Product search */}
                  <ProductSearch
                    token={token}
                    orgId={orgId}
                    value={line.product_name}
                    onSelect={(p) => handleProductSelect(line.key, p)}
                  />

                  {/* Qty */}
                  <input
                    type="number"
                    min="0"
                    step="any"
                    className="w-full px-2 py-1.5 text-sm rounded border border-input bg-background focus:outline-none focus:ring-1 focus:ring-ring"
                    placeholder="0"
                    value={line.qty}
                    onChange={(e) => updateLine(line.key, "qty", e.target.value)}
                  />

                  {/* Unit price */}
                  <input
                    type="number"
                    min="0"
                    step="any"
                    className="w-full px-2 py-1.5 text-sm rounded border border-input bg-background focus:outline-none focus:ring-1 focus:ring-ring"
                    placeholder="0.00"
                    value={line.unit_price}
                    onChange={(e) => updateLine(line.key, "unit_price", e.target.value)}
                  />

                  {/* Discount % */}
                  <input
                    type="number"
                    min="0"
                    max="100"
                    step="any"
                    className="w-full px-2 py-1.5 text-sm rounded border border-input bg-background focus:outline-none focus:ring-1 focus:ring-ring"
                    placeholder="0"
                    value={line.discount_pct}
                    onChange={(e) => updateLine(line.key, "discount_pct", e.target.value)}
                  />

                  {/* GST % (auto-filled, editable) */}
                  <input
                    type="number"
                    min="0"
                    step="any"
                    className="w-full px-2 py-1.5 text-sm rounded border border-input bg-background focus:outline-none focus:ring-1 focus:ring-ring"
                    placeholder="0"
                    value={line.gst_rate}
                    onChange={(e) => updateLine(line.key, "gst_rate", e.target.value)}
                  />

                  {/* Line total */}
                  <span className="text-right text-sm font-semibold tabular-nums">
                    {total > 0 ? fmtINR(total) : "—"}
                  </span>

                  {/* Remove */}
                  <button
                    type="button"
                    onClick={() => removeLine(line.key)}
                    className="text-muted-foreground hover:text-destructive transition-colors"
                    aria-label="Remove line"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
              );
            })}
          </div>
        </div>

        {/* ── Totals ── */}
        <div className="flex justify-end">
          <div className="w-64 space-y-1 text-sm">
            <div className="flex justify-between text-muted-foreground">
              <span>Subtotal (taxable)</span>
              <span className="tabular-nums">{fmtINR(totals.subtotal)}</span>
            </div>
            <div className="flex justify-between text-muted-foreground">
              <span>Total GST</span>
              <span className="tabular-nums">{fmtINR(totals.tax)}</span>
            </div>
            <div className="flex justify-between font-semibold text-base border-t pt-1 mt-1">
              <span>Grand Total</span>
              <span className="tabular-nums">{fmtINR(totals.grand)}</span>
            </div>
          </div>
        </div>

        {/* Error */}
        {error && (
          <p className="text-sm text-destructive bg-destructive/10 rounded px-3 py-2">{error}</p>
        )}
      </div>

      {/* ── Footer ── */}
      <div className="flex justify-end gap-2 pt-4 border-t mt-4">
        <Button variant="outline" size="sm" onClick={onClose} disabled={saving}>
          Cancel
        </Button>
        <Button size="sm" onClick={handleSubmit} disabled={saving}>
          {saving ? (
            <>
              <Loader2 className="h-4 w-4 mr-1 animate-spin" />
              Creating…
            </>
          ) : (
            "Create Invoice"
          )}
        </Button>
      </div>
    </Modal>
  );
}
