"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Modal } from "@/components/ui/modal";
import { Input } from "@/components/ui/input";
import { Search, Hash, Upload, Download, Plus, FileWarning, CheckCircle } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";
import Link from "next/link";

function getApiBase() {
  // Strip any trailing /api or /api/v1 from the URL, then always append /api/v1
  // This makes it safe regardless of whether NEXT_PUBLIC_API_URL includes the path or not
  return `${API_URL.replace(/\/api(\/v\d+)?\/?$/, '')}/api/v1`;
}

function authHeaders(token?: string | null, orgId?: string | null): Record<string, string> {
  return {
    "Content-Type": "application/json",
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...(orgId ? { "X-Organization-Id": orgId }       : {}),
  };
}

// ─── Types ────────────────────────────────────────────────────────────────────
interface HsnCode {
  id:          number;
  code:        string;
  description: string | null;
  gst_rate:    number;
  cess_rate:   number | null;
  category:    string | null;
}

// ─── Add / Edit Modal ────────────────────────────────────────────────────────
function CodeFormModal({
  open, editing, onClose, onSaved,
}: {
  open: boolean;
  editing: HsnCode | null;
  onClose: () => void;
  onSaved: () => void;
}) {
  const { token, orgId } = useOrgBranch();
  const [code,          setCode]          = useState("");
  const [codeType,      setCodeType]      = useState<"HSN" | "SAC">("HSN");
  const [description,   setDescription]   = useState("");
  const [gstRate,       setGstRate]       = useState(5);
  const [effectiveFrom, setEffectiveFrom] = useState("");
  const [saving,        setSaving]        = useState(false);
  const [error,         setError]         = useState<string | null>(null);

  useEffect(() => {
    if (editing) {
      setCode(editing.code);
      setCodeType("HSN");
      setDescription(editing.description ?? "");
      setGstRate(Number(editing.gst_rate));
      setEffectiveFrom("");
    } else {
      setCode(""); setCodeType("HSN"); setDescription("");
      setGstRate(5); setEffectiveFrom(new Date().toISOString().slice(0, 10));
    }
    setError(null);
  }, [editing, open]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true); setError(null);
    try {
      const url = editing
        ? `${getApiBase()}/hsn_sac_codes/${editing.id}`
        : `${getApiBase()}/hsn_sac_codes`;
      const res = await fetch(url, {
        method:  editing ? "PATCH" : "POST",
        headers: authHeaders(token, orgId),
        body:    JSON.stringify({ hsn_sac_code: { code, code_type: codeType, description, gst_rate: gstRate, effective_from: effectiveFrom } }),
      });
      const json = await res.json();
      if (!res.ok) throw new Error(json.errors?.join(", ") ?? "Failed to save");
      onSaved(); onClose();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to save");
    } finally {
      setSaving(false);
    }
  }

  const GST_RATES = [0, 5, 12, 18, 28];

  return (
    <Modal open={open} onClose={onClose} title={editing ? "Edit HSN/SAC Code" : "Add HSN/SAC Code"} size="md">
      <form onSubmit={handleSubmit} className="space-y-4 pt-2">
        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1.5">
            <label className="text-sm font-medium text-text-primary">Code *</label>
            <Input value={code} onChange={(e) => setCode(e.target.value)} required placeholder="e.g. 10061090" />
          </div>
          <div className="space-y-1.5">
            <label className="text-sm font-medium text-text-primary">Type</label>
            <select value={codeType} onChange={(e) => setCodeType(e.target.value as "HSN" | "SAC")} className="flex h-9 w-full rounded-md border border-border bg-background px-3 text-sm focus:outline-none focus:ring-1 focus:ring-accent">
              <option value="HSN">HSN</option>
              <option value="SAC">SAC</option>
            </select>
          </div>
        </div>
        <div className="space-y-1.5">
          <label className="text-sm font-medium text-text-primary">Description</label>
          <Input value={description} onChange={(e) => setDescription(e.target.value)} placeholder="e.g. Rice, semi-milled or wholly milled" />
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1.5">
            <label className="text-sm font-medium text-text-primary">GST Rate *</label>
            <select value={gstRate} onChange={(e) => setGstRate(Number(e.target.value))} className="flex h-9 w-full rounded-md border border-border bg-background px-3 text-sm focus:outline-none focus:ring-1 focus:ring-accent">
              {GST_RATES.map((r) => <option key={r} value={r}>{r}%</option>)}
            </select>
          </div>
          <div className="space-y-1.5">
            <label className="text-sm font-medium text-text-primary">Effective From *</label>
            <Input type="date" value={effectiveFrom} onChange={(e) => setEffectiveFrom(e.target.value)} required />
          </div>
        </div>
        {error && <p className="text-sm text-danger">{error}</p>}
        <div className="flex justify-end gap-2 border-t border-border pt-3">
          <Button type="button" variant="outline" onClick={onClose} disabled={saving}>Cancel</Button>
          <Button type="submit" disabled={saving}>{saving ? "Saving…" : editing ? "Save Changes" : "Add Code"}</Button>
        </div>
      </form>
    </Modal>
  );
}

