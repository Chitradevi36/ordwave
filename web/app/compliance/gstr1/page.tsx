"use client";

import { useState, useCallback, useEffect } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { useOrgBranch } from "@/lib/org-branch-context";
import { FileSpreadsheet, Download, RefreshCw } from "lucide-react";

// ── Types ─────────────────────────────────────────────────────────────────────

interface B2BEntry {
  customer_name: string;
  gstin:         string;
  invoice_count: number;
  taxable_value: number;
  tax_amount:    number;
  total:         number;
}

interface B2CEntry {
  state:         string;
  invoice_count: number;
  taxable_value: number;
  tax_amount:    number;
  total:         number;
}

interface CdnrEntry {
  customer_name: string;
  gstin:         string;
  note_count:    number;
  taxable_value: number;
  tax_amount:    number;
}

interface HsnEntry {
  hsn_code:      string;
  description:   string | null;
  uqc:           string;
  qty:           number;
  taxable_value: number;
  igst:          number;
  cgst:          number;
  sgst:          number;
  cess:          number;
}

interface Gstr1Preview {
  period:        string;
  b2b:           B2BEntry[];
  b2c:           B2CEntry[];
  cdnr:          CdnrEntry[];
  hsn_summary:   HsnEntry[];
  summary: {
    total_invoices:   number;
    total_taxable:    number;
    total_tax:        number;
    total_value:      number;
  };
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const fmt   = (n: number) => `₹ ${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2 })}`;
const MONTHS = ["January","February","March","April","May","June","July","August","September","October","November","December"];

const _now         = new Date();
const currentYear  = _now.getFullYear();
const currentMonth = _now.getMonth() + 1; // 1-12

// Default to the previous month (rolls back to December of prior year in January)
const defaultMonth = currentMonth === 1 ? 12 : currentMonth - 1;
const defaultYear  = currentMonth === 1 ? currentYear - 1 : currentYear;

const YEARS = Array.from({ length: 4 }, (_, i) => currentYear - i);

// ── Page ──────────────────────────────────────────────────────────────────────

export default function Gstr1Page() {
  const { token, orgId } = useOrgBranch();

  const [month, setMonth]       = useState(defaultMonth);
  const [year, setYear]         = useState(defaultYear);
  const [preview, setPreview]   = useState<Gstr1Preview | null>(null);
  const [loading, setLoading]   = useState(false);
  const [error, setError]       = useState<string | null>(null);
  const [downloading, setDownloading] = useState(false);
  const [activeSection, setActiveSection] = useState<"b2b" | "b2c" | "cdnr" | "hsn">("b2b");

  const fetchPreview = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(
        `/api/v1/compliance/gstr1/preview?month=${month}&year=${year}`,
        { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId } }
      );
      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "Failed to fetch preview");
      setPreview(body.data);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  }, [token, orgId, month, year]);

  const handleDownloadJson = async () => {
    if (!token || !orgId) return;
    setDownloading(true);
    try {
      const res = await fetch(
        `/api/v1/compliance/gstr1/export?month=${month}&year=${year}&format=json`,
        { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId } }
      );
      if (!res.ok) {
        let msg = "Export failed";
        try {
          const errBody = await res.json();
          msg = errBody.errors?.join(", ") || errBody.message || msg;
        } catch { /* non-JSON body */ }
        throw new Error(msg);
      }
      const blob = await res.blob();
      const url  = URL.createObjectURL(blob);
      const a    = document.createElement("a");
      a.href     = url;
      a.download = `GSTR1_${year}_${String(month).padStart(2, "0")}.json`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Export failed");
    } finally {
      setDownloading(false);
    }
  };

  // Auto-fetch on mount and whenever month / year / org changes
  useEffect(() => {
    if (token && orgId) fetchPreview();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [month, year, token, orgId]);

  const sel = "h-9 rounded-md border border-border bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary";

  // Reusable th alignment helper
  const thLeft  = "px-4 py-3 text-left   text-xs font-semibold text-text-secondary uppercase tracking-wide";
  const thRight = "px-4 py-3 text-right  text-xs font-semibold text-text-secondary uppercase tracking-wide";
  const tdLeft  = "px-4 py-2.5";
  const tdRight = "px-4 py-2.5 text-right tabular-nums";

  return (
    <AppShell title="GSTR-1 Export" hideBreadcrumb>
      <PageHeader
        title="GSTR-1 Export"
        subtitle="Generate and download GST Return 1 data"
        actions={[
          {
            label:    downloading ? "Exporting…" : "Download JSON",
            onClick:  handleDownloadJson,
            variant:  "outline",
            icon:     Download,
            disabled: downloading || loading,
          },
        ]}
      />

      <div className="space-y-6">
        {/* ── Filters ──────────────────────────────────────────────────── */}
        <div className="flex items-center gap-3 flex-wrap">
          <div className="flex items-center gap-2">
            <label className="text-sm font-medium text-text-secondary">Month</label>
            <select className={sel} value={month} onChange={(e) => setMonth(Number(e.target.value))}>
              {MONTHS.map((m, i) => (
                <option key={i + 1} value={i + 1}>{m}</option>
              ))}
            </select>
          </div>
          <div className="flex items-center gap-2">
            <label className="text-sm font-medium text-text-secondary">Year</label>
            <select className={sel} value={year} onChange={(e) => setYear(Number(e.target.value))}>
              {YEARS.map((y) => (
                <option key={y} value={y}>{y}</option>
              ))}
            </select>
          </div>
          <Button onClick={fetchPreview} disabled={loading}>
            <RefreshCw className={`h-3.5 w-3.5 mr-1.5 ${loading ? "animate-spin" : ""}`} />
            {loading ? "Fetching…" : "Fetch Preview"}
          </Button>
        </div>

        {/* ── Error banner ──────────────────────────────────────────────── */}
        {error && (
          <div className="rounded-md bg-destructive/10 border border-destructive/30 px-4 py-3 text-sm text-destructive">
            {error}
          </div>
        )}

        {/* ── Preview content ───────────────────────────────────────────── */}
        {loading && !preview && (
          <div className="space-y-4 animate-pulse">
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
              {[0,1,2,3].map(i => (
                <div key={i} className="rounded-lg border bg-card px-5 py-4 h-20" />
              ))}
            </div>
            <div className="rounded-lg border bg-card h-48" />
          </div>
        )}
        {preview && (
          <div className="space-y-6">
            {/* Summary cards */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
              {[
                { label: "Total Invoices", value: String(preview.summary.total_invoices), mono: false },
                { label: "Taxable Value",  value: fmt(preview.summary.total_taxable),     mono: true  },
                { label: "Total Tax",      value: fmt(preview.summary.total_tax),          mono: true  },
                { label: "Grand Total",    value: fmt(preview.summary.total_value),        mono: true  },
              ].map(({ label, value, mono }) => (
                <div key={label} className="rounded-lg border bg-card px-5 py-4">
                  <p className="text-xs text-text-secondary mb-1">{label}</p>
                  <p className={`text-xl font-bold tabular-nums ${mono ? "" : "text-2xl"}`}>{value}</p>
                </div>
              ))}
            </div>

            {/* Section tabs */}
            <div className="border-b">
              <div className="flex gap-0">
                {(["b2b", "b2c", "cdnr", "hsn"] as const).map((s) => (
                  <button
                    key={s}
                    onClick={() => setActiveSection(s)}
                    className={`px-5 py-2.5 text-sm font-medium border-b-2 transition-colors ${
                      activeSection === s
                        ? "border-primary text-primary"
                        : "border-transparent text-text-secondary hover:text-text-primary"
                    }`}
                  >
                    {s.toUpperCase()}
                    <Badge variant="secondary" className="ml-2 text-xs">
                      {s === "b2b" ? preview.b2b.length
                        : s === "b2c" ? preview.b2c.length
                        : s === "cdnr" ? preview.cdnr.length
                        : preview.hsn_summary.length}
                    </Badge>
                  </button>
                ))}
              </div>
            </div>

            {/* ── B2B ────────────────────────────────────────────────────── */}
            {activeSection === "b2b" && (
              <div className="rounded-lg border overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="bg-muted/40 border-b">
                    <tr>
                      <th className={thLeft}>Customer</th>
                      <th className={thLeft}>GSTIN</th>
                      <th className={thRight}>Invoices</th>
                      <th className={thRight}>Taxable Value</th>
                      <th className={thRight}>Tax Amount</th>
                      <th className={thRight}>Total</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y">
                    {preview.b2b.length === 0 ? (
                      <tr><td colSpan={6} className="px-4 py-10 text-center text-text-secondary text-sm">No B2B invoices for this period</td></tr>
                    ) : preview.b2b.map((row, i) => (
                      <tr key={i} className="hover:bg-muted/20 transition-colors">
                        <td className={`${tdLeft} font-medium`}>{row.customer_name}</td>
                        <td className={`${tdLeft} font-mono text-xs text-text-secondary`}>{row.gstin}</td>
                        <td className={tdRight}>{row.invoice_count}</td>
                        <td className={tdRight}>{fmt(row.taxable_value)}</td>
                        <td className={tdRight}>{fmt(row.tax_amount)}</td>
                        <td className={`${tdRight} font-semibold`}>{fmt(row.total)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}

            {/* ── B2C ────────────────────────────────────────────────────── */}
            {activeSection === "b2c" && (
              <div className="rounded-lg border overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="bg-muted/40 border-b">
                    <tr>
                      <th className={thLeft}>State</th>
                      <th className={thRight}>Invoices</th>
                      <th className={thRight}>Taxable Value</th>
                      <th className={thRight}>Tax Amount</th>
                      <th className={thRight}>Total</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y">
                    {preview.b2c.length === 0 ? (
                      <tr><td colSpan={5} className="px-4 py-10 text-center text-text-secondary text-sm">No B2C invoices for this period</td></tr>
                    ) : preview.b2c.map((row, i) => (
                      <tr key={i} className="hover:bg-muted/20 transition-colors">
                        <td className={`${tdLeft} font-medium`}>{row.state}</td>
                        <td className={tdRight}>{row.invoice_count}</td>
                        <td className={tdRight}>{fmt(row.taxable_value)}</td>
                        <td className={tdRight}>{fmt(row.tax_amount)}</td>
                        <td className={`${tdRight} font-semibold`}>{fmt(row.total)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}

            {/* ── CDNR ───────────────────────────────────────────────────── */}
            {activeSection === "cdnr" && (
              <div className="rounded-lg border overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="bg-muted/40 border-b">
                    <tr>
                      <th className={thLeft}>Customer</th>
                      <th className={thLeft}>GSTIN</th>
                      <th className={thRight}>Notes</th>
                      <th className={thRight}>Taxable Value</th>
                      <th className={thRight}>Tax Amount</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y">
                    {preview.cdnr.length === 0 ? (
                      <tr><td colSpan={5} className="px-4 py-10 text-center text-text-secondary text-sm">No credit notes for this period</td></tr>
                    ) : preview.cdnr.map((row, i) => (
                      <tr key={i} className="hover:bg-muted/20 transition-colors">
                        <td className={`${tdLeft} font-medium`}>{row.customer_name}</td>
                        <td className={`${tdLeft} font-mono text-xs text-text-secondary`}>{row.gstin}</td>
                        <td className={tdRight}>{row.note_count}</td>
                        <td className={tdRight}>{fmt(row.taxable_value)}</td>
                        <td className={`${tdRight} font-semibold`}>{fmt(row.tax_amount)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}

            {/* ── HSN ────────────────────────────────────────────────────── */}
            {activeSection === "hsn" && (
              <div className="rounded-lg border overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="bg-muted/40 border-b">
                    <tr>
                      <th className={thLeft}>HSN Code</th>
                      <th className={thLeft}>Description</th>
                      <th className={thLeft}>UQC</th>
                      <th className={thRight}>Qty</th>
                      <th className={thRight}>Taxable Value</th>
                      <th className={thRight}>IGST</th>
                      <th className={thRight}>CGST</th>
                      <th className={thRight}>SGST</th>
                      <th className={thRight}>Cess</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y">
                    {preview.hsn_summary.length === 0 ? (
                      <tr><td colSpan={9} className="px-4 py-10 text-center text-text-secondary text-sm">No HSN data for this period</td></tr>
                    ) : preview.hsn_summary.map((row, i) => (
                      <tr key={i} className="hover:bg-muted/20 transition-colors">
                        <td className={`${tdLeft} font-mono text-xs font-medium`}>{row.hsn_code}</td>
                        <td className={`${tdLeft} text-text-secondary max-w-[160px] truncate`}>{row.description ?? "—"}</td>
                        <td className={`${tdLeft} text-text-secondary`}>{row.uqc}</td>
                        <td className={tdRight}>{Number(row.qty).toLocaleString("en-IN")}</td>
                        <td className={tdRight}>{fmt(row.taxable_value)}</td>
                        <td className={tdRight}>{fmt(row.igst)}</td>
                        <td className={tdRight}>{fmt(row.cgst)}</td>
                        <td className={tdRight}>{fmt(row.sgst)}</td>
                        <td className={tdRight}>{fmt(row.cess)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}

        {/* ── Empty state ───────────────────────────────────────────────── */}
        {!preview && !loading && (
          <div className="rounded-lg border bg-card py-16 text-center">
            <FileSpreadsheet className="h-10 w-10 text-text-secondary mx-auto mb-3" />
            <p className="text-sm text-text-secondary">
              Select a period and click <strong>Fetch Preview</strong> to generate the GSTR-1 summary.
            </p>
          </div>
        )}
      </div>
    </AppShell>
  );
}
