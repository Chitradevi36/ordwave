"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { useQueries } from "@tanstack/react-query";
import {
  AlertTriangle,
  ArrowRight,
  Banknote,
  Bot,
  Building2,
  CheckCircle2,
  ChevronRight,
  CircleAlert,
  Clock3,
  CreditCard,
  IndianRupee,
  Package2,
  Search,
  ShieldAlert,
  Siren,
  Target,
  TrendingDown,
  TrendingUp,
  Users,
} from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { apiClient } from "@/lib/api/client";
import { useApprovals } from "@/lib/api/hooks/useApprovals";
import { useCreditRisk } from "@/lib/api/hooks/useCreditRisk";
import { useOrgBranch } from "@/lib/org-branch-context";
import type { DashboardData, DashboardTimeseriesPoint } from "@/lib/api/hooks/useDashboard";

function fmtMoney(value: number | null | undefined, compact = false) {
  if (value == null) return "-";
  const sign = value < 0 ? "-" : "";
  const amount = Math.abs(value);
  if (!compact) return `${sign}Rs ${Number(amount).toLocaleString("en-IN")}`;
  if (amount >= 10_00_000) return `${sign}Rs ${(amount / 10_00_000).toFixed(1)}Cr`;
  if (amount >= 1_00_000) return `${sign}Rs ${(amount / 1_00_000).toFixed(1)}L`;
  if (amount >= 1_000) return `${sign}Rs ${(amount / 1_000).toFixed(1)}K`;
  return `${sign}Rs ${Number(amount).toLocaleString("en-IN")}`;
}

function fmtPct(value: number | null | undefined) {
  if (value == null || Number.isNaN(value)) return "0.0%";
  return `${value >= 0 ? "+" : ""}${value.toFixed(1)}%`;
}

function clamp(value: number, min = 0, max = 100) {
  return Math.max(min, Math.min(max, value));
}

function pctChange(current: number, previous: number) {
  if (!previous) return current > 0 ? 100 : 0;
  return ((current - previous) / previous) * 100;
}

function formatRelativeDate(dateString?: string) {
  if (!dateString) return "Just now";
  const value = new Date(dateString);
  if (Number.isNaN(value.getTime())) return "Just now";
  const diffMs = Date.now() - value.getTime();
  const diffMinutes = Math.round(diffMs / 60000);
  if (diffMinutes < 60) return `${Math.max(diffMinutes, 1)}m ago`;
  const diffHours = Math.round(diffMinutes / 60);
  if (diffHours < 24) return `${diffHours}h ago`;
  return `${Math.round(diffHours / 24)}d ago`;
}

function seriesForRange(points: DashboardTimeseriesPoint[] | undefined, range: "7d" | "30d" | "quarter" | "year") {
  const source = points ?? [];
  if (range === "7d") return source.slice(-7);
  if (range === "30d") return source.slice(-30);
  if (range === "quarter") return source.slice(-90);
  return source.slice(-365);
}

function progressWidth(value: number, total: number) {
  if (!total) return 0;
  return clamp((value / total) * 100);
}

function Sparkline({
  data,
  color,
  fill,
  className = "",
}: {
  data: number[];
  color: string;
  fill: string;
  className?: string;
}) {
  if (!data.length) {
    return <div className={`h-14 rounded-lg bg-background/60 ${className}`} />;
  }

  const width = 132;
  const height = 48;
  const pad = 4;
  const min = Math.min(...data);
  const max = Math.max(...data);
  const range = max - min || 1;
  const points = data
    .map((point, index) => {
      const x = pad + (index / Math.max(data.length - 1, 1)) * (width - pad * 2);
      const y = height - pad - ((point - min) / range) * (height - pad * 2);
      return `${x},${y}`;
    })
    .join(" ");

  const firstX = pad;
  const lastX = width - pad;
  const fillPoints = `${firstX},${height - pad} ${points} ${lastX},${height - pad}`;

  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} className={className} aria-hidden="true">
      <polygon points={fillPoints} fill={fill} />
      <polyline
        points={points}
        fill="none"
        stroke={color}
        strokeWidth={2}
        strokeLinejoin="round"
        strokeLinecap="round"
      />
    </svg>
  );
}

function ProgressRing({ value, tone }: { value: number; tone: string }) {
  const radius = 18;
  const circumference = 2 * Math.PI * radius;
  const dashOffset = circumference - (clamp(value) / 100) * circumference;

  return (
    <svg width="44" height="44" viewBox="0 0 44 44" aria-hidden="true">
      <circle cx="22" cy="22" r={radius} fill="none" stroke="#E5E7EB" strokeWidth="4" />
      <circle
        cx="22"
        cy="22"
        r={radius}
        fill="none"
        stroke={tone}
        strokeWidth="4"
        strokeLinecap="round"
        strokeDasharray={circumference}
        strokeDashoffset={dashOffset}
        transform="rotate(-90 22 22)"
      />
    </svg>
  );
}

function EmptyState({
  icon: Icon,
  title,
  description,
  href,
  cta,
}: {
  icon: typeof Bot;
  title: string;
  description: string;
  href: string;
  cta: string;
}) {
  return (
    <div className="flex min-h-[180px] flex-col items-center justify-center rounded-2xl border border-dashed border-border bg-background-subtle px-6 py-8 text-center">
      <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-primary/10 text-primary">
        <Icon className="h-5 w-5" />
      </div>
      <p className="mt-4 text-sm font-semibold text-text-primary">{title}</p>
      <p className="mt-2 max-w-sm text-sm text-text-secondary">{description}</p>
      <Link
        href={href}
        className="mt-4 inline-flex items-center gap-1 rounded-lg bg-primary px-3 py-2 text-sm font-medium text-white transition-colors hover:bg-primary-700"
      >
        {cta}
        <ArrowRight className="h-4 w-4" />
      </Link>
    </div>
  );
}