// ─── Bulk Import Modal ────────────────────────────────────────────────────────
function BulkImportModal({ onClose, onImported }: { onClose: () => void; onImported: () => void }) {
  const { token, orgId } = useOrgBranch();
  const [file,    setFile]    = useState<File | null>(null);
  const [loading, setLoading] = useState(false);
  const [result,  setResult]  = useState<{ success_count: number; failed_rows: { row: number; errors: string[] }[] } | null>(null);
  const [error,   setError]   = useState("");
  const inputRef = useRef<HTMLInputElement>(null);

  const downloadSample = async () => {
    try {
      const res = await fetch(`${getApiBase()}/hsn_sac_codes/sample_csv`, { headers: authHeaders(token, orgId) });
      const blob = await res.blob();
      const a = document.createElement("a");
      a.href = URL.createObjectURL(blob); a.download = "sample_hsn_sac_codes.csv"; a.click();
    } catch { /* ignore */ }
  };

  const handleUpload = async () => {
    if (!file) return;
    setLoading(true); setError(""); setResult(null);
    try {
      const { Authorization, "X-Organization-Id": orgIdH } = authHeaders(token, orgId);
      const fd = new FormData(); fd.append("file", file);
      const res = await fetch(`${getApiBase()}/hsn_sac_codes/bulk_import`, {
        method: "POST",
        headers: { ...(Authorization ? { Authorization } : {}), ...(orgIdH ? { "X-Organization-Id": orgIdH } : {}) },
        body: fd,
      });
      const json = await res.json();
      if (res.ok) setResult(json.data);
      else        setError(json.errors?.join(", ") ?? "Import failed");
    } catch { setError("Network error — please try again"); }
    finally   { setLoading(false); }
  };

  return (
    <Modal open onClose={onClose} title="Bulk Import HSN / SAC Codes" size="lg">
      <div className="space-y-5">
        <div className="rounded-md border border-border bg-background-subtle px-4 py-3 text-sm text-text-secondary">
          <p className="font-medium text-text-primary mb-1">CSV format</p>
          <p>Required: <code className="font-mono text-xs bg-white border border-border rounded px-1">code</code>, <code className="font-mono text-xs bg-white border border-border rounded px-1">gst_rate</code>, <code className="font-mono text-xs bg-white border border-border rounded px-1">effective_from</code></p>
          <p className="mt-0.5">Optional: <code className="font-mono text-xs bg-white border border-border rounded px-1">code_type</code> (HSN/SAC), <code className="font-mono text-xs bg-white border border-border rounded px-1">description</code></p>
          <p className="mt-0.5 text-xs">Duplicate (code + effective_from) rows are silently skipped. Max 2,000 rows.</p>
        </div>
        <button type="button" onClick={downloadSample} className="inline-flex items-center gap-2 text-sm text-primary hover:underline">
          <Download className="h-4 w-4" /> Download sample CSV
        </button>
        {!result && (
          <div>
            <div onClick={() => inputRef.current?.click()} className="flex flex-col items-center justify-center gap-2 rounded-lg border-2 border-dashed border-border bg-background-subtle hover:border-primary/50 cursor-pointer py-8">
              <Upload className="h-7 w-7 text-text-secondary/60" />
              {file ? <p className="text-sm font-medium text-text-primary">{file.name}</p> : <p className="text-sm text-text-primary">Click to select a CSV file</p>}
            </div>
            <input ref={inputRef} type="file" accept=".csv,text/csv" className="hidden" onChange={(e) => { setFile(e.target.files?.[0] ?? null); setError(""); }} />
          </div>
        )}
        {error && <div className="flex items-start gap-2 rounded-md bg-danger/8 border border-danger/20 px-3 py-2.5 text-sm text-danger"><FileWarning className="h-4 w-4 shrink-0 mt-0.5" />{error}</div>}
        {result && (
          <div className="space-y-3">
            <div className="flex items-center gap-4">
              <div className="flex items-center gap-2 rounded-md bg-success/10 border border-success/20 px-3 py-2 text-sm">
                <CheckCircle className="h-4 w-4 text-success" /><span className="font-medium text-success">{result.success_count} imported</span>
              </div>
              {result.failed_rows.length > 0 && (
                <div className="flex items-center gap-2 rounded-md bg-danger/8 border border-danger/20 px-3 py-2 text-sm">
                  <FileWarning className="h-4 w-4 text-danger" /><span className="font-medium text-danger">{result.failed_rows.length} failed</span>
                </div>
              )}
            </div>
          </div>
        )}
        <div className="flex justify-end gap-2 border-t border-border pt-3">
          {result ? (
            <Button onClick={() => { if (result.success_count > 0) onImported(); onClose(); }}>Done</Button>
          ) : (
            <>
              <Button variant="outline" onClick={onClose} disabled={loading}>Cancel</Button>
              <Button onClick={handleUpload} disabled={!file || loading}>
                {loading ? <>Importing…</> : <><Upload className="h-4 w-4 mr-2" />Import CSV</>}
              </Button>
            </>
          )}
        </div>
      </div>
    </Modal>
  );
}

