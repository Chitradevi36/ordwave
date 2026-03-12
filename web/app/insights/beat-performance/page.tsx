"use client";

import { useState, useEffect, useCallback } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { DataTable, Column } from "@/components/ui/data-table";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";
import { RefreshCw, MapPin, CheckCircle, ShoppingCart, Wallet } from "lucide-react";
import {
  ResponsiveContainer, BarChart, Bar, XAxis, YAxis,
  CartesianGrid, Tooltip, Legend, RadarChart, Radar,
  PolarGrid, PolarAngleAxis, PolarRadiusAxis,
} from "recharts";

function fmt(n: number | undefined | null) {
  if (n == null) return "—";
  return Number(n).toLocaleString("en-IN");
}
function fmtPct(n: number | undefined | null) {
  if (n == null) return "—";
  return `${Number(n).toFixed(1)}%`;
}

interface RepRow {
  id: number;
  rep_id: number;
  name: string;
  completed: number;
  planned: number;
  skipped: number;
  total: number;
  completion_rate: number;
}

interface BeatRow {
  id: number;
  beat_id: number;
  beat_name: string;
  completed: number;
  skipped: number;
  total: number;
  completion_rate: number;
}

interface BeatData {
  summary?: {
    visits_planned?: number;
    visits_completed?: number;
    visits_skipped?: number;
    completion_rate?: number;
    order_conversion_rate?: number;
    collection_conversion_rate?: number;
    orders_from_visits?: number;
    collections_from_visits?: number;
  };
  reps_table?: RepRow[];
  beats_table?: BeatRow[];
}

const repColumns: Column<RepRow>[] = [
  { key: "name",            header: "Sales Rep" },
  { key: "completed",       header: "Completed",        render: (v) => fmt(v as number) },
  { key: "planned",         header: "Planned",          render: (v) => fmt(v as number) },
  { key: "skipped",         header: "Skipped",          render: (v) => fmt(v as number) },
  { key: "completion_rate", header: "Completion Rate",  render: (v) => fmtPct(v as number) },
];

const beatColumns: Column<BeatRow>[] = [
  { key: "beat_name",       header: "Beat" },
  { key: "total",           header: "Total Visits",     render: (v) => fmt(v as number) },
  { key: "completed",       header: "Completed",        render: (v) => fmt(v as number) },
  { key: "skipped",         header: "Skipped",          render: (v) => fmt(v as number) },
  { key: "completion_rate", header: "Completion Rate",  render: (v) => fmtPct(v as number) },
];

