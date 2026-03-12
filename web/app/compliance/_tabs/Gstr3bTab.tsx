"use client";

import { useState, useCallback, useEffect } from "react";
import { Button } from "@/components/ui/button";
import { useOrgBranch } from "@/lib/org-branch-context";
import { RefreshCw, Zap, CheckCircle2, Lock } from "lucide-react";

// ── Types ─────────────────────────────────────────────────────────────────────

interface Table31Row {
  taxable_value: number;
  igst?: number;
  cgst?: number;
  sgst?: number;
  cess?: number;
}

interface Table31 {
  outward_taxable_supplies: Table31Row;
  outward_zero_rated:       Table31Row;
  outward_nil_exempt:       Table31Row;
  inward_rc_taxable:        Table31Row;
  non_gst_supplies:         Table31Row;
}

interface Table4 {
  itc_available:      { igst: number; cgst: number; sgst: number; cess: number };
  itc_reverse_charge: { igst: number; cgst: number; sgst: number; cess: number };
}

interface Table5 {
  nil_exempt_non_gst: { inter_state: number; intra_state: number; non_gst: number };
}

interface Gstr3bPayload {
  period_from:  string;
  period_to:    string;
  month:        number;
  year:         number;
  table_3_1:    Table31;
  table_4:      Table4;
  table_5:      Table5;
  metadata: {
    invoice_count:      number;
    credit_note_count:  number;
    purchase_count:     number;
    rc_purchase_count:  number;
    generated_at:       string;
  };
}

interface PeriodInfo {
  id:           number;
  month:        number;
  year:         number;
  status:       string;
  display_name: string;
}

interface SnapshotInfo {
  id:             number;
  version_number: number;
  section_key:    string;
  totals:         Record<string, number>;
  generated_at:   string;
  is_filed:       boolean;
}

