"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { AppShell, PageHeader } from "@/components/layout";
import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Pencil, PowerOff, Search, X, Plus, Package, Upload, Download, CheckCircle, FileWarning } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Modal } from "@/components/ui/modal";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";

// ─── Sub-nav ──────────────────────────────────────────────────────────────────
function ProductsSubNav({ active }: { active: "products" | "categories" | "uom" | "price-lists" }) {
  const items = [
    { key: "products",    label: "Products",         href: "/products" },
    { key: "categories",  label: "Categories",       href: "/products/categories" },
    { key: "uom",         label: "Units of Measure", href: "/products/uom" },
    { key: "price-lists", label: "Price Lists",      href: "/products/price-lists" },
  ];
  return (
    <div className="flex gap-1 border-b border-border mb-6">
      {items.map((item) => (
        <Link
          key={item.key}
          href={item.href}
          className={`px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors ${
            active === item.key
              ? "border-primary text-primary"
              : "border-transparent text-text-secondary hover:text-text-primary"
          }`}
        >
          {item.label}
        </Link>
      ))}
    </div>
  );
}

// ─── Types ────────────────────────────────────────────────────────────────────
interface ProductCategory { id: number; name: string; }

interface Product {
  id:             number;
  sku:            string;
  name:           string;
  gst_rate:       number;
  status:         string;
  min_order_qty:  number;
  barcode:        string | null;
  weight_kg:      number | null;
  image_url:      string | null;
  hsn:            { id: number; code: string; description: string; gst_rate: number } | null;
  category:       { id: number; name: string } | null;
  uom:            { id: number; name: string; symbol: string } | null;
}

const STATUS_VARIANT: Record<string, "success" | "danger" | "warning" | "outline"> = {
  active:       "success",
  discontinued: "danger",
};

