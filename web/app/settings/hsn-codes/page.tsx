"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Modal } from "@/components/ui/modal";
import { API_URL } from "@/lib/api/client";
import { useOrgBranch } from "@/lib/org-branch-context";
import {
  ChevronLeft,
  ChevronRight,
  Plus,
  Search,
  Upload,
  Download,
  Pencil,
  TrendingUp,
  Ban,
  CheckCircle,
  FileWarning,
} from "lucide-react";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------
interface HsnSacCode {
  id: number;
  code: string;
  code_type: "HSN" | "SAC";
  description: string | null;
  chapter: string | null;
  gst_rate: number;
  cgst_rate: number;
  sgst_rate: number;
  igst_rate: number;
  active: boolean;
  current_rate: boolean;
  effective_from: string;
  effective_to: string | null;
}

interface PaginationMeta {
  current_page: number;
  total_pages: number;
  total_count: number;
  per_page: number;
}

const GST_RATES = [0, 5, 12, 18, 28] as const;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function getApiBase() {
  return process.env.NEXT_PUBLIC_API_URL ?? `${API_URL}/api/v1`;
}

function authHeaders(token?: string | null, orgId?: string | null): Record<string, string> {
  return {
    "Content-Type": "application/json",
    ...(token  ? { Authorization: `Bearer ${token}` }  : {}),
    ...(orgId  ? { "X-Organization-Id": orgId }        : {}),
  };
}

function gstBadgeVariant(rate: number): string {
  const map: Record<number, string> = {
    0:  "bg-muted text-text-secondary border border-border",
    5:  "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400",
    12: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400",
    18: "bg-orange-100 text-orange-800 dark:bg-orange-900/30 dark:text-orange-400",
    28: "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400",
  };
  return map[rate] ?? "bg-muted text-text-secondary";
}

