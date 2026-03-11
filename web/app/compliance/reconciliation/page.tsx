"use client";

import { useState, useCallback, useEffect } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { useOrgBranch } from "@/lib/org-branch-context";
import { RefreshCw, Zap, CheckCircle2, EyeOff, Eye, AlertTriangle, XOctagon, Info } from "lucide-react";

// ── Types ─────────────────────────────────────────────────────────────────────

interface ReconciliationIssue {
  id: number;
  issue_type: string;
  severity: string;
  status: string;
  summary: string;
  supplier_gstin: string | null;
  customer_gstin: string | null;
  invoice_number: string | null;
  invoice_date: string | null;
  amount_books: number | null;
  amount_portal: number | null;
  difference_amount: number | null;
  difference_formatted: string | null;
  resolution_notes: string | null;
  resolved_at: string | null;
  created_at: string;
}

interface IssuesSummary {
  month: number;
  year: number;
  total: number;
  by_severity: Record<string, number>;
  by_type: Record<string, number>;
  by_status: Record<string, number>;
  blocking_count: number;
}

interface IssuesResponse {
  total: number;
  issues: ReconciliationIssue[];
}

// ── Helpers ───────────────────────────────────────────────────────────────────

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

const SEVERITY_META: Record<string, { label: string; color: string; icon: React.ReactNode }> = {
  blocking: { label: "Blocking", color: "bg-red-100 text-red-700 border border-red-200",    icon: <XOctagon className="h-3.5 w-3.5" /> },
  high:     { label: "High",     color: "bg-orange-100 text-orange-700",                   icon: <AlertTriangle className="h-3.5 w-3.5" /> },
  medium:   { label: "Medium",   color: "bg-yellow-100 text-yellow-700",                   icon: <AlertTriangle className="h-3.5 w-3.5" /> },
  low:      { label: "Low",      color: "bg-gray-100 text-gray-600",                       icon: <Info className="h-3.5 w-3.5" /> },
};

const STATUS_META: Record<string, { label: string; color: string }> = {
  open:         { label: "Open",         color: "bg-red-50 text-red-700" },
  acknowledged: { label: "Acknowledged", color: "bg-blue-50 text-blue-700" },
  resolved:     { label: "Resolved",     color: "bg-green-50 text-green-600" },
  ignored:      { label: "Ignored",      color: "bg-gray-50 text-gray-500" },
};

const ISSUE_TYPE_LABELS: Record<string, string> = {
  missing_in_2b:             "Missing in 2B",
  missing_in_books:          "Missing in Books",
  tax_mismatch:              "Tax Mismatch",
  date_mismatch:             "Date Mismatch",
  gstin_mismatch:            "GSTIN Mismatch",
  invoice_value_mismatch:    "Value Mismatch",
  duplicate_invoice:         "Duplicate Invoice",
  invalid_hsn:               "Invalid HSN",
  missing_gstin:             "Missing GSTIN",
  reverse_charge_mismatch:   "RC Mismatch",
  itc_risk:                  "ITC Risk",
};

const sel = "h-9 rounded-md border border-border bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary";

// ── Page ──────────────────────────────────────────────────────────────────────

