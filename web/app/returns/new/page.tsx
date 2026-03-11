"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";

import { Button } from "@/components/ui/button";
import { useOrgBranch } from "@/lib/org-branch-context";
import { Plus, Trash2 } from "lucide-react";
import { ANALYTICS_EVENTS, trackBusinessEvent } from "@/lib/analytics";

interface Branch   { id: number; name: string }
interface Customer { id: number; name: string; code: string }
interface Product  { id: number; name: string; sku: string; gst_rate: number; hsn_code: string; base_price?: number }

interface ReturnLine {
  product_id:          number | null;
  product_name:        string;
  product_sku:         string;
  qty_reported:        string;
  condition_reported:  string;
  reason_code:         string;
  unit_price_snapshot: string;
  gst_rate_snapshot:   string;
  hsn_code_snapshot:   string;
}

const EMPTY_LINE: ReturnLine = {
  product_id:          null,
  product_name:        "",
  product_sku:         "",
  qty_reported:        "",
  condition_reported:  "unknown",
  reason_code:         "other",
  unit_price_snapshot: "",
  gst_rate_snapshot:   "",
  hsn_code_snapshot:   "",
};

const CONDITIONS = ["resalable", "damaged", "expired", "unknown"];
const REASON_CODES = ["customer_refused", "quality_issue", "expired", "short_supply", "other"];