interface Gstr3bResponse {
  period:   PeriodInfo;
  snapshot: SnapshotInfo | null;
  payload:  Gstr3bPayload | null;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const fmt = (n: number | undefined | null) =>
  n == null ? "—" : `₹ ${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2 })}`;

const STATUS_BADGE: Record<string, string> = {
  draft:     "bg-gray-100 text-gray-600",
  generated: "bg-blue-100 text-blue-700",
  reviewed:  "bg-indigo-100 text-indigo-700",
  locked:    "bg-orange-100 text-orange-700",
  filed:     "bg-green-100 text-green-700",
};

// ── Sub-components ────────────────────────────────────────────────────────────

function TaxRow({ label, row }: { label: string; row: Table31Row }) {
  return (
    <tr className="hover:bg-muted/20 transition-colors">
      <td className="px-4 py-3 text-sm font-medium w-64">{label}</td>
      <td className="px-4 py-3 text-right text-sm tabular-nums">{fmt(row.taxable_value)}</td>
      <td className="px-4 py-3 text-right text-sm tabular-nums">{fmt(row.igst)}</td>
      <td className="px-4 py-3 text-right text-sm tabular-nums">{fmt(row.cgst)}</td>
      <td className="px-4 py-3 text-right text-sm tabular-nums">{fmt(row.sgst)}</td>
      <td className="px-4 py-3 text-right text-sm tabular-nums">{fmt(row.cess)}</td>
    </tr>
  );
}

function TableCard({ heading, children }: { heading: string; children: React.ReactNode }) {
  return (
    <div className="rounded-lg border overflow-x-auto">
      <div className="bg-muted/40 px-4 py-3 border-b">
        <p className="text-xs font-semibold text-text-secondary uppercase tracking-wide">{heading}</p>
      </div>
      <table className="w-full text-sm">
        {children}
      </table>
    </div>
  );
}

// ── Component ─────────────────────────────────────────────────────────────────

export interface Gstr3bTabProps {
  month: number;
  year:  number;
}

export default function Gstr3bTab({ month, year }: Gstr3bTabProps) {
  const { token, orgId } = useOrgBranch();

  const [data, setData]         = useState<Gstr3bResponse | null>(null);
  const [loading, setLoading]   = useState(false);
  const [generating, setGenerating] = useState(false);
  const [error, setError]       = useState<string | null>(null);

  const h = useCallback(() => ({
    Authorization: `Bearer ${token}`,
    "X-Organization-Id": orgId ?? "",
    "Content-Type": "application/json",
  }), [token, orgId]);

  const fetchExisting = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(
        `/api/v1/compliance/gstr3b/show?month=${month}&year=${year}`,
        { headers: h() }
      );
      if (res.status === 404) { setData(null); return; }
      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "Failed to load GSTR-3B");
      setData(body.data);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  }, [token, orgId, month, year, h]);

  useEffect(() => {
    if (token && orgId) fetchExisting();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [month, year, token, orgId]);

  const handleGenerate = async () => {
    if (!token || !orgId) return;
    setGenerating(true);
    setError(null);
    try {
      const res = await fetch("/api/v1/compliance/gstr3b/generate", {
        method: "POST",
        headers: h(),
        body: JSON.stringify({ month, year }),
      });
      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "Generation failed");
      setData(body.data);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Generation failed");
    } finally {
      setGenerating(false);
    }
  };

  const p = data?.payload;
  const periodStatus = data?.period?.status;
  const isLocked = periodStatus === "locked" || periodStatus === "filed";

  return (
    <div className="space-y-6">

      {/* ── Toolbar with metadata, buttons & status ───────────────────── */}
      <div className="flex items-center justify-between gap-3 flex-wrap">
        {/* Version & Generated metadata */}
        {data?.snapshot && (
          <div className="flex items-center gap-4 text-xs text-text-secondary">
            <span>Version {data.snapshot.version_number}</span>
            <span>•</span>
            <span>Generated {new Date(data.snapshot.generated_at).toLocaleString("en-IN")}</span>
            {data.snapshot.is_filed && (
              <>
                <span>•</span>
                <span className="text-green-600 font-semibold flex items-center gap-1">
                  <CheckCircle2 className="h-3 w-3" /> Filed snapshot
                </span>
              </>
            )}
          </div>
        )}
        {/* CTAs on the right */}
        <div className="flex items-center gap-3">
          <Button
            onClick={handleGenerate}
            disabled={generating || loading || isLocked}
          >
            <Zap className="h-3.5 w-3.5 mr-1.5" />
            {generating ? "Generating…" : data?.payload ? "Re-generate" : "Generate 3B"}
          </Button>
          <Button variant="outline" onClick={fetchExisting} disabled={loading}>
            <RefreshCw className={`h-3.5 w-3.5 mr-1.5 ${loading ? "animate-spin" : ""}`} />
            Refresh
          </Button>
          {data?.period && (
            <span className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold ${STATUS_BADGE[periodStatus ?? "draft"] ?? "bg-gray-100 text-gray-600"}`}>
              {isLocked && <Lock className="h-3 w-3" />}
              {periodStatus === "filed" && <CheckCircle2 className="h-3 w-3" />}
              {(periodStatus ?? "draft").toUpperCase()}
            </span>
          )}
        </div>
      </div>

      {/* ── Error ──────────────────────────────────────────────────────── */}
      {error && (
        <div className="rounded-md bg-destructive/10 border border-destructive/30 px-4 py-3 text-sm text-destructive">
          {error}
        </div>
      )}

      {/* ── Locked warning ─────────────────────────────────────────────── */}
      {isLocked && (
        <div className="rounded-md bg-muted border px-4 py-3 text-sm text-text-secondary flex items-center gap-2">
          <Lock className="h-4 w-4 shrink-0" />
          This period is {periodStatus} — regeneration is disabled. Contact an admin to reopen.
        </div>
      )}

      {/* ── Loading skeleton ────────────────────────────────────────────── */}
      {loading && !data && (
        <div className="space-y-4 animate-pulse">
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
            {[0,1,2,3].map(i => <div key={i} className="rounded-lg border bg-card h-20" />)}
          </div>
          <div className="rounded-lg border bg-card h-64" />
        </div>
      )}

      {/* ── 3B tables ──────────────────────────────────────────────────── */}
      {p && (
        <div className="space-y-6">

          {/* Summary cards */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
            {[
              { label: "Outward Taxable",      value: fmt(p.table_3_1.outward_taxable_supplies.taxable_value) },
              { label: "Total IGST",           value: fmt(p.table_3_1.outward_taxable_supplies.igst) },
              { label: "CGST + SGST",          value: fmt((p.table_3_1.outward_taxable_supplies.cgst ?? 0) + (p.table_3_1.outward_taxable_supplies.sgst ?? 0)) },
              { label: "ITC Available (IGST)", value: fmt(p.table_4.itc_available.igst) },
            ].map(({ label, value }) => (
              <div key={label} className="rounded-lg border bg-card px-5 py-4">
                <p className="text-xs text-text-secondary mb-1">{label}</p>
                <p className="text-xl font-bold tabular-nums">{value}</p>
              </div>
            ))}
          </div>

          {/* Table 3.1 */}
          <TableCard heading="Table 3.1 — Outward and Inward Supplies">
            <thead className="bg-muted/40 border-b">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-semibold text-text-secondary uppercase tracking-wide w-64">Nature of Supply</th>
                <th className="px-4 py-3 text-right text-xs font-semibold text-text-secondary uppercase tracking-wide">Taxable Value</th>
                <th className="px-4 py-3 text-right text-xs font-semibold text-text-secondary uppercase tracking-wide">IGST</th>
                <th className="px-4 py-3 text-right text-xs font-semibold text-text-secondary uppercase tracking-wide">CGST</th>
                <th className="px-4 py-3 text-right text-xs font-semibold text-text-secondary uppercase tracking-wide">SGST</th>
                <th className="px-4 py-3 text-right text-xs font-semibold text-text-secondary uppercase tracking-wide">Cess</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              <TaxRow label="(a) Outward taxable supplies (other than zero rated, nil and exempted)" row={p.table_3_1.outward_taxable_supplies} />
              <TaxRow label="(b) Outward taxable supplies (zero rated)"                              row={p.table_3_1.outward_zero_rated} />
              <TaxRow label="(c) Other outward supplies (Nil rated, exempted)"                       row={p.table_3_1.outward_nil_exempt} />
              <TaxRow label="(d) Inward supplies (liable to reverse charge)"                         row={p.table_3_1.inward_rc_taxable} />
              <TaxRow label="(e) Non-GST outward supplies"                                           row={p.table_3_1.non_gst_supplies} />
            </tbody>
          </TableCard>

          {/* Table 4 — ITC */}
          <TableCard heading="Table 4 — Eligible ITC">
            <thead className="bg-muted/40 border-b">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-semibold text-text-secondary uppercase tracking-wide w-64">ITC Type</th>
                <th className="px-4 py-3 text-right text-xs font-semibold text-text-secondary uppercase tracking-wide">IGST</th>
                <th className="px-4 py-3 text-right text-xs font-semibold text-text-secondary uppercase tracking-wide">CGST</th>
                <th className="px-4 py-3 text-right text-xs font-semibold text-text-secondary uppercase tracking-wide">SGST</th>
                <th className="px-4 py-3 text-right text-xs font-semibold text-text-secondary uppercase tracking-wide">Cess</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {[
                { label: "(A) ITC Available (eligible)",  row: p.table_4.itc_available },
                { label: "(B) ITC on Reverse Charge",     row: p.table_4.itc_reverse_charge },
              ].map(({ label, row }) => (
                <tr key={label} className="hover:bg-muted/20 transition-colors">
                  <td className="px-4 py-3 text-sm font-medium">{label}</td>
                  <td className="px-4 py-3 text-right text-sm tabular-nums">{fmt(row.igst)}</td>
                  <td className="px-4 py-3 text-right text-sm tabular-nums">{fmt(row.cgst)}</td>
                  <td className="px-4 py-3 text-right text-sm tabular-nums">{fmt(row.sgst)}</td>
                  <td className="px-4 py-3 text-right text-sm tabular-nums">{fmt(row.cess)}</td>
                </tr>
              ))}
            </tbody>
          </TableCard>

          {/* Table 5 — Exempt */}
          <TableCard heading="Table 5 — Exempt, Nil and Non-GST Outward Supplies">
            <thead className="bg-muted/40 border-b">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-semibold text-text-secondary uppercase tracking-wide">Category</th>
                <th className="px-4 py-3 text-right text-xs font-semibold text-text-secondary uppercase tracking-wide">Inter-State</th>
                <th className="px-4 py-3 text-right text-xs font-semibold text-text-secondary uppercase tracking-wide">Intra-State</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              <tr className="hover:bg-muted/20 transition-colors">
                <td className="px-4 py-3 text-sm font-medium">Nil Rated / Exempt supplies</td>
                <td className="px-4 py-3 text-right text-sm tabular-nums">{fmt(p.table_5.nil_exempt_non_gst.inter_state)}</td>
                <td className="px-4 py-3 text-right text-sm tabular-nums">{fmt(p.table_5.nil_exempt_non_gst.intra_state)}</td>
              </tr>
              <tr className="hover:bg-muted/20 transition-colors">
                <td className="px-4 py-3 text-sm font-medium">Non-GST supplies</td>
                <td className="px-4 py-3 text-right text-sm tabular-nums" colSpan={2}>{fmt(p.table_5.nil_exempt_non_gst.non_gst)}</td>
              </tr>
            </tbody>
          </TableCard>

          {/* Source metadata */}
          <div className="rounded-lg border bg-muted/20 px-5 py-4">
            <p className="text-xs font-semibold text-text-secondary uppercase tracking-wide mb-3">Source Counts</p>
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 text-sm">
              {[
                { label: "Sales Invoices",    value: p.metadata.invoice_count },
                { label: "Credit Notes",      value: p.metadata.credit_note_count },
                { label: "Purchase Invoices", value: p.metadata.purchase_count },
                { label: "Reverse Charge",    value: p.metadata.rc_purchase_count },
              ].map(({ label, value }) => (
                <div key={label}>
                  <p className="text-text-secondary text-xs">{label}</p>
                  <p className="font-bold tabular-nums text-base">{value}</p>
                </div>
              ))}
            </div>
          </div>

        </div>
      )}

      {/* ── Empty state ────────────────────────────────────────────────── */}
      {!p && !loading && !error && (
        <div className="rounded-lg border bg-card py-16 text-center">
          <Zap className="h-10 w-10 text-text-secondary mx-auto mb-3" />
          <p className="text-sm font-semibold text-text-primary mb-1">No GSTR-3B data for this period</p>
          <p className="text-sm text-text-secondary">
            Click <strong>Generate 3B</strong> to compute from your books.
          </p>
        </div>
      )}
    </div>
  );
}
