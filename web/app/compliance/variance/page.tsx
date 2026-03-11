"use client";

import { useState, useCallback, useEffect } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { Button } from "@/components/ui/button";
import { useOrgBranch } from "@/lib/org-branch-context";
import { RefreshCw, AlertTriangle, CheckCircle2, Info } from "lucide-react";

// ── Types ─────────────────────────────────────────────────────────────────────

interface VarianceCell {
  key:           string;
  label:         string;
  source_value:  number;
  target_value:  number;
  difference:    number;
  variance_flag: boolean;
}

interface VarianceSection {
  axis:        string;
  label:       string;
  cells:       VarianceCell[];
  has_variance: boolean;
  // gstr2b-specific extras
  gstr2b_unmatched_lines?:     number;
  gstr2b_tax_mismatch_lines?:  number;
  note?:                       string | null;
}

interface VarianceSummary {
  period:              string;
  gstr1_available:     boolean;
  gstr1_filed:         boolean;
  gstr3b_available:    boolean;
  gstr3b_filed:        boolean;
  gstr2b_available:    boolean;
  gstr2b_import_status: string | null;
  ready_to_file:       boolean;
}

interface VarianceResponse {
  status:        "complete" | "partial" | "missing_data";
  month:         number;
  year:          number;
  summary:       VarianceSummary;
  gstr1_vs_3b:   VarianceSection | null;
  gstr2b_vs_3b:  VarianceSection | null;
  has_variances: boolean;
  errors:        string[];
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const fmt = (n: number | undefined | null) =>
  n == null ? "—" : `₹ ${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2 })}`;

const fmtDiff = (n: number) => {
  const abs = `₹ ${Math.abs(n).toLocaleString("en-IN", { minimumFractionDigits: 2 })}`;
  if (n === 0) return <span className="text-text-secondary tabular-nums">—</span>;
  if (n > 0)   return <span className="text-amber-600 tabular-nums font-semibold">+{abs}</span>;
  return              <span className="text-red-600  tabular-nums font-semibold">-{abs}</span>;
};

const MONTHS = [
  "January","February","March","April","May","June",
  "July","August","September","October","November","December",
];
const _now         = new Date();
const currentYear  = _now.getFullYear();
const currentMonth = _now.getMonth() + 1;
const defaultMonth = currentMonth === 1 ? 12 : currentMonth - 1;
const defaultYear  = currentMonth === 1 ? currentYear - 1 : currentYear;
const YEARS        = Array.from({ length: 4 }, (_, i) => currentYear - i);

const sel = "h-9 rounded-md border border-border bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary";

const STATUS_CONFIG: Record<string, { label: string; cls: string }> = {
  complete:     { label: "Complete",     cls: "bg-green-100 text-green-700" },
  partial:      { label: "Partial",      cls: "bg-amber-100 text-amber-700" },
  missing_data: { label: "Missing Data", cls: "bg-red-100 text-red-700"     },
};

// ── Sub-components ────────────────────────────────────────────────────────────

function SummaryBadge({ available, filed, label }: { available: boolean; filed: boolean; label: string }) {
  const cls =
    !available ? "bg-gray-100 text-gray-500"
    : filed    ? "bg-green-100 text-green-700"
    :            "bg-blue-100 text-blue-700";
  const text = !available ? "Not generated" : filed ? "Filed" : "Draft";
  return (
    <div className="flex items-center justify-between py-2 border-b last:border-0">
      <span className="text-sm font-medium">{label}</span>
      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold ${cls}`}>
        {text}
      </span>
    </div>
  );
}

function VarianceSectionCard({
  section,
  sourceLabel,
  targetLabel,
}: {
  section: VarianceSection;
  sourceLabel: string;
  targetLabel: string;
}) {
  return (
    <div className="rounded-lg border overflow-hidden">
      <div className={`px-5 py-3 border-b flex items-center justify-between ${section.has_variance ? "bg-amber-50" : "bg-muted/30"}`}>
        <div>
          <p className="text-sm font-semibold">{section.label}</p>
        </div>
        {section.has_variance ? (
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-amber-100 text-amber-700">
            <AlertTriangle className="h-3.5 w-3.5" /> Variances found
          </span>
        ) : (
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-green-100 text-green-700">
            <CheckCircle2 className="h-3.5 w-3.5" /> Matches
          </span>
        )}
      </div>

      {/* GSTR-2B unmatched warning */}
      {(section.gstr2b_unmatched_lines ?? 0) > 0 && (
        <div className="bg-red-50 border-b border-red-200 px-5 py-3 text-sm text-red-700 flex items-start gap-2">
          <AlertTriangle className="h-4 w-4 mt-0.5 shrink-0" />
          <span>
            <strong>{section.gstr2b_unmatched_lines} lines</strong> missing in books — ITC at risk.
            {section.gstr2b_tax_mismatch_lines ? ` Also ${section.gstr2b_tax_mismatch_lines} tax mismatch lines.` : ""}
          </span>
        </div>
      )}

      <table className="w-full text-sm">
        <thead className="bg-muted/40 border-b">
          <tr>
            <th className="px-5 py-3 text-left text-xs font-semibold text-text-secondary uppercase tracking-wide w-44">Field</th>
            <th className="px-5 py-3 text-right text-xs font-semibold text-text-secondary uppercase tracking-wide">{sourceLabel}</th>
            <th className="px-5 py-3 text-right text-xs font-semibold text-text-secondary uppercase tracking-wide">{targetLabel}</th>
            <th className="px-5 py-3 text-right text-xs font-semibold text-text-secondary uppercase tracking-wide">Difference</th>
            <th className="px-4 py-3 text-center text-xs font-semibold text-text-secondary uppercase tracking-wide w-28">Status</th>
          </tr>
        </thead>
        <tbody className="divide-y">
          {section.cells.map((cell) => (
            <tr
              key={cell.key}
              className={`transition-colors ${cell.variance_flag ? "bg-amber-50/60 hover:bg-amber-50" : "hover:bg-muted/20"}`}
            >
              <td className="px-5 py-3 text-sm font-medium">{cell.label}</td>
              <td className="px-5 py-3 text-right tabular-nums text-sm">{fmt(cell.source_value)}</td>
              <td className="px-5 py-3 text-right tabular-nums text-sm">{fmt(cell.target_value)}</td>
              <td className="px-5 py-3 text-right text-sm">{fmtDiff(cell.difference)}</td>
              <td className="px-4 py-3 text-center">
                {cell.variance_flag ? (
                  <span className="inline-flex items-center gap-1 text-xs font-semibold text-amber-700">
                    <AlertTriangle className="h-3 w-3" /> Review
                  </span>
                ) : (
                  <span className="inline-flex items-center gap-1 text-xs font-semibold text-green-700">
                    <CheckCircle2 className="h-3 w-3" /> OK
                  </span>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      {section.note && (
        <div className="bg-amber-50 border-t border-amber-200 px-5 py-3 text-xs text-amber-700 flex items-start gap-2">
          <Info className="h-3.5 w-3.5 mt-0.5 shrink-0" />
          {section.note}
        </div>
      )}
    </div>
  );
}

// ── Page ──────────────────────────────────────────────────────────────────────

export default function VariancePage() {
  const { token, orgId } = useOrgBranch();

  const [month, setMonth] = useState(defaultMonth);
  const [year,  setYear]  = useState(defaultYear);

  const [data,    setData]    = useState<VarianceResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error,   setError]   = useState<string | null>(null);

  const headers = useCallback(() => ({
    Authorization:      `Bearer ${token}`,
    "X-Organization-Id": orgId ?? "",
    "Content-Type":      "application/json",
  }), [token, orgId]);

  const fetchVariance = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const res  = await fetch(
        `/api/v1/compliance/gstr3b/variance?month=${month}&year=${year}`,
        { headers: headers() }
      );
      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "Failed to load variance report");
      setData(body.data);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  }, [token, orgId, month, year, headers]);

  useEffect(() => {
    if (token && orgId) fetchVariance();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [month, year, token, orgId]);

  const s = data?.summary;

  return (
    <AppShell title="Variance Report" hideBreadcrumb>
      <PageHeader
        title="3B Variance Report"
        subtitle="Compare books (GSTR-1) vs GSTR-3B vs GSTR-2B to surface mismatches before filing"
        actions={[{
          label:   loading ? "Refreshing…" : "Refresh",
          onClick: fetchVariance,
          variant: "outline" as const,
          icon:    RefreshCw,
          disabled: loading,
        }]}
      />

      <div className="space-y-6">

        {/* ── Filters ────────────────────────────────────────────────────── */}
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

          {/* Status badge */}
          {data && (() => {
            const cfg = STATUS_CONFIG[data.status] ?? STATUS_CONFIG.missing_data;
            return (
              <span className={`inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold ${cfg.cls}`}>
                {cfg.label}
              </span>
            );
          })()}

          {/* Variance alert */}
          {data?.has_variances && (
            <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-amber-100 text-amber-700">
              <AlertTriangle className="h-3.5 w-3.5" /> Variances require review
            </span>
          )}
          {data && !data.has_variances && data.status !== "missing_data" && (
            <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-green-100 text-green-700">
              <CheckCircle2 className="h-3.5 w-3.5" /> All figures match
            </span>
          )}
        </div>

        {/* ── Error ──────────────────────────────────────────────────────── */}
        {error && (
          <div className="rounded-md bg-destructive/10 border border-destructive/30 px-4 py-3 text-sm text-destructive">
            {error}
          </div>
        )}

        {/* ── Backend errors / missing data ──────────────────────────────── */}
        {data?.errors && data.errors.length > 0 && (
          <div className="rounded-md bg-amber-50 border border-amber-200 px-4 py-3 text-sm text-amber-800 space-y-1">
            {data.errors.map((e, i) => (
              <p key={i} className="flex items-start gap-2">
                <Info className="h-4 w-4 mt-0.5 shrink-0" />
                {e}
              </p>
            ))}
          </div>
        )}

        {/* ── Skeleton ───────────────────────────────────────────────────── */}
        {loading && !data && (
          <div className="space-y-4 animate-pulse">
            <div className="grid grid-cols-3 gap-4">
              {[0,1,2].map(i => <div key={i} className="rounded-lg border bg-card h-32" />)}
            </div>
            <div className="rounded-lg border bg-card h-64" />
          </div>
        )}

        {data && (
          <div className="space-y-6">

            {/* ── Summary status cards ──────────────────────────────────── */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">

              <div className="rounded-lg border bg-card px-5 py-4">
                <p className="text-xs font-semibold text-text-secondary uppercase tracking-wide mb-3">Return Status</p>
                {s && (
                  <div>
                    <SummaryBadge label="GSTR-1"  available={s.gstr1_available}  filed={s.gstr1_filed}  />
                    <SummaryBadge label="GSTR-3B" available={s.gstr3b_available} filed={s.gstr3b_filed} />
                    <SummaryBadge label="GSTR-2B" available={s.gstr2b_available} filed={false}          />
                  </div>
                )}
              </div>

              <div className="rounded-lg border bg-card px-5 py-4">
                <p className="text-xs font-semibold text-text-secondary uppercase tracking-wide mb-3">Period</p>
                <p className="text-2xl font-bold">{s?.period ?? `${MONTHS[month - 1]} ${year}`}</p>
                {s?.ready_to_file ? (
                  <p className="mt-2 text-xs text-green-600 flex items-center gap-1">
                    <CheckCircle2 className="h-3.5 w-3.5" /> Ready to file
                  </p>
                ) : (
                  <p className="mt-2 text-xs text-text-secondary">Complete all returns to file</p>
                )}
              </div>

              <div className="rounded-lg border bg-card px-5 py-4">
                <p className="text-xs font-semibold text-text-secondary uppercase tracking-wide mb-3">Overall</p>
                {data.has_variances ? (
                  <div className="flex items-center gap-2 text-amber-700">
                    <AlertTriangle className="h-7 w-7" />
                    <div>
                      <p className="font-bold text-base">Action needed</p>
                      <p className="text-xs">Resolve variances before filing</p>
                    </div>
                  </div>
                ) : data.status === "missing_data" ? (
                  <div className="flex items-center gap-2 text-text-secondary">
                    <Info className="h-7 w-7" />
                    <div>
                      <p className="font-bold text-base">Incomplete data</p>
                      <p className="text-xs">Generate missing returns first</p>
                    </div>
                  </div>
                ) : (
                  <div className="flex items-center gap-2 text-green-700">
                    <CheckCircle2 className="h-7 w-7" />
                    <div>
                      <p className="font-bold text-base">All clear</p>
                      <p className="text-xs">Figures match within tolerance</p>
                    </div>
                  </div>
                )}
              </div>
            </div>

            {/* ── GSTR-1 vs GSTR-3B ────────────────────────────────────── */}
            {data.gstr1_vs_3b ? (
              <VarianceSectionCard
                section={data.gstr1_vs_3b}
                sourceLabel="GSTR-1"
                targetLabel="GSTR-3B (Table 3.1)"
              />
            ) : (
              <div className="rounded-lg border bg-muted/20 px-5 py-8 text-center text-sm text-text-secondary">
                <Info className="h-6 w-6 mx-auto mb-2 opacity-40" />
                GSTR-1 vs GSTR-3B comparison unavailable — generate both returns first.
              </div>
            )}

            {/* ── GSTR-2B vs GSTR-3B ───────────────────────────────────── */}
            {data.gstr2b_vs_3b ? (
              <VarianceSectionCard
                section={data.gstr2b_vs_3b}
                sourceLabel="GSTR-2B (matched)"
                targetLabel="GSTR-3B (Table 4)"
              />
            ) : (
              <div className="rounded-lg border bg-muted/20 px-5 py-8 text-center text-sm text-text-secondary">
                <Info className="h-6 w-6 mx-auto mb-2 opacity-40" />
                GSTR-2B vs GSTR-3B comparison unavailable — import GSTR-2B first.
              </div>
            )}

          </div>
        )}

        {/* ── Empty state ─────────────────────────────────────────────────── */}
        {!data && !loading && !error && (
          <div className="rounded-lg border bg-card py-16 text-center">
            <AlertTriangle className="h-10 w-10 text-text-secondary mx-auto mb-3 opacity-40" />
            <p className="text-sm text-text-secondary">
              Select a period and click <strong>Refresh</strong> to load the variance report.
            </p>
          </div>
        )}

      </div>
    </AppShell>
  );
}
