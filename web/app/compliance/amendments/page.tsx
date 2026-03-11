"use client";

import { useState, useCallback, useEffect } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { useOrgBranch } from "@/lib/org-branch-context";
import { RefreshCw, Scan, FileEdit, AlertTriangle, CheckCircle2, Clock } from "lucide-react";

// ── Types ─────────────────────────────────────────────────────────────────────

type AmendmentType = "new_invoice" | "modified_invoice" | "new_cn" | "modified_cn" | "cancelled_invoice";
type AmendmentStatus = "detected" | "acknowledged" | "included_in_amendment" | "dismissed";

interface AmendmentCandidate {
  id:                     number;
  amendment_type:         AmendmentType;
  status:                 AmendmentStatus;
  source_type:            "SalesInvoice" | "CreditNote";
  source_id:              number;
  document_number:        string;
  taxable_value_original: number | null;
  taxable_value_current:  number | null;
  tax_original:           number | null;
  tax_current:            number | null;
  change_summary:         string;
  detected_at:            string;
  acknowledged_at:        string | null;
  acknowledged_by:        string | null;
  gst_return_period_id:   number;
}

interface AmendmentsResponse {
  period_id:  number;
  month:      number;
  year:       number;
  count:      number;
  candidates: AmendmentCandidate[];
}

