"use client";

import { useState, useEffect, useCallback } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";
import { RefreshCw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

// ── Types ─────────────────────────────────────────────────────────────────────

interface SchemeStat {
  scheme_id:         number;
  scheme_code:       string;
  scheme_name:       string;
  scheme_type:       string;
  redemption_count:  number;
  total_discount:    number;
  total_revenue:     number;
  roi_pct:           number | null;
  budget_amount:     number | null;
  budget_utilized:   number;
  budget_alert_pct:  number;
}

interface SchemeAnalytics {
  summary: {
    total_schemes:   number;
    active_schemes:  number;
    total_redemptions: number;
    total_discount:  number;
    total_revenue:   number;
    avg_roi_pct:     number | null;
  };
  schemes: SchemeStat[];
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const fmt    = (n: number) => `₹ ${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2 })}`;
const fmtNum = (n: number) => Number(n).toLocaleString("en-IN");

function todayStr()    { return new Date().toISOString().slice(0, 10); }
function thirtyDaysAgo() {
  const d = new Date();
  d.setDate(d.getDate() - 30);
  return d.toISOString().slice(0, 10);
}

const SCHEME_TYPE_LABEL: Record<string, string> = {
  item_discount:   "Item Discount",
  order_discount:  "Order Discount",
  free_goods:      "Free Goods",
  flat_price:      "Flat Price",
  buy_x_get_y:     "Buy X Get Y",
  volume_discount: "Volume Discount",
  slab_discount:   "Slab Discount",
  combo_discount:  "Combo Discount",
};

// ── Page ──────────────────────────────────────────────────────────────────────

export default function SchemeAnalyticsPage() {
  const { token, orgId } = useOrgBranch();

  const [from, setFrom]       = useState(thirtyDaysAgo());
  const [to, setTo]           = useState(todayStr());
  const [data, setData]       = useState<SchemeAnalytics | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError]     = useState<string | null>(null);

  const fetchData = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams({ from, to });
      const res = await fetch(`${API_URL}/api/v1/analytics/schemes?${params}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "Failed to load analytics");
      setData(body.data);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  }, [token, orgId, from, to]);

  useEffect(() => { fetchData(); }, [fetchData]);

  const inputCls = "h-9 rounded-md border border-border bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary";

  return (
    <AppShell breadcrumbs={[
      { label: "Insights",          href: "/insights" },
      { label: "Scheme Analytics" },
    ]}>
      <PageHeader
        title="Scheme Analytics"
        subtitle="Budget utilization, redemption rates and ROI for pricing schemes"
      />

      {/* Filters */}
      <div className="flex items-center gap-3 flex-wrap">
        <div className="flex items-center gap-2">
          <label className="text-sm text-text-secondary">From</label>
          <input type="date" className={inputCls} value={from} onChange={(e) => setFrom(e.target.value)} />
        </div>
        <div className="flex items-center gap-2">
          <label className="text-sm text-text-secondary">To</label>
          <input type="date" className={inputCls} value={to} onChange={(e) => setTo(e.target.value)} />
        </div>
        <Button size="sm" variant="outline" onClick={fetchData} disabled={loading}>
          <RefreshCw className={`h-3.5 w-3.5 mr-1.5 ${loading ? "animate-spin" : ""}`} />
          Refresh
        </Button>
      </div>

      {error && (
        <div className="rounded-md bg-destructive/10 border border-destructive/30 px-4 py-3 text-sm text-destructive">
          {error}
        </div>
      )}

      {loading && !data && (
        <div className="py-12 text-center text-sm text-text-secondary">Loading analytics…</div>
      )}

      {data && (
        <div className="space-y-6">
          {/* KPI cards */}
          <div className="grid grid-cols-3 lg:grid-cols-6 gap-4">
            {[
              { label: "Total Schemes",     value: fmtNum(data.summary.total_schemes) },
              { label: "Active Schemes",    value: fmtNum(data.summary.active_schemes) },
              { label: "Total Redemptions", value: fmtNum(data.summary.total_redemptions) },
              { label: "Total Discount",    value: fmt(data.summary.total_discount) },
              { label: "Total Revenue",     value: fmt(data.summary.total_revenue) },
              { label: "Avg ROI",           value: data.summary.avg_roi_pct != null ? `${Number(data.summary.avg_roi_pct).toFixed(1)}%` : "—" },
            ].map(({ label, value }) => (
              <div key={label} className="rounded-lg border border-border bg-surface p-4">
                <p className="text-xs text-text-secondary">{label}</p>
                <p className="text-lg font-bold mt-1 truncate">{value}</p>
              </div>
            ))}
          </div>

          {/* Budget Utilization */}
          {data.schemes.some((s) => s.budget_amount) && (
            <div className="rounded-lg border bg-card p-5">
              <h3 className="text-xs font-semibold text-text-secondary uppercase tracking-wider mb-4">Budget Utilization</h3>
              <div className="space-y-4">
                {data.schemes
                  .filter((s) => s.budget_amount)
                  .map((s) => {
                    const pct = Math.min((s.budget_utilized / (s.budget_amount!)) * 100, 100);
                    const alertPct = s.budget_alert_pct ?? 80;
                    const isAlerted = pct >= alertPct;
                    return (
                      <div key={s.scheme_id}>
                        <div className="flex items-center justify-between mb-1.5">
                          <div className="flex items-center gap-2">
                            <span className="text-sm font-medium">{s.scheme_name}</span>
                            <Badge variant="secondary" className="text-xs">{s.scheme_code}</Badge>
                            {isAlerted && (
                              <Badge variant="warning" className="text-xs">Alert</Badge>
                            )}
                          </div>
                          <span className="text-sm text-text-secondary">
                            {fmt(s.budget_utilized)} / {fmt(s.budget_amount!)} ({pct.toFixed(1)}%)
                          </span>
                        </div>
                        <div className="h-2.5 rounded-full bg-muted overflow-visible relative">
                          <div
                            className={`h-full rounded-full transition-all ${isAlerted ? "bg-amber-500" : "bg-primary"}`}
                            style={{ width: `${pct}%` }}
                          />
                          {/* Alert threshold marker */}
                          <div
                            className="absolute top-0 h-full w-0.5 bg-amber-400/60"
                            style={{ left: `${alertPct}%` }}
                            title={`Alert at ${alertPct}%`}
                          />
                        </div>
                      </div>
                    );
                  })}
              </div>
            </div>
          )}

          {/* Scheme Table */}
          <div className="rounded-lg border overflow-x-auto">
            <div className="px-4 py-3 bg-muted/40 border-b">
              <p className="text-xs font-semibold text-text-secondary uppercase tracking-wider">All Schemes Performance</p>
            </div>
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-muted/20">
                  {[
                    { label: "Scheme",         align: "text-left"  },
                    { label: "Type",           align: "text-left"  },
                    { label: "Redemptions",    align: "text-right" },
                    { label: "Total Discount", align: "text-right" },
                    { label: "Total Revenue",  align: "text-right" },
                    { label: "ROI %",          align: "text-right" },
                  ].map(({ label, align }) => (
                    <th key={label} className={`px-3 py-2.5 ${align} text-xs font-semibold text-text-secondary`}>{label}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y">
                {data.schemes.length === 0 ? (
                  <tr><td colSpan={6} className="px-3 py-8 text-center text-text-secondary">No scheme data for this period</td></tr>
                ) : data.schemes.map((s) => (
                  <tr key={s.scheme_id} className="hover:bg-muted/20">
                    <td className="px-3 py-2">
                      <div className="font-medium">{s.scheme_name}</div>
                      <div className="text-xs text-text-secondary font-mono">{s.scheme_code}</div>
                    </td>
                    <td className="px-3 py-2 text-text-secondary">
                      {SCHEME_TYPE_LABEL[s.scheme_type] ?? s.scheme_type}
                    </td>
                    <td className="px-3 py-2 text-right">{fmtNum(s.redemption_count)}</td>
                    <td className="px-3 py-2 text-right text-destructive">{fmt(s.total_discount)}</td>
                    <td className="px-3 py-2 text-right">{fmt(s.total_revenue)}</td>
                    <td className="px-3 py-2 text-right font-semibold">
                      {s.roi_pct != null ? (
                        <span className={s.roi_pct >= 0 ? "text-green-600" : "text-destructive"}>
                          {Number(s.roi_pct).toFixed(1)}%
                        </span>
                      ) : "—"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </AppShell>
  );
}
