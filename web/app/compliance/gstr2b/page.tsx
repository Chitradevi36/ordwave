"use client";

import { useState, useCallback, useEffect, useRef } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { useOrgBranch } from "@/lib/org-branch-context";
import { Upload, RefreshCw, ChevronDown, CheckCircle2, XCircle, AlertTriangle, Clock } from "lucide-react";

// ── Types ─────────────────────────────────────────────────────────────────────

interface Gst2bImport {
  id: number;
  gstin: string;
  month: number;
  year: number;
  period_label: string;
  file_name: string | null;
  import_status: string;
  total_rows: number;
  matched_rows: number;
  unmatched_rows: number;
  match_rate: number;
  imported_at: string | null;
  error_message: string | null;
}

interface ImportLine {
  id: number;
  supplier_gstin: string;
  supplier_name: string | null;
  invoice_number: string;
  invoice_date: string | null;
  invoice_value: number | null;
  taxable_value: number | null;
  igst: number | null;
  cgst: number | null;
  sgst: number | null;
  cess: number | null;
  document_type: string | null;
  section_type: string | null;
  match_status: string;
  match_confidence: number | null;
  match_explanation: string | null;
  matched_purchase_invoice_id: number | null;
}

interface LinesResponse {
  total: number;
  page: number;
  per_page: number;
  lines: ImportLine[];
}

// ── Helpers ────────────────────────────────────────────────────────────────────

const fmt = (n: number | null | undefined) =>
  n == null ? "—" : `₹ ${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2 })}`;

const MONTHS = [
  "January","February","March","April","May","June",
  "July","August","September","October","November","December",
];
const _now = new Date();
const currentYear  = _now.getFullYear();
const currentMonth = _now.getMonth() + 1;
const defaultMonth = currentMonth === 1 ? 12 : currentMonth - 1;
const defaultYear  = currentMonth === 1 ? currentYear - 1 : currentYear;
const YEARS = Array.from({ length: 4 }, (_, i) => currentYear - i);

const MATCH_STATUS_META: Record<string, { label: string; color: string }> = {
  matched:             { label: "Matched",           color: "bg-green-100 text-green-700" },
  missing_in_books:    { label: "Missing in Books",  color: "bg-red-100 text-red-700" },
  missing_in_2b:       { label: "Missing in 2B",     color: "bg-orange-100 text-orange-700" },
  tax_mismatch:        { label: "Tax Mismatch",       color: "bg-yellow-100 text-yellow-700" },
  date_mismatch:       { label: "Date Mismatch",      color: "bg-yellow-100 text-yellow-700" },
  gstin_mismatch:      { label: "GSTIN Mismatch",     color: "bg-yellow-100 text-yellow-700" },
  multiple_candidates: { label: "Multiple Matches",   color: "bg-purple-100 text-purple-700" },
  partial_match:       { label: "Partial Match",      color: "bg-blue-100 text-blue-700" },
  ignored:             { label: "Ignored",            color: "bg-gray-100 text-gray-500" },
  pending:             { label: "Pending",             color: "bg-gray-100 text-gray-600" },
};

const IMPORT_STATUS_META: Record<string, { icon: React.ReactNode; color: string }> = {
  completed: { icon: <CheckCircle2 className="h-4 w-4" />, color: "text-green-600" },
  failed:    { icon: <XCircle className="h-4 w-4" />,      color: "text-red-600" },
  parsing:   { icon: <RefreshCw className="h-4 w-4 animate-spin" />, color: "text-blue-500" },
  matching:  { icon: <RefreshCw className="h-4 w-4 animate-spin" />, color: "text-blue-500" },
  uploaded:  { icon: <Clock className="h-4 w-4" />,        color: "text-gray-500" },
  parsed:    { icon: <Clock className="h-4 w-4" />,        color: "text-blue-500" },
};