function formatDate(dateStr: string | null): string {
  if (!dateStr) return "—";
  return new Date(dateStr).toLocaleDateString("en-IN", {
    year: "numeric", month: "short", day: "numeric",
  });
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------
function EmptyState({ onAdd }: { onAdd: () => void }) {
  return (
    <div className="flex flex-col items-center justify-center py-20 text-center">
      <div className="mb-4 rounded-full bg-background-subtle p-4">
        <Plus className="h-8 w-8 text-text-secondary/50" />
      </div>
      <p className="text-sm font-medium text-text-primary">No HSN/SAC codes yet</p>
      <p className="mt-1 text-xs text-text-secondary">
        Add codes manually or bulk-import from a CSV.
      </p>
      <Button size="sm" className="mt-4" onClick={onAdd}>
        <Plus className="mr-1.5 h-3.5 w-3.5" /> Add HSN Code
      </Button>
    </div>
  );
}

// ---------------------------------------------------------------------------
// HSN/SAC Code Form Modal (create / edit)
// ---------------------------------------------------------------------------
interface CodeFormModalProps {
  open: boolean;
  editing: HsnSacCode | null;
  onClose: () => void;
  onSaved: () => void;
}

function CodeFormModal({ open, editing, onClose, onSaved }: CodeFormModalProps) {
  const { token, orgId } = useOrgBranch();
  const [code,          setCode]          = useState("");
  const [codeType,      setCodeType]      = useState<"HSN" | "SAC">("HSN");
  const [description,   setDescription]   = useState("");
  const [chapter,       setChapter]       = useState("");
  const [gstRate,       setGstRate]       = useState<number>(5);
  const [effectiveFrom, setEffectiveFrom] = useState("");
  const [saving,        setSaving]        = useState(false);
  const [error,         setError]         = useState<string | null>(null);

  // Seed from editing record
  useEffect(() => {
    if (editing) {
      setCode(editing.code);
      setCodeType(editing.code_type);
      setDescription(editing.description ?? "");
      setChapter(editing.chapter ?? "");
      setGstRate(editing.gst_rate);
      setEffectiveFrom(editing.effective_from?.slice(0, 10) ?? "");
    } else {
      setCode(""); setCodeType("HSN"); setDescription(""); setChapter("");
      setGstRate(5); setEffectiveFrom(new Date().toISOString().slice(0, 10));
    }
    setError(null);
  }, [editing, open]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);
    try {
      const url = editing
        ? `${getApiBase()}/hsn_sac_codes/${editing.id}`
        : `${getApiBase()}/hsn_sac_codes`;
      const res = await fetch(url, {
        method: editing ? "PATCH" : "POST",
        headers: authHeaders(token, orgId),
        body: JSON.stringify({
          hsn_sac_code: { code, code_type: codeType, description, chapter, gst_rate: gstRate, effective_from: effectiveFrom },
        }),
      });
      const json = await res.json();
      if (!res.ok) throw new Error(json.errors?.join(", ") ?? "Failed to save");
      onSaved();
      onClose();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to save");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal open={open} onClose={onClose} title={editing ? "Edit HSN/SAC Code" : "Add HSN/SAC Code"} size="md">
        <form onSubmit={handleSubmit} className="space-y-4 pt-2">
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <label htmlFor="code" className="text-sm font-medium text-text-primary">Code *</label>
              <Input id="code" value={code} onChange={(e) => setCode(e.target.value)} required placeholder="e.g. 10061090" />
            </div>
            <div className="space-y-1.5">
              <label htmlFor="codeType" className="text-sm font-medium text-text-primary">Type *</label>
              <select
                id="codeType"
                value={codeType}
                onChange={(e) => setCodeType(e.target.value as "HSN" | "SAC")}
                className="flex h-9 w-full rounded-md border border-border bg-background px-3 py-1 text-sm shadow-sm focus:outline-none focus:ring-1 focus:ring-accent"
              >
                <option value="HSN">HSN</option>
                <option value="SAC">SAC</option>
              </select>
            </div>
          </div>

          <div className="space-y-1.5">
            <label htmlFor="description" className="text-sm font-medium text-text-primary">Description</label>
            <Input id="description" value={description} onChange={(e) => setDescription(e.target.value)} placeholder="Short description" />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <label htmlFor="chapter" className="text-sm font-medium text-text-primary">Chapter</label>
              <Input id="chapter" value={chapter} onChange={(e) => setChapter(e.target.value)} placeholder="e.g. 10" />
            </div>
            <div className="space-y-1.5">
              <label htmlFor="gstRate" className="text-sm font-medium text-text-primary">GST Rate (%) *</label>
              <select
                id="gstRate"
                value={String(gstRate)}
                onChange={(e) => setGstRate(Number(e.target.value))}
                className="flex h-9 w-full rounded-md border border-border bg-background px-3 py-1 text-sm shadow-sm focus:outline-none focus:ring-1 focus:ring-accent"
              >
                {GST_RATES.map((r) => (
                  <option key={r} value={String(r)}>{r}%</option>
                ))}
              </select>
            </div>
          </div>

          <div className="space-y-1.5">
            <label htmlFor="effectiveFrom" className="text-sm font-medium text-text-primary">Effective From *</label>
            <Input id="effectiveFrom" type="date" value={effectiveFrom} onChange={(e) => setEffectiveFrom(e.target.value)} required />
          </div>

          {error && <p className="rounded-md bg-red-50 px-3 py-2 text-xs text-red-700 dark:bg-red-950/30 dark:text-red-400">{error}</p>}

          <div className="flex justify-end gap-2 pt-1">
            <Button type="button" variant="outline" onClick={onClose}>Cancel</Button>
            <Button type="submit" disabled={saving}>{saving ? "Saving…" : "Save"}</Button>
          </div>
        </form>
    </Modal>
  );
}

// ---------------------------------------------------------------------------
// Rate Change Modal
// ---------------------------------------------------------------------------
interface RateChangeModalProps {
  open: boolean;
  code: HsnSacCode | null;
  onClose: () => void;
  onSaved: () => void;
}

function RateChangeModal({ open, code, onClose, onSaved }: RateChangeModalProps) {
  const { token, orgId } = useOrgBranch();
  const [newRate,        setNewRate]        = useState<number>(5);
  const [effectiveFrom,  setEffectiveFrom]  = useState("");
  const [saving,         setSaving]         = useState(false);
  const [error,          setError]          = useState<string | null>(null);

  useEffect(() => {
    if (code) {
      setNewRate(code.gst_rate);
      setEffectiveFrom(new Date().toISOString().slice(0, 10));
    }
    setError(null);
  }, [code, open]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!code) return;
    setSaving(true);
    setError(null);
    try {
      const res = await fetch(`${getApiBase()}/hsn_sac_codes/${code.id}/rate_change`, {
        method: "POST",
        headers: authHeaders(token, orgId),
        body: JSON.stringify({ gst_rate: newRate, effective_from: effectiveFrom }),
      });
      const json = await res.json();
      if (!res.ok) throw new Error(json.errors?.join(", ") ?? "Failed to change rate");
      onSaved();
      onClose();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to change rate");
    } finally {
      setSaving(false);
    }
  }

  if (!code) return null;

  return (
    <Modal open={open} onClose={onClose} title={`Rate Change — ${code.code}`} size="sm">
        <form onSubmit={handleSubmit} className="space-y-4 pt-2">
          <div className="rounded-md bg-background-subtle px-4 py-3 text-sm">
            <span className="text-text-secondary">Current rate: </span>
            <span className="font-semibold text-text-primary">{code.gst_rate}%</span>
            <span className="ml-3 text-text-secondary">effective </span>
            <span className="font-medium text-text-primary">{formatDate(code.effective_from)}</span>
          </div>

          <div className="space-y-1.5">
            <label htmlFor="newRate" className="text-sm font-medium text-text-primary">New GST Rate (%) *</label>
            <select
              id="newRate"
              value={String(newRate)}
              onChange={(e) => setNewRate(Number(e.target.value))}
              className="flex h-9 w-full rounded-md border border-border bg-background px-3 py-1 text-sm shadow-sm focus:outline-none focus:ring-1 focus:ring-accent"
            >
              {GST_RATES.map((r) => (
                <option key={r} value={String(r)}>{r}%</option>
              ))}
            </select>
          </div>

          <div className="space-y-1.5">
            <label htmlFor="rateEffectiveFrom" className="text-sm font-medium text-text-primary">New Effective From *</label>
            <Input
              id="rateEffectiveFrom"
              type="date"
              value={effectiveFrom}
              onChange={(e) => setEffectiveFrom(e.target.value)}
              required
            />
          </div>

          {error && <p className="rounded-md bg-red-50 px-3 py-2 text-xs text-red-700 dark:bg-red-950/30 dark:text-red-400">{error}</p>}

          <div className="flex justify-end gap-2 pt-1">
            <Button type="button" variant="outline" onClick={onClose}>Cancel</Button>
            <Button type="submit" disabled={saving}>{saving ? "Saving…" : "Apply Rate Change"}</Button>
          </div>
        </form>
    </Modal>
  );
}