// ─── Bulk Import Modal ────────────────────────────────────────────────────────
function BulkImportModal({
  token, orgId, onClose, onImported,
}: {
  token:      string | null;
  orgId:      string | null;
  onClose:    () => void;
  onImported: () => void;
}) {
  const [file,    setFile]    = useState<File | null>(null);
  const [loading, setLoading] = useState(false);
  const [result,  setResult]  = useState<{
    success_count: number;
    skipped_rows:  { row: number; sku: string; reason: string }[];
    failed_rows:   { row: number; sku: string; errors: string[] }[];
  } | null>(null);
  const [error,   setError]   = useState("");
  const inputRef = useRef<HTMLInputElement>(null);

  const downloadSample = () => {
    if (!token || !orgId) return;
    fetch(`${API_URL}/api/v1/products/sample_csv`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then((r) => r.blob())
      .then((blob) => {
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url; a.download = "sample_products.csv"; a.click();
        URL.revokeObjectURL(url);
      });
  };

  const handleUpload = async () => {
    if (!file || !token || !orgId) return;
    setLoading(true); setError(""); setResult(null);
    try {
      const fd = new FormData();
      fd.append("file", file);
      const res = await fetch(`${API_URL}/api/v1/products/bulk_import`, {
        method:  "POST",
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
        body:    fd,
      });
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
    if (result && result.success_count > 0) onImported();
    onClose();
  };

  return (
    <Modal open onClose={onClose} title="Bulk Import Products" size="lg">
      <div className="space-y-5">
        <div className="rounded-md border border-border bg-background-subtle px-4 py-3 text-sm text-text-secondary">
          <p className="font-medium text-text-primary mb-1">CSV format</p>
          <p>Required: <code className="font-mono text-xs bg-white border border-border rounded px-1">sku</code>, <code className="font-mono text-xs bg-white border border-border rounded px-1">name</code></p>
          <p className="mt-0.5">Optional: <code className="font-mono text-xs bg-white border border-border rounded px-1">category</code>, <code className="font-mono text-xs bg-white border border-border rounded px-1">uom</code>, <code className="font-mono text-xs bg-white border border-border rounded px-1">hsn_code</code>, <code className="font-mono text-xs bg-white border border-border rounded px-1">gst_rate</code>, <code className="font-mono text-xs bg-white border border-border rounded px-1">selling_price</code>, <code className="font-mono text-xs bg-white border border-border rounded px-1">description</code></p>
          <p className="mt-0.5 text-xs">Rows with an existing SKU will be <span className="font-medium">skipped</span>. Max 1,000 rows per file.</p>
        </div>

        <button type="button" onClick={downloadSample} className="inline-flex items-center gap-2 text-sm text-primary hover:underline">
          <Download className="h-4 w-4" /> Download sample CSV
        </button>

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

        {error && (
          <div className="flex items-start gap-2 rounded-md bg-danger/8 border border-danger/20 px-3 py-2.5 text-sm text-danger">
            <FileWarning className="h-4 w-4 shrink-0 mt-0.5" />{error}
          </div>
        )}

        {result && (
          <div className="space-y-3">
            <div className="flex items-center gap-4 flex-wrap">
              <div className="flex items-center gap-2 rounded-md bg-success/10 border border-success/20 px-3 py-2 text-sm">
                <CheckCircle className="h-4 w-4 text-success" />
                <span className="font-medium text-success">{result.success_count} imported</span>
              </div>
              {result.skipped_rows.length > 0 && (
                <div className="flex items-center gap-2 rounded-md bg-warning/10 border border-warning/20 px-3 py-2 text-sm">
                  <span className="font-medium text-warning">{result.skipped_rows.length} skipped (duplicate SKUs)</span>
                </div>
              )}
              {result.failed_rows.length > 0 && (
                <div className="flex items-center gap-2 rounded-md bg-danger/8 border border-danger/20 px-3 py-2 text-sm">
                  <FileWarning className="h-4 w-4 text-danger" />
                  <span className="font-medium text-danger">{result.failed_rows.length} failed</span>
                </div>
              )}
            </div>
            {result.failed_rows.length > 0 && (
              <div className="rounded-md border border-border overflow-auto max-h-44">
                <table className="w-full text-xs">
                  <thead className="bg-background-subtle">
                    <tr>
                      <th className="px-3 py-2 text-left font-semibold text-text-secondary">Row</th>
                      <th className="px-3 py-2 text-left font-semibold text-text-secondary">SKU</th>
                      <th className="px-3 py-2 text-left font-semibold text-text-secondary">Error</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border bg-white">
                    {result.failed_rows.map((f) => (
                      <tr key={f.row}>
                        <td className="px-3 py-1.5 tabular-nums text-text-secondary">{f.row}</td>
                        <td className="px-3 py-1.5 font-mono">{f.sku || "—"}</td>
                        <td className="px-3 py-1.5 text-danger">{f.errors.join(", ")}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}

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

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function ProductsPage() {
  const router   = useRouter();
  const { token, orgId } = useOrgBranch();

  const [products,     setProducts]     = useState<Product[]>([]);
  const [categories,   setCategories]   = useState<ProductCategory[]>([]);
  const [loading,      setLoading]      = useState(false);
  const [actionLoading, setActionLoading] = useState<number | null>(null);
  const [search,       setSearch]       = useState("");
  const [categoryId,   setCategoryId]   = useState("");
  const [status,       setStatus]       = useState("");
  const [page,         setPage]         = useState(1);
  const [totalPages,   setTotalPages]   = useState(1);
  const [totalCount,   setTotalCount]   = useState(0);
  const [exporting,    setExporting]    = useState(false);
  const [showImport,   setShowImport]   = useState(false);

  // Load filter options
  useEffect(() => {
    if (!token || !orgId) return;
    const headers = { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId };
    fetch(`${API_URL}/api/v1/product_categories?per_page=100`, { headers })
      .then((r) => r.json())
      .then((j) => j.data && setCategories(j.data));
  }, [token, orgId]);

  const handleDiscontinue = useCallback(async (id: number) => {
    if (!token || !orgId) return;
    setActionLoading(id);
    try {
      const res = await fetch(`${API_URL}/api/v1/products/${id}/discontinue`, {
        method:  "POST",
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      if (res.ok) {
        setProducts((prev) => prev.map((p) => p.id === id ? { ...p, status: "discontinued" } : p));
      }
    } finally {
      setActionLoading(null);
    }
  }, [token, orgId]);

  const columns: Column<Product>[] = [
    // {
    //   key:    "image_url",
    //   header: "",
    //   render: (_, row) => row.image_url
    //     ? <img src={row.image_url} alt={row.name} className="h-8 w-8 rounded object-cover" />
    //     : <div className="h-8 w-8 rounded bg-muted flex items-center justify-center text-xs text-text-secondary">—</div>,
    // },
    {
      key:    "sku",
      header: "SKU / Name",
      render: (_, row) => (
        <div>
          <p className="font-medium text-text-primary">{row.name}</p>
          <p className="text-xs text-text-secondary font-mono">{row.sku}</p>
        </div>
      ),
    },
    {
      key:    "category",
      header: "Category",
      render: (_, row) => <span className="text-sm text-text-secondary">{row.category?.name ?? "—"}</span>,
    },
    {
      key:    "hsn",
      header: "HSN",
      render: (_, row) => row.hsn
        ? (
          <div>
            <p className="text-sm font-mono text-text-primary">{row.hsn.code}</p>
            <p className="text-xs text-text-secondary">GST {row.gst_rate}%</p>
          </div>
        )
        : <span className="text-sm text-text-secondary">—</span>,
    },
    {
      key:    "uom",
      header: "UOM",
      render: (_, row) => <span className="text-sm text-text-secondary">{row.uom?.symbol ?? "—"}</span>,
    },
    {
      key:    "min_order_qty",
      header: "Min Qty",
      render: (v) => <span className="text-sm">{String(v)}</span>,
    },
    {
      key:    "status",
      header: "Status",
      render: (v) => (
        <Badge variant={STATUS_VARIANT[v as string] ?? "outline"}>
          {String(v).charAt(0).toUpperCase() + String(v).slice(1)}
        </Badge>
      ),
    },
    {
      key:    "actions_col",
      header: "",
      render: (_, row) => (
        <div className="flex items-center gap-1" onClick={(e) => e.stopPropagation()}>
          <button
            onClick={() => router.push(`/products/${row.id}/edit`)}
            className="p-1 rounded hover:bg-muted text-text-secondary hover:text-text-primary transition-colors"
            title="Edit"
          >
            <Pencil className="h-3.5 w-3.5" />
          </button>
          {row.status === "active" && (
            <button
              onClick={() => handleDiscontinue(row.id)}
              disabled={actionLoading === row.id}
              className="p-1 rounded hover:bg-muted text-text-secondary hover:text-warning transition-colors disabled:opacity-40"
              title="Discontinue"
            >
              <PowerOff className="h-3.5 w-3.5" />
            </button>
          )}
        </div>
      ),
    },
  ];

  const fetchProducts = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const qs = new URLSearchParams({ page: String(page), per_page: "20" });
      if (search)     qs.set("q",           search);
      if (categoryId) qs.set("category_id", categoryId);
      if (status)     qs.set("status",      status);

      const res  = await fetch(`${API_URL}/api/v1/products?${qs}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) {
        setProducts(json.data);
        setTotalPages(json.meta?.total_pages ?? 1);
        setTotalCount(json.meta?.total_count  ?? 0);
      }
    } finally {
      setLoading(false);
    }
  }, [token, orgId, page, search, categoryId, status]);

  useEffect(() => { fetchProducts(); }, [fetchProducts]);

  const clearFilters = () => {
    setSearch(""); setCategoryId(""); setStatus(""); setPage(1);
  };

  const hasFilters = search || categoryId || status;

  const handleExportCsv = useCallback(async () => {
    if (!token || !orgId || exporting) return;
    setExporting(true);
    try {
      const qs = new URLSearchParams();
      if (search)     qs.set("q",           search);
      if (categoryId) qs.set("category_id", categoryId);
      if (status)     qs.set("status",      status);
      const res = await fetch(`${API_URL}/api/v1/products/export_csv?${qs}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const blob = await res.blob();
      const url  = URL.createObjectURL(blob);
      const a    = document.createElement("a");
      const cd   = res.headers.get("Content-Disposition") ?? "";
      const name = cd.match(/filename="?([^"]+)"?/)?.[1] ?? "products_export.csv";
      a.href = url; a.download = name; a.click();
      URL.revokeObjectURL(url);
    } finally {
      setExporting(false);
    }
  }, [token, orgId, search, categoryId, status, exporting]);

  return (
    <AppShell title="Products">
      <PageHeader
        title="Products"
        description={totalCount > 0 ? `${totalCount} products` : undefined}
        actions={[
          {
            label:   'Import CSV',
            variant: 'outline' as const,
            icon:    Upload,
            onClick: () => setShowImport(true),
          },
          ...(totalCount > 0 ? [{
            label:   exporting ? 'Exporting…' : 'Export CSV',
            variant: 'ghost' as const,
            icon:    Download,
            onClick: handleExportCsv,
          }] : []),
          ...(totalCount > 0 ? [{
            label:   'Add Product',
            icon:    Plus,
            onClick: () => router.push('/products/new'),
          }] : []),
        ]}
      />

      <ProductsSubNav active="products" />

      {showImport && (
        <BulkImportModal
          token={token}
          orgId={orgId}
          onClose={() => setShowImport(false)}
          onImported={() => { setShowImport(false); fetchProducts(); }}
        />
      )}

      {/* Filters */}
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <div className="relative flex-1 min-w-[220px]">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary" />
          <Input
            className="pl-9"
            placeholder="Search by SKU or name…"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
          />
        </div>
        <select
          value={categoryId}
          onChange={(e) => { setCategoryId(e.target.value); setPage(1); }}
          className="px-3 py-2 text-sm border border-border rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20"
        >
          <option value="">All categories</option>
          {categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
        </select>
        <select
          value={status}
          onChange={(e) => { setStatus(e.target.value); setPage(1); }}
          className="px-3 py-2 text-sm border border-border rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20"
        >
          <option value="">All statuses</option>
          <option value="active">Active</option>
          <option value="discontinued">Discontinued</option>
        </select>
        {hasFilters && (
          <button onClick={clearFilters} className="flex items-center gap-1 text-sm text-text-secondary hover:text-text-primary">
            <X className="h-3.5 w-3.5" /> Clear
          </button>
        )}
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-24">
          <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent" />
        </div>
      ) : products.length === 0 ? (
        <div className="flex flex-col items-center justify-center rounded-lg border border-border py-20 text-center">
          <div className="mb-4 rounded-full bg-background-subtle p-4">
            <Package className="h-8 w-8 text-text-secondary/50" />
          </div>
          <p className="text-sm font-medium text-text-primary">No products yet</p>
          <p className="mt-1 text-xs text-text-secondary">
            {hasFilters ? "No products match the current filters." : "Add your first product to start building your catalogue."}
          </p>
          {!hasFilters && (
            <Button size="sm" className="mt-4" onClick={() => router.push('/products/new')}>
              <Plus className="mr-1.5 h-3.5 w-3.5" /> Add Product
            </Button>
          )}
        </div>
      ) : (
        <DataTable
          columns={columns}
          data={products}
          onRowClick={(row) => router.push(`/products/${row.id}/edit`)}
        />
      )}

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="mt-4 flex items-center justify-between text-sm text-text-secondary">
          <span>{totalCount} products</span>
          <div className="flex items-center gap-2">
            <button
              disabled={page <= 1}
              onClick={() => setPage((p) => p - 1)}
              className="px-3 py-1 rounded border border-border hover:bg-muted disabled:opacity-40"
            >
              Previous
            </button>
            <span>Page {page} of {totalPages}</span>
            <button
              disabled={page >= totalPages}
              onClick={() => setPage((p) => p + 1)}
              className="px-3 py-1 rounded border border-border hover:bg-muted disabled:opacity-40"
            >
              Next
            </button>
          </div>
        </div>
      )}
    </AppShell>
  );
}