interface DetectResponse {
  period_id:      number;
  detected_count: number;
  counts:         Record<string, number>;
  candidates:     AmendmentCandidate[];
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const fmt = (n: number | null | undefined) =>
  n == null ? "—" : `₹ ${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2 })}`;

const fmtDate = (s: string | null) =>
  s ? new Date(s).toLocaleString("en-IN", { dateStyle: "medium", timeStyle: "short" }) : "—";

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

// Amendment-type human labels
const TYPE_LABELS: Record<AmendmentType, string> = {
  new_invoice:       "New Invoice",
  modified_invoice:  "Modified Invoice",
  new_cn:            "New Credit Note",
  modified_cn:       "Modified Credit Note",
  cancelled_invoice: "Cancelled Invoice",
};

const TYPE_BADGE: Record<AmendmentType, string> = {
  new_invoice:       "bg-blue-100 text-blue-700",
  modified_invoice:  "bg-amber-100 text-amber-700",
  new_cn:            "bg-purple-100 text-purple-700",
  modified_cn:       "bg-orange-100 text-orange-700",
  cancelled_invoice: "bg-red-100 text-red-700",
};

const STATUS_BADGE: Record<AmendmentStatus, string> = {
  detected:              "bg-yellow-100 text-yellow-700",
  acknowledged:          "bg-blue-100 text-blue-700",
  included_in_amendment: "bg-green-100 text-green-700",
  dismissed:             "bg-gray-100 text-gray-500",
};

const STATUS_ICON: Record<AmendmentStatus, React.ReactNode> = {
  detected:              <Clock className="h-3 w-3" />,
  acknowledged:          <CheckCircle2 className="h-3 w-3" />,
  included_in_amendment: <CheckCircle2 className="h-3 w-3" />,
  dismissed:             <span className="h-3 w-3 inline-block">×</span>,
};

const STATUS_FILTERS: { value: string; label: string }[] = [
  { value: "all",                   label: "All"       },
  { value: "detected",              label: "Detected"  },
  { value: "acknowledged",          label: "Reviewed"  },
  { value: "included_in_amendment", label: "Included"  },
  { value: "dismissed",             label: "Dismissed" },
];

// ── Page ──────────────────────────────────────────────────────────────────────

export default function AmendmentsPage() {
  const { token, orgId } = useOrgBranch();

  const [month, setMonth] = useState(defaultMonth);
  const [year,  setYear]  = useState(defaultYear);
  const [statusFilter, setStatusFilter] = useState("all");

  const [data,       setData]       = useState<AmendmentsResponse | null>(null);
  const [loading,    setLoading]    = useState(false);
  const [detecting,  setDetecting]  = useState(false);
  const [error,      setError]      = useState<string | null>(null);
  const [detectMsg,  setDetectMsg]  = useState<string | null>(null);

  const headers = useCallback(() => ({
    Authorization:       `Bearer ${token}`,
    "X-Organization-Id": orgId ?? "",
    "Content-Type":      "application/json",
  }), [token, orgId]);

  // ── Fetch candidates ───────────────────────────────────────────────────────
  const fetchAmendments = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const statusQ = statusFilter !== "all" ? `&status=${statusFilter}` : "";
      const res  = await fetch(
        `/api/v1/compliance/gstr1/amendments?month=${month}&year=${year}${statusQ}`,
        { headers: headers() }
      );
      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "Failed to load amendments");
      setData(body.data);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  }, [token, orgId, month, year, statusFilter, headers]);

  useEffect(() => {
    if (token && orgId) fetchAmendments();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [month, year, statusFilter, token, orgId]);

  // ── Detect amendments ──────────────────────────────────────────────────────
  const handleDetect = async () => {
    if (!token || !orgId) return;
    setDetecting(true);
    setDetectMsg(null);
    setError(null);
    try {
      const res  = await fetch("/api/v1/compliance/gstr1/detect_amendments", {
        method:  "POST",
        headers: headers(),
        body:    JSON.stringify({ month, year }),
      });
      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "Detection failed");
      const d: DetectResponse = body.data;
      setDetectMsg(`Detected ${d.detected_count} amendment candidate${d.detected_count !== 1 ? "s" : ""}.`);
      // Reload the list
      await fetchAmendments();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Detection failed");
    } finally {
      setDetecting(false);
    }
  };

  // ── Derived counts ─────────────────────────────────────────────────────────
  const openCount = data?.candidates.filter(c => ["detected","acknowledged"].includes(c.status)).length ?? 0;

  return (
    <AppShell title="Amendment Candidates" hideBreadcrumb>
      <PageHeader
        title="GSTR-1 Amendment Candidates"
        subtitle="Documents created or modified after a period was filed — must be included in GSTR-1A"
        actions={[
          {
            label:    detecting ? "Detecting…" : "Detect Amendments",
            onClick:  handleDetect,
            icon:     Scan,
            disabled: detecting || loading,
          },
        ]}
      />

      <div className="space-y-6">

        {/* ── Filters ──────────────────────────────────────────────────────── */}
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

          {/* Status filter tabs */}
          <div className="flex items-center gap-1 ml-2">
            {STATUS_FILTERS.map(f => (
              <button
                key={f.value}
                onClick={() => setStatusFilter(f.value)}
                className={`px-3 py-1.5 rounded-md text-xs font-medium transition-colors border ${
                  statusFilter === f.value
                    ? "bg-primary text-white border-primary"
                    : "bg-background border-border text-text-secondary hover:bg-muted"
                }`}
              >
                {f.label}
              </button>
            ))}
          </div>

          <Button variant="outline" size="sm" onClick={fetchAmendments} disabled={loading}>
            <RefreshCw className={`h-3.5 w-3.5 mr-1.5 ${loading ? "animate-spin" : ""}`} />
            Refresh
          </Button>

          {/* Open count badge */}
          {data && openCount > 0 && (
            <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-amber-100 text-amber-700">
              <AlertTriangle className="h-3.5 w-3.5" />
              {openCount} open
            </span>
          )}
        </div>

        {/* ── Success message ───────────────────────────────────────────────── */}
        {detectMsg && (
          <div className="rounded-md bg-green-50 border border-green-200 px-4 py-3 text-sm text-green-700 flex items-center gap-2">
            <CheckCircle2 className="h-4 w-4 shrink-0" />
            {detectMsg}
          </div>
        )}

        {/* ── Error ────────────────────────────────────────────────────────── */}
        {error && (
          <div className="rounded-md bg-destructive/10 border border-destructive/30 px-4 py-3 text-sm text-destructive">
            {error}
          </div>
        )}

        {/* ── Summary cards ────────────────────────────────────────────────── */}
        {data && data.candidates.length > 0 && (
          <div className="grid grid-cols-2 sm:grid-cols-5 gap-3">
            {(Object.keys(TYPE_LABELS) as AmendmentType[]).map(type => {
              const count = data.candidates.filter(c => c.amendment_type === type).length;
              return (
                <div key={type} className="rounded-lg border bg-card px-4 py-3">
                  <p className="text-xs text-text-secondary mb-1">{TYPE_LABELS[type]}</p>
                  <p className="text-2xl font-bold tabular-nums">{count}</p>
                </div>
              );
            })}
          </div>
        )}

        {/* ── Skeleton ─────────────────────────────────────────────────────── */}
        {loading && !data && (
          <div className="rounded-lg border bg-card h-64 animate-pulse" />
        )}

        {/* ── Table ────────────────────────────────────────────────────────── */}
        {data && (
          <div className="rounded-lg border overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-muted/40 border-b">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-semibold text-text-secondary uppercase tracking-wide">Document</th>
                  <th className="px-4 py-3 text-left text-xs font-semibold text-text-secondary uppercase tracking-wide">Type</th>
                  <th className="px-4 py-3 text-left text-xs font-semibold text-text-secondary uppercase tracking-wide">Status</th>
                  <th className="px-4 py-3 text-right text-xs font-semibold text-text-secondary uppercase tracking-wide">Current Taxable</th>
                  <th className="px-4 py-3 text-right text-xs font-semibold text-text-secondary uppercase tracking-wide">Current Tax</th>
                  <th className="px-4 py-3 text-left text-xs font-semibold text-text-secondary uppercase tracking-wide">Change Summary</th>
                  <th className="px-4 py-3 text-left text-xs font-semibold text-text-secondary uppercase tracking-wide">Detected</th>
                  <th className="px-4 py-3 text-left text-xs font-semibold text-text-secondary uppercase tracking-wide">Acknowledged By</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {data.candidates.length === 0 ? (
                  <tr>
                    <td colSpan={8} className="px-4 py-12 text-center text-text-secondary text-sm">
                      <FileEdit className="h-8 w-8 mx-auto mb-2 opacity-30" />
                      No amendment candidates
                      {statusFilter !== "all" ? ` with status "${statusFilter}"` : ""} for this period.
                      <br />
                      <span className="text-xs">If this period is filed, use <strong>Detect Amendments</strong> to scan for changes.</span>
                    </td>
                  </tr>
                ) : data.candidates.map(c => (
                  <tr
                    key={c.id}
                    className={`transition-colors ${
                      c.status === "detected" ? "hover:bg-amber-50/40" : "hover:bg-muted/20"
                    }`}
                  >
                    {/* Document number */}
                    <td className="px-4 py-3">
                      <p className="font-medium font-mono text-xs">{c.document_number}</p>
                      <p className="text-xs text-text-secondary mt-0.5">{c.source_type}</p>
                    </td>

                    {/* Amendment type */}
                    <td className="px-4 py-3">
                      <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-semibold ${TYPE_BADGE[c.amendment_type]}`}>
                        {TYPE_LABELS[c.amendment_type]}
                      </span>
                    </td>

                    {/* Status */}
                    <td className="px-4 py-3">
                      <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-xs font-semibold ${STATUS_BADGE[c.status]}`}>
                        {STATUS_ICON[c.status]}
                        {c.status.replace(/_/g, " ")}
                      </span>
                    </td>

                    {/* Values */}
                    <td className="px-4 py-3 text-right tabular-nums text-sm">{fmt(c.taxable_value_current)}</td>
                    <td className="px-4 py-3 text-right tabular-nums text-sm">{fmt(c.tax_current)}</td>

                    {/* Summary */}
                    <td className="px-4 py-3 text-xs text-text-secondary max-w-[220px]">
                      <span className="line-clamp-2">{c.change_summary}</span>
                    </td>

                    {/* Detected at */}
                    <td className="px-4 py-3 text-xs text-text-secondary whitespace-nowrap">
                      {fmtDate(c.detected_at)}
                    </td>

                    {/* Acknowledged by */}
                    <td className="px-4 py-3 text-xs text-text-secondary">
                      {c.acknowledged_by ? (
                        <span className="text-blue-700 font-medium">{c.acknowledged_by}</span>
                      ) : c.status === "detected" ? (
                        <Badge variant="outline" className="text-xs text-amber-600 border-amber-300">Pending</Badge>
                      ) : "—"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>

            {/* Footer count */}
            {data.candidates.length > 0 && (
              <div className="border-t px-4 py-3 text-xs text-text-secondary flex items-center justify-between bg-muted/20">
                <span>{data.count} total candidate{data.count !== 1 ? "s" : ""} for {MONTHS[month - 1]} {year}</span>
                {openCount > 0 && (
                  <span className="text-amber-600 font-semibold">{openCount} open — include in GSTR-1A before filing</span>
                )}
              </div>
            )}
          </div>
        )}

        {/* ── Empty state (no data loaded) ──────────────────────────────────── */}
        {!data && !loading && !error && (
          <div className="rounded-lg border bg-card py-16 text-center">
            <FileEdit className="h-10 w-10 text-text-secondary mx-auto mb-3 opacity-40" />
            <p className="text-sm text-text-secondary">
              Select a <strong>filed</strong> period, then click{" "}
              <strong>Detect Amendments</strong> to scan for post-filing changes.
            </p>
          </div>
        )}

      </div>
    </AppShell>
  );
}