const GST_VARIANT: Record<number, "success" | "default" | "warning" | "secondary"> = {
  0:  "outline" as "default",
  5:  "success",
  12: "default",
  18: "warning",
  28: "secondary",
};

// ─── Sub-nav (shared pattern) ─────────────────────────────────────────────────
function ProductsSubNav() {
  const items = [
    { label: "Products",         href: "/products" },
    { label: "Categories",       href: "/products/categories" },
    { label: "Units of Measure", href: "/products/uom" },
    { label: "Price Lists",      href: "/products/price-lists" },
    { label: "HSN / SAC",        href: "/products/hsn-codes" },
  ];
  return (
    <div className="flex gap-1 border-b border-border mb-6 overflow-x-auto">
      {items.map((item) => (
        <Link
          key={item.href}
          href={item.href}
          className="px-4 py-2 text-sm font-medium border-b-2 -mb-px whitespace-nowrap transition-colors border-transparent text-text-secondary hover:text-text-primary"
        >
          {item.label}
        </Link>
      ))}
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function HsnCodesPage() {
  const { token, orgId } = useOrgBranch();

  const [codes,      setCodes]      = useState<HsnCode[]>([]);
  const [loading,    setLoading]    = useState(false);
  const [total,      setTotal]      = useState(0);
  const [page,       setPage]       = useState(1);
  const [search,     setSearch]     = useState("");
  const [gstFilter,  setGstFilter]  = useState("");
  const [showForm,   setShowForm]   = useState(false);
  const [editingCode, setEditingCode] = useState<HsnCode | null>(null);
  const [showImport, setShowImport] = useState(false);
  const [exporting,  setExporting]  = useState(false);
  const perPage = 25;

  const fetchCodes = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const qs = new URLSearchParams({ page: String(page), per_page: String(perPage) });
      if (search)    qs.set("q",        search);
      if (gstFilter) qs.set("gst_rate", gstFilter);
      const res  = await fetch(`${getApiBase()}/hsn_sac_codes?${qs}`, {
        headers: authHeaders(token, orgId),
      });
      const json = await res.json();
      setCodes(json.data ?? []);
      setTotal(json.meta?.total_count ?? json.meta?.total ?? json.data?.length ?? 0);
    } finally {
      setLoading(false);
    }
  }, [token, orgId, page, search, gstFilter]);

  useEffect(() => { fetchCodes(); }, [fetchCodes]);

  async function handleExportCsv() {
    if (exporting) return;
    setExporting(true);
    try {
      const { Authorization, "X-Organization-Id": orgIdH } = authHeaders(token, orgId);
      const qs = new URLSearchParams();
      if (search)    qs.set("q",        search);
      if (gstFilter) qs.set("gst_rate", gstFilter);
      const res = await fetch(`${getApiBase()}/hsn_sac_codes/export_csv?${qs}`, {
        headers: { ...(Authorization ? { Authorization } : {}), ...(orgIdH ? { "X-Organization-Id": orgIdH } : {}) },
      });
      const blob = await res.blob();
      const a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = "hsn_sac_codes.csv";
      a.click();
    } catch { /* ignore */ }
    finally { setExporting(false); }
  }

  const gstOptions = [0, 5, 12, 18, 28];

  return (
    <AppShell title="HSN / SAC Codes" hideBreadcrumb>
      <PageHeader
        title="HSN / SAC Codes"
        description="Harmonised System of Nomenclature and Service Accounting Codes used in GST invoicing"
        actions={[
          { label: "Bulk Import CSV",                             onClick: () => setShowImport(true),              icon: Upload,    variant: "outline" },
          { label: exporting ? "Exporting…" : "Export CSV",      onClick: handleExportCsv,                        icon: Download,  variant: "outline", disabled: exporting },
          { label: "Add HSN Code",                               onClick: () => { setEditingCode(null); setShowForm(true); }, icon: Plus },
        ]}
      />

      {showForm && (
        <CodeFormModal
          open={showForm}
          editing={editingCode}
          onClose={() => setShowForm(false)}
          onSaved={fetchCodes}
        />
      )}

      {showImport && (
        <BulkImportModal
          onClose={() => setShowImport(false)}
          onImported={fetchCodes}
        />
      )}

      {/* <ProductsSubNav /> */}

      {/* Filters */}
      <div className="mb-4 flex flex-wrap gap-3 items-center">
        <div className="relative flex-1 min-w-0 max-w-xs">
          <Search className="absolute left-2.5 top-2 h-4 w-4 text-text-secondary" />
          <input
            type="text"
            placeholder="Search code or description…"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            className="w-full h-9 rounded-md border border-border bg-background pl-8 pr-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
          />
        </div>

        <div className="flex gap-1 flex-wrap">
          <button
            onClick={() => { setGstFilter(""); setPage(1); }}
            className={`px-3 h-8 text-xs rounded-full border transition-colors ${!gstFilter ? "bg-accent text-white border-accent" : "border-border text-text-secondary hover:text-text-primary"}`}
          >
            All rates
          </button>
          {gstOptions.map((r) => (
            <button
              key={r}
              onClick={() => { setGstFilter(String(r)); setPage(1); }}
              className={`px-3 h-8 text-xs rounded-full border transition-colors ${gstFilter === String(r) ? "bg-accent text-white border-accent" : "border-border text-text-secondary hover:text-text-primary"}`}
            >
              {r}% GST
            </button>
          ))}
        </div>
      </div>

      {/* Stats chips */}
      {/* <div className="mb-4 flex items-center gap-3">
        <Hash className="h-4 w-4 text-text-secondary" />
        <span className="text-sm text-text-secondary">{total.toLocaleString("en-IN")} code{total !== 1 ? "s" : ""} found</span>
      </div> */}

      {/* Table */}
      {loading ? (
        <div className="flex justify-center py-12">
          <div className="h-6 w-6 animate-spin rounded-full border-2 border-accent border-t-transparent" />
        </div>
      ) : (
        <>
          <div className="rounded-lg border border-border overflow-auto">
            <table className="w-full text-sm">
              <thead className="bg-background-subtle">
                <tr>
                  <th className="px-4 py-2.5 text-left font-semibold text-text-secondary w-36">HSN / SAC Code</th>
                  <th className="px-4 py-2.5 text-left font-semibold text-text-secondary">Description</th>
                  <th className="px-4 py-2.5 text-left font-semibold text-text-secondary w-28">Category</th>
                  <th className="px-4 py-2.5 text-right font-semibold text-text-secondary w-24">GST Rate</th>
                  <th className="px-4 py-2.5 text-right font-semibold text-text-secondary w-24">CESS</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border bg-white">
                {codes.map((c) => (
                  <tr key={c.id} className="hover:bg-background-subtle">
                    <td className="px-4 py-2.5 font-mono text-sm font-medium text-accent">{c.code}</td>
                    <td className="px-4 py-2.5 text-text-primary">{c.description ?? "—"}</td>
                    <td className="px-4 py-2.5">
                      {c.category ? (
                        <Badge variant="outline">{c.category}</Badge>
                      ) : (
                        <span className="text-text-secondary text-xs">—</span>
                      )}
                    </td>
                    <td className="px-4 py-2.5 text-right">
                      <Badge variant={GST_VARIANT[c.gst_rate] ?? "outline"}>{c.gst_rate}%</Badge>
                    </td>
                    <td className="px-4 py-2.5 text-right text-text-secondary tabular-nums text-xs">
                      {c.cess_rate != null && Number(c.cess_rate) > 0 ? `${Number(c.cess_rate).toFixed(1)}%` : "—"}
                    </td>
                  </tr>
                ))}
                {codes.length === 0 && (
                  <tr>
                    <td colSpan={5} className="px-4 py-10 text-center text-text-secondary text-sm">
                      No HSN / SAC codes found.
                      {(search || gstFilter) && (
                        <button
                          onClick={() => { setSearch(""); setGstFilter(""); setPage(1); }}
                          className="ml-2 text-accent hover:underline"
                        >
                          Clear filters
                        </button>
                      )}
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          {total > perPage && (
            <div className="mt-4 flex items-center justify-between text-sm">
              <span className="text-text-secondary">
                Showing {((page - 1) * perPage) + 1}–{Math.min(page * perPage, total)} of {total}
              </span>
              <div className="flex gap-2">
                <Button variant="outline" size="sm" disabled={page === 1} onClick={() => setPage((p) => p - 1)}>Previous</Button>
                <Button variant="outline" size="sm" disabled={page * perPage >= total} onClick={() => setPage((p) => p + 1)}>Next</Button>
              </div>
            </div>
          )}
        </>
      )}
    </AppShell>
  );
}