const sel = "h-9 rounded-md border border-border bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary";
const thL = "px-4 py-3 text-left text-xs font-semibold text-text-secondary uppercase tracking-wide";
const thR = "px-4 py-3 text-right text-xs font-semibold text-text-secondary uppercase tracking-wide";
const tdL = "px-4 py-2.5";
const tdR = "px-4 py-2.5 text-right tabular-nums";

// ── Page ──────────────────────────────────────────────────────────────────────

export default function Gstr2bPage() {
  const { token, orgId } = useOrgBranch();

  const [month, setMonth] = useState(defaultMonth);
  const [year, setYear]   = useState(defaultYear);

  const [imports, setImports] = useState<Gst2bImport[]>([]);
  const [loadingImports, setLoadingImports] = useState(false);
  const [importsError, setImportsError] = useState<string | null>(null);

  const [selectedImport, setSelectedImport] = useState<Gst2bImport | null>(null);
  const [lines, setLines]       = useState<LinesResponse | null>(null);
  const [loadingLines, setLoadingLines] = useState(false);
  const [lineFilter, setLineFilter] = useState<string>("all");

  // Upload state
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const [uploadSuccess, setUploadSuccess] = useState<string | null>(null);
  const [gstin, setGstin] = useState("");
  const fileRef = useRef<HTMLInputElement>(null);

  const headers = useCallback(() => ({
    Authorization: `Bearer ${token}`,
    "X-Organization-Id": orgId ?? "",
  }), [token, orgId]);

  // ── Fetch import list ──────────────────────────────────────────────────────
  const fetchImports = useCallback(async () => {
    if (!token || !orgId) return;
    setLoadingImports(true);
    setImportsError(null);
    try {
      const res = await fetch(
        `/api/v1/compliance/gstr2b/imports?month=${month}&year=${year}`,
        { headers: headers() }
      );
      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "Failed to load imports");
      setImports(body.data ?? []);
    } catch (e) {
      setImportsError(e instanceof Error ? e.message : "Failed to load imports");
    } finally {
      setLoadingImports(false);
    }
  }, [token, orgId, month, year, headers]);

  useEffect(() => {
    if (token && orgId) fetchImports();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [month, year, token, orgId]);

  // ── Fetch lines for selected import ───────────────────────────────────────
  const fetchLines = useCallback(async (importId: number, status = "all") => {
    if (!token || !orgId) return;
    setLoadingLines(true);
    try {
      const params = status !== "all" ? `?match_status=${status}` : "";
      const res = await fetch(
        `/api/v1/compliance/gstr2b/imports/${importId}/lines${params}`,
        { headers: headers() }
      );
      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "Failed to load lines");
      setLines(body.data);
    } catch (e) {
      setLines(null);
    } finally {
      setLoadingLines(false);
    }
  }, [token, orgId, headers]);

  const handleSelectImport = (imp: Gst2bImport) => {
    setSelectedImport(imp);
    setLineFilter("all");
    fetchLines(imp.id, "all");
  };

  const handleLineFilterChange = (status: string) => {
    setLineFilter(status);
    if (selectedImport) fetchLines(selectedImport.id, status);
  };

  // ── File upload ────────────────────────────────────────────────────────────
  const handleUpload = async () => {
    const file = fileRef.current?.files?.[0];
    if (!file || !gstin.trim()) {
      setUploadError("Provide a GSTIN and select a JSON file.");
      return;
    }
    setUploading(true);
    setUploadError(null);
    setUploadSuccess(null);
    try {
      const text = await file.text();
      const payload = JSON.parse(text);
      const res = await fetch("/api/v1/compliance/gstr2b/import", {
        method: "POST",
        headers: { ...headers(), "Content-Type": "application/json" },
        body: JSON.stringify({
          gstin:        gstin.trim().toUpperCase(),
          month,
          year,
          json_payload: payload,
        }),
      });
      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "Upload failed");
      setUploadSuccess(`Imported successfully — ${body.data.total_rows} rows, ${body.data.matched_rows} matched`);
      if (fileRef.current) fileRef.current.value = "";
      await fetchImports();
    } catch (e) {
      setUploadError(e instanceof Error ? e.message : "Upload failed");
    } finally {
      setUploading(false);
    }
  };

  // ── Render ──────────────────────────────────────────────────────────────────
  return (
    <AppShell title="GSTR-2B Import" hideBreadcrumb>
      <PageHeader
        title="GSTR-2B Import"
        subtitle="Import GSTR-2B JSON from the GST portal and reconcile with purchase books"
      />

      <div className="space-y-6">

        {/* ── Period filter ────────────────────────────────────────────── */}
        <div className="flex items-center gap-3 flex-wrap">
          <div className="flex items-center gap-2">
            <label className="text-sm font-medium text-text-secondary">Month</label>
            <select className={sel} value={month} onChange={e => setMonth(Number(e.target.value))}>
              {MONTHS.map((m, i) => <option key={i + 1} value={i + 1}>{m}</option>)}
            </select>
          </div>
          <div className="flex items-center gap-2">
            <label className="text-sm font-medium text-text-secondary">Year</label>
            <select className={sel} value={year} onChange={e => setYear(Number(e.target.value))}>
              {YEARS.map(y => <option key={y} value={y}>{y}</option>)}
            </select>
          </div>
          <Button variant="outline" onClick={fetchImports} disabled={loadingImports}>
            <RefreshCw className={`h-3.5 w-3.5 mr-1.5 ${loadingImports ? "animate-spin" : ""}`} />
            Refresh
          </Button>
        </div>

        {/* ── Upload panel ─────────────────────────────────────────────── */}
        <div className="rounded-lg border bg-card p-5 space-y-4">
          <h3 className="text-sm font-semibold">Upload GSTR-2B JSON</h3>
          <div className="flex items-end gap-3 flex-wrap">
            <div className="flex flex-col gap-1">
              <label className="text-xs text-text-secondary font-medium">Your GSTIN</label>
              <input
                className="h-9 rounded-md border border-border bg-background px-3 text-sm w-48 focus:outline-none focus:ring-2 focus:ring-primary font-mono uppercase"
                placeholder="27AAPFU0939F1ZV"
                value={gstin}
                onChange={e => setGstin(e.target.value)}
                maxLength={15}
              />
            </div>
            <div className="flex flex-col gap-1">
              <label className="text-xs text-text-secondary font-medium">JSON File</label>
              <input
                ref={fileRef}
                type="file"
                accept=".json,application/json"
                className="h-9 text-sm file:mr-3 file:py-1 file:px-3 file:rounded file:border-0 file:text-sm file:font-medium file:bg-muted file:text-text-primary hover:file:bg-muted/80 cursor-pointer"
              />
            </div>
            <Button onClick={handleUpload} disabled={uploading} className="bg-primary hover:bg-primary-700">
              <Upload className="h-3.5 w-3.5 mr-1.5" />
              {uploading ? "Uploading…" : "Import"}
            </Button>
          </div>
          {uploadError && (
            <div className="rounded-md bg-destructive/10 border border-destructive/30 px-4 py-2.5 text-sm text-destructive">
              {uploadError}
            </div>
          )}
          {uploadSuccess && (
            <div className="rounded-md bg-green-50 border border-green-200 px-4 py-2.5 text-sm text-green-700 flex items-center gap-2">
              <CheckCircle2 className="h-4 w-4 shrink-0" />
              {uploadSuccess}
            </div>
          )}
        </div>

        {/* ── Error banner ─────────────────────────────────────────────── */}
        {importsError && (
          <div className="rounded-md bg-destructive/10 border border-destructive/30 px-4 py-3 text-sm text-destructive">
            {importsError}
          </div>
        )}

        {/* ── Main content: import list + lines ────────────────────────── */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">

          {/* Import list */}
          <div className="lg:col-span-1 rounded-lg border overflow-hidden">
            <div className="bg-muted/40 px-4 py-3 border-b">
              <p className="text-xs font-semibold text-text-secondary uppercase tracking-wide">
                Imports for {MONTHS[month - 1]} {year}
              </p>
            </div>
            {loadingImports ? (
              <div className="space-y-2 p-4 animate-pulse">
                {[0,1,2].map(i => <div key={i} className="h-14 rounded bg-muted/40" />)}
              </div>
            ) : imports.length === 0 ? (
              <div className="py-12 text-center text-sm text-text-secondary">
                No imports for this period.
              </div>
            ) : (
              <div className="divide-y">
                {imports.map(imp => {
                  const meta = IMPORT_STATUS_META[imp.import_status] ?? IMPORT_STATUS_META.uploaded;
                  const active = selectedImport?.id === imp.id;
                  return (
                    <button
                      key={imp.id}
                      onClick={() => handleSelectImport(imp)}
                      className={`w-full text-left px-4 py-3 transition-colors ${
                        active ? "bg-primary/5 border-l-2 border-primary" : "hover:bg-muted/20"
                      }`}
                    >
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-xs font-mono font-medium text-text-primary truncate max-w-[140px]">
                          {imp.gstin}
                        </span>
                        <span className={`flex items-center gap-1 text-xs ${meta.color}`}>
                          {meta.icon}
                          {imp.import_status}
                        </span>
                      </div>
                      {imp.import_status === "completed" && (
                        <div className="flex items-center gap-3 mt-1">
                          <span className="text-xs text-text-secondary">{imp.total_rows} rows</span>
                          <span className="text-xs text-green-600">{imp.matched_rows} matched</span>
                          <span className="text-xs text-text-secondary">{imp.match_rate}%</span>
                        </div>
                      )}
                      {imp.import_status === "failed" && (
                        <p className="text-xs text-red-600 mt-1 truncate">{imp.error_message}</p>
                      )}
                      {imp.file_name && (
                        <p className="text-xs text-text-secondary mt-0.5 truncate">{imp.file_name}</p>
                      )}
                    </button>
                  );
                })}
              </div>
            )}
          </div>

          {/* Lines panel */}
          <div className="lg:col-span-2 rounded-lg border overflow-hidden">
            {!selectedImport ? (
              <div className="flex flex-col items-center justify-center h-64 text-sm text-text-secondary">
                <ChevronDown className="h-8 w-8 mb-3 text-border" />
                Select an import to view reconciliation lines
              </div>
            ) : (
              <>
                {/* Header + filter */}
                <div className="bg-muted/40 px-4 py-3 border-b flex items-center justify-between gap-3 flex-wrap">
                  <p className="text-xs font-semibold text-text-secondary uppercase tracking-wide">
                    Lines — {selectedImport.gstin}
                  </p>
                  <div className="flex items-center gap-2">
                    <label className="text-xs text-text-secondary">Filter</label>
                    <select
                      className="h-7 rounded border border-border bg-background px-2 text-xs focus:outline-none focus:ring-1 focus:ring-primary"
                      value={lineFilter}
                      onChange={e => handleLineFilterChange(e.target.value)}
                    >
                      <option value="all">All</option>
                      <option value="matched">Matched</option>
                      <option value="missing_in_books">Missing in Books</option>
                      <option value="tax_mismatch">Tax Mismatch</option>
                      <option value="multiple_candidates">Multiple Candidates</option>
                      <option value="pending">Pending</option>
                    </select>
                  </div>
                </div>

                {/* Match rate bar */}
                {selectedImport.import_status === "completed" && (
                  <div className="px-4 py-3 border-b bg-card flex items-center gap-4 text-sm">
                    <div className="flex-1">
                      <div className="flex justify-between text-xs text-text-secondary mb-1">
                        <span>Match rate</span>
                        <span className="font-semibold tabular-nums">{selectedImport.match_rate}%</span>
                      </div>
                      <div className="h-1.5 rounded-full bg-muted overflow-hidden">
                        <div
                          className="h-full rounded-full bg-green-500 transition-all"
                          style={{ width: `${selectedImport.match_rate}%` }}
                        />
                      </div>
                    </div>
                    <div className="flex gap-5 text-xs">
                      <span className="text-green-600 tabular-nums font-medium">{selectedImport.matched_rows} matched</span>
                      <span className="text-red-500 tabular-nums font-medium">{selectedImport.unmatched_rows} unmatched</span>
                    </div>
                  </div>
                )}

                {/* Lines table */}
                <div className="overflow-x-auto">
                  {loadingLines ? (
                    <div className="space-y-2 p-4 animate-pulse">
                      {[0,1,2,3,4].map(i => <div key={i} className="h-10 rounded bg-muted/40" />)}
                    </div>
                  ) : !lines || lines.lines.length === 0 ? (
                    <div className="py-12 text-center text-sm text-text-secondary">
                      No lines found
                      {lineFilter !== "all" ? ` with status "${lineFilter}"` : ""}
                    </div>
                  ) : (
                    <table className="w-full text-sm">
                      <thead className="bg-muted/40 border-b">
                        <tr>
                          <th className={thL}>Invoice #</th>
                          <th className={thL}>Supplier GSTIN</th>
                          <th className={thL}>Date</th>
                          <th className={thR}>Taxable</th>
                          <th className={thR}>IGST</th>
                          <th className={thR}>CGST+SGST</th>
                          <th className={thL}>Status</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y">
                        {lines.lines.map(line => {
                          const ms = MATCH_STATUS_META[line.match_status] ?? { label: line.match_status, color: "bg-gray-100 text-gray-600" };
                          return (
                            <tr key={line.id} className="hover:bg-muted/20 transition-colors">
                              <td className={`${tdL} font-mono text-xs font-medium max-w-[140px] truncate`}>
                                {line.invoice_number}
                              </td>
                              <td className={`${tdL} font-mono text-xs text-text-secondary`}>
                                {line.supplier_gstin}
                              </td>
                              <td className={`${tdL} text-text-secondary text-xs`}>
                                {line.invoice_date ?? "—"}
                              </td>
                              <td className={tdR}>{fmt(line.taxable_value)}</td>
                              <td className={tdR}>{fmt(line.igst)}</td>
                              <td className={tdR}>
                                {line.cgst != null && line.sgst != null
                                  ? fmt((line.cgst ?? 0) + (line.sgst ?? 0))
                                  : "—"}
                              </td>
                              <td className={tdL}>
                                <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${ms.color}`}>
                                  {ms.label}
                                </span>
                              </td>
                            </tr>
                          );
                        })}
                      </tbody>
                    </table>
                  )}
                </div>

                {/* Pagination summary */}
                {lines && lines.total > lines.per_page && (
                  <div className="px-4 py-2.5 border-t text-xs text-text-secondary bg-muted/20">
                    Showing {lines.lines.length} of {lines.total} lines
                  </div>
                )}
              </>
            )}
          </div>
        </div>

        {/* ── Problems summary ─────────────────────────────────────────── */}
        {selectedImport && selectedImport.import_status === "completed" && selectedImport.unmatched_rows > 0 && (
          <div className="rounded-lg border border-yellow-200 bg-yellow-50 px-5 py-4 flex items-start gap-3">
            <AlertTriangle className="h-5 w-5 text-yellow-600 shrink-0 mt-0.5" />
            <div className="text-sm">
              <p className="font-semibold text-yellow-800">
                {selectedImport.unmatched_rows} unmatched lines require attention
              </p>
              <p className="text-yellow-700 mt-0.5">
                Run the reconciliation engine to generate detailed issues for review.
                Go to <a href="/compliance/reconciliation" className="underline font-medium">Reconciliation</a>.
              </p>
            </div>
          </div>
        )}
      </div>
    </AppShell>
  );
}
