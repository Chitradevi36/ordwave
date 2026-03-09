"use client";

import { useState, useCallback } from "react";
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

const currentYear  = new Date().getFullYear();
const currentMonth = new Date().getMonth() + 1;

const YEARS = Array.from({ length: 4 }, (_, i) => currentYear - i);

// ── Page ──────────────────────────────────────────────────────────────────────

export default function Gstr1Page() {
  const { token, orgId } = useOrgBranch();

  const [month, setMonth]       = useState(currentMonth);
  const [year, setYear]         = useState(currentYear);
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
      if (!res.ok) throw new Error("Export failed");
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

  const sel = "h-9 rounded-md border border-border bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary";

  return (
    <AppShell breadcrumbs={[
      { label: "Finance",    href: "/finance" },
      { label: "Compliance", href: "/compliance" },
      { label: "GSTR-1" },
    ]}>
      <PageHeader
        title="GSTR-1 Export"
        subtitle="Generate and download GST Return 1 data"
        actions={preview ? [
          {
            label:    downloading ? "Exporting…" : "Download JSON",
            onClick:  handleDownloadJson,
            variant:  "outline",
            icon:     Download,
            disabled: downloading,
          },
        ] : []}
      />

      {/* Filters */}
      <div className="flex items-center gap-3 flex-wrap">
        <div className="flex items-center gap-2">
          <label className="text-sm text-text-secondary">Month</label>
          <select className={sel} value={month} onChange={(e) => setMonth(Number(e.target.value))}>
            {MONTHS.map((m, i) => (
              <option key={i + 1} value={i + 1}>{m}</option>
            ))}
          </select>
        </div>
        <div className="flex items-center gap-2">
          <label className="text-sm text-text-secondary">Year</label>
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

      {error && (
        <div className="rounded-md bg-destructive/10 border border-destructive/30 px-4 py-3 text-sm text-destructive">
          {error}
        </div>
      )}

      {preview && (
        <div className="space-y-6">
          {/* Summary cards */}
          <div className="grid grid-cols-4 gap-4">
            {[
              { label: "Total Invoices",  value: String(preview.summary.total_invoices) },
              { label: "Taxable Value",   value: fmt(preview.summary.total_taxable) },
              { label: "Total Tax",       value: fmt(preview.summary.total_tax) },
              { label: "Grand Total",     value: fmt(preview.summary.total_value) },
            ].map(({ label, value }) => (
              <div key={label} className="rounded-lg border bg-card p-4">
                <p className="text-xs text-text-secondary">{label}</p>
                <p className="text-lg font-bold mt-1">{value}</p>
              </div>
            ))}
          </div>

          {/* Section tabs */}
          <div className="border-b">
            <div className="flex gap-1">
              {(["b2b", "b2c", "cdnr", "hsn"] as const).map((s) => (
                <button
                  key={s}
                  onClick={() => setActiveSection(s)}
                  className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors ${
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

          {/* B2B */}
          {activeSection === "b2b" && (
            <div className="rounded-lg border overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-muted/40">
                  <tr>
                    {["Customer", "GSTIN", "Invoices", "Taxable Value", "Tax Amount", "Total"].map((h) => (
                      <th key={h} className="px-3 py-2.5 text-left text-xs font-semibold text-text-secondary">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y">
                  {preview.b2b.length === 0 ? (
                    <tr><td colSpan={6} className="px-3 py-8 text-center text-text-secondary">No B2B invoices for this period</td></tr>
                  ) : preview.b2b.map((row, i) => (
                    <tr key={i} className="hover:bg-muted/20">
                      <td className="px-3 py-2 font-medium">{row.customer_name}</td>
                      <td className="px-3 py-2 font-mono text-xs">{row.gstin}</td>
                      <td className="px-3 py-2 text-right">{row.invoice_count}</td>
                      <td className="px-3 py-2 text-right">{fmt(row.taxable_value)}</td>
                      <td className="px-3 py-2 text-right">{fmt(row.tax_amount)}</td>
                      <td className="px-3 py-2 text-right font-semibold">{fmt(row.total)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* B2C */}
          {activeSection === "b2c" && (
            <div className="rounded-lg border overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-muted/40">
                  <tr>
                    {["State", "Invoices", "Taxable Value", "Tax Amount", "Total"].map((h) => (
                      <th key={h} className="px-3 py-2.5 text-left text-xs font-semibold text-text-secondary">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y">
                  {preview.b2c.length === 0 ? (
                    <tr><td colSpan={5} className="px-3 py-8 text-center text-text-secondary">No B2C invoices for this period</td></tr>
                  ) : preview.b2c.map((row, i) => (
                    <tr key={i} className="hover:bg-muted/20">
                      <td className="px-3 py-2 font-medium">{row.state}</td>
                      <td className="px-3 py-2 text-right">{row.invoice_count}</td>
                      <td className="px-3 py-2 text-right">{fmt(row.taxable_value)}</td>
                      <td className="px-3 py-2 text-right">{fmt(row.tax_amount)}</td>
                      <td className="px-3 py-2 text-right font-semibold">{fmt(row.total)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* CDNR */}
          {activeSection === "cdnr" && (
            <div className="rounded-lg border overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-muted/40">
                  <tr>
                    {["Customer", "GSTIN", "Notes", "Taxable Value", "Tax Amount"].map((h) => (
                      <th key={h} className="px-3 py-2.5 text-left text-xs font-semibold text-text-secondary">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y">
                  {preview.cdnr.length === 0 ? (
                    <tr><td colSpan={5} className="px-3 py-8 text-center text-text-secondary">No credit/debit notes for this period</td></tr>
                  ) : preview.cdnr.map((row, i) => (
                    <tr key={i} className="hover:bg-muted/20">
                      <td className="px-3 py-2 font-medium">{row.customer_name}</td>
                      <td className="px-3 py-2 font-mono text-xs">{row.gstin}</td>
                      <td className="px-3 py-2 text-right">{row.note_count}</td>
                      <td className="px-3 py-2 text-right">{fmt(row.taxable_value)}</td>
                      <td className="px-3 py-2 text-right">{fmt(row.tax_amount)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* HSN */}
          {activeSection === "hsn" && (
            <div className="rounded-lg border overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-muted/40">
                  <tr>
                    {["HSN Code", "Description", "UQC", "Qty", "Taxable", "IGST", "CGST", "SGST", "Cess"].map((h) => (
                      <th key={h} className="px-3 py-2.5 text-left text-xs font-semibold text-text-secondary">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y">
                  {preview.hsn_summary.length === 0 ? (
                    <tr><td colSpan={9} className="px-3 py-8 text-center text-text-secondary">No HSN data for this period</td></tr>
                  ) : preview.hsn_summary.map((row, i) => (
                    <tr key={i} className="hover:bg-muted/20">
                      <td className="px-3 py-2 font-mono text-xs">{row.hsn_code}</td>
                      <td className="px-3 py-2 text-text-secondary">{row.description ?? "—"}</td>
                      <td className="px-3 py-2 text-text-secondary">{row.uqc}</td>
                      <td className="px-3 py-2 text-right">{Number(row.qty).toLocaleString("en-IN")}</td>
                      <td className="px-3 py-2 text-right">{fmt(row.taxable_value)}</td>
                      <td className="px-3 py-2 text-right">{fmt(row.igst)}</td>
                      <td className="px-3 py-2 text-right">{fmt(row.cgst)}</td>
                      <td className="px-3 py-2 text-right">{fmt(row.sgst)}</td>
                      <td className="px-3 py-2 text-right">{fmt(row.cess)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {!preview && !loading && (
        <div className="rounded-lg border bg-card p-12 text-center">
          <FileSpreadsheet className="h-10 w-10 text-text-secondary mx-auto mb-3" />
          <p className="text-sm text-text-secondary">Select a period and click <strong>Fetch Preview</strong> to generate the GSTR-1 summary.</p>
        </div>
      )}
    </AppShell>
  );
}
