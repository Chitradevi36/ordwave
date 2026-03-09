"use client";

import { useState, useEffect, useCallback } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";
import { RefreshCw } from "lucide-react";
import { Button } from "@/components/ui/button";

// ── Types ─────────────────────────────────────────────────────────────────────

interface ReturnAnalytics {
  summary: {
    total_returns:   number;
    total_qty:       number;
    total_value:     number;
    approval_rate:   number;
  };
  by_reason: {
    reason_code:  string;
    count:        number;
    total_qty:    number;
    total_value:  number;
    pct_of_total: number;
  }[];
  by_product: {
    product_name: string;
    product_sku:  string;
    count:        number;
    total_qty:    number;
    total_value:  number;
  }[];
  by_customer: {
    customer_name: string;
    customer_code: string;
    count:         number;
    total_value:   number;
  }[];
  by_month: {
    month:        string;
    count:        number;
    total_value:  number;
  }[];
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const fmt     = (n: number) => `₹ ${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2 })}`;
const fmtNum  = (n: number) => Number(n).toLocaleString("en-IN");

const REASON_LABELS: Record<string, string> = {
  wrong_product:     "Wrong Product",
  damaged_in_transit:"Damaged in Transit",
  quality_issue:     "Quality Issue",
  expired:           "Expired",
  order_mistake:     "Order Mistake",
  excess_quantity:   "Excess Quantity",
  other:             "Other",
};

function todayStr()    { return new Date().toISOString().slice(0, 10); }
function thirtyDaysAgo() {
  const d = new Date();
  d.setDate(d.getDate() - 30);
  return d.toISOString().slice(0, 10);
}

// ── Page ──────────────────────────────────────────────────────────────────────

export default function ReturnAnalyticsPage() {
  const { token, orgId, branches } = useOrgBranch();

  const [from, setFrom]         = useState(thirtyDaysAgo());
  const [to, setTo]             = useState(todayStr());
  const [branchId, setBranchId] = useState("");
  const [data, setData]         = useState<ReturnAnalytics | null>(null);
  const [loading, setLoading]   = useState(false);
  const [error, setError]       = useState<string | null>(null);

  const fetchData = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams({ from, to });
      if (branchId) params.set("branch_id", branchId);
      const res = await fetch(`${API_URL}/api/v1/analytics/returns?${params}`, {
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
  }, [token, orgId, from, to, branchId]);

  useEffect(() => { fetchData(); }, [fetchData]);

  const inputCls = "h-9 rounded-md border border-border bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary";

  return (
    <AppShell breadcrumbs={[
      { label: "Insights", href: "/insights" },
      { label: "Returns Analytics" },
    ]}>
      <PageHeader
        title="Returns Analytics"
        subtitle="Analyse return patterns by reason, product, customer and time"
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
        <div className="flex items-center gap-2">
          <label className="text-sm text-text-secondary">Branch</label>
          <select className={inputCls} value={branchId} onChange={(e) => setBranchId(e.target.value)}>
            <option value="">All Branches</option>
            {branches?.map((b: { id: number; name: string }) => (
              <option key={b.id} value={b.id}>{b.name}</option>
            ))}
          </select>
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
          {/* Summary KPIs */}
          <div className="grid grid-cols-4 gap-4">
            {[
              { label: "Total Returns",  value: fmtNum(data.summary.total_returns) },
              { label: "Total Qty",      value: fmtNum(data.summary.total_qty) },
              { label: "Total Value",    value: fmt(data.summary.total_value) },
              { label: "Approval Rate",  value: `${Number(data.summary.approval_rate).toFixed(1)}%` },
            ].map(({ label, value }) => (
              <div key={label} className="rounded-lg border bg-card p-4">
                <p className="text-xs text-text-secondary">{label}</p>
                <p className="text-2xl font-bold mt-1">{value}</p>
              </div>
            ))}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* By Reason */}
            <div className="rounded-lg border bg-card p-5">
              <h3 className="text-xs font-semibold text-text-secondary uppercase tracking-wider mb-4">By Reason Code</h3>
              {data.by_reason.length === 0 ? (
                <p className="text-sm text-text-secondary">No data</p>
              ) : (
                <div className="space-y-3">
                  {data.by_reason.map((r) => (
                    <div key={r.reason_code}>
                      <div className="flex justify-between text-sm mb-1">
                        <span className="font-medium">{REASON_LABELS[r.reason_code] ?? r.reason_code}</span>
                        <span className="text-text-secondary">{r.count} returns · {fmt(r.total_value)}</span>
                      </div>
                      <div className="h-2 rounded-full bg-muted overflow-hidden">
                        <div
                          className="h-full bg-primary rounded-full"
                          style={{ width: `${Math.min(r.pct_of_total, 100)}%` }}
                        />
                      </div>
                      <p className="text-xs text-text-secondary mt-0.5">{Number(r.pct_of_total).toFixed(1)}% of total</p>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Monthly Trend */}
            <div className="rounded-lg border bg-card p-5">
              <h3 className="text-xs font-semibold text-text-secondary uppercase tracking-wider mb-4">Monthly Trend</h3>
              {data.by_month.length === 0 ? (
                <p className="text-sm text-text-secondary">No data</p>
              ) : (
                <table className="w-full text-sm">
                  <thead>
                    <tr>
                      <th className="text-left text-xs text-text-secondary pb-2">Month</th>
                      <th className="text-right text-xs text-text-secondary pb-2">Count</th>
                      <th className="text-right text-xs text-text-secondary pb-2">Value</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y">
                    {data.by_month.map((m) => (
                      <tr key={m.month}>
                        <td className="py-1.5 text-text-secondary">{m.month}</td>
                        <td className="py-1.5 text-right">{m.count}</td>
                        <td className="py-1.5 text-right font-medium">{fmt(m.total_value)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </div>

          {/* By Product */}
          <div className="rounded-lg border overflow-x-auto">
            <div className="px-4 py-3 bg-muted/40 border-b">
              <p className="text-xs font-semibold text-text-secondary uppercase tracking-wider">Top Products by Returns</p>
            </div>
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-muted/20">
                  {["Product", "SKU", "Return Count", "Qty Returned", "Total Value"].map((h) => (
                    <th key={h} className="px-3 py-2.5 text-left text-xs font-semibold text-text-secondary">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y">
                {data.by_product.length === 0 ? (
                  <tr><td colSpan={5} className="px-3 py-8 text-center text-text-secondary">No data</td></tr>
                ) : data.by_product.map((p, i) => (
                  <tr key={i} className="hover:bg-muted/20">
                    <td className="px-3 py-2 font-medium">{p.product_name}</td>
                    <td className="px-3 py-2 font-mono text-xs text-text-secondary">{p.product_sku}</td>
                    <td className="px-3 py-2 text-right">{p.count}</td>
                    <td className="px-3 py-2 text-right">{fmtNum(p.total_qty)}</td>
                    <td className="px-3 py-2 text-right font-semibold">{fmt(p.total_value)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* By Customer */}
          <div className="rounded-lg border overflow-x-auto">
            <div className="px-4 py-3 bg-muted/40 border-b">
              <p className="text-xs font-semibold text-text-secondary uppercase tracking-wider">Top Customers by Returns</p>
            </div>
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-muted/20">
                  {["Customer", "Code", "Return Count", "Total Value"].map((h) => (
                    <th key={h} className="px-3 py-2.5 text-left text-xs font-semibold text-text-secondary">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y">
                {data.by_customer.length === 0 ? (
                  <tr><td colSpan={4} className="px-3 py-8 text-center text-text-secondary">No data</td></tr>
                ) : data.by_customer.map((c, i) => (
                  <tr key={i} className="hover:bg-muted/20">
                    <td className="px-3 py-2 font-medium">{c.customer_name}</td>
                    <td className="px-3 py-2 font-mono text-xs text-text-secondary">{c.customer_code}</td>
                    <td className="px-3 py-2 text-right">{c.count}</td>
                    <td className="px-3 py-2 text-right font-semibold">{fmt(c.total_value)}</td>
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
