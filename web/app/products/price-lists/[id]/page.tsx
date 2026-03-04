"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { useRouter, useParams } from "next/navigation";
import { AppShell } from "@/components/layout";
import { Breadcrumb } from "@/components/ui/breadcrumb";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Modal } from "@/components/ui/modal";
import { Trash2, Plus, PackageSearch, X, Tag, Layers, IndianRupee, TrendingDown, ChevronDown, Pencil, AlertTriangle, Upload, Download, CheckCircle, FileWarning } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";

// ─── Types ────────────────────────────────────────────────────────────────────
interface PriceListItem {
  id:           number;
  product_id:   number;
  product_sku:  string;
  product_name: string;
  unit_price:   number;
  min_qty:      number;
  discount_pct: number;
}

interface PriceListDetail {
  id:          number;
  name:        string;
  list_type:   string;
  valid_from:  string | null;
  valid_to:    string | null;
  items_count: number;
  branch:      { id: number; name: string } | null;
  items:       PriceListItem[];
}

interface Product { id: number; sku: string; name: string; }

const TYPE_VARIANT: Record<string, "default" | "secondary" | "success" | "warning" | "outline"> = {
  standard: "default", promo: "warning", retailer_specific: "secondary", tier_specific: "outline",
};

// ─── Add Item Modal ───────────────────────────────────────────────────────────
function AddItemModal({
  open, priceListId, token, orgId,
  onClose, onAdded,
}: {
  open:        boolean;
  priceListId: number;
  token:       string | null;
  orgId:       string | null;
  onClose:     () => void;
  onAdded:     (item: PriceListItem) => void;
}) {
  const [allProducts, setAllProducts] = useState<Product[]>([]);
  const [search,      setSearch]      = useState("");
  const [dropOpen,    setDropOpen]    = useState(false);
  const [selected,    setSelected]    = useState<Product | null>(null);
  const [form,        setForm]        = useState({ unit_price: "", min_qty: "1", discount_pct: "0" });
  const [loading,     setLoading]     = useState(false);
  const [errors,      setErrors]      = useState<string[]>([]);
  const comboRef = useRef<HTMLDivElement>(null);

  // Load all active products once when modal opens
  useEffect(() => {
    if (!open || !token || !orgId) return;
    fetch(`http://localhost:3001/api/v1/products?per_page=200&status=active`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    }).then((r) => r.json()).then((j) => j.data && setAllProducts(j.data));
  }, [open, token, orgId]);

  // Reset on open
  useEffect(() => {
    if (open) {
      setSelected(null); setSearch(""); setDropOpen(false);
      setForm({ unit_price: "", min_qty: "1", discount_pct: "0" });
      setErrors([]);
    }
  }, [open]);

  // Close dropdown on outside click
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (comboRef.current && !comboRef.current.contains(e.target as Node))
        setDropOpen(false);
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, []);

  const filtered = allProducts.filter((p) =>
    !search || p.name.toLowerCase().includes(search.toLowerCase()) ||
    p.sku.toLowerCase().includes(search.toLowerCase())
  );

  const selectProduct = (p: Product) => {
    setSelected(p); setSearch(""); setDropOpen(false);
  };

  const setField = (field: string) =>
    (e: React.ChangeEvent<HTMLInputElement>) =>
      setForm((prev) => ({ ...prev, [field]: e.target.value }));

  const price    = parseFloat(form.unit_price) || 0;
  const disc     = parseFloat(form.discount_pct) || 0;
  const minQty   = parseFloat(form.min_qty) || 1;
  const effective = price * (1 - disc / 100);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!token || !orgId || !selected) return;
    setLoading(true); setErrors([]);
    try {
      const res = await fetch(`http://localhost:3001/api/v1/price_lists/${priceListId}/items`, {
        method:  "POST",
        headers: {
          "Content-Type":    "application/json",
          Authorization:     `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify({
          price_list_item: {
            product_id:   selected.id,
            unit_price:   form.unit_price,
            min_qty:      form.min_qty,
            discount_pct: form.discount_pct,
          },
        }),
      });
      const json = await res.json();
      if (res.ok) { onAdded(json.data); onClose(); }
      else        { setErrors(json.errors ?? ["Something went wrong"]); }
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal open={open} onClose={onClose} title="Add Product to Price List" size="md">
      <form onSubmit={handleSubmit} className="space-y-5">
        {errors.length > 0 && (
          <div className="rounded-md bg-danger/8 border border-danger/20 px-3 py-2.5 text-sm text-danger">
            {errors.join(", ")}
          </div>
        )}

        {/* ── Product combobox ── */}
        <div>
          <label className="text-sm font-medium text-text-primary mb-1.5 block">
            Product <span className="text-danger">*</span>
          </label>

          {selected ? (
            <div className="flex items-center gap-3 rounded-md border border-primary/40 bg-primary/5 px-3 py-2.5">
              <PackageSearch className="h-4 w-4 text-primary shrink-0" />
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-text-primary truncate">{selected.name}</p>
                <p className="text-xs text-text-secondary font-mono">{selected.sku}</p>
              </div>
              <button
                type="button"
                onClick={() => { setSelected(null); setSearch(""); }}
                className="p-1 rounded hover:bg-primary/10 text-text-secondary hover:text-danger transition-colors"
              >
                <X className="h-3.5 w-3.5" />
              </button>
            </div>
          ) : (
            <div ref={comboRef} className="relative">
              <div className="relative">
                <PackageSearch className="absolute left-2.5 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary pointer-events-none" />
                <input
                  placeholder="Search by name or SKU…"
                  value={search}
                  onChange={(e) => { setSearch(e.target.value); setDropOpen(true); }}
                  onFocus={() => setDropOpen(true)}
                  className="w-full pl-8 pr-8 py-2 text-sm border border-border rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
                />
                <ChevronDown className="absolute right-2.5 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary pointer-events-none" />
              </div>
              {dropOpen && (
                <div className="absolute z-50 mt-1 w-full rounded-md border border-border bg-white shadow-lg max-h-52 overflow-auto">
                  {filtered.length === 0 ? (
                    <div className="px-3 py-4 text-sm text-text-secondary text-center">No products found</div>
                  ) : (
                    filtered.map((p) => (
                      <button
                        key={p.id}
                        type="button"
                        onClick={() => selectProduct(p)}
                        className="w-full flex items-center gap-3 px-3 py-2.5 hover:bg-background-subtle text-left transition-colors"
                      >
                        <span className="font-mono text-xs bg-background-subtle text-text-secondary px-1.5 py-0.5 rounded shrink-0">
                          {p.sku}
                        </span>
                        <span className="text-sm text-text-primary truncate">{p.name}</span>
                      </button>
                    ))
                  )}
                </div>
              )}
            </div>
          )}
        </div>

        {/* ── Pricing fields ── */}
        <div className="grid grid-cols-3 gap-3">
          <div>
            <label className="text-sm font-medium text-text-primary mb-1 block flex items-center gap-1">
              <IndianRupee className="h-3.5 w-3.5" /> Unit Price *
            </label>
            <Input
              type="number" min="0" step="0.01"
              placeholder="0.00"
              value={form.unit_price}
              onChange={setField("unit_price")}
              required
            />
          </div>
          <div>
            <label className="text-sm font-medium text-text-primary mb-1 block flex items-center gap-1">
              <Layers className="h-3.5 w-3.5" /> Min Qty
            </label>
            <Input type="number" min="1" value={form.min_qty} onChange={setField("min_qty")} />
            <p className="mt-0.5 text-[11px] text-text-secondary">Leave 1 for base price</p>
          </div>
          <div>
            <label className="text-sm font-medium text-text-primary mb-1 block flex items-center gap-1">
              <TrendingDown className="h-3.5 w-3.5" /> Discount %
            </label>
            <Input type="number" min="0" max="100" step="0.1" value={form.discount_pct} onChange={setField("discount_pct")} />
          </div>
        </div>

        {/* ── Live effective price preview ── */}
        {price > 0 && (
          <div className="rounded-md border border-border bg-background-subtle px-4 py-3 flex items-center justify-between">
            <div className="text-sm text-text-secondary">
              {disc > 0
                ? <span>₹{price.toFixed(2)} <span className="text-success font-medium">− {disc}%</span></span>
                : <span>Base price</span>
              }
              {minQty > 1 && <span className="ml-2 text-xs">· applies from qty {minQty}</span>}
            </div>
            <div className="text-right">
              <span className="text-xs text-text-secondary">Effective price</span>
              <p className="text-base font-semibold text-text-primary">₹{effective.toFixed(2)}</p>
            </div>
          </div>
        )}

        <div className="flex justify-end gap-2 pt-1 border-t border-border">
          <Button type="button" variant="outline" onClick={onClose} disabled={loading}>Cancel</Button>
          <Button type="submit" disabled={loading || !selected}>
            {loading ? "Adding…" : "Add Item"}
          </Button>
        </div>
      </form>
    </Modal>
  );
}

// ─── Bulk Import Modal ─────────────────────────────────────────────────────────
function BulkImportModal({
  priceListId, token, orgId, onClose, onImported,
}: {
  priceListId: number;
  token:       string | null;
  orgId:       string | null;
  onClose:     () => void;
  onImported:  () => void;   // triggers a full reload of the price list
}) {
  const [file,    setFile]    = useState<File | null>(null);
  const [loading, setLoading] = useState(false);
  const [result,  setResult]  = useState<{
    imported_count: number;
    failed_count:   number;
    imported: { line: number; sku: string; action: string }[];
    failed:   { line: number; sku: string; error: string }[];
  } | null>(null);
  const [error, setError] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);

  const downloadSample = () => {
    if (!token || !orgId) return;
    const a = document.createElement("a");
    a.href = `http://localhost:3001/api/v1/price_lists/${priceListId}/items/sample_csv`;
    // Append token via query param won't work with Bearer — open as a fetch/blob instead
    fetch(a.href, { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId } })
      .then((r) => r.blob())
      .then((blob) => {
        const url = URL.createObjectURL(blob);
        a.href = url;
        a.download = `price_list_${priceListId}_sample.csv`;
        a.click();
        URL.revokeObjectURL(url);
      });
  };

  const handleUpload = async () => {
    if (!file || !token || !orgId) return;
    setLoading(true); setError(""); setResult(null);
    try {
      const fd = new FormData();
      fd.append("file", file);
      const res = await fetch(
        `http://localhost:3001/api/v1/price_lists/${priceListId}/items/bulk_import`,
        {
          method:  "POST",
          headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
          body:    fd,
        },
      );
      const json = await res.json();
      if (res.ok) setResult(json.data);
      else        setError(json.errors?.join(", ") ?? "Import failed");
    } catch {
      setError("Network error — please try again");
    } finally {
      setLoading(false);
    }
  };

  const handleDone = () => {
    if (result && result.imported_count > 0) onImported();
    onClose();
  };

  return (
    <Modal open onClose={onClose} title="Bulk Import Items" size="lg">
      <div className="space-y-5">

        {/* Instructions */}
        <div className="rounded-md border border-border bg-background-subtle px-4 py-3 text-sm text-text-secondary">
          <p className="font-medium text-text-primary mb-1">CSV format</p>
          <p>Required columns: <code className="font-mono text-xs bg-white border border-border rounded px-1">sku</code>, <code className="font-mono text-xs bg-white border border-border rounded px-1">unit_price</code></p>
          <p className="mt-0.5">Optional: <code className="font-mono text-xs bg-white border border-border rounded px-1">min_qty</code> (default 1), <code className="font-mono text-xs bg-white border border-border rounded px-1">discount_pct</code> (default 0)</p>
          <p className="mt-0.5 text-xs">Existing items for the same product + min_qty will be <span className="font-medium">updated</span>, not duplicated.</p>
        </div>

        {/* Sample CSV download */}
        <button
          type="button"
          onClick={downloadSample}
          className="inline-flex items-center gap-2 text-sm text-primary hover:underline"
        >
          <Download className="h-4 w-4" /> Download sample CSV
        </button>

        {/* File picker */}
        {!result && (
          <div>
            <div
              onClick={() => inputRef.current?.click()}
              className="flex flex-col items-center justify-center gap-2 rounded-lg border-2 border-dashed border-border bg-background-subtle hover:border-primary/50 hover:bg-primary/5 transition-colors cursor-pointer py-8"
            >
              <Upload className="h-7 w-7 text-text-secondary/60" />
              {file ? (
                <div className="text-center">
                  <p className="text-sm font-medium text-text-primary">{file.name}</p>
                  <p className="text-xs text-text-secondary">{(file.size / 1024).toFixed(1)} KB</p>
                </div>
              ) : (
                <div className="text-center">
                  <p className="text-sm text-text-primary">Click to select a CSV file</p>
                  <p className="text-xs text-text-secondary">.csv files only</p>
                </div>
              )}
            </div>
            <input
              ref={inputRef}
              type="file"
              accept=".csv,text/csv"
              className="hidden"
              onChange={(e) => { setFile(e.target.files?.[0] ?? null); setError(""); }}
            />
          </div>
        )}

        {/* Error */}
        {error && (
          <div className="flex items-start gap-2 rounded-md bg-danger/8 border border-danger/20 px-3 py-2.5 text-sm text-danger">
            <FileWarning className="h-4 w-4 shrink-0 mt-0.5" />
            {error}
          </div>
        )}

        {/* Results */}
        {result && (
          <div className="space-y-3">
            <div className="flex items-center gap-4">
              <div className="flex items-center gap-2 rounded-md bg-success/10 border border-success/20 px-3 py-2 text-sm">
                <CheckCircle className="h-4 w-4 text-success" />
                <span className="font-medium text-success">{result.imported_count} imported</span>
              </div>
              {result.failed_count > 0 && (
                <div className="flex items-center gap-2 rounded-md bg-danger/8 border border-danger/20 px-3 py-2 text-sm">
                  <FileWarning className="h-4 w-4 text-danger" />
                  <span className="font-medium text-danger">{result.failed_count} failed</span>
                </div>
              )}
            </div>

            {result.failed.length > 0 && (
              <div className="rounded-md border border-border overflow-auto max-h-44">
                <table className="w-full text-xs">
                  <thead className="bg-background-subtle">
                    <tr>
                      <th className="px-3 py-2 text-left font-semibold text-text-secondary">Line</th>
                      <th className="px-3 py-2 text-left font-semibold text-text-secondary">SKU</th>
                      <th className="px-3 py-2 text-left font-semibold text-text-secondary">Error</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border bg-white">
                    {result.failed.map((f) => (
                      <tr key={`${f.line}-${f.sku}`}>
                        <td className="px-3 py-1.5 tabular-nums text-text-secondary">{f.line}</td>
                        <td className="px-3 py-1.5 font-mono">{f.sku || "—"}</td>
                        <td className="px-3 py-1.5 text-danger">{f.error}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}

        {/* Actions */}
        <div className="flex justify-end gap-2 border-t border-border pt-3">
          {result ? (
            <Button onClick={handleDone}>Done</Button>
          ) : (
            <>
              <Button variant="outline" onClick={onClose} disabled={loading}>Cancel</Button>
              <Button onClick={handleUpload} disabled={!file || loading}>
                {loading ? (
                  <><span className="h-3.5 w-3.5 mr-2 animate-spin rounded-full border-2 border-white border-t-transparent inline-block" />Importing…</>
                ) : (
                  <><Upload className="h-4 w-4 mr-2" />Import CSV</>
                )}
              </Button>
            </>
          )}
        </div>
      </div>
    </Modal>
  );
}

// ─── Edit Item Modal ──────────────────────────────────────────────────────────
function EditItemModal({
  item, priceListId, token, orgId, onClose, onUpdated,
}: {
  item:        PriceListItem;
  priceListId: number;
  token:       string | null;
  orgId:       string | null;
  onClose:     () => void;
  onUpdated:   (updated: PriceListItem) => void;
}) {
  const [form, setForm] = useState({
    unit_price:   String(item.unit_price),
    min_qty:      String(item.min_qty),
    discount_pct: String(item.discount_pct),
  });
  const [loading, setLoading] = useState(false);
  const [errors,  setErrors]  = useState<string[]>([]);

  const setField = (field: string) =>
    (e: React.ChangeEvent<HTMLInputElement>) =>
      setForm((prev) => ({ ...prev, [field]: e.target.value }));

  const price     = parseFloat(form.unit_price)   || 0;
  const disc      = parseFloat(form.discount_pct) || 0;
  const minQty    = parseFloat(form.min_qty)      || 1;
  const effective = price * (1 - disc / 100);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!token || !orgId) return;
    setLoading(true); setErrors([]);
    try {
      const res = await fetch(
        `http://localhost:3001/api/v1/price_lists/${priceListId}/items/${item.id}`,
        {
          method:  "PATCH",
          headers: {
            "Content-Type":      "application/json",
            Authorization:       `Bearer ${token}`,
            "X-Organization-Id": orgId,
          },
          body: JSON.stringify({ price_list_item: form }),
        },
      );
      const json = await res.json();
      if (res.ok) { onUpdated(json.data); onClose(); }
      else        { setErrors(json.errors ?? ["Something went wrong"]); }
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal open onClose={onClose} title="Edit Price" size="md">
      <form onSubmit={handleSubmit} className="space-y-5">
        {errors.length > 0 && (
          <div className="rounded-md bg-danger/8 border border-danger/20 px-3 py-2.5 text-sm text-danger">
            {errors.join(", ")}
          </div>
        )}

        {/* Product info — read-only */}
        <div className="flex items-center gap-3 rounded-md border border-border bg-background-subtle px-3 py-2.5">
          <PackageSearch className="h-4 w-4 text-text-secondary shrink-0" />
          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium text-text-primary truncate">{item.product_name}</p>
            <p className="text-xs font-mono text-text-secondary">{item.product_sku}</p>
          </div>
        </div>

        {/* Pricing fields */}
        <div className="grid grid-cols-3 gap-3">
          <div>
            <label className="text-sm font-medium text-text-primary mb-1 block flex items-center gap-1">
              <IndianRupee className="h-3.5 w-3.5" /> Unit Price *
            </label>
            <Input
              type="number" min="0" step="0.01"
              value={form.unit_price}
              onChange={setField("unit_price")}
              required
            />
          </div>
          <div>
            <label className="text-sm font-medium text-text-primary mb-1 block flex items-center gap-1">
              <Layers className="h-3.5 w-3.5" /> Min Qty
            </label>
            <Input type="number" min="1" value={form.min_qty} onChange={setField("min_qty")} />
            <p className="mt-0.5 text-[11px] text-text-secondary">1 = base price</p>
          </div>
          <div>
            <label className="text-sm font-medium text-text-primary mb-1 block flex items-center gap-1">
              <TrendingDown className="h-3.5 w-3.5" /> Discount %
            </label>
            <Input type="number" min="0" max="100" step="0.1" value={form.discount_pct} onChange={setField("discount_pct")} />
          </div>
        </div>

        {/* Live effective price */}
        {price > 0 && (
          <div className="rounded-md border border-border bg-background-subtle px-4 py-3 flex items-center justify-between">
            <div className="text-sm text-text-secondary">
              {disc > 0
                ? <span>₹{price.toFixed(2)} <span className="text-success font-medium">− {disc}%</span></span>
                : <span>Base price</span>
              }
              {minQty > 1 && <span className="ml-2 text-xs">· applies from qty {minQty}</span>}
            </div>
            <div className="text-right">
              <span className="text-xs text-text-secondary">Effective price</span>
              <p className="text-base font-semibold text-text-primary">₹{effective.toFixed(2)}</p>
            </div>
          </div>
        )}

        <div className="flex justify-end gap-2 pt-1 border-t border-border">
          <Button type="button" variant="outline" onClick={onClose} disabled={loading}>Cancel</Button>
          <Button type="submit" disabled={loading}>{loading ? "Saving…" : "Save Changes"}</Button>
        </div>
      </form>
    </Modal>
  );
}

// ─── Delete Confirm Modal ─────────────────────────────────────────────────────
function DeleteConfirmModal({
  item, priceListId, token, orgId, onClose, onDeleted,
}: {
  item:        PriceListItem;
  priceListId: number;
  token:       string | null;
  orgId:       string | null;
  onClose:     () => void;
  onDeleted:   (itemId: number) => void;
}) {
  const [loading, setLoading] = useState(false);
  const [error,   setError]   = useState("");

  const handleDelete = async () => {
    if (!token || !orgId) return;
    setLoading(true); setError("");
    try {
      const res = await fetch(
        `http://localhost:3001/api/v1/price_lists/${priceListId}/items/${item.id}`,
        {
          method:  "DELETE",
          headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
        },
      );
      if (res.ok) { onDeleted(item.id); onClose(); }
      else        { const j = await res.json(); setError(j.error ?? "Failed to remove item"); }
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal open onClose={onClose} title="Remove Item" size="sm">
      <div className="space-y-4">
        <div className="flex gap-3">
          <div className="shrink-0 rounded-full bg-danger/10 p-2">
            <AlertTriangle className="h-5 w-5 text-danger" />
          </div>
          <div>
            <p className="text-sm text-text-primary">
              Remove <span className="font-semibold">{item.product_name}</span> from this price list?
            </p>
            <p className="mt-1 text-xs text-text-secondary">
              Current price ₹{Number(item.unit_price).toFixed(2)}
              {item.discount_pct > 0 && ` (${item.discount_pct}% off)`}
              {item.min_qty > 1 && `, min qty ${item.min_qty}`}. This cannot be undone.
            </p>
          </div>
        </div>

        {error && (
          <p className="text-xs text-danger">{error}</p>
        )}

        <div className="flex justify-end gap-2 border-t border-border pt-3">
          <Button variant="outline" onClick={onClose} disabled={loading}>Cancel</Button>
          <Button variant="danger" onClick={handleDelete} disabled={loading}>
            {loading ? "Removing…" : "Remove Item"}
          </Button>
        </div>
      </div>
    </Modal>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function PriceListDetailPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const { token, orgId } = useOrgBranch();

  const [pl,           setPl]           = useState<PriceListDetail | null>(null);
  const [fetching,     setFetching]     = useState(true);
  const [showAdd,      setShowAdd]      = useState(false);
  const [showImport,   setShowImport]   = useState(false);
  const [editingItem,  setEditingItem]  = useState<PriceListItem | null>(null);
  const [deletingItem, setDeletingItem] = useState<PriceListItem | null>(null);

  const load = useCallback(async () => {
    if (!token || !orgId || !params.id) return;
    setFetching(true);
    try {
      const res  = await fetch(`http://localhost:3001/api/v1/price_lists/${params.id}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) setPl(json.data);
    } finally {
      setFetching(false);
    }
  }, [token, orgId, params.id]);

  useEffect(() => { load(); }, [load]);

  const handleItemUpdated = useCallback((updated: PriceListItem) => {
    setPl((prev) => prev
      ? { ...prev, items: prev.items.map((i) => i.id === updated.id ? updated : i) }
      : prev
    );
  }, []);

  const handleItemDeleted = useCallback((itemId: number) => {
    setPl((prev) => prev
      ? { ...prev, items: prev.items.filter((i) => i.id !== itemId) }
      : prev
    );
  }, []);

  const downloadSampleCsv = useCallback(() => {
    if (!token || !orgId || !params.id) return;
    fetch(
      `http://localhost:3001/api/v1/price_lists/${params.id}/items/sample_csv`,
      { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId } },
    )
      .then((r) => r.blob())
      .then((blob) => {
        const url = URL.createObjectURL(blob);
        const a   = document.createElement("a");
        a.href     = url;
        a.download = `price_list_${params.id}_sample.csv`;
        a.click();
        URL.revokeObjectURL(url);
      });
  }, [token, orgId, params.id]);

  const downloadExportCsv = useCallback(() => {
    if (!token || !orgId || !params.id) return;
    fetch(
      `http://localhost:3001/api/v1/price_lists/${params.id}/items/export_csv`,
      { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId } },
    )
      .then((r) => r.blob())
      .then((blob) => {
        const url = URL.createObjectURL(blob);
        const a   = document.createElement("a");
        const name = `price_list_${params.id}_items_${new Date().toISOString().slice(0, 10)}.csv`;
        a.href = url; a.download = name; a.click();
        URL.revokeObjectURL(url);
      });
  }, [token, orgId, params.id]);

  if (fetching) {
    return (
      <AppShell title="Price Lists">
        <div className="flex items-center justify-center py-24">
          <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent" />
        </div>
      </AppShell>
    );
  }

  if (!pl) {
    return (
      <AppShell title="Price Lists">
        <p className="text-sm text-danger">Price list not found.</p>
      </AppShell>
    );
  }

  return (
    <AppShell title="Price Lists">
      <Breadcrumb items={[
        { label: "Products", href: "/products" },
        { label: "Price Lists", href: "/products/price-lists" },
        { label: pl.name },
      ]} />

      <div className="mb-6 flex items-start justify-between gap-4">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-3 flex-wrap">
            <h1 className="text-2xl font-bold text-text-primary">{pl.name}</h1>
            <Badge variant={TYPE_VARIANT[pl.list_type] ?? "outline"}>
              {pl.list_type.replace(/_/g, " ")}
            </Badge>
          </div>
          <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-text-secondary">
            {pl.branch && (
              <span className="flex items-center gap-1">
                <Tag className="h-3.5 w-3.5" /> {pl.branch.name}
              </span>
            )}
            {pl.valid_from && (
              <span>From: <span className="text-text-primary font-medium">{new Date(pl.valid_from).toLocaleDateString("en-IN")}</span></span>
            )}
            {pl.valid_to && (
              <span>To: <span className="text-text-primary font-medium">{new Date(pl.valid_to).toLocaleDateString("en-IN")}</span></span>
            )}
            <span className="flex items-center gap-1">
              <Layers className="h-3.5 w-3.5" />
              <span className="text-text-primary font-medium">{pl.items.length}</span> items
            </span>
          </div>
        </div>
        <Button onClick={() => setShowAdd(true)} className="shrink-0">
          <Plus className="h-4 w-4 mr-1" /> Add Item
        </Button>
        <Button variant="outline" onClick={() => setShowImport(true)} className="shrink-0">
          <Upload className="h-4 w-4 mr-1" /> Import CSV
        </Button>
        <Button variant="ghost" onClick={downloadExportCsv} className="shrink-0">
          <Download className="h-4 w-4 mr-1" /> Export CSV
        </Button>
      </div>

      {/* Items table */}
      <div className="rounded-lg border border-border overflow-auto">
        <table className="w-full text-sm">
          <thead className="bg-background-subtle">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-text-secondary">SKU</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-text-secondary">Product</th>
              <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-text-secondary">Unit Price</th>
              <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-text-secondary">Min Qty</th>
              <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-text-secondary">Discount</th>
              <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-text-secondary">Effective Price</th>
              <th className="w-10" />
            </tr>
          </thead>
          <tbody className="divide-y divide-border bg-white">
            {pl.items.length === 0 ? (
              <tr>
                <td colSpan={7}>
                  <div className="flex flex-col items-center justify-center py-16 text-center">
                    <div className="mb-3 rounded-full bg-background-subtle p-4">
                      <PackageSearch className="h-7 w-7 text-text-secondary/40" />
                    </div>
                    <p className="text-sm font-medium text-text-primary">No items in this price list</p>
                    <p className="mt-1 text-xs text-text-secondary max-w-xs">
                      Add products with their unit prices to make this list usable in orders.
                    </p>
                    <button
                      onClick={() => setShowAdd(true)}
                      className="mt-4 inline-flex items-center gap-1.5 rounded-md bg-primary px-3 py-1.5 text-xs font-medium text-white hover:bg-primary/90 transition-colors"
                    >
                      <Plus className="h-3.5 w-3.5" /> Add First Item
                    </button>
                  </div>
                </td>
              </tr>
            ) : pl.items.map((item) => {
              const effective = item.unit_price * (1 - item.discount_pct / 100);
              const isQtyBreak = item.min_qty > 1;
              return (
                <tr key={item.id} className="hover:bg-background-subtle transition-colors group">
                  <td className="px-4 py-3">
                    <span className="font-mono text-xs bg-background-subtle text-text-secondary px-1.5 py-0.5 rounded">
                      {item.product_sku}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <span className="font-medium text-text-primary">{item.product_name}</span>
                      {isQtyBreak && (
                        <span className="inline-flex items-center gap-0.5 rounded-full bg-warning/10 px-1.5 py-0.5 text-[10px] font-medium text-warning">
                          <Layers className="h-2.5 w-2.5" /> qty ≥ {item.min_qty}
                        </span>
                      )}
                    </div>
                  </td>
                  <td className="px-4 py-3 text-right tabular-nums">₹{Number(item.unit_price).toFixed(2)}</td>
                  <td className="px-4 py-3 text-right tabular-nums text-text-secondary">{item.min_qty}</td>
                  <td className="px-4 py-3 text-right">
                    {item.discount_pct > 0
                      ? <span className="inline-flex items-center gap-0.5 rounded-full bg-success/10 px-2 py-0.5 text-xs font-medium text-success">
                          <TrendingDown className="h-3 w-3" />{item.discount_pct}% off
                        </span>
                      : <span className="text-text-secondary">—</span>
                    }
                  </td>
                  <td className="px-4 py-3 text-right tabular-nums font-semibold text-text-primary">
                    ₹{effective.toFixed(2)}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <div className="flex items-center justify-end gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                      <button
                        onClick={() => setEditingItem(item)}
                        className="p-1.5 rounded hover:bg-primary/10 text-text-secondary hover:text-primary transition-colors"
                        title="Edit price"
                      >
                        <Pencil className="h-3.5 w-3.5" />
                      </button>
                      <button
                        onClick={() => setDeletingItem(item)}
                        className="p-1.5 rounded hover:bg-danger/10 text-text-secondary hover:text-danger transition-colors"
                        title="Remove item"
                      >
                        <Trash2 className="h-3.5 w-3.5" />
                      </button>
                    </div>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {showImport && pl && (
        <BulkImportModal
          priceListId={pl.id}
          token={token}
          orgId={orgId}
          onClose={() => setShowImport(false)}
          onImported={load}
        />
      )}

      {pl && (
        <AddItemModal
          open={showAdd}
          priceListId={pl.id}
          token={token}
          orgId={orgId}
          onClose={() => setShowAdd(false)}
          onAdded={(item) => setPl((prev) => prev ? { ...prev, items: [...prev.items, item] } : prev)}
        />
      )}

      {editingItem && pl && (
        <EditItemModal
          item={editingItem}
          priceListId={pl.id}
          token={token}
          orgId={orgId}
          onClose={() => setEditingItem(null)}
          onUpdated={(updated) => { handleItemUpdated(updated); setEditingItem(null); }}
        />
      )}

      {deletingItem && pl && (
        <DeleteConfirmModal
          item={deletingItem}
          priceListId={pl.id}
          token={token}
          orgId={orgId}
          onClose={() => setDeletingItem(null)}
          onDeleted={(id) => { handleItemDeleted(id); setDeletingItem(null); }}
        />
      )}
    </AppShell>
  );
}