// ---------------------------------------------------------------------------
// Bulk Import Modal
// ---------------------------------------------------------------------------
function HsnBulkImportModal({
  onClose, onImported,
}: {
  onClose:    () => void;
  onImported: () => void;
}) {
  const { token, orgId } = useOrgBranch();
  const [file,    setFile]    = useState<File | null>(null);
  const [loading, setLoading] = useState(false);
  const [result,  setResult]  = useState<{
    success_count: number;
    failed_rows:   { row: number; errors: string[] }[];
  } | null>(null);
  const [error,   setError]   = useState("");
  const inputRef = useRef<HTMLInputElement>(null);

  const downloadSample = async () => {
    const hdrs = authHeaders(token, orgId) as Record<string, string>;
    try {
      const res = await fetch(`${getApiBase()}/hsn_sac_codes/sample_csv`, { headers: hdrs });
      const blob = await res.blob();
      const url  = URL.createObjectURL(blob);
      const a    = document.createElement("a");
      a.href = url; a.download = "sample_hsn_sac_codes.csv"; a.click();
      URL.revokeObjectURL(url);
    } catch { /* ignore */ }
  };

  const handleUpload = async () => {
    if (!file) return;
    setLoading(true); setError(""); setResult(null);
    try {
      const { Authorization, "X-Organization-Id": orgIdHeader } = authHeaders(token, orgId) as Record<string, string>;
      if (!Authorization) { setError("Session expired. Please log in again."); return; }
      const fd = new FormData();
      fd.append("file", file);
      const res = await fetch(`${getApiBase()}/hsn_sac_codes/bulk_import`, {
        method:  "POST",
        headers: {
          ...(Authorization ? { Authorization }                 : {}),
          ...(orgIdHeader   ? { "X-Organization-Id": orgIdHeader } : {}),
        },
        body: fd,
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
    <Modal open onClose={onClose} title="Bulk Import HSN / SAC Codes" size="lg">
      <div className="space-y-5">
        <div className="rounded-md border border-border bg-background-subtle px-4 py-3 text-sm text-text-secondary">
          <p className="font-medium text-text-primary mb-1">CSV format</p>
          <p>Required: <code className="font-mono text-xs bg-white border border-border rounded px-1">code</code>, <code className="font-mono text-xs bg-white border border-border rounded px-1">gst_rate</code>, <code className="font-mono text-xs bg-white border border-border rounded px-1">effective_from</code></p>
          <p className="mt-0.5">Optional: <code className="font-mono text-xs bg-white border border-border rounded px-1">code_type</code> (HSN/SAC), <code className="font-mono text-xs bg-white border border-border rounded px-1">description</code>, <code className="font-mono text-xs bg-white border border-border rounded px-1">chapter</code></p>
          <p className="mt-0.5 text-xs">Duplicate (code + effective_from) rows are silently skipped. Max 2,000 rows per file.</p>
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
                      <th className="px-3 py-2 text-left font-semibold text-text-secondary">Error</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border bg-white">
                    {result.failed_rows.map((f) => (
                      <tr key={f.row}>
                        <td className="px-3 py-1.5 tabular-nums text-text-secondary">{f.row}</td>
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

// ---------------------------------------------------------------------------
// Main Page
// ---------------------------------------------------------------------------
export default function HsnCodesPage() {
  const router = useRouter();
  const { token, orgId } = useOrgBranch();

  const [codes,      setCodes]      = useState<HsnSacCode[]>([]);
  const [meta,       setMeta]       = useState<PaginationMeta | null>(null);
  const [loading,    setLoading]    = useState(true);
  const [page,       setPage]       = useState(1);

  // Filters
  const [query,      setQuery]      = useState("");
  const [typeFilter, setTypeFilter] = useState("all");
  const [rateFilter, setRateFilter] = useState("all");

  // Modals
  const [showForm,       setShowForm]       = useState(false);
  const [editingCode,    setEditingCode]    = useState<HsnSacCode | null>(null);
  const [rateChangeCode, setRateChangeCode] = useState<HsnSacCode | null>(null);
  const [showRateChange, setShowRateChange] = useState(false);
  const [showImport,     setShowImport]     = useState(false);

  // Export
  const [exporting,  setExporting]  = useState(false);

  // ---------------------------------------------------------------------------
  // Fetch
  // ---------------------------------------------------------------------------
  const fetchCodes = useCallback(async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams({ page: String(page), per_page: "20" });
      if (query)                params.set("q",         query);
      if (typeFilter !== "all") params.set("code_type", typeFilter);
      if (rateFilter !== "all") params.set("gst_rate",  rateFilter);

      const res = await fetch(`${getApiBase()}/hsn_sac_codes?${params.toString()}`, {
        headers: authHeaders(token, orgId),
      });
      if (res.status === 401) { router.replace("/login"); return; }
      const json = await res.json();
      if (res.ok) {
        setCodes(json.data ?? []);
        setMeta(json.meta ?? null);
      }
    } finally {
      setLoading(false);
    }
  }, [page, query, typeFilter, rateFilter, router, token, orgId]);

  useEffect(() => { fetchCodes(); }, [fetchCodes]);

  // Reset page when filters change
  useEffect(() => { setPage(1); }, [query, typeFilter, rateFilter]);

  // ---------------------------------------------------------------------------
  // Deactivate
  // ---------------------------------------------------------------------------
  async function handleDeactivate(code: HsnSacCode) {
    if (!confirm(`Deactivate HSN code ${code.code}?`)) return;
    const res = await fetch(`${getApiBase()}/hsn_sac_codes/${code.id}`, {
      method: "DELETE",
      headers: authHeaders(token, orgId),
    });
    if (res.ok) fetchCodes();
  }

  // ---------------------------------------------------------------------------
  // Render
  // ---------------------------------------------------------------------------

  async function handleExportCsv() {
    if (exporting) return;
    setExporting(true);
    try {
      const { Authorization, "X-Organization-Id": orgIdHeader } = authHeaders(token, orgId) as Record<string, string>;
      const qs = new URLSearchParams();
      if (query)                qs.set("q",         query);
      if (typeFilter !== "all") qs.set("code_type", typeFilter);
      if (rateFilter !== "all") qs.set("gst_rate",  rateFilter);
      const res = await fetch(`${getApiBase()}/hsn_sac_codes/export_csv?${qs}`, {
        headers: {
          ...(Authorization ? { Authorization } : {}),
          ...(orgIdHeader ? { "X-Organization-Id": orgIdHeader } : {}),
        },
      });
      const blob = await res.blob();
      const url  = URL.createObjectURL(blob);
      const a    = document.createElement("a");
      const cd   = res.headers.get("Content-Disposition") ?? "";
      const name = cd.match(/filename="?([^"]+)"?/)?.[1] ?? "hsn_sac_codes.csv";
      a.href = url; a.download = name; a.click();
      URL.revokeObjectURL(url);
    } finally {
      setExporting(false);
    }
  }
  return (
    <AppShell title="HSN / SAC Codes">
      {/* Breadcrumb */}
      <nav className="mb-3 flex items-center gap-1.5 text-xs text-text-secondary">
        <button onClick={() => router.push("/settings")} className="hover:text-text-primary transition-colors">
          Settings
        </button>
        <ChevronRight className="h-3 w-3" />
        <span className="text-text-primary">HSN / SAC Codes</span>
      </nav>

      <PageHeader
        title="HSN / SAC Codes"
        description="Manage the GST rate master catalogue. Rate changes create an audit trail."
        actions={[
          {
            label: "Bulk Import CSV",
            icon: Upload,
            variant: "outline",
            onClick: () => setShowImport(true),
          },
          {
            label:   exporting ? "Exporting…" : "Export CSV",
            icon:    Download,
            variant: "ghost",
            onClick: handleExportCsv,
          },
          {
            label: "Add HSN Code",
            icon: Plus,
            onClick: () => { setEditingCode(null); setShowForm(true); },
          },
        ]}
      />

      {showImport && (
        <HsnBulkImportModal
          onClose={() => setShowImport(false)}
          onImported={() => { setShowImport(false); fetchCodes(); }}
        />
      )}

      {/* Filter bar */}
      <div className="mb-4 flex flex-wrap gap-2">
        <div className="relative flex-1 min-w-[200px]">
          <Search className="absolute left-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-text-secondary" />
          <Input
            placeholder="Search code or description…"
            className="pl-9 h-8 text-sm"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
        </div>
        <select
          value={typeFilter}
          onChange={(e) => setTypeFilter(e.target.value)}
          className="h-8 rounded-md border border-border bg-background px-2 text-sm focus:outline-none focus:ring-1 focus:ring-accent"
        >
          <option value="all">All Types</option>
          <option value="HSN">HSN</option>
          <option value="SAC">SAC</option>
        </select>
        <select
          value={rateFilter}
          onChange={(e) => setRateFilter(e.target.value)}
          className="h-8 rounded-md border border-border bg-background px-2 text-sm focus:outline-none focus:ring-1 focus:ring-accent"
        >
          <option value="all">All Rates</option>
          {GST_RATES.map((r) => (
            <option key={r} value={String(r)}>{r}% GST</option>
          ))}
        </select>
      </div>

      {/* Table */}
      <Card>
        <CardContent className="p-0">
          {loading ? (
            <div className="space-y-0 divide-y divide-border">
              {Array.from({ length: 8 }).map((_, i) => (
                <div key={i} className="grid grid-cols-[130px_56px_1fr_72px_72px_96px_88px] items-center gap-3 px-4 py-3">
                  <div className="h-3 w-24 animate-pulse rounded bg-border" />
                  <div className="h-3 w-8 animate-pulse rounded bg-border" />
                  <div className="h-3 animate-pulse rounded bg-border" />
                  <div className="h-5 w-10 animate-pulse rounded-full bg-border" />
                  <div className="h-3 w-8 animate-pulse rounded bg-border" />
                  <div className="h-3 w-16 animate-pulse rounded bg-border" />
                  <div className="h-3 w-12 animate-pulse rounded bg-border ml-auto" />
                </div>
              ))}
            </div>
          ) : codes.length === 0 ? (
            <EmptyState onAdd={() => { setEditingCode(null); setShowForm(true); }} />
          ) : (
            <>
              {/* Header row */}
              <div className="grid grid-cols-[130px_56px_1fr_72px_72px_96px_88px] gap-3 border-b border-border bg-background-subtle px-4 py-2 text-xs font-medium uppercase tracking-wider text-text-secondary">
                <span>Code</span>
                <span>Type</span>
                <span>Description</span>
                <span>GST %</span>
                <span>Chapter</span>
                <span>Eff. From</span>
                <span className="text-right">Actions</span>
              </div>
              <div className="divide-y divide-border">
                {codes.map((c) => (
                  <div
                    key={c.id}
                    className={`grid grid-cols-[130px_56px_1fr_72px_72px_96px_88px] items-center gap-3 px-4 py-3 text-sm transition-colors hover:bg-background-subtle ${!c.active ? "opacity-50" : ""}`}
                  >
                    <span className="font-mono font-medium text-text-primary truncate">{c.code}</span>
                    <span className="text-xs text-text-secondary">{c.code_type}</span>
                    <span className="truncate text-text-secondary">{c.description ?? "—"}</span>
                    <span>
                      <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ${gstBadgeVariant(c.gst_rate)}`}>
                        {c.gst_rate}%
                      </span>
                    </span>
                    <span className="text-xs text-text-secondary">{c.chapter ?? "—"}</span>
                    <span className="text-xs text-text-secondary">{formatDate(c.effective_from)}</span>
                    <div className="flex items-center justify-end gap-0.5">
                      <Button
                        size="icon"
                        variant="ghost"
                        className="h-7 w-7"
                        title="Edit"
                        onClick={() => { setEditingCode(c); setShowForm(true); }}
                      >
                        <Pencil className="h-3.5 w-3.5" />
                      </Button>
                      <Button
                        size="icon"
                        variant="ghost"
                        className={`h-7 w-7 transition-opacity ${c.active && c.current_rate ? "opacity-100" : "opacity-0 pointer-events-none"}`}
                        title="Rate Change"
                        onClick={() => { if (c.active && c.current_rate) { setRateChangeCode(c); setShowRateChange(true); } }}
                      >
                        <TrendingUp className="h-3.5 w-3.5" />
                      </Button>
                      <Button
                        size="icon"
                        variant="ghost"
                        className={`h-7 w-7 text-destructive hover:text-destructive transition-opacity ${c.active ? "opacity-100" : "opacity-0 pointer-events-none"}`}
                        title="Deactivate"
                        onClick={() => { if (c.active) handleDeactivate(c); }}
                      >
                        <Ban className="h-3.5 w-3.5" />
                      </Button>
                    </div>
                  </div>
                ))}
              </div>
            </>
          )}
        </CardContent>
      </Card>

      {/* Pagination */}
      {meta && meta.total_pages > 1 && (
        <div className="mt-4 flex items-center justify-between text-sm text-text-secondary">
          <span>{meta.total_count} total codes</span>
          <div className="flex items-center gap-2">
            <Button
              size="sm"
              variant="outline"
              disabled={page <= 1}
              onClick={() => setPage((p) => p - 1)}
            >
              <ChevronLeft className="h-4 w-4" />
            </Button>
            <span className="text-xs">
              Page {meta.current_page} / {meta.total_pages}
            </span>
            <Button
              size="sm"
              variant="outline"
              disabled={page >= meta.total_pages}
              onClick={() => setPage((p) => p + 1)}
            >
              <ChevronRight className="h-4 w-4" />
            </Button>
          </div>
        </div>
      )}

      {/* Modals */}
      <CodeFormModal
        open={showForm}
        editing={editingCode}
        onClose={() => setShowForm(false)}
        onSaved={fetchCodes}
      />
      <RateChangeModal
        open={showRateChange}
        code={rateChangeCode}
        onClose={() => setShowRateChange(false)}
        onSaved={fetchCodes}
      />
    </AppShell>
  );
}
