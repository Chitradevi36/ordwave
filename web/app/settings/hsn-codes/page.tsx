"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Modal } from "@/components/ui/modal";
import {
  ChevronLeft,
  ChevronRight,
  Plus,
  Search,
  Upload,
  Pencil,
  TrendingUp,
  Ban,
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
  return process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3001/api/v1";
}

function authHeaders(): Record<string, string> {
  const token =
    typeof window !== "undefined" ? localStorage.getItem("auth_token") : null;
  const orgId =
    typeof window !== "undefined"
      ? localStorage.getItem("organization_id")
      : null;
  return {
    "Content-Type": "application/json",
    ...(token  ? { Authorization: `Bearer ${token}` }  : {}),
    ...(orgId  ? { "X-Organization-Id": orgId }        : {}),
  };
}

function gstBadgeVariant(rate: number): string {
  const map: Record<number, string> = {
    0:  "bg-muted text-muted-foreground border border-border",
    5:  "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400",
    12: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400",
    18: "bg-orange-100 text-orange-800 dark:bg-orange-900/30 dark:text-orange-400",
    28: "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400",
  };
  return map[rate] ?? "bg-muted text-muted-foreground";
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
        headers: authHeaders(),
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
        headers: authHeaders(),
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
// Main Page
// ---------------------------------------------------------------------------
export default function HsnCodesPage() {
  const router = useRouter();

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

  // Bulk import
  const [importing,  setImporting]  = useState(false);
  const [importMsg,  setImportMsg]  = useState<{ type: "success" | "error"; text: string } | null>(null);
  const importDismissRef = useRef<ReturnType<typeof setTimeout> | null>(null);

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
        headers: authHeaders(),
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
  }, [page, query, typeFilter, rateFilter, router]);

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
      headers: authHeaders(),
    });
    if (res.ok) fetchCodes();
  }

  // ---------------------------------------------------------------------------
  // Bulk import
  // ---------------------------------------------------------------------------
  function scheduleImportDismiss() {
    if (importDismissRef.current) clearTimeout(importDismissRef.current);
    importDismissRef.current = setTimeout(() => setImportMsg(null), 8000);
  }

  async function handleBulkImport(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setImporting(true);
    setImportMsg(null);
    try {
      const { Authorization, "X-Organization-Id": orgId } = authHeaders() as Record<string, string>;
      if (!Authorization) {
        setImportMsg({ type: "error", text: "Session expired. Please log in again." });
        return;
      }
      const form = new FormData();
      form.append("file", file);
      const res = await fetch(`${getApiBase()}/hsn_sac_codes/bulk_import`, {
        method: "POST",
        headers: {
          ...(Authorization ? { Authorization } : {}),
          ...(orgId ? { "X-Organization-Id": orgId } : {}),
        },
        body: form,
      });
      if (res.status === 401) {
        setImportMsg({ type: "error", text: "Session expired. Please log in again." });
        return;
      }
      const json = await res.json();
      if (res.ok) {
        const d = json.data;
        const skippedNote = d.skipped_rows?.length  ? ` ${d.skipped_rows.length} skipped (duplicates).`  : "";
        const failedNote  = d.failed_rows?.length   ? ` ${d.failed_rows.length} failed.`                  : "";
        setImportMsg({ type: "success", text: `${d.success_count} codes imported.${skippedNote}${failedNote}` });
        scheduleImportDismiss();
        fetchCodes();
      } else {
        setImportMsg({ type: "error", text: json.errors?.join(", ") ?? "Import failed" });
        scheduleImportDismiss();
      }
    } finally {
      setImporting(false);
      e.target.value = "";
    }
  }

  // ---------------------------------------------------------------------------
  // Render
  // ---------------------------------------------------------------------------
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
            label: importing ? "Importing…" : "Bulk Import CSV",
            icon: Upload,
            variant: "outline",
            onClick: () => document.getElementById("bulk-import-input")?.click(),
          },
          {
            label: "Add HSN Code",
            icon: Plus,
            onClick: () => { setEditingCode(null); setShowForm(true); },
          },
        ]}
      />

      {/* Hidden file input */}
      <input
        id="bulk-import-input"
        type="file"
        accept=".csv"
        className="sr-only"
        onChange={handleBulkImport}
      />

      {/* Import feedback + sample download */}
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <a href="/samples/sample_hsn_sac_codes.csv" download className="text-xs text-accent hover:underline">
          Download sample CSV
        </a>
        {meta && (
          <span className="text-xs text-text-secondary">
            {meta.total_count} code{meta.total_count !== 1 ? "s" : ""} total
          </span>
        )}
      </div>

      {/* Import result banner */}
      {importMsg && (
        <div className={`mb-4 flex items-center justify-between rounded-md px-4 py-2.5 text-sm ${
          importMsg.type === "success"
            ? "bg-green-50 text-green-800 dark:bg-green-950/30 dark:text-green-400"
            : "bg-red-50 text-red-700 dark:bg-red-950/30 dark:text-red-400"
        }`}>
          <span>{importMsg.text}</span>
          <button
            onClick={() => setImportMsg(null)}
            className="ml-4 text-current opacity-60 hover:opacity-100 transition-opacity"
            aria-label="Dismiss"
          >
            ✕
          </button>
        </div>
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