export default function NewReturnPage() {
  const router = useRouter();
  const { token, orgId, branchId } = useOrgBranch();

  const [branches, setBranches]   = useState<Branch[]>([]);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [lines, setLines]         = useState<ReturnLine[]>([{ ...EMPTY_LINE }]);
  const [productSearch, setProductSearch] = useState<Record<number, string>>({});
  const [productResults, setProductResults] = useState<Record<number, Product[]>>({});

  const [formData, setFormData] = useState({
    branch_id:   branchId || "",
    customer_id: "",
    source_type: "manual",
    source_id:   "",
    return_date: new Date().toISOString().split("T")[0],
    notes:       "",
  });

  const [submitting, setSubmitting] = useState(false);
  const [error, setError]           = useState<string | null>(null);

  // ── Fetch branches + customers ───────────────────────────────────────────
  useEffect(() => {
    if (!token || !orgId) return;
    const headers = { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId };

    fetch("/api/v1/branches", { headers })
      .then((r) => r.json())
      .then((b) => setBranches(b.data ?? []));

    fetch("/api/v1/customers?per_page=500", { headers })
      .then((r) => r.json())
      .then((b) => setCustomers(b.data ?? []));
  }, [token, orgId]);

  // ── Product search debounce ──────────────────────────────────────────────
  const searchProduct = useCallback(
    async (lineIdx: number, query: string) => {
      if (!token || !orgId || query.length < 2) {
        setProductResults((prev) => ({ ...prev, [lineIdx]: [] }));
        return;
      }
      const res = await fetch(`/api/v1/products?q=${encodeURIComponent(query)}&per_page=10`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const body = await res.json();
      setProductResults((prev) => ({ ...prev, [lineIdx]: body.data ?? [] }));
    },
    [token, orgId]
  );

  const handleProductSearchChange = (lineIdx: number, value: string) => {
    setProductSearch((prev) => ({ ...prev, [lineIdx]: value }));
    if (value.length >= 2) searchProduct(lineIdx, value);
    else setProductResults((prev) => ({ ...prev, [lineIdx]: [] }));
  };

  const selectProduct = (lineIdx: number, product: Product) => {
    const updated = [...lines];
    updated[lineIdx] = {
      ...updated[lineIdx],
      product_id:          product.id,
      product_name:        product.name,
      product_sku:         product.sku,
      gst_rate_snapshot:   String(product.gst_rate ?? ""),
      hsn_code_snapshot:   product.hsn_code ?? "",
      unit_price_snapshot: String(product.base_price ?? ""),
    };
    setLines(updated);
    setProductSearch((prev) => ({ ...prev, [lineIdx]: `${product.sku} — ${product.name}` }));
    setProductResults((prev) => ({ ...prev, [lineIdx]: [] }));
  };

  const updateLine = (idx: number, field: keyof ReturnLine, value: string) => {
    const updated = [...lines];
    updated[idx] = { ...updated[idx], [field]: value };
    setLines(updated);
  };

  const addLine    = () => setLines([...lines, { ...EMPTY_LINE }]);
  const removeLine = (idx: number) => setLines(lines.filter((_, i) => i !== idx));

  // ── Submit ───────────────────────────────────────────────────────────────
  const handleSaveDraft = async () => {
    setError(null);
    if (!formData.customer_id) { setError("Please select a customer"); return; }
    if (lines.some((l) => !l.product_id)) { setError("All lines need a product selected"); return; }

    setSubmitting(true);
    try {
      const payload = {
        return_request: {
          ...formData,
          lines: lines.map((l) => ({
            product_id:          l.product_id,
            qty_reported:        parseFloat(l.qty_reported) || 0,
            condition_reported:  l.condition_reported,
            reason_code:         l.reason_code,
            unit_price_snapshot: l.unit_price_snapshot ? parseFloat(l.unit_price_snapshot) : null,
            gst_rate_snapshot:   l.gst_rate_snapshot   ? parseFloat(l.gst_rate_snapshot)   : null,
            hsn_code_snapshot:   l.hsn_code_snapshot   || null,
          })),
        },
      };

      const res = await fetch("/api/v1/return_requests", {
        method:  "POST",
        headers: {
          "Content-Type":   "application/json",
          Authorization:    `Bearer ${token}`,
          "X-Organization-Id": orgId!,
        },
        body: JSON.stringify(payload),
      });

      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "Failed to create return");
      trackBusinessEvent(ANALYTICS_EVENTS.RETURN_CREATED, { module: "dispatch", page: "/returns/new" });
      router.push(`/returns/${body.data.id}`);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "An error occurred");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <AppShell breadcrumbs={[
      { label: "Returns", href: "/returns" },
      { label: "New Return" },
    ]}>
      <div className="max-w-4xl space-y-6">

        <PageHeader
          title="New Return"
          description="Create a return request from a customer"
        />

        {error && (
          <div className="bg-danger/5 border border-danger/20 text-danger rounded-md px-4 py-3 text-sm">
            {error}
          </div>
        )}

        {/* ── Header Fields ── */}
        <div className="bg-white border rounded-lg p-6 space-y-4">
          <h3 className="font-semibold text-text-primary">Return Details</h3>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-text-secondary mb-1">Branch</label>
              <select
                value={formData.branch_id}
                onChange={(e) => setFormData({ ...formData, branch_id: e.target.value })}
                className="w-full border rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
              >
                <option value="">Select branch…</option>
                {branches.map((b) => (
                  <option key={b.id} value={b.id}>{b.name}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-text-secondary mb-1">Customer *</label>
              <select
                value={formData.customer_id}
                onChange={(e) => setFormData({ ...formData, customer_id: e.target.value })}
                className="w-full border rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
              >
                <option value="">Select customer…</option>
                {customers.map((c) => (
                  <option key={c.id} value={c.id}>{c.name} ({c.code})</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-text-secondary mb-1">Source Type</label>
              <select
                value={formData.source_type}
                onChange={(e) => setFormData({ ...formData, source_type: e.target.value })}
                className="w-full border rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
              >
                <option value="manual">Manual</option>
                <option value="order">Sales Order</option>
                <option value="delivery">Delivery Stop</option>
              </select>
            </div>

            {formData.source_type !== "manual" && (
              <div>
                <label className="block text-sm font-medium text-text-secondary mb-1">
                  {formData.source_type === "order" ? "Sales Order ID" : "Delivery Stop ID"}
                </label>
                <input
                  type="text"
                  value={formData.source_id}
                  onChange={(e) => setFormData({ ...formData, source_id: e.target.value })}
                  placeholder="Enter ID…"
                  className="w-full border rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                />
              </div>
            )}

            <div>
              <label className="block text-sm font-medium text-text-secondary mb-1">Return Date</label>
              <input
                type="date"
                value={formData.return_date}
                onChange={(e) => setFormData({ ...formData, return_date: e.target.value })}
                className="w-full border rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
              />
            </div>

            <div className="md:col-span-2">
              <label className="block text-sm font-medium text-text-secondary mb-1">Notes</label>
              <textarea
                value={formData.notes}
                onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
                rows={2}
                placeholder="Optional notes…"
                className="w-full border rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
              />
            </div>
          </div>
        </div>

        {/* ── Lines ── */}
        <div className="bg-white border rounded-lg p-6 space-y-4">
          <div className="flex justify-between items-center">
            <h3 className="font-semibold text-text-primary">Return Items</h3>
            <Button variant="outline" size="sm" onClick={addLine}>
              <Plus className="w-4 h-4 mr-1" /> Add Item
            </Button>
          </div>

          {lines.map((line, idx) => (
            <div key={idx} className="border rounded-md p-4 space-y-3 bg-background-subtle">
              <div className="flex justify-between items-start">
                <span className="text-sm font-medium text-text-secondary">Item {idx + 1}</span>
                {lines.length > 1 && (
                  <button
                    onClick={() => removeLine(idx)}
                    className="text-danger hover:text-danger/80"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                )}
              </div>

              {/* Product search */}
              <div className="relative">
                <label className="block text-xs font-medium text-text-secondary mb-1">Product *</label>
                <input
                  type="text"
                  value={productSearch[idx] ?? ""}
                  onChange={(e) => handleProductSearchChange(idx, e.target.value)}
                  placeholder="Search by SKU or name (min 2 chars)…"
                  className="w-full border rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                />
                {(productResults[idx] ?? []).length > 0 && (
                  <div className="absolute z-20 top-full left-0 right-0 bg-white border rounded-md shadow-lg mt-1 max-h-48 overflow-y-auto">
                    {productResults[idx].map((p) => (
                      <button
                        key={p.id}
                        className="w-full text-left px-3 py-2 text-sm hover:bg-background-subtle"
                        onClick={() => selectProduct(idx, p)}
                      >
                        <span className="font-mono text-xs text-text-secondary mr-2">{p.sku}</span>
                        {p.name}
                      </button>
                    ))}
                  </div>
                )}
              </div>

              <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                <div>
                  <label className="block text-xs font-medium text-text-secondary mb-1">Qty Returned *</label>
                  <input
                    type="number"
                    min="0"
                    step="0.001"
                    value={line.qty_reported}
                    onChange={(e) => updateLine(idx, "qty_reported", e.target.value)}
                    className="w-full border rounded-md px-3 py-1.5 text-sm"
                  />
                </div>

                <div>
                  <label className="block text-xs font-medium text-text-secondary mb-1">Condition</label>
                  <select
                    value={line.condition_reported}
                    onChange={(e) => updateLine(idx, "condition_reported", e.target.value)}
                    className="w-full border rounded-md px-2 py-1.5 text-sm"
                  >
                    {CONDITIONS.map((c) => (
                      <option key={c} value={c}>{c}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-medium text-text-secondary mb-1">Reason</label>
                  <select
                    value={line.reason_code}
                    onChange={(e) => updateLine(idx, "reason_code", e.target.value)}
                    className="w-full border rounded-md px-2 py-1.5 text-sm"
                  >
                    {REASON_CODES.map((r) => (
                      <option key={r} value={r}>{r.replace(/_/g, " ")}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-medium text-text-secondary mb-1">Unit Price</label>
                  <input
                    type="number"
                    min="0"
                    step="0.01"
                    value={line.unit_price_snapshot}
                    onChange={(e) => updateLine(idx, "unit_price_snapshot", e.target.value)}
                    placeholder="0.00"
                    className="w-full border rounded-md px-3 py-1.5 text-sm"
                  />
                </div>
              </div>
            </div>
          ))}
        </div>

        {/* ── Actions ── */}
        <div className="flex justify-end gap-3 pt-2">
          <Button variant="outline" onClick={() => router.push("/returns")}>
            Cancel
          </Button>
          <Button variant="default" onClick={handleSaveDraft} disabled={submitting}>
            {submitting ? "Saving…" : "Save Draft"}
          </Button>
        </div>
      </div>
    </AppShell>
  );
}