export default function InsightsBeatPerformancePage() {
  const { token, orgId, branches } = useOrgBranch();
  const [data, setData] = useState<BeatData | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [branchId, setBranchId] = useState("");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");

  const fetchData = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const qp = new URLSearchParams();
      if (branchId) qp.set("branch_id", branchId);
      if (dateFrom) qp.set("date_from", dateFrom);
      if (dateTo)   qp.set("date_to", dateTo);
      const res = await fetch(`${API_URL}/api/v1/analytics/beat_performance?${qp}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      if (!res.ok) throw new Error("Failed to load beat performance data");
      const json = await res.json();
      setData(json.data);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  }, [token, orgId, branchId, dateFrom, dateTo]);

  useEffect(() => { void fetchData(); }, [fetchData]);

  const s = data?.summary;
  const statCards = [
    { label: "Visits Planned",        value: fmt(s?.visits_planned),               icon: MapPin,      color: "text-text-secondary" },
    { label: "Visits Completed",      value: fmt(s?.visits_completed),             icon: CheckCircle, color: "text-success" },
    { label: "Visits Skipped",        value: fmt(s?.visits_skipped),               icon: MapPin,      color: "text-warning" },
    { label: "Completion Rate",       value: fmtPct(s?.completion_rate),           icon: CheckCircle, color: "text-primary" },
    { label: "Order Conversion",      value: fmtPct(s?.order_conversion_rate),     icon: ShoppingCart, color: "text-secondary" },
    { label: "Collection Conversion", value: fmtPct(s?.collection_conversion_rate), icon: Wallet,     color: "text-accent" },
  ];

  return (
    <AppShell title="Beat Performance" breadcrumbs={[
      { label: "Insights", href: "/insights" },
      { label: "Beat Performance" },
    ]}>
      <PageHeader
        title="Beat Performance"
        description="Visit activity and conversion rates for the selected period."
        actions={[{ label: "Refresh", onClick: fetchData, icon: RefreshCw }]}
      />

      {/* Filters */}
      <div className="flex flex-wrap gap-3 px-6 mb-4">
        <select value={branchId} onChange={(e) => setBranchId(e.target.value)}
          className="h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent">
          <option value="">All Branches</option>
          {branches?.map((b: { id: number; name: string }) => (
            <option key={b.id} value={String(b.id)}>{b.name}</option>
          ))}
        </select>
        <input type="date" value={dateFrom} onChange={(e) => setDateFrom(e.target.value)}
          className="h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent" />
        <input type="date" value={dateTo} onChange={(e) => setDateTo(e.target.value)}
          className="h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent" />
      </div>

      {error && (
        <div className="mx-6 mb-4 rounded-md bg-danger/8 border border-danger/20 px-4 py-3 text-sm text-danger">{error}</div>
      )}

      {/* Summary funnel */}
      {s && (
        <div className="px-6 mb-6">
          <div className="rounded-lg border border-border overflow-hidden">
            <div className="px-4 py-3 border-b border-border bg-background-subtle">
              <span className="text-sm font-medium text-text-primary">Visit Funnel</span>
            </div>
            <div className="px-4 py-4">
              <div className="flex items-end gap-4 flex-wrap">
                {[
                  { label: "Planned",     count: s.visits_planned ?? 0,    pct: 100 },
                  { label: "Completed",   count: s.visits_completed ?? 0,  pct: s.completion_rate ?? 0 },
                  { label: "Orders",      count: s.orders_from_visits ?? 0, pct: s.order_conversion_rate ?? 0 },
                  { label: "Collections", count: s.collections_from_visits ?? 0, pct: s.collection_conversion_rate ?? 0 },
                ].map((step) => (
                  <div key={step.label} className="flex flex-col items-center gap-1 min-w-[72px]">
                    <span className="text-xl font-bold text-text-primary">{fmt(step.count)}</span>
                    <div className="w-full bg-surface rounded h-2">
                      <div className="bg-primary h-2 rounded" style={{ width: `${Math.min(step.pct, 100)}%` }} />
                    </div>
                    <span className="text-xs text-text-secondary">{step.label}</span>
                    <span className="text-xs text-primary font-medium">{fmtPct(step.pct)}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
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

      {/* Per-rep and per-beat charts + tables */}
      <div className="grid grid-cols-1 gap-5 px-6 pb-6 lg:grid-cols-2">
        {/* Sales Rep stacked bar chart */}
        <div className="rounded-lg border border-border bg-surface p-4">
          <p className="mb-3 text-sm font-semibold text-text-primary">By Sales Rep — Visits</p>
          {(data?.reps_table?.length ?? 0) > 0 ? (
            <ResponsiveContainer width="100%" height={220}>
              <BarChart
                data={data?.reps_table?.slice(0, 10) ?? []}
                margin={{ top: 0, right: 8, left: 0, bottom: 0 }}
              >
                <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
                <XAxis
                  dataKey="name"
                  tickLine={false}
                  axisLine={false}
                  tick={{ fontSize: 10, fill: "hsl(var(--text-secondary))" }}
                  interval={0}
                  angle={-30}
                  textAnchor="end"
                  height={50}
                />
                <YAxis tickLine={false} axisLine={false} tick={{ fontSize: 10, fill: "hsl(var(--text-secondary))" }} />
                <Tooltip
                  contentStyle={{ background: "hsl(var(--surface))", border: "1px solid hsl(var(--border))", borderRadius: 6, fontSize: 12 }}
                />
                <Legend wrapperStyle={{ fontSize: 11 }} />
                <Bar dataKey="completed" name="Completed" stackId="v" fill="#10b981" radius={[0, 0, 0, 0]} />
                <Bar dataKey="skipped"   name="Skipped"   stackId="v" fill="#f59e0b" radius={[3, 3, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          ) : (
            <DataTable columns={repColumns} data={(data?.reps_table ?? []).map((r) => ({ ...r, id: r.rep_id }))} />
          )}
        </div>

        {/* Beat radar chart */}
        <div className="rounded-lg border border-border bg-surface p-4">
          <p className="mb-3 text-sm font-semibold text-text-primary">By Beat — Completion Rate</p>
          {(data?.beats_table?.length ?? 0) > 0 ? (
            <ResponsiveContainer width="100%" height={220}>
              <RadarChart data={(data?.beats_table ?? []).slice(0, 8).map((b) => ({ ...b, subject: b.beat_name.slice(0, 12) }))}>
                <PolarGrid stroke="hsl(var(--border))" />
                <PolarAngleAxis dataKey="subject" tick={{ fontSize: 10, fill: "hsl(var(--text-secondary))" }} />
                <PolarRadiusAxis
                  angle={30}
                  domain={[0, 100]}
                  tick={{ fontSize: 9, fill: "hsl(var(--text-secondary))" }}
                />
                <Radar name="Completion %" dataKey="completion_rate" stroke="#3b82f6" fill="#3b82f6" fillOpacity={0.25} strokeWidth={2} />
                <Tooltip
                  contentStyle={{ background: "hsl(var(--surface))", border: "1px solid hsl(var(--border))", borderRadius: 6, fontSize: 12 }}
                  formatter={(v: number) => [`${v.toFixed(1)}%`, "Completion"]}
                />
              </RadarChart>
            </ResponsiveContainer>
          ) : (
            <DataTable columns={beatColumns} data={(data?.beats_table ?? []).map((b) => ({ ...b, id: b.beat_id }))} />
          )}
        </div>
      </div>

      {/* Raw tables for detail */}
      <div className="grid grid-cols-1 gap-5 px-6 pb-6 lg:grid-cols-2">
        <div className="rounded-lg border border-border overflow-hidden">
          <div className="px-4 py-3 border-b border-border bg-background-subtle">
            <span className="text-sm font-medium text-text-primary">Sales Rep Detail</span>
          </div>
          <DataTable columns={repColumns} data={(data?.reps_table ?? []).map((r) => ({ ...r, id: r.rep_id }))} />
        </div>
        <div className="rounded-lg border border-border overflow-hidden">
          <div className="px-4 py-3 border-b border-border bg-background-subtle">
            <span className="text-sm font-medium text-text-primary">Beat Detail</span>
          </div>
          <DataTable columns={beatColumns} data={(data?.beats_table ?? []).map((b) => ({ ...b, id: b.beat_id }))} />
        </div>
      </div>
    </AppShell>
  );
}
