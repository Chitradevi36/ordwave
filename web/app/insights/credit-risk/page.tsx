"use client";

import { useState, useEffect, useCallback } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";
import { RefreshCw, AlertTriangle, ShieldAlert, Eye } from "lucide-react";

function fmt(n: number | undefined | null, prefix = "") {
  if (n == null) return "—";
  return `${prefix}${Number(n).toLocaleString("en-IN")}`;
}

interface RiskyRetailer {
  id: number;
  customer_id: number;
  customer_name: string;
  customer_code: string;
  credit_limit: number;
  current_balance: number;
  available_credit: number;
  overdue_amount: number;
  overdue_days: number;
  hold_required: boolean;
  watchlist: boolean;
  overdue_bucket: string;
  utilization_pct: number;
}

interface CreditRiskData {
  summary?: {
    total_accounts?: number;
    risky_count?: number;
    blocked_count?: number;
    watchlist_count?: number;
    total_overdue?: number;
    total_exposure?: number;
  };
  aging_buckets?: {
    current?: number;
    d1_15?: number;
    d16_30?: number;
    d31_60?: number;
    over_60?: number;
  };
  risky_retailers?: RiskyRetailer[];
}

const retailerColumns: Column<RiskyRetailer>[] = [
  { key: "customer_name",    header: "Customer" },
  { key: "customer_code",    header: "Code" },
  { key: "credit_limit",     header: "Limit",       render: (v) => fmt(v as number, "₹") },
  { key: "current_balance",  header: "Balance",     render: (v) => fmt(v as number, "₹") },
  { key: "available_credit", header: "Available",   render: (v) => (
    <span className={(v as number) <= 0 ? "text-error font-semibold" : ""}>{fmt(v as number, "₹")}</span>
  )},
  { key: "overdue_amount",   header: "Overdue",     render: (v) => (
    <span className={(v as number) > 0 ? "text-error font-semibold" : ""}>{fmt(v as number, "₹")}</span>
  )},
  { key: "overdue_days",     header: "Days",        render: (v) => (
    <span className={(v as number) > 30 ? "text-error" : (v as number) > 0 ? "text-warning" : ""}>{fmt(v as number)}</span>
  )},
  { key: "utilization_pct",  header: "Utilization", render: (v) => `${Number(v).toFixed(1)}%` },
  { key: "hold_required",    header: "Hold",        render: (v) => v ? <Badge variant="danger">Held</Badge> : null },
  { key: "watchlist",        header: "Watchlist",   render: (v) => v ? <Badge variant="warning">Watch</Badge> : null },
];