interface OwnerControlTowerProps {
  dashboard: DashboardData | undefined;
  isLoading: boolean;
}

export function OwnerControlTower({ dashboard, isLoading }: OwnerControlTowerProps) {
  const [analyticsMetric, setAnalyticsMetric] = useState<"revenue" | "collections" | "orders" | "profit">("revenue");
  const [analyticsRange, setAnalyticsRange] = useState<"7d" | "30d" | "quarter" | "year">("30d");
  const [searchTerm, setSearchTerm] = useState("");

  const { branches, branchId, orgId } = useOrgBranch();
  const { data: approvals } = useApprovals();
  const { data: creditRisk, isLoading: creditLoading } = useCreditRisk();

  const branchTargets = useMemo(() => {
    if (!orgId) return [];
    if (branchId) {
      return branches.filter((branch) => String(branch.id) === branchId).slice(0, 1);
    }
    return branches.slice(0, 6);
  }, [branches, branchId, orgId]);

  const branchSnapshots = useQueries({
    queries: branchTargets.map((branch) => ({
      queryKey: ["dashboard-branch-snapshot", { orgId, branchId: String(branch.id) }],
      queryFn: async () => {
        const { data } = await apiClient.get<{ data: DashboardData }>("/api/v1/dashboard", {
          params: { branch_id: branch.id },
        });
        return { branch, snapshot: data.data };
      },
      staleTime: 60_000,
      enabled: !!orgId,
    })),
  });

  const blockedOrders = approvals?.held_orders ?? [];
  const creditRequests = approvals?.credit_requests ?? [];
  const riskyRetailers = creditRisk?.risky_retailers ?? [];
  const collectionQueue = [...riskyRetailers]
    .sort((a, b) => {
      if (b.overdue_amount !== a.overdue_amount) return b.overdue_amount - a.overdue_amount;
      return b.overdue_days - a.overdue_days;
    })
    .slice(0, 5);

  const branchCards = branchSnapshots
    .map((branchQuery) => {
      const branch = branchQuery.data?.branch;
      const snapshot = branchQuery.data?.snapshot;
      const riskScore = snapshot
        ? snapshot.orders.on_hold * 4 +
          snapshot.credit.blocked_accounts * 5 +
          snapshot.inventory.low_stock * 2 +
          Math.ceil(snapshot.collections.overdue / 100000)
        : -1;
      const growth = snapshot?.revenue.delta_pct ?? 0;
      const healthScore = snapshot
        ? clamp(
            100 -
              snapshot.orders.on_hold * 6 -
              snapshot.credit.blocked_accounts * 8 -
              snapshot.inventory.low_stock * 2 -
              Math.min(snapshot.collections.overdue / 50000, 30) +
              Math.max(growth, 0) * 0.6,
          )
        : 0;

      return { branchQuery, branch, snapshot, riskScore, growth, healthScore };
    })
    .filter((item) => item.branch)
    .sort((a, b) => b.healthScore - a.healthScore);

  const bestBranchId = branchCards[0]?.branch?.id;
  const worstBranchId = branchCards[branchCards.length - 1]?.branch?.id;

  const timeseries = dashboard?.timeseries ?? [];
  const last30 = seriesForRange(timeseries, "30d");
  const prevRevenue = last30.at(-2)?.orders_value ?? 0;
  const prevCollections = last30.at(-2)?.collections ?? 0;
  const revenueToday = dashboard?.revenue.today_invoiced ?? 0;
  const collectionsToday = dashboard?.collections.today ?? 0;
  const outstanding = dashboard?.collections.outstanding ?? 0;
  const pendingApprovals = (dashboard?.orders.pending ?? 0) + creditRequests.length;
  const cashFlowProxy = collectionsToday - revenueToday;
  const profitMarginProxy = dashboard?.revenue.mtd
    ? ((dashboard.collections.mtd - dashboard.collections.overdue) / dashboard.revenue.mtd) * 100
    : 0;

  const kpis = [
    {
      label: "Revenue Today",
      value: fmtMoney(revenueToday, true),
      change: pctChange(revenueToday, prevRevenue),
      compareLabel: `vs ${fmtMoney(prevRevenue, true)} yesterday`,
      goal: clamp((revenueToday / Math.max((dashboard?.revenue.mtd ?? 0) / 20, 1)) * 100),
      trend: last30.map((point) => point.orders_value),
      href: "/orders",
      tone: "from-primary/15 via-primary/5 to-background",
      icon: IndianRupee,
      ring: "#1B5E20",
    },
    {
      label: "Collections Today",
      value: fmtMoney(collectionsToday, true),
      change: pctChange(collectionsToday, prevCollections),
      compareLabel: `vs ${fmtMoney(prevCollections, true)} yesterday`,
      goal: clamp((collectionsToday / Math.max((dashboard?.collections.mtd ?? 0) / 20, 1)) * 100),
      trend: last30.map((point) => point.collections),
      href: "/collections",
      tone: "from-emerald-100 via-background to-background",
      icon: Banknote,
      ring: "#2E7D32",
    },
    {
      label: "Outstanding",
      value: fmtMoney(outstanding, true),
      change: pctChange(outstanding, dashboard?.credit.total_overdue ?? 0),
      compareLabel: `${fmtMoney(dashboard?.credit.total_overdue ?? 0, true)} overdue inside book`,
      goal: clamp(100 - (outstanding / Math.max((dashboard?.collections.mtd ?? 1) * 1.2, 1)) * 100),
      trend: last30.map((point) => Math.max(point.orders_value - point.collections, 0)),
      href: "/insights/credit-risk",
      tone: "from-red-50 via-background to-background",
      icon: CreditCard,
      ring: "#DC2626",
    },
    {
      label: "Pending Approvals",
      value: pendingApprovals.toLocaleString("en-IN"),
      change: pctChange(pendingApprovals, dashboard?.orders.yesterday ?? 0),
      compareLabel: `${blockedOrders.length} blocked orders, ${creditRequests.length} credit requests`,
      goal: clamp(100 - pendingApprovals * 8),
      trend: [
        dashboard?.orders.approved ?? 0,
        dashboard?.orders.pending ?? 0,
        dashboard?.orders.on_hold ?? 0,
        blockedOrders.length,
        creditRequests.length,
      ],
      href: "/approvals",
      tone: "from-amber-50 via-background to-background",
      icon: ShieldAlert,
      ring: "#D97706",
    },
    {
      label: "Cash Flow",
      value: fmtMoney(cashFlowProxy, true),
      change: pctChange(cashFlowProxy, prevCollections - prevRevenue),
      compareLabel: "Collections minus invoiced today",
      goal: clamp(((cashFlowProxy + Math.max(revenueToday, 1)) / Math.max(revenueToday * 1.4, 1)) * 100),
      trend: last30.map((point) => point.collections - point.orders_value),
      href: "/finance",
      tone: "from-blue-50 via-background to-background",
      icon: TrendingUp,
      ring: "#2563EB",
    },
    {
      label: "Profit Margin",
      value: `${Math.max(profitMarginProxy, 0).toFixed(1)}%`,
      change: dashboard?.revenue.delta_pct ?? 0,
      compareLabel: "Proxy until margin feed is wired",
      goal: clamp((Math.max(profitMarginProxy, 0) / 25) * 100),
      trend: last30.map((point) => (point.orders_value ? ((point.collections - point.orders_value * 0.82) / point.orders_value) * 100 : 0)),
      href: "/insights",
      tone: "from-violet-50 via-background to-background",
      icon: Target,
      ring: "#7C3AED",
    },
  ];

  const actionItems = [
    ...blockedOrders.slice(0, 3).map((order) => ({
      key: `held-${order.id}`,
      severity: "critical" as const,
      icon: Siren,
      title: `${order.order_number} blocked for approval`,
      description: `${order.customer_name} • ${order.lines_count} item${order.lines_count === 1 ? "" : "s"}`,
      amount: fmtMoney(order.total_amount, true),
      owner: order.created_by || "Sales",
      href: `/orders/${order.id}`,
      cta: "Open order",
    })),
    ...creditRequests.slice(0, 2).map((request) => ({
      key: `credit-${request.id}`,
      severity: "high" as const,
      icon: ShieldAlert,
      title: `${request.customer_name} credit limit request`,
      description: `Requested ${fmtMoney(request.new_limit, true)} from ${fmtMoney(request.current_limit, true)}`,
      amount: fmtMoney(request.new_limit - request.current_limit, true),
      owner: request.requested_by || "Finance",
      href: "/approvals/credit-limits",
      cta: "Review credit",
    })),
    ...collectionQueue.slice(0, 2).map((retailer) => ({
      key: `collect-${retailer.id}`,
      severity: retailer.hold_required ? ("critical" as const) : ("high" as const),
      icon: AlertTriangle,
      title: `${retailer.customer_name} overdue follow-up`,
      description: `${retailer.customer_code} • ${retailer.overdue_days}d overdue`,
      amount: fmtMoney(retailer.overdue_amount, true),
      owner: "Collections",
      href: "/collections",
      cta: "Collect now",
    })),
    ...(dashboard && dashboard.inventory.low_stock > 0
      ? [
          {
            key: "inventory-low",
            severity: "medium" as const,
            icon: Package2,
            title: `${dashboard.inventory.low_stock} SKUs below threshold`,
            description: "Refill fast movers before the next branch cycle",
            amount: `${dashboard.inventory.low_stock} SKUs`,
            owner: "Warehouse",
            href: "/inventory/stock",
            cta: "View stock",
          },
        ]
      : []),
    ...(dashboard && dashboard.alerts.length > 0
      ? [
          {
            key: "ops-exception",
            severity: "medium" as const,
            icon: CircleAlert,
            title: dashboard.alerts[0].label,
            description: "Operational exception detected in live dashboard feed",
            amount: dashboard.alerts[0].count.toLocaleString("en-IN"),
            owner: "Ops",
            href: dashboard.alerts[0].href,
            cta: "Resolve",
          },
        ]
      : []),
  ];

  const filteredActions = actionItems.filter((item) => {
    const haystack = `${item.title} ${item.description} ${item.owner}`.toLowerCase();
    return haystack.includes(searchTerm.toLowerCase());
  });

  const analyticsSeries = useMemo(() => {
    const selected = seriesForRange(timeseries, analyticsRange);
    return selected.map((point) => {
      if (analyticsMetric === "collections") return point.collections;
      if (analyticsMetric === "orders") return point.orders_value;
      if (analyticsMetric === "profit") return point.collections - point.orders_value * 0.82;
      return point.orders_value;
    });
  }, [analyticsMetric, analyticsRange, timeseries]);

  const analyticsCurrent = analyticsSeries.reduce((sum, item) => sum + item, 0);
  const analyticsPrevious = useMemo(() => {
    const bucketSize = analyticsSeries.length;
    if (!bucketSize) return 0;
    const values = (timeseries ?? []).map((point) => {
      if (analyticsMetric === "collections") return point.collections;
      if (analyticsMetric === "orders") return point.orders_value;
      if (analyticsMetric === "profit") return point.collections - point.orders_value * 0.82;
      return point.orders_value;
    });
    return values.slice(-bucketSize * 2, -bucketSize).reduce((sum, value) => sum + value, 0);
  }, [analyticsMetric, analyticsRange, analyticsSeries.length, timeseries]);

  const inventoryTotal =
    (dashboard?.inventory.low_stock ?? 0) +
    (dashboard?.inventory.zero_stock ?? 0) +
    (dashboard?.inventory.dead_stock ?? 0) +
    Math.max(dashboard?.top_products.length ?? 0, 1);

  const inventoryHealth = [
    {
      label: "Low Stock",
      value: dashboard?.inventory.low_stock ?? 0,
      tone: "bg-amber-500",
      trend: dashboard && dashboard.inventory.low_stock > 0 ? "Needs refill" : "Healthy",
    },
    {
      label: "Out of Stock",
      value: dashboard?.inventory.zero_stock ?? 0,
      tone: "bg-red-500",
      trend: dashboard && dashboard.inventory.zero_stock > 0 ? "Immediate risk" : "Covered",
    },
    {
      label: "Dead Stock",
      value: dashboard?.inventory.dead_stock ?? 0,
      tone: "bg-slate-500",
      trend: "Aging inventory",
    },
    {
      label: "Fast Moving",
      value: dashboard?.top_products.slice(0, 5).length ?? 0,
      tone: "bg-primary",
      trend: "Top SKUs driving demand",
    },
    {
      label: "Slow Moving",
      value: (dashboard?.inventory.dead_stock ?? 0) + Math.max((dashboard?.inventory.zero_stock ?? 0) - 1, 0),
      tone: "bg-orange-500",
      trend: "Clear via scheme or transfer",
    },
  ];

  const topRiskRetailers = [...riskyRetailers]
    .sort((a, b) => b.overdue_amount - a.overdue_amount)
    .slice(0, 5);

  const activity = [
    ...(blockedOrders[0]
      ? [
          {
            key: `blocked-${blockedOrders[0].id}`,
            title: `Order ${blockedOrders[0].order_number} moved to hold`,
            subtitle: blockedOrders[0].customer_name,
            time: blockedOrders[0].created_at,
            tone: "text-danger",
            icon: Siren,
          },
        ]
      : []),
    ...(creditRequests[0]
      ? [
          {
            key: `creditreq-${creditRequests[0].id}`,
            title: "Credit approval requested",
            subtitle: `${creditRequests[0].customer_name} requested by ${creditRequests[0].requested_by}`,
            time: creditRequests[0].created_at,
            tone: "text-amber-700",
            icon: ShieldAlert,
          },
        ]
      : []),
    ...(collectionsToday > 0
      ? [
          {
            key: "collection-today",
            title: "Payment received",
            subtitle: `${fmtMoney(collectionsToday, true)} collected today`,
            time: new Date(Date.now() - 45 * 60000).toISOString(),
            tone: "text-primary",
            icon: Banknote,
          },
        ]
      : []),
    ...(dashboard && dashboard.orders.approved > 0
      ? [
          {
            key: "approved-today",
            title: "Orders approved",
            subtitle: `${dashboard.orders.approved} orders progressed today`,
            time: new Date(Date.now() - 90 * 60000).toISOString(),
            tone: "text-blue-700",
            icon: CheckCircle2,
          },
        ]
      : []),
    ...(dashboard && dashboard.inventory.low_stock > 0
      ? [
          {
            key: "stock-alert",
            title: "Stock threshold crossed",
            subtitle: `${dashboard.inventory.low_stock} SKUs are below reorder level`,
            time: new Date(Date.now() - 3 * 3600 * 1000).toISOString(),
            tone: "text-amber-700",
            icon: Package2,
          },
        ]
      : []),
    ...(topRiskRetailers[0]?.hold_required
      ? [
          {
            key: "retailer-blocked",
            title: "Retailer placed on credit hold",
            subtitle: topRiskRetailers[0].customer_name,
            time: new Date(Date.now() - 5 * 3600 * 1000).toISOString(),
            tone: "text-danger",
            icon: Users,
          },
        ]
      : []),
  ].sort((a, b) => new Date(b.time).getTime() - new Date(a.time).getTime());

  const creditSummary = creditRisk?.summary;
  const avgCollectionDays = topRiskRetailers.length
    ? Math.round(topRiskRetailers.reduce((sum, retailer) => sum + retailer.overdue_days, 0) / topRiskRetailers.length)
    : 0;

  if (isLoading && !dashboard) {
    return (
      <div className="mb-6 space-y-4">
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-6">
          {Array.from({ length: 6 }).map((_, index) => (
            <div key={index} className="h-48 animate-pulse rounded-2xl border border-border bg-background-subtle" />
          ))}
        </div>
        <div className="grid grid-cols-1 gap-4 xl:grid-cols-[1.5fr_1fr]">
          <div className="h-[420px] animate-pulse rounded-2xl border border-border bg-background-subtle" />
          <div className="h-[420px] animate-pulse rounded-2xl border border-border bg-background-subtle" />
        </div>
        <div className="grid grid-cols-1 gap-4 xl:grid-cols-3">
          {Array.from({ length: 3 }).map((_, index) => (
            <div key={index} className="h-[340px] animate-pulse rounded-2xl border border-border bg-background-subtle" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="mb-6 space-y-4">
      <section className="rounded-3xl border border-border bg-gradient-to-br from-primary/[0.06] via-background to-background p-4 shadow-sm sm:p-6">
        <div className="flex flex-col gap-4 xl:flex-row xl:items-start xl:justify-between">
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <Badge variant="success" className="px-3 py-1 text-[11px] uppercase tracking-wide">
                Executive Command Center
              </Badge>
              <Badge variant="outline" className="px-3 py-1 text-[11px]">
                As of {dashboard?.as_of ?? "Today"}
              </Badge>
            </div>
            <h2 className="mt-3 text-2xl font-semibold text-text-primary sm:text-3xl">
              Operational visibility for revenue, risk, and branch control.
            </h2>
            <p className="mt-2 max-w-3xl text-sm text-text-secondary sm:text-base">
              Designed for fast executive decisions: what changed today, where cash is stuck, which branch needs intervention,
              and what should be approved next.
            </p>
          </div>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-[minmax(220px,1fr)_auto] xl:w-[440px]">
            <label className="flex h-11 items-center gap-2 rounded-xl border border-border bg-background px-3 shadow-sm">
              <Search className="h-4 w-4 text-text-secondary" />
              <input
                value={searchTerm}
                onChange={(event) => setSearchTerm(event.target.value)}
                placeholder="Search actions, branches, or retailers"
                className="w-full bg-transparent text-sm text-text-primary outline-none placeholder:text-text-secondary"
                aria-label="Search dashboard actions"
              />
            </label>
            <div className="flex flex-wrap gap-2">
              <Link href="/orders/new" className="inline-flex h-11 items-center gap-2 rounded-xl bg-primary px-4 text-sm font-semibold text-white transition-colors hover:bg-primary-700">
                <ArrowRight className="h-4 w-4" />
                New order
              </Link>
              <Link href="/collections" className="inline-flex h-11 items-center gap-2 rounded-xl border border-border bg-background px-4 text-sm font-medium text-text-primary transition-colors hover:bg-background-subtle">
                <Banknote className="h-4 w-4 text-primary" />
                Collect
              </Link>
            </div>
          </div>
        </div>

        <div className="mt-6 grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-6">
          {kpis.map((kpi) => {
            const TrendIcon = kpi.change >= 0 ? TrendingUp : TrendingDown;
            return (
              <Link
                key={kpi.label}
                href={kpi.href}
                className={`group min-h-[192px] rounded-2xl border border-border bg-gradient-to-br ${kpi.tone} p-4 shadow-sm transition-all duration-200 hover:-translate-y-0.5 hover:shadow-md`}
              >
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <p className="text-xs font-semibold uppercase tracking-wide text-text-secondary">{kpi.label}</p>
                    <p className="mt-3 text-3xl font-semibold tracking-tight text-text-primary">{kpi.value}</p>
                  </div>
                  <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-background text-primary shadow-sm">
                    <kpi.icon className="h-5 w-5" />
                  </div>
                </div>
                <div className="mt-4 flex items-center justify-between gap-3">
                  <div>
                    <div className={`inline-flex items-center gap-1 rounded-full px-2 py-1 text-xs font-semibold ${kpi.change >= 0 ? "bg-accent/15 text-[#1B4332]" : "bg-red-100 text-danger"}`}>
                      <TrendIcon className="h-3.5 w-3.5" />
                      {fmtPct(kpi.change)}
                    </div>
                    <p className="mt-2 text-xs text-text-secondary">{kpi.compareLabel}</p>
                  </div>
                  <ProgressRing value={kpi.goal} tone={kpi.ring} />
                </div>
                <div className="mt-4">
                  <Sparkline data={kpi.trend} color={kpi.ring} fill={`${kpi.ring}20`} />
                </div>
                <div className="mt-3">
                  <div className="flex items-center justify-between text-[11px] text-text-secondary">
                    <span>Goal progress</span>
                    <span>{Math.round(kpi.goal)}%</span>
                  </div>
                  <div className="mt-2 h-2 rounded-full bg-background/80">
                    <div className="h-2 rounded-full bg-primary transition-all" style={{ width: `${kpi.goal}%` }} />
                  </div>
                </div>
              </Link>
            );
          })}
        </div>
      </section>

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-[1.5fr_1fr]">
        <Card className="overflow-hidden rounded-2xl">
          <CardHeader className="border-b border-border bg-background/80 pb-4">
            <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
              <div>
                <CardTitle className="text-base font-semibold">Action Center</CardTitle>
                <p className="text-sm text-text-secondary">The exceptions that deserve attention before more orders move.</p>
              </div>
              <div className="flex flex-wrap gap-2">
                <Badge variant="danger" className="px-3 py-1">{blockedOrders.length} blocked</Badge>
                <Badge variant="warning" className="px-3 py-1">{creditRequests.length} pending credit</Badge>
                <Badge variant="outline" className="px-3 py-1">{collectionQueue.length} collections due</Badge>
              </div>
            </div>
          </CardHeader>
          <CardContent className="p-0">
            {filteredActions.length === 0 ? (
              <div className="p-6">
                <EmptyState
                  icon={CheckCircle2}
                  title="Your action queue is under control"
                  description="No urgent blocks matched this search. Use the queue to stay ahead of approvals, collections, and stock risk."
                  href="/approvals"
                  cta="Review approvals"
                />
              </div>
            ) : (
              <div className="divide-y divide-border">
                {filteredActions.map((item) => {
                  const severityStyles = {
                    critical: "border-danger bg-red-50/40 text-danger",
                    high: "border-amber-500 bg-amber-50/60 text-amber-700",
                    medium: "border-blue-500 bg-blue-50/60 text-blue-700",
                  }[item.severity];

                  return (
                    <div key={item.key} className="grid gap-3 px-4 py-4 transition-colors hover:bg-background-subtle sm:grid-cols-[auto_1.5fr_auto_auto_auto] sm:items-center sm:px-6">
                      <div className={`flex h-10 w-10 items-center justify-center rounded-xl border-l-4 ${severityStyles}`}>
                        <item.icon className="h-4 w-4" />
                      </div>
                      <div className="min-w-0">
                        <p className="truncate text-sm font-semibold text-text-primary">{item.title}</p>
                        <p className="truncate text-sm text-text-secondary">{item.description}</p>
                      </div>
                      <p className="text-sm font-semibold text-text-primary">{item.amount}</p>
                      <p className="text-sm text-text-secondary">{item.owner}</p>
                      <Link
                        href={item.href}
                        className="inline-flex items-center justify-center rounded-lg bg-primary px-3 py-2 text-sm font-medium text-white transition-colors hover:bg-primary-700"
                      >
                        {item.cta}
                      </Link>
                    </div>
                  );
                })}
              </div>
            )}
          </CardContent>
        </Card>

        <Card className="overflow-hidden rounded-2xl">
          <CardHeader className="border-b border-border pb-4">
            <div className="flex items-start justify-between gap-3">
              <div>
                <CardTitle className="text-base font-semibold">Live Activity</CardTitle>
                <p className="text-sm text-text-secondary">Business events flowing through approvals, collections, and fulfillment.</p>
              </div>
              <Link href="/orders" className="flex items-center gap-1 text-xs font-medium text-accent hover:underline">
                Details
                <ChevronRight className="h-3 w-3" />
              </Link>
            </div>
          </CardHeader>
          <CardContent className="space-y-4 pt-4">
            {activity.length === 0 ? (
              <EmptyState
                icon={Clock3}
                title="Your activity feed is waiting for today’s movement"
                description="Once approvals, payments, dispatches, or inventory exceptions start moving, they will show up here."
                href="/orders/new"
                cta="Create first order"
              />
            ) : (
              activity.slice(0, 6).map((item, index) => (
                <div key={item.key} className="relative flex gap-3">
                  {index < Math.min(activity.length, 6) - 1 && <div className="absolute left-5 top-10 h-[calc(100%-1rem)] w-px bg-border" />}
                  <div className="relative z-10 flex h-10 w-10 items-center justify-center rounded-xl bg-background-subtle">
                    <item.icon className={`h-4 w-4 ${item.tone}`} />
                  </div>
                  <div className="min-w-0 flex-1 pb-3">
                    <div className="flex items-center justify-between gap-3">
                      <p className="text-sm font-semibold text-text-primary">{item.title}</p>
                      <span className="shrink-0 text-xs text-text-secondary">{formatRelativeDate(item.time)}</span>
                    </div>
                    <p className="text-sm text-text-secondary">{item.subtitle}</p>
                  </div>
                </div>
              ))
            )}
          </CardContent>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-[1.35fr_1fr]">
        <Card className="rounded-2xl">
          <CardHeader className="border-b border-border pb-4">
            <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
              <div>
                <CardTitle className="text-base font-semibold">Branch Performance</CardTitle>
                <p className="text-sm text-text-secondary">Ranked by health score so the best and weakest branches are obvious.</p>
              </div>
              <div className="flex flex-wrap gap-2">
                {bestBranchId && <Badge variant="success" className="px-3 py-1">Best branch highlighted</Badge>}
                {worstBranchId && branchCards.length > 1 && <Badge variant="danger" className="px-3 py-1">Worst branch highlighted</Badge>}
              </div>
            </div>
          </CardHeader>
          <CardContent className="p-0">
            {!branchCards.length ? (
              <div className="p-6">
                <EmptyState
                  icon={Building2}
                  title="Branch views unlock when branch data is active"
                  description="Add branches or sync branch-level activity to compare revenue, collections, and risk side by side."
                  href="/settings"
                  cta="Review setup"
                />
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full min-w-[860px] text-sm">
                  <thead className="bg-background-subtle">
                    <tr className="border-b border-border text-left">
                      <th className="px-4 py-3 font-medium text-text-secondary">Branch</th>
                      <th className="px-4 py-3 font-medium text-text-secondary">Revenue</th>
                      <th className="px-4 py-3 font-medium text-text-secondary">Collections</th>
                      <th className="px-4 py-3 font-medium text-text-secondary">Outstanding</th>
                      <th className="px-4 py-3 font-medium text-text-secondary">Risk</th>
                      <th className="px-4 py-3 font-medium text-text-secondary">Growth</th>
                      <th className="px-4 py-3 font-medium text-text-secondary">Health</th>
                    </tr>
                  </thead>
                  <tbody>
                    {branchCards.map(({ branchQuery, branch, snapshot, riskScore, growth, healthScore }) => {
                      const isBest = branch?.id === bestBranchId;
                      const isWorst = branch?.id === worstBranchId && branchCards.length > 1;
                      const rowClasses = isBest
                        ? "bg-accent/5"
                        : isWorst
                          ? "bg-red-50/50"
                          : "bg-background";

                      return (
                        <tr key={branch?.id} className={`border-b border-border transition-colors hover:bg-background-subtle ${rowClasses}`}>
                          <td className="px-4 py-4">
                            <div className="flex items-center gap-3">
                              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10 text-primary">
                                <Building2 className="h-4 w-4" />
                              </div>
                              <div>
                                <div className="flex flex-wrap items-center gap-2">
                                  <p className="font-semibold text-text-primary">{branch?.name}</p>
                                  {isBest && <Badge variant="success" className="text-[10px]">Best</Badge>}
                                  {isWorst && <Badge variant="danger" className="text-[10px]">Needs attention</Badge>}
                                </div>
                                <p className="text-xs text-text-secondary">{branch?.code ?? "Branch snapshot"}</p>
                              </div>
                            </div>
                          </td>
                          <td className="px-4 py-4 font-semibold text-text-primary">
                            {branchQuery.isLoading ? "Loading..." : fmtMoney(snapshot?.revenue.mtd, true)}
                          </td>
                          <td className="px-4 py-4 text-text-primary">{fmtMoney(snapshot?.collections.mtd, true)}</td>
                          <td className="px-4 py-4 text-text-primary">{fmtMoney(snapshot?.collections.outstanding, true)}</td>
                          <td className="px-4 py-4">
                            <div className="flex items-center gap-2">
                              <span className={`inline-flex h-2.5 w-2.5 rounded-full ${riskScore > 25 ? "bg-danger" : riskScore > 10 ? "bg-amber-500" : "bg-primary"}`} />
                              <span className="font-medium text-text-primary">{riskScore}</span>
                            </div>
                          </td>
                          <td className={`px-4 py-4 font-medium ${growth >= 0 ? "text-primary" : "text-danger"}`}>{fmtPct(growth)}</td>
                          <td className="px-4 py-4">
                            <div className="flex items-center gap-3">
                              <div className="h-2 w-24 rounded-full bg-background-subtle">
                                <div className={`h-2 rounded-full ${healthScore >= 75 ? "bg-primary" : healthScore >= 50 ? "bg-amber-500" : "bg-danger"}`} style={{ width: `${healthScore}%` }} />
                              </div>
                              <span className="font-semibold text-text-primary">{Math.round(healthScore)}</span>
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </CardContent>
        </Card>

        <Card className="rounded-2xl">
          <CardHeader className="border-b border-border pb-4">
            <div className="flex items-start justify-between gap-3">
              <div>
                <CardTitle className="text-base font-semibold">Credit Health</CardTitle>
                <p className="text-sm text-text-secondary">Exposure, overdue pressure, and who can block tomorrow’s orders.</p>
              </div>
              <Link href="/insights/credit-risk" className="flex items-center gap-1 text-xs font-medium text-accent hover:underline">
                Full risk view
                <ChevronRight className="h-3 w-3" />
              </Link>
            </div>
          </CardHeader>
          <CardContent className="space-y-4 pt-4">
            <div className="grid grid-cols-2 gap-3">
              <div className="rounded-xl border border-border bg-background-subtle p-3">
                <p className="text-xs text-text-secondary">Total Outstanding</p>
                <p className="mt-2 text-lg font-semibold text-text-primary">{fmtMoney(dashboard?.collections.outstanding, true)}</p>
              </div>
              <div className="rounded-xl border border-border bg-background-subtle p-3">
                <p className="text-xs text-text-secondary">Overdue</p>
                <p className="mt-2 text-lg font-semibold text-danger">{fmtMoney(creditSummary?.total_overdue ?? dashboard?.credit.total_overdue, true)}</p>
              </div>
              <div className="rounded-xl border border-border bg-background-subtle p-3">
                <p className="text-xs text-text-secondary">Blocked Amount</p>
                <p className="mt-2 text-lg font-semibold text-text-primary">{fmtMoney(topRiskRetailers.filter((retailer) => retailer.hold_required).reduce((sum, retailer) => sum + retailer.overdue_amount, 0), true)}</p>
              </div>
              <div className="rounded-xl border border-border bg-background-subtle p-3">
                <p className="text-xs text-text-secondary">Average Collection Days</p>
                <p className="mt-2 text-lg font-semibold text-text-primary">{avgCollectionDays}d</p>
              </div>
            </div>

            <div>
              <div className="mb-3 flex items-center justify-between">
                <p className="text-sm font-semibold text-text-primary">Top 5 Risk Retailers</p>
                <Badge variant="warning" className="px-3 py-1">{creditSummary?.blocked_count ?? dashboard?.credit.blocked_accounts ?? 0} blocked</Badge>
              </div>
              {creditLoading && topRiskRetailers.length === 0 ? (
                <div className="space-y-2">
                  {Array.from({ length: 5 }).map((_, index) => (
                    <div key={index} className="h-14 animate-pulse rounded-xl bg-background-subtle" />
                  ))}
                </div>
              ) : topRiskRetailers.length === 0 ? (
                <EmptyState
                  icon={Users}
                  title="Credit risk is stable today"
                  description="No risky retailers have breached the thresholds used by the command center."
                  href="/customers"
                  cta="Review customers"
                />
              ) : (
                <div className="space-y-2">
                  {topRiskRetailers.map((retailer) => (
                    <Link
                      key={retailer.id}
                      href={`/customers/${retailer.customer_id}`}
                      className="flex items-center justify-between gap-3 rounded-xl border border-border px-3 py-3 transition-colors hover:bg-background-subtle"
                    >
                      <div className="min-w-0">
                        <div className="flex flex-wrap items-center gap-2">
                          <p className="truncate text-sm font-semibold text-text-primary">{retailer.customer_name}</p>
                          {retailer.hold_required && <Badge variant="danger" className="text-[10px]">Hold</Badge>}
                          {retailer.watchlist && <Badge variant="warning" className="text-[10px]">Watch</Badge>}
                        </div>
                        <p className="text-xs text-text-secondary">{retailer.customer_code} • {retailer.overdue_days}d overdue • {retailer.utilization_pct.toFixed(0)}% utilized</p>
                      </div>
                      <div className="text-right">
                        <p className="text-sm font-semibold text-danger">{fmtMoney(retailer.overdue_amount, true)}</p>
                        <p className="text-xs text-text-secondary">{fmtMoney(retailer.available_credit, true)} available</p>
                      </div>
                    </Link>
                  ))}
                </div>
              )}
            </div>
          </CardContent>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-[1.25fr_1fr]">
        <Card className="rounded-2xl">
          <CardHeader className="border-b border-border pb-4">
            <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
              <div>
                <CardTitle className="text-base font-semibold">Revenue Analytics</CardTitle>
                <p className="text-sm text-text-secondary">Switch between business lenses without leaving the command center.</p>
              </div>
              <div className="flex flex-wrap gap-2">
                {(["7d", "30d", "quarter", "year"] as const).map((range) => (
                  <button
                    key={range}
                    onClick={() => setAnalyticsRange(range)}
                    className={`rounded-lg px-3 py-2 text-sm font-medium transition-colors ${analyticsRange === range ? "bg-primary text-white" : "border border-border bg-background text-text-primary hover:bg-background-subtle"}`}
                  >
                    {range === "7d" ? "7 Days" : range === "30d" ? "30 Days" : range === "quarter" ? "Quarter" : "Year"}
                  </button>
                ))}
              </div>
            </div>
          </CardHeader>
          <CardContent className="pt-4">
            <div className="flex flex-wrap gap-2">
              {([
                { key: "revenue", label: "Revenue" },
                { key: "collections", label: "Collections" },
                { key: "orders", label: "Orders" },
                { key: "profit", label: "Profit" },
              ] as const).map((option) => (
                <button
                  key={option.key}
                  onClick={() => setAnalyticsMetric(option.key)}
                  className={`rounded-full px-3 py-1.5 text-sm font-medium transition-colors ${analyticsMetric === option.key ? "bg-primary text-white" : "bg-background-subtle text-text-secondary hover:text-text-primary"}`}
                >
                  {option.label}
                </button>
              ))}
            </div>

            <div className="mt-4 grid grid-cols-1 gap-4 lg:grid-cols-[1fr_280px]">
              <div className="rounded-2xl border border-border bg-background-subtle p-4">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <p className="text-xs font-semibold uppercase tracking-wide text-text-secondary">{analyticsMetric}</p>
                    <p className="mt-2 text-2xl font-semibold text-text-primary">{fmtMoney(analyticsCurrent, true)}</p>
                  </div>
                  <Badge variant={analyticsCurrent >= analyticsPrevious ? "success" : "danger"} className="px-3 py-1">
                    {fmtPct(pctChange(analyticsCurrent, analyticsPrevious))}
                  </Badge>
                </div>
                <div className="mt-4 rounded-xl border border-border bg-background px-3 py-4">
                  <Sparkline data={analyticsSeries} color="#1B5E20" fill="#1B5E2020" className="h-[180px] w-full" />
                </div>
              </div>
              <div className="space-y-3">
                <div className="rounded-2xl border border-border bg-background-subtle p-4">
                  <p className="text-xs text-text-secondary">Comparison</p>
                  <p className="mt-2 text-lg font-semibold text-text-primary">{fmtMoney(analyticsPrevious, true)}</p>
                  <p className="mt-1 text-sm text-text-secondary">Previous period for the same selected range.</p>
                </div>
                <div className="rounded-2xl border border-border bg-background-subtle p-4">
                  <p className="text-xs text-text-secondary">Executive note</p>
                  <p className="mt-2 text-sm text-text-primary">
                    {analyticsMetric === "profit"
                      ? "Profit is using a proxy until direct margin data is available from finance."
                      : "Use this switcher to compare commercial momentum with actual cash realization."}
                  </p>
                </div>
                <div className="rounded-2xl border border-border bg-background-subtle p-4">
                  <p className="text-xs text-text-secondary">Best next action</p>
                  <p className="mt-2 text-sm text-text-primary">
                    {pendingApprovals > 0
                      ? "Reduce approval backlog first to keep revenue conversion moving."
                      : dashboard && dashboard.credit.total_overdue > 0
                        ? "Push collections follow-up to improve cash conversion."
                        : "Momentum is healthy. Focus on branch execution and stock coverage."}
                  </p>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="rounded-2xl">
          <CardHeader className="border-b border-border pb-4">
            <div className="flex items-start justify-between gap-3">
              <div>
                <CardTitle className="text-base font-semibold">Inventory Health</CardTitle>
                <p className="text-sm text-text-secondary">Fast scan of pressure points before they spill into order service.</p>
              </div>
              <Link href="/inventory/stock" className="flex items-center gap-1 text-xs font-medium text-accent hover:underline">
                Open stock
                <ChevronRight className="h-3 w-3" />
              </Link>
            </div>
          </CardHeader>
          <CardContent className="space-y-4 pt-4">
            {inventoryHealth.map((metric) => (
              <div key={metric.label} className="rounded-xl border border-border px-3 py-3">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <p className="text-sm font-semibold text-text-primary">{metric.label}</p>
                    <p className="text-xs text-text-secondary">{metric.trend}</p>
                  </div>
                  <p className="text-lg font-semibold text-text-primary">{metric.value.toLocaleString("en-IN")}</p>
                </div>
                <div className="mt-3 h-2 rounded-full bg-background-subtle">
                  <div className={`h-2 rounded-full ${metric.tone}`} style={{ width: `${progressWidth(metric.value, inventoryTotal)}%` }} />
                </div>
              </div>
            ))}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
