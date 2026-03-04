"use client";

import { useState, useEffect, useCallback } from "react";
import { ChevronDown, ChevronUp, Wand2, Search, X, CheckCircle, AlertTriangle } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

// ─── Types ────────────────────────────────────────────────────────────────────
export interface ProductCategory { id: number; name: string; }
export interface UnitsOfMeasure   { id: number; name: string; symbol: string; }
export interface HsnSacCode {
  id: number; code: string; code_type: string; description: string; gst_rate: number;
}

export interface ProductFormData {
  sku:                  string;
  name:                 string;
  product_category_id:  string;
  units_of_measure_id:  string;   // plural — matches DB column / controller permitted params
  hsn_sac_code_id:      string;
  gst_rate:             string;
  min_order_qty:        string;
  purchase_price:       string;
  barcode:              string;
  weight_kg:            string;
  description:          string;
  image_url:            string;
  status:               string;
}

interface Props {
  initialData?:          Partial<ProductFormData>;
  initialHsn?:           HsnSacCode | null;
  categories:            ProductCategory[];
  uoms:                  UnitsOfMeasure[];
  loading:               boolean;
  errors:                string[];
  token:                 string | null;
  orgId:                 string | null;
  purchasePriceVisible?: boolean;
  onSubmit:              (data: ProductFormData) => void;
  onCancel:              () => void;
  onGenerateSku?:        () => Promise<string>;
  onCategoryCreated?:    (cat: ProductCategory) => void;
  onUomCreated?:         (uom: UnitsOfMeasure)  => void;
  submitLabel?:          string;
}

// ─── Shared style tokens ──────────────────────────────────────────────────────
const SELECT_CLS =
  "w-full px-3 py-2 text-sm border border-border rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary";
const LABEL_CLS = "text-sm font-medium text-text-primary mb-1 block";

// ─── HsnLookup ────────────────────────────────────────────────────────────────
function HsnLookup({
  token, orgId,
  selectedHsn, setSelectedHsn,
  onGstFill,
}: {
  token:          string | null;
  orgId:          string | null;
  selectedHsn:    HsnSacCode | null;
  setSelectedHsn: (hsn: HsnSacCode | null) => void;
  onGstFill:      (rate: number) => void;
}) {
  const [query,     setQuery]     = useState(selectedHsn?.code ?? "");
  const [results,   setResults]   = useState<HsnSacCode[]>([]);
  const [open,      setOpen]      = useState(false);
  const [searching, setSearching] = useState(false);

  const search = useCallback(async (q: string) => {
    if (!token || !orgId || q.trim().length < 2) { setResults([]); return; }
    setSearching(true);
    try {
      const res  = await fetch(
        `http://localhost:3001/api/v1/hsn_sac_codes?q=${encodeURIComponent(q)}&per_page=10`,
        { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId } },
      );
      const json = await res.json();
      if (res.ok) setResults(json.data ?? []);
    } finally {
      setSearching(false);
    }
  }, [token, orgId]);

  useEffect(() => {
    const t = setTimeout(() => search(query), 300);
    return () => clearTimeout(t);
  }, [query, search]);

  const pick = (hsn: HsnSacCode) => {
    setSelectedHsn(hsn);
    setQuery(hsn.code);
    setOpen(false);
    onGstFill(hsn.gst_rate);
  };

  const clear = () => {
    setSelectedHsn(null);
    setQuery("");
    setResults([]);
  };

  return (
    <div className="relative">
      <div className="flex gap-2">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary" />
          <input
            value={query}
            onChange={(e) => { setQuery(e.target.value); setOpen(true); }}
            onFocus={() => query.length >= 2 && setOpen(true)}
            onBlur={() => setTimeout(() => setOpen(false), 150)}
            placeholder="Search by HSN/SAC code or description…"
            className="w-full pl-9 pr-3 py-2 text-sm border border-border rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
          />
        </div>
        {selectedHsn && (
          <button type="button" onClick={clear} className="p-2 text-text-secondary hover:text-danger">
            <X className="h-4 w-4" />
          </button>
        )}
      </div>

      {selectedHsn && (
        <div className="mt-1.5 flex items-center gap-2 flex-wrap">
          <CheckCircle className="h-3.5 w-3.5 text-accent shrink-0" />
          <span className="text-xs text-text-secondary truncate max-w-xs">{selectedHsn.description}</span>
          <Badge variant="success" className="text-xs shrink-0">Auto from HSN master</Badge>
          <Badge variant="outline" className="text-xs shrink-0">{selectedHsn.code_type}</Badge>
        </div>
      )}

      {open && results.length > 0 && (
        <ul className="absolute z-50 mt-1 w-full rounded-md border border-border bg-white shadow-lg max-h-60 overflow-auto text-sm">
          {results.map((h) => (
            <li
              key={h.id}
              onMouseDown={() => pick(h)}
              className="flex items-start justify-between px-3 py-2.5 cursor-pointer hover:bg-background-subtle gap-3"
            >
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-0.5">
                  <span className="font-medium text-text-primary">{h.code}</span>
                  <span className="text-xs rounded-full px-1.5 py-0.5 bg-secondary/10 text-secondary font-medium">
                    {h.code_type}
                  </span>
                </div>
                <p className="text-xs text-text-secondary truncate">{h.description}</p>
              </div>
              <span className="shrink-0 text-xs font-medium bg-background-subtle px-2 py-0.5 rounded-md text-text-primary whitespace-nowrap">
                GST {h.gst_rate}%
              </span>
            </li>
          ))}
        </ul>
      )}

      {open && !searching && results.length === 0 && query.length >= 2 && (
        <div className="absolute z-50 mt-1 w-full text-xs text-text-secondary bg-white border border-border rounded-md px-3 py-2.5 shadow flex items-start gap-1.5">
          <AlertTriangle className="h-3.5 w-3.5 text-warning shrink-0 mt-0.5" />
          <span>No codes found — you can still enter the code manually and set the GST rate below.</span>
        </div>
      )}
    </div>
  );
}