export default function InsightsCreditRiskPage() {
  const { token, orgId, branches } = useOrgBranch();
  const [data, setData] = useState<CreditRiskData | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [branchId, setBranchId] = useState("");

  const fetchData = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const qp = new URLSearchParams();
      if (branchId) qp.set("branch_id", branchId);
      const res = await fetch(`${API_URL}/api/v1/analytics/credit_risk?${qp}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      if (!res.ok) throw new Error("Failed to load credit risk data");
      const json = await res.json();
      setData(json.data);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  }, [token, orgId, branchId]);

  useEffect(() => { void fetchData(); }, [fetchData]);

  const s = data?.summary;
  const b = data?.aging_buckets;

  const buckets = [
    { label: "Current (0 days)",   count: b?.current, color: "bg-success" },
    { label: "1–15 days",          count: b?.d1_15,   color: "bg-warning" },
    { label: "16–30 days",         count: b?.d16_30,  color: "bg-orange-400" },
    { label: "31–60 days",         count: b?.d31_60,  color: "bg-error" },
    { label: "Over 60 days",       count: b?.over_60, color: "bg-red-800" },
  ];
  const totalBucket = buckets.reduce((acc, bk) => acc + (bk.count ?? 0), 0) || 1;

  const statCards = [
    { label: "Total Accounts",   value: fmt(s?.total_accounts),       icon: AlertTriangle, color: "text-text-secondary" },
    { label: "Risky Accounts",   value: fmt(s?.risky_count),          icon: AlertTriangle, color: "text-warning" },
    { label: "Blocked Accounts", value: fmt(s?.blocked_count),        icon: ShieldAlert,   color: "text-error" },
    { label: "On Watchlist",     value: fmt(s?.watchlist_count),      icon: Eye,           color: "text-orange-500" },
    { label: "Total Overdue",    value: fmt(s?.total_overdue, "₹"),   icon: AlertTriangle, color: "text-error" },
    { label: "Total Exposure",   value: fmt(s?.total_exposure, "₹"),  icon: AlertTriangle, color: "text-warning" },
  ];

  return (
    <AppShell title="Credit Risk" breadcrumbs={[
      { label: "Insights", href: "/insights" },
      { label: "Credit Risk" },
    ]}>
      <PageHeader
        title="Credit Risk"
        description="Credit accounts with overdue, blocked or watchlist status."
        actions={[{ label: "Refresh", onClick: fetchData, icon: RefreshCw }]}
      />

      {/* Branch filter */}
      <div className="flex flex-wrap gap-3 px-6 mb-4">
        <select value={branchId} onChange={(e) => setBranchId(e.target.value)}
          className="h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent">
          <option value="">All Branches</option>
          {branches?.map((b: { id: number; name: string }) => (
            <option key={b.id} value={String(b.id)}>{b.name}</option>
          ))}
        </select>
      </div>

      {error && (
        <div className="mx-6 mb-4 rounded-md bg-danger/8 border border-danger/20 px-4 py-3 text-sm text-danger">{error}</div>
      )}

      {/* Stat Strip */}
      <div className="grid grid-cols-2 gap-3 px-6 mb-6 sm:grid-cols-3 lg:grid-cols-6">
        {statCards.map((s) => {
          const Icon = s.icon;
          return (
            <div key={s.label} className="rounded-lg border border-border bg-surface px-4 py-3">
              <div className="flex items-center justify-between mb-1">
                <span className="text-xs font-medium text-text-secondary">{s.label}</span>
                <Icon className={`h-3.5 w-3.5 ${s.color}`} />
              </div>
              {loading
                ? <span className="block h-4 w-16 animate-pulse rounded bg-border" />
                : <p className="text-lg font-bold text-text-primary">{s.value}</p>}
            </div>
          );
        })}
      </div>

      {/* Aging Buckets */}
      {data?.aging_buckets && (
        <div className="px-6 mb-6">
          <div className="rounded-lg border border-border overflow-hidden">
            <div className="px-4 py-3 border-b border-border bg-background-subtle">
              <span className="text-sm font-medium text-text-primary">Aging Breakdown</span>
            </div>
            <div className="px-4 py-4">
              <div className="space-y-3">
                {buckets.map((bk) => (
                  <div key={bk.label} className="flex items-center gap-3">
                    <span className="w-36 text-xs text-text-secondary shrink-0">{bk.label}</span>
                    <div className="flex-1 bg-surface rounded-full h-3 overflow-hidden">
                      <div
                        className={`h-full rounded-full ${bk.color}`}
                        style={{ width: `${Math.round(((bk.count ?? 0) / totalBucket) * 100)}%` }}
                      />
                    </div>
                    <span className="w-10 text-xs font-semibold text-right">{bk.count ?? 0}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Risky Retailers table */}
      <div className="px-6 pb-6">
        <div className="rounded-lg border border-border overflow-hidden">
          <div className="px-4 py-3 border-b border-border bg-background-subtle">
            <span className="text-sm font-medium text-text-primary">Risky Retailers</span>
          </div>
          <DataTable columns={retailerColumns} data={data?.risky_retailers ?? []} />
        </div>
      </div>
    </AppShell>
  );
}