export default function ReconciliationPage() {
  const { token, orgId } = useOrgBranch();

  const [month, setMonth] = useState(defaultMonth);
  const [year, setYear]   = useState(defaultYear);

  const [issues, setIssues]       = useState<IssuesResponse | null>(null);
  const [summary, setSummary]     = useState<IssuesSummary | null>(null);
  const [loading, setLoading]     = useState(false);
  const [running, setRunning]     = useState(false);
  const [error, setError]         = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  // Filter state
  const [severityFilter, setSeverityFilter] = useState("all");
  const [statusFilter, setStatusFilter]     = useState("open");
  const [typeFilter, setTypeFilter]         = useState("all");

  // Resolution modal
  const [modalIssue, setModalIssue]   = useState<ReconciliationIssue | null>(null);
  const [modalAction, setModalAction] = useState<"resolve" | "ignore" | null>(null);
  const [modalNotes, setModalNotes]   = useState("");
  const [submitting, setSubmitting]   = useState(false);

  const h = useCallback(() => ({
    Authorization: `Bearer ${token}`,
    "X-Organization-Id": orgId ?? "",
    "Content-Type": "application/json",
  }), [token, orgId]);

  // ── Fetch issues + summary ────────────────────────────────────────────────
  const fetchData = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const severityQ = severityFilter !== "all" ? `&severity=${severityFilter}` : "";
      const statusQ   = statusFilter   !== "all" ? `&status=${statusFilter}`     : "";
      const typeQ     = typeFilter     !== "all" ? `&issue_type=${typeFilter}`    : "";

      const [issuesRes, summaryRes] = await Promise.all([
        fetch(`/api/v1/compliance/reconciliation/issues?${severityQ}${statusQ}${typeQ}`, { headers: h() }),
        fetch(`/api/v1/compliance/reconciliation/summary?month=${month}&year=${year}`, { headers: h() }),
      ]);
      const [issuesBody, summaryBody] = await Promise.all([issuesRes.json(), summaryRes.json()]);

      if (!issuesRes.ok) throw new Error(issuesBody.errors?.join(", ") || "Failed to load issues");
      if (!summaryRes.ok) throw new Error(summaryBody.errors?.join(", ") || "Failed to load summary");

      setIssues(issuesBody.data);
      setSummary(summaryBody.data);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load");
    } finally {
      setLoading(false);
    }
  }, [token, orgId, month, year, severityFilter, statusFilter, typeFilter, h]);

  useEffect(() => {
    if (token && orgId) fetchData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [month, year, token, orgId, severityFilter, statusFilter, typeFilter]);

  // ── Run reconciliation engine ─────────────────────────────────────────────
  const handleRun = async () => {
    if (!token || !orgId) return;
    setRunning(true);
    setError(null);
    try {
      const res = await fetch("/api/v1/compliance/reconciliation/run", {
        method: "POST",
        headers: h(),
        body: JSON.stringify({ month, year }),
      });
      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "Run failed");
      await fetchData();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Run failed");
    } finally {
      setRunning(false);
    }
  };

  // ── Quick action: acknowledge ─────────────────────────────────────────────
  const handleAcknowledge = async (issue: ReconciliationIssue) => {
    setActionError(null);
    try {
      const res = await fetch(`/api/v1/compliance/reconciliation/issues/${issue.id}/acknowledge`, {
        method: "POST", headers: h(),
      });
      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "Failed");
      setIssues(prev => prev ? {
        ...prev,
        issues: prev.issues.map(i => i.id === issue.id ? body.data : i),
      } : prev);
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Action failed");
    }
  };

  // ── Modal action: resolve / ignore ────────────────────────────────────────
  const openModal = (issue: ReconciliationIssue, action: "resolve" | "ignore") => {
    setModalIssue(issue);
    setModalAction(action);
    setModalNotes("");
  };

  const handleModalSubmit = async () => {
    if (!modalIssue || !modalAction) return;
    setSubmitting(true);
    setActionError(null);
    try {
      const endpoint = modalAction === "resolve"
        ? `/api/v1/compliance/reconciliation/issues/${modalIssue.id}/resolve`
        : `/api/v1/compliance/reconciliation/issues/${modalIssue.id}/ignore`;

      const body = modalAction === "resolve"
        ? { notes: modalNotes }
        : { reason: modalNotes };

      const res = await fetch(endpoint, {
        method: "POST", headers: h(), body: JSON.stringify(body),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.errors?.join(", ") || "Action failed");

      setIssues(prev => prev ? {
        ...prev,
        issues: prev.issues.map(i => i.id === modalIssue.id ? data.data : i),
      } : prev);
      setModalIssue(null);
      setModalAction(null);
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Action failed");
    } finally {
      setSubmitting(false);
    }
  };

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <AppShell title="Reconciliation" hideBreadcrumb>
      <PageHeader
        title="GST Reconciliation"
        subtitle="Review and resolve discrepancies between books and portal data"
        actions={[
          {
            label:   running ? "Running…" : "Run Engine",
            onClick: handleRun,
            icon:    Zap,
            disabled: running || loading,
          },
        ]}
      />

      <div className="space-y-6">

        {/* ── Filters ──────────────────────────────────────────────────── */}
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

          <div className="h-5 w-px bg-border" />

          <select className={sel} value={severityFilter} onChange={e => setSeverityFilter(e.target.value)}>
            <option value="all">All Severities</option>
            <option value="blocking">Blocking</option>
            <option value="high">High</option>
            <option value="medium">Medium</option>
            <option value="low">Low</option>
          </select>

          <select className={sel} value={statusFilter} onChange={e => setStatusFilter(e.target.value)}>
            <option value="all">All Statuses</option>
            <option value="open">Open</option>
            <option value="acknowledged">Acknowledged</option>
            <option value="resolved">Resolved</option>
            <option value="ignored">Ignored</option>
          </select>

          <select className={sel} value={typeFilter} onChange={e => setTypeFilter(e.target.value)}>
            <option value="all">All Types</option>
            {Object.entries(ISSUE_TYPE_LABELS).map(([k, v]) => (
              <option key={k} value={k}>{v}</option>
            ))}
          </select>

          <Button variant="outline" onClick={fetchData} disabled={loading}>
            <RefreshCw className={`h-3.5 w-3.5 mr-1.5 ${loading ? "animate-spin" : ""}`} />
            Refresh
          </Button>
        </div>

        {/* ── Error ────────────────────────────────────────────────────── */}
        {error && (
          <div className="rounded-md bg-destructive/10 border border-destructive/30 px-4 py-3 text-sm text-destructive">
            {error}
          </div>
        )}
        {actionError && (
          <div className="rounded-md bg-destructive/10 border border-destructive/30 px-4 py-2.5 text-sm text-destructive">
            {actionError}
          </div>
        )}

        {/* ── Summary cards ─────────────────────────────────────────────── */}
        {summary && (
          <div className="grid grid-cols-2 sm:grid-cols-5 gap-4">
            <div className="rounded-lg border bg-card px-5 py-4 col-span-2 sm:col-span-1">
              <p className="text-xs text-text-secondary mb-1">Total Issues</p>
              <p className="text-2xl font-bold tabular-nums">{summary.total}</p>
            </div>
            {(["blocking","high","medium","low"] as const).map(sev => {
              const meta = SEVERITY_META[sev];
              const count = summary.by_severity[sev] ?? 0;
              return (
                <div key={sev} className="rounded-lg border bg-card px-5 py-4">
                  <div className="flex items-center gap-1.5 mb-1">
                    <span className={`inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-xs font-medium ${meta.color}`}>
                      {meta.icon} {meta.label}
                    </span>
                  </div>
                  <p className="text-xl font-bold tabular-nums">{count}</p>
                </div>
              );
            })}
          </div>
        )}

        {/* ── Loading skeleton ─────────────────────────────────────────── */}
        {loading && !issues && (
          <div className="space-y-2 animate-pulse">
            {[0,1,2,3,4].map(i => <div key={i} className="h-14 rounded-lg border bg-muted/40" />)}
          </div>
        )}

        {/* ── Issues table ─────────────────────────────────────────────── */}
        {issues && (
          <div className="rounded-lg border overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-muted/40 border-b">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-semibold text-text-secondary uppercase tracking-wide">Issue</th>
                  <th className="px-4 py-3 text-left text-xs font-semibold text-text-secondary uppercase tracking-wide">Severity</th>
                  <th className="px-4 py-3 text-left text-xs font-semibold text-text-secondary uppercase tracking-wide">Status</th>
                  <th className="px-4 py-3 text-left text-xs font-semibold text-text-secondary uppercase tracking-wide">Invoice</th>
                  <th className="px-4 py-3 text-left text-xs font-semibold text-text-secondary uppercase tracking-wide">Supplier</th>
                  <th className="px-4 py-3 text-right text-xs font-semibold text-text-secondary uppercase tracking-wide">Difference</th>
                  <th className="px-4 py-3 text-left text-xs font-semibold text-text-secondary uppercase tracking-wide w-36">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {issues.issues.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="px-4 py-12 text-center text-text-secondary">
                      <CheckCircle2 className="h-8 w-8 mx-auto mb-2 text-green-400" />
                      No issues found for the selected filters
                    </td>
                  </tr>
                ) : issues.issues.map(issue => {
                  const sev    = SEVERITY_META[issue.severity] ?? SEVERITY_META.low;
                  const status = STATUS_META[issue.status]     ?? STATUS_META.open;
                  const isOpen = issue.status === "open";
                  const isAck  = issue.status === "acknowledged";

                  return (
                    <tr key={issue.id} className="hover:bg-muted/20 transition-colors">
                      <td className="px-4 py-3 max-w-[240px]">
                        <p className="font-medium text-xs text-text-primary truncate">{issue.summary}</p>
                        <p className="text-xs text-text-secondary mt-0.5">
                          {ISSUE_TYPE_LABELS[issue.issue_type] ?? issue.issue_type}
                        </p>
                      </td>
                      <td className="px-4 py-3">
                        <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-xs font-medium ${sev.color}`}>
                          {sev.icon} {sev.label}
                        </span>
                      </td>
                      <td className="px-4 py-3">
                        <span className={`inline-flex px-2 py-0.5 rounded text-xs font-medium ${status.color}`}>
                          {status.label}
                        </span>
                      </td>
                      <td className="px-4 py-3">
                        <p className="font-mono text-xs font-medium">{issue.invoice_number ?? "—"}</p>
                        <p className="text-xs text-text-secondary">{issue.invoice_date ?? ""}</p>
                      </td>
                      <td className="px-4 py-3">
                        <p className="font-mono text-xs text-text-secondary">{issue.supplier_gstin ?? "—"}</p>
                      </td>
                      <td className="px-4 py-3 text-right tabular-nums text-sm">
                        {issue.difference_formatted ?? "—"}
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-1.5">
                          {isOpen && (
                            <button
                              onClick={() => handleAcknowledge(issue)}
                              title="Acknowledge"
                              className="p-1 rounded hover:bg-blue-50 text-blue-500 transition-colors"
                            >
                              <Eye className="h-3.5 w-3.5" />
                            </button>
                          )}
                          {(isOpen || isAck) && (
                            <>
                              <button
                                onClick={() => openModal(issue, "resolve")}
                                title="Resolve"
                                className="p-1 rounded hover:bg-green-50 text-green-600 transition-colors"
                              >
                                <CheckCircle2 className="h-3.5 w-3.5" />
                              </button>
                              <button
                                onClick={() => openModal(issue, "ignore")}
                                title="Ignore"
                                className="p-1 rounded hover:bg-gray-100 text-gray-500 transition-colors"
                              >
                                <EyeOff className="h-3.5 w-3.5" />
                              </button>
                            </>
                          )}
                          {issue.status === "resolved" && (
                            <span className="text-xs text-green-600 flex items-center gap-1">
                              <CheckCircle2 className="h-3.5 w-3.5" /> Resolved
                            </span>
                          )}
                          {issue.status === "ignored" && (
                            <span className="text-xs text-gray-400 flex items-center gap-1">
                              <EyeOff className="h-3.5 w-3.5" /> Ignored
                            </span>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>

            {/* Pagination footer */}
            {issues.total > 50 && (
              <div className="px-4 py-2.5 border-t bg-muted/20 text-xs text-text-secondary">
                Showing {issues.issues.length} of {issues.total} issues
              </div>
            )}
          </div>
        )}

      </div>

      {/* ── Resolution Modal ─────────────────────────────────────────────── */}
      {modalIssue && modalAction && (
        <div className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4">
          <div className="bg-background rounded-xl border shadow-xl w-full max-w-md p-6 space-y-4">
            <h3 className="text-base font-semibold capitalize">
              {modalAction === "resolve" ? "Resolve Issue" : "Ignore Issue"}
            </h3>
            <p className="text-sm text-text-secondary">{modalIssue.summary}</p>
            <div>
              <label className="text-xs font-medium text-text-secondary block mb-1">
                {modalAction === "resolve" ? "Resolution notes" : "Reason for ignoring"}
              </label>
              <textarea
                className="w-full h-24 rounded-md border border-border bg-background px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary resize-none"
                placeholder={modalAction === "resolve" ? "Describe how the issue was resolved…" : "Why is this being ignored?"}
                value={modalNotes}
                onChange={e => setModalNotes(e.target.value)}
              />
            </div>
            {actionError && (
              <p className="text-xs text-destructive">{actionError}</p>
            )}
            <div className="flex justify-end gap-3 pt-1">
              <Button variant="outline" onClick={() => { setModalIssue(null); setModalAction(null); }}>
                Cancel
              </Button>
              <Button
                onClick={handleModalSubmit}
                disabled={submitting}
                className={modalAction === "resolve" ? "bg-primary hover:bg-primary-700" : "bg-gray-600 hover:bg-gray-700"}
              >
                {submitting ? "Saving…" : modalAction === "resolve" ? "Mark Resolved" : "Ignore"}
              </Button>
            </div>
          </div>
        </div>
      )}
    </AppShell>
  );
}