// ─── CategorySelect ─────────────────────────────────────────────────────────
function CategorySelect({
  categories, value, onChange, token, orgId, onCreated, selectCls,
}: {
  categories: ProductCategory[];
  value:      string;
  onChange:   (id: string) => void;
  token:      string | null;
  orgId:      string | null;
  onCreated?: (cat: ProductCategory) => void;
  selectCls:  string;
}) {
  const [adding,  setAdding]  = useState(false);
  const [newName, setNewName] = useState("");
  const [saving,  setSaving]  = useState(false);
  const [error,   setError]   = useState("");

  const handleCreate = async () => {
    if (!newName.trim() || !token || !orgId) return;
    setSaving(true); setError("");
    try {
      const res  = await fetch("http://localhost:3001/api/v1/product_categories", {
        method:  "POST",
        headers: {
          "Content-Type":      "application/json",
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify({ product_category: { name: newName.trim() } }),
      });
      const json = await res.json();
      if (res.ok) {
        onCreated?.(json.data);
        onChange(String(json.data.id));
        setNewName(""); setAdding(false);
      } else {
        setError((json.errors ?? ["Failed to create category"]).join(", "));
      }
    } finally { setSaving(false); }
  };

  return (
    <div>
      <select value={value} onChange={(e) => onChange(e.target.value)} required className={selectCls}>
        <option value="">Select category…</option>
        {categories.map((c) => (
          <option key={c.id} value={c.id}>{c.name}</option>
        ))}
      </select>
      {!adding ? (
        <button type="button" onClick={() => setAdding(true)}
          className="mt-1.5 text-xs text-primary hover:underline">+ New category</button>
      ) : (
        <div className="mt-2 space-y-1.5">
          <div className="flex gap-2">
            <Input value={newName} onChange={(e) => setNewName(e.target.value)}
              placeholder="Category name" className="flex-1 text-sm"
              onKeyDown={(e) => e.key === "Enter" && (e.preventDefault(), handleCreate())} />
            <Button type="button" size="sm" onClick={handleCreate} disabled={saving || !newName.trim()}>
              {saving ? "…" : "Add"}
            </Button>
            <Button type="button" size="sm" variant="outline"
              onClick={() => { setAdding(false); setNewName(""); setError(""); }}>Cancel</Button>
          </div>
          {error && <p className="text-xs text-danger">{error}</p>}
        </div>
      )}
    </div>
  );
}

// ─── UomSelect ────────────────────────────────────────────────────────────────
function UomSelect({
  uoms, value, onChange, token, orgId, onCreated, selectCls,
}: {
  uoms:       UnitsOfMeasure[];
  value:      string;
  onChange:   (id: string) => void;
  token:      string | null;
  orgId:      string | null;
  onCreated?: (uom: UnitsOfMeasure) => void;
  selectCls:  string;
}) {
  const [adding,    setAdding]    = useState(false);
  const [newName,   setNewName]   = useState("");
  const [newSymbol, setNewSymbol] = useState("");
  const [saving,    setSaving]    = useState(false);
  const [error,     setError]     = useState("");

  const handleCreate = async () => {
    if (!newName.trim() || !newSymbol.trim() || !token || !orgId) return;
    setSaving(true); setError("");
    try {
      const res  = await fetch("http://localhost:3001/api/v1/units_of_measure", {
        method:  "POST",
        headers: {
          "Content-Type":      "application/json",
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify({ units_of_measure: { name: newName.trim(), symbol: newSymbol.trim().toUpperCase(), active: true } }),
      });
      const json = await res.json();
      if (res.ok) {
        onCreated?.(json.data);
        onChange(String(json.data.id));
        setNewName(""); setNewSymbol(""); setAdding(false);
      } else {
        setError((json.errors ?? ["Failed to create unit"]).join(", "));
      }
    } finally { setSaving(false); }
  };

  return (
    <div>
      <select value={value} onChange={(e) => onChange(e.target.value)} required className={selectCls}>
        <option value="">Select UOM…</option>
        {uoms.map((u) => (
          <option key={u.id} value={u.id}>{u.name} ({u.symbol})</option>
        ))}
      </select>
      {!adding ? (
        <button type="button" onClick={() => setAdding(true)}
          className="mt-1.5 text-xs text-primary hover:underline">+ New unit</button>
      ) : (
        <div className="mt-2 space-y-1.5">
          <div className="flex gap-2">
            <Input value={newName} onChange={(e) => setNewName(e.target.value)}
              placeholder="Name (e.g. Pieces)" className="flex-1 text-sm" />
            <Input value={newSymbol} onChange={(e) => setNewSymbol(e.target.value)}
              placeholder="Symbol (PCS)" className="w-28 text-sm" />
            <Button type="button" size="sm" onClick={handleCreate}
              disabled={saving || !newName.trim() || !newSymbol.trim()}>
              {saving ? "…" : "Add"}
            </Button>
            <Button type="button" size="sm" variant="outline"
              onClick={() => { setAdding(false); setNewName(""); setNewSymbol(""); setError(""); }}>Cancel</Button>
          </div>
          {error && <p className="text-xs text-danger">{error}</p>}
        </div>
      )}
    </div>
  );
}

// ─── ProductForm ──────────────────────────────────────────────────────────────
export function ProductForm({
  initialData, initialHsn = null, categories, uoms, loading, errors,
  token, orgId, purchasePriceVisible = true,
  onSubmit, onCancel, onGenerateSku, submitLabel = "Save Product",
  onCategoryCreated, onUomCreated,
}: Props) {
  const [form, setForm] = useState<ProductFormData>({
    sku:                  "",
    name:                 "",
    product_category_id:  "",
    units_of_measure_id:  "",
    hsn_sac_code_id:      "",
    gst_rate:             "",
    min_order_qty:        "1",
    purchase_price:       "",
    barcode:              "",
    weight_kg:            "",
    description:          "",
    image_url:            "",
    status:               "active",
    ...initialData,
  });

  const [selectedHsn,   setSelectedHsn]  = useState<HsnSacCode | null>(initialHsn);
  const [advancedOpen,  setAdvancedOpen]  = useState(false);
  const [skuGenerating, setSkuGenerating] = useState(false);

  const set = (field: keyof ProductFormData) =>
    (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) =>
      setForm((p) => ({ ...p, [field]: e.target.value }));

  const handleGstFill = (rate: number) =>
    setForm((p) => ({ ...p, gst_rate: String(rate) }));

  const handleHsnSelect = (hsn: HsnSacCode | null) => {
    setSelectedHsn(hsn);
    setForm((p) => ({
      ...p,
      hsn_sac_code_id: hsn ? String(hsn.id) : "",
      gst_rate:        hsn ? String(hsn.gst_rate) : "",
    }));
  };

  const handleGenerateSku = async () => {
    if (!onGenerateSku) return;
    setSkuGenerating(true);
    try {
      const sku = await onGenerateSku();
      setForm((p) => ({ ...p, sku }));
    } finally {
      setSkuGenerating(false);
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(form);
  };

  const hsnVerified = selectedHsn !== null;
  const canSubmit   = !loading && form.hsn_sac_code_id !== "" && form.name !== "" && form.sku !== "";

  return (
    <form onSubmit={handleSubmit} className="space-y-5">
      {errors.length > 0 && (
        <div className="rounded-md bg-danger/10 border border-danger/20 p-3">
          <ul className="space-y-1 text-sm text-danger list-disc list-inside">
            {errors.map((err, i) => <li key={i}>{err}</li>)}
          </ul>
        </div>
      )}

      {/* ── SECTION 1: Required fields ──────────────────────────────────── */}
      <div className="space-y-4">

        {/* Product Name */}
        <div>
          <label className={LABEL_CLS}>
            Product Name <span className="text-danger">*</span>
          </label>
          <Input
            value={form.name}
            onChange={set("name")}
            placeholder="e.g. Basmati Rice 5kg"
            required
          />
        </div>

        {/* SKU + Generate */}
        <div>
          <label className={LABEL_CLS}>
            SKU <span className="text-danger">*</span>
          </label>
          <div className="flex gap-2">
            <Input
              value={form.sku}
              onChange={set("sku")}
              placeholder="e.g. PROD-001"
              required
              className="flex-1"
            />
            {onGenerateSku && (
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={handleGenerateSku}
                disabled={skuGenerating}
                className="shrink-0"
              >
                <Wand2 className="h-3.5 w-3.5 mr-1.5" />
                {skuGenerating ? "…" : "Generate"}
              </Button>
            )}
          </div>
          <p className="mt-1 text-xs text-text-secondary">
            Uppercase letters, numbers, hyphens, underscores — max 50. Immutable after first order.
          </p>
        </div>

        {/* Category + UOM */}
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className={LABEL_CLS}>
              Category <span className="text-danger">*</span>
            </label>
            <CategorySelect
              categories={categories}
              value={form.product_category_id}
              onChange={(id) => setForm((p) => ({ ...p, product_category_id: id }))}
              token={token}
              orgId={orgId}
              onCreated={onCategoryCreated}
              selectCls={SELECT_CLS}
            />
          </div>
          <div>
            <label className={LABEL_CLS}>
              Unit of Measure <span className="text-danger">*</span>
            </label>
            <UomSelect
              uoms={uoms}
              value={form.units_of_measure_id}
              onChange={(id) => setForm((p) => ({ ...p, units_of_measure_id: id }))}
              token={token}
              orgId={orgId}
              onCreated={onUomCreated}
              selectCls={SELECT_CLS}
            />
          </div>
        </div>

        {/* HSN / SAC Code */}
        <div>
          <label className={LABEL_CLS}>
            HSN / SAC Code <span className="text-danger">*</span>
          </label>
          <HsnLookup
            token={token}
            orgId={orgId}
            selectedHsn={selectedHsn}
            setSelectedHsn={handleHsnSelect}
            onGstFill={handleGstFill}
          />
          {!form.hsn_sac_code_id && (
            <p className="mt-1 text-xs text-text-secondary">
              Search and select — GST rate auto-fills from master.
            </p>
          )}
        </div>

        {/* GST Rate + Status */}
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className={LABEL_CLS}>GST Rate (%)</label>
            {hsnVerified ? (
              <div className="flex items-center gap-2 h-10 px-3 rounded-md border border-border bg-background-subtle text-sm text-text-primary">
                <span className="font-medium">{form.gst_rate}%</span>
                <Badge variant="success" className="ml-auto text-xs">Auto from HSN</Badge>
              </div>
            ) : (
              <>
                <select value={form.gst_rate} onChange={set("gst_rate")} className={SELECT_CLS}>
                  <option value="">Select rate…</option>
                  {[0, 5, 12, 18, 28].map((r) => (
                    <option key={r} value={r}>{r}%</option>
                  ))}
                </select>
                {form.hsn_sac_code_id && (
                  <p className="mt-1 flex items-center gap-1 text-xs text-warning">
                    <AlertTriangle className="h-3 w-3 shrink-0" />
                    HSN not verified — rate must be set manually.
                  </p>
                )}
                {!form.hsn_sac_code_id && (
                  <p className="mt-1 text-xs text-text-secondary">Auto-fills when HSN code is selected.</p>
                )}
              </>
            )}
          </div>
          <div>
            <label className={LABEL_CLS}>Status</label>
            <select value={form.status} onChange={set("status")} className={SELECT_CLS}>
              <option value="active">Active</option>
              <option value="discontinued">Discontinued</option>
            </select>
          </div>
        </div>
      </div>

      {/* ── SECTION 2: Advanced (collapsible) ────────────────────────────── */}
      <div className="border border-border rounded-md overflow-hidden">
        <button
          type="button"
          onClick={() => setAdvancedOpen((p) => !p)}
          className="w-full flex items-center justify-between px-4 py-3 bg-background-subtle hover:bg-background text-sm font-medium text-text-primary transition-colors"
        >
          <span>
            Advanced Options{" "}
            <span className="font-normal text-text-secondary">(optional)</span>
          </span>
          {advancedOpen
            ? <ChevronUp className="h-4 w-4 text-text-secondary" />
            : <ChevronDown className="h-4 w-4 text-text-secondary" />}
        </button>

        {advancedOpen && (
          <div className="px-4 py-4 space-y-4 border-t border-border bg-white">

            {/* Min Order Qty + Purchase Price (role-gated) */}
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className={LABEL_CLS}>Min Order Qty</label>
                <Input type="number" min="1" value={form.min_order_qty} onChange={set("min_order_qty")} />
                <p className="mt-0.5 text-xs text-text-secondary">Default: 1</p>
              </div>
              {purchasePriceVisible && (
                <div>
                  <label className={LABEL_CLS}>Purchase Price (₹)</label>
                  <Input
                    type="number" min="0" step="0.01"
                    value={form.purchase_price}
                    onChange={set("purchase_price")}
                    placeholder="0.00"
                  />
                  <p className="mt-0.5 text-xs text-text-secondary">Owner / accounts only</p>
                </div>
              )}
            </div>

            {/* Barcode + Weight */}
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className={LABEL_CLS}>Barcode</label>
                <Input value={form.barcode} onChange={set("barcode")} placeholder="EAN / UPC barcode" />
              </div>
              <div>
                <label className={LABEL_CLS}>Weight (kg)</label>
                <Input
                  type="number" min="0" step="0.001"
                  value={form.weight_kg} onChange={set("weight_kg")} placeholder="0.000"
                />
              </div>
            </div>

            {/* Image URL */}
            <div>
              <label className={LABEL_CLS}>Image URL</label>
              <Input value={form.image_url} onChange={set("image_url")} placeholder="https://…" />
              <p className="mt-0.5 text-xs text-text-secondary">JPG / PNG direct URL (file upload coming soon)</p>
            </div>

            {/* Description */}
            <div>
              <label className={LABEL_CLS}>Description</label>
              <textarea
                value={form.description} onChange={set("description")}
                rows={3} placeholder="Optional product description…"
                className="w-full px-3 py-2 text-sm border border-border rounded-md bg-white resize-none focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
              />
            </div>
          </div>
        )}
      </div>

      {/* Actions */}
      <div className="flex items-center justify-end gap-3 pt-2 border-t border-border">
        <Button type="button" variant="outline" onClick={onCancel} disabled={loading}>
          Cancel
        </Button>
        <Button type="submit" disabled={!canSubmit}>
          {loading ? "Saving…" : submitLabel}
        </Button>
      </div>
    </form>
  );
}
