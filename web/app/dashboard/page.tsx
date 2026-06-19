"use client";

import Link from "next/link";
import { useEffect } from "react";
import { useRouter } from "next/navigation";
import {
  Plus, ShoppingCart, TrendingUp, Wallet, AlertTriangle,
  CreditCard, Package, Users, Tag, AlertCircle,
  CheckCircle2, Clock, Ban, ChevronRight,
} from "lucide-react";
import { useOnboardingGuard } from "@/lib/hooks/useOnboardingGuard";
import { AppShell } from "@/components/layout/app-shell";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { KpiCard, KpiCardSkeleton } from "@/components/dashboard/KpiCard";
import { SalesTrendChart } from "@/components/dashboard/SalesTrendChart";
import { useDashboardData, DashboardAlert } from "@/lib/api/hooks/useDashboard";
import { ANALYTICS_EVENTS, trackClick, engagementEvents } from "@/lib/analytics";
import { useOrders } from "@/lib/api/hooks/useOrders";
import { useCurrentRoleWithLoading } from "@/lib/hooks/use-current-role";
import { SalesRepView } from "@/components/dashboard/SalesRepView";
import { AccountantView } from "@/components/dashboard/AccountantView";
import { WarehouseView } from "@/components/dashboard/WarehouseView";
import { DriverView } from "@/components/dashboard/DriverView";
import { ManagerView } from "@/components/dashboard/ManagerView";
import CustomerView from "@/components/dashboard/CustomerView";
// import { RiskiestRetailersPanel } from "@/components/dashboard/RiskiestRetailersPanel";

// â”€â”€ Formatters â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function fmt(val: string | number | null | undefined, compact = false): string {
  if (val == null) return "—";
  const n = typeof val === "string" ? parseFloat(val) : (val as number);
  if (isNaN(n)) return String(val);
  if (compact) {
    if (n >= 10_00_000) return "₹" + (n / 10_00_000).toFixed(1) + "Cr";
    if (n >= 1_00_000)  return "₹" + (n / 1_00_000).toFixed(1) + "L";
    if (n >= 1_000)     return "₹" + (n / 1_000).toFixed(1) + "K";
  }
  return "₹" + n.toLocaleString("en-IN", { maximumFractionDigits: 0 });
}

function fmtDate(iso: string) {
  try { return new Date(iso).toLocaleDateString("en-IN", { day: "2-digit", month: "short" }); }
  catch { return iso; }
}

function greeting(name: string) {
  const h = new Date().getHours();
  const salutation = h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening";
  return `${salutation}, ${name} 👋`;
}

function today() {
  return new Date().toLocaleDateString("en-IN", { weekday: "long", day: "numeric", month: "long", year: "numeric" });
}

// â”€â”€ Status badge â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const STATUS_VARIANTS: Record<string, "warning" | "secondary" | "default" | "success" | "danger"> = {
  submitted: "warning",
  draft: "secondary",
  on_hold: "danger",
  approved: "default",
  confirmed: "default",
  dispatched: "default",
  delivered: "success",
  cancelled: "danger",
};

// â”€â”€ Alert ribbon â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const ALERT_ICONS: Record<string, React.ElementType> = {
  on_hold:   Clock,
  pending:   AlertCircle,
  overdue:   CreditCard,
  low_stock: Package,
  blocked:   Ban,
};

const ALERT_BG: Record<string, string> = {
  high:   "bg-red-50 border-red-200 text-red-700",
  medium: "bg-amber-50 border-amber-200 text-amber-700",
  low:    "bg-blue-50 border-blue-200 text-blue-700",
};

function AlertRibbon({ alerts }: { alerts: DashboardAlert[] }) {
  if (!alerts.length) return null;
  return (
    <div className="flex flex-wrap gap-2 mb-5">
      {alerts.map((a) => {
        const Icon = ALERT_ICONS[a.type] ?? AlertTriangle;
        return (
          <Link
            key={a.type}
            href={a.href}
            onClick={() => trackClick(ANALYTICS_EVENTS.DASHBOARD_ALERT_CLICKED, {
              alert_type: a.type,
              severity:   a.severity as "high" | "medium" | "low",
              count:      a.count,
              page:       "/dashboard",
              module:     "dashboard",
            })}
            className={`flex items-center gap-2 rounded-lg border px-3 py-2 text-sm font-medium transition-opacity hover:opacity-80 ${ALERT_BG[a.severity]}`}
          >
            <Icon className="h-4 w-4 shrink-0" />
            <span className="font-bold">{a.count}</span>&nbsp;{a.label}
          </Link>
        );
      })}
    </div>
  );
}

// â”€â”€ Order pipeline mini-donut (SVG progress rings) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// ── Dashboard fetch-error banner ────────────────────────────────────────────
function DashboardErrorBanner({ onRetry }: { onRetry: () => void }) {
  return (
    <div className="mb-5 flex items-center justify-between rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
      <div className="flex items-center gap-2">
        <AlertTriangle className="h-4 w-4 shrink-0" />
        <span>Unable to load dashboard data. Check your connection and try again.</span>
      </div>
      <button
        onClick={onRetry}
        className="ml-4 shrink-0 rounded-lg border border-red-300 bg-white px-3 py-1 text-xs font-medium text-red-700 hover:bg-red-50 transition-colors"
      >
        Retry
      </button>
    </div>
  );
}

// ── Order pipeline mini-donut (SVG progress rings)
function PipelineRing({ label, count, color, icon: Icon }: { label: string; count: number; color: string; icon: React.ElementType }) {
  return (
    <div className="flex flex-col items-center gap-1">
      <span className={`flex h-10 w-10 items-center justify-center rounded-full ${color}`}>
        <Icon className="h-5 w-5" />
      </span>
      <p className="text-xl font-bold text-text-primary">{count}</p>
      <p className="text-xs text-text-secondary text-center">{label}</p>
    </div>
  );
}

// â”€â”€ Top-N table â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
function TopTable<T extends { id: number; name: string }>({
  title, rows, renderSub, renderRight, href,
}: {
  title: string;
  rows: T[];
  renderSub: (r: T) => string;
  renderRight: (r: T) => string;
  href: string;
}) {
  return (
    <Card className="flex flex-col">
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <CardTitle className="text-sm font-semibold">{title}</CardTitle>
        <Link href={href} className="flex items-center text-xs text-accent hover:underline">
          View all <ChevronRight className="h-3 w-3" />
        </Link>
      </CardHeader>
      <CardContent className="p-0 flex-1">
        {rows.length === 0 ? (
          <p className="px-5 py-6 text-sm text-text-secondary text-center">No data yet</p>
        ) : (
          <ol className="divide-y divide-border">
            {rows.map((r, i) => (
              <li key={r.id} className="flex items-center gap-3 px-4 py-2.5 hover:bg-background-subtle transition-colors">
                <span className="w-5 text-center text-xs font-bold text-text-secondary">{i + 1}</span>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-text-primary truncate">{r.name}</p>
                  <p className="text-xs text-text-secondary">{renderSub(r)}</p>
                </div>
                <p className="text-sm font-semibold text-text-primary whitespace-nowrap">{renderRight(r)}</p>
              </li>
            ))}
          </ol>
        )}
      </CardContent>
    </Card>
  );
}

// â”€â”€ Dashboard â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
export default function DashboardPage() {
  const isReady = useOnboardingGuard();
  const router  = useRouter();

  const { data, isLoading, isError, refetch } = useDashboardData();
  const { data: ordersData, isLoading: ordersLoading } = useOrders({ per_page: 3, sort: "created_at_desc" });
  const { role, loading: roleLoading } = useCurrentRoleWithLoading();

  // Track dashboard view
  useEffect(() => {
    if (isReady && !roleLoading && role) {
      const metricsLoaded: Record<string, number> = {
        orders: ordersData?.data?.length ?? 0,
        alerts: data?.alerts?.length ?? 0,
      };
      engagementEvents.viewDashboard("main", role ?? "user", metricsLoaded);
    }
  }, [isReady, roleLoading, role, ordersData, data]);

  // Show loading skeleton only while auth is hydrating
  if (!isReady) {
    return (
      <AppShell title="Dashboard">
        <div className="space-y-5">
          <div className="h-7 w-56 rounded bg-gray-100 animate-pulse mb-4" />
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
            {[1,2,3,4,5].map(i => <KpiCardSkeleton key={i} />)}
          </div>
          <div className="h-64 rounded-xl bg-gray-100 animate-pulse" />
        </div>
      </AppShell>
    );
  }

  const orders = ordersData?.data ?? [];

  // Derived sparkline: last 14 days of orders_value for revenue KPI
  const spark14 = (data?.timeseries ?? []).slice(-14).map(d => d.orders_value);

  return (
    <AppShell title="Dashboard">

      {/* â”€â”€ Greeting header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
      <div className="flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between mb-5">
        <div>
          {isLoading ? (
            <div className="h-7 w-56 rounded bg-gray-100 animate-pulse mb-1" />
          ) : (
            <h1 className="text-xl font-bold text-text-primary">
              {data ? greeting(data.greeting_name) : "Welcome back"}
            </h1>
          )}
          <p className="text-sm text-text-secondary"> Today: {(data?.orders.today ?? 0)} Order{(data?.orders.today ?? 0) !== 1 ? "s" : ""} • {fmt(data?.collections.today, true)} Collected {((data?.orders.pending ?? 0) + (data?.orders.on_hold ?? 0)) > 0 && ` • ${(data?.orders.pending ?? 0) + (data?.orders.on_hold ?? 0)} Approval${((data?.orders.pending ?? 0) + (data?.orders.on_hold ?? 0)) !== 1 ? "s" : ""} Pending`}</p>
        </div>
        {(!role || role === "owner" || role === "admin" || role === "manager" || role === "sales_rep") && (
          <div className="flex gap-2 mt-3 sm:mt-0">
            <button
              onClick={() => router.push("/orders/new")}
              className="flex items-center gap-1.5 rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-white hover:bg-primary-700 transition-colors"
            >
              <Plus className="h-4 w-4" /> New Order
            </button>
          </div>
        )}
      </div>      
      {/* â”€â”€ Alert ribbon â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
      {/* ── Role-specific dashboard view ────────────────────────────────────── */}
      {role === "sales_rep" ? (
        <SalesRepView data={data} isLoading={isLoading || roleLoading} isError={isError} />
      ) : role === "manager" ? (
        <ManagerView data={data} isLoading={isLoading || roleLoading} isError={isError} />
      ) : role === "accountant" ? (
        <AccountantView data={data} isLoading={isLoading || roleLoading} isError={isError} />
      ) : role === "warehouse_staff" ? (
        <WarehouseView data={data} isLoading={isLoading || roleLoading} isError={isError} />
      ) : role === "driver" ? (
        <DriverView data={data} isLoading={isLoading || roleLoading} isError={isError} />
      ) : role === "customer" ? (
        <CustomerView data={data} isLoading={isLoading || roleLoading} isError={isError} />
      ) : (
        <>
          {!isLoading && data?.alerts && <AlertRibbon alerts={data.alerts} />}
          {isError && !isLoading && <DashboardErrorBanner onRetry={refetch} />}

      {/* â”€â”€ Primary KPI row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5 mb-5">
        <KpiCard
          label="Revenue (MTD)"
          value={isLoading ? "" : fmt(data?.revenue.mtd, true)}
          change={data?.revenue.delta_pct ?? undefined}
          icon={TrendingUp}
          color="green"
          sparklineData={spark14.length ? spark14 : undefined}
          loading={isLoading}
          error={isError}
        />
        <KpiCard
          label="Orders Today"
          value={isLoading ? "" : (data?.orders.today ?? 0).toLocaleString("en-IN")}
          icon={ShoppingCart}
          color="blue"
          loading={isLoading}
          error={isError}
        />
        <KpiCard
          label="Collections (MTD)"
          value={isLoading ? "" : fmt(data?.collections.mtd, true)}
          icon={Wallet}
          color="green"
          loading={isLoading}
          error={isError}
        />
        <KpiCard
          label="Outstanding"
          value={isLoading ? "" : fmt(data?.collections.outstanding, true)}
          icon={CreditCard}
          color={data && data.collections.overdue > 0 ? "red" : "amber"}
          loading={isLoading}
          error={isError}
        />
        <KpiCard
          label="Active Schemes"
          value={isLoading ? "" : (data?.active_schemes ?? 0).toString()}
          icon={Tag}
          color="amber"
          loading={isLoading}
          error={isError}
        />
      </div>

      {/* â”€â”€ Chart row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3 mb-5">

        {/* 30-day dual trend â€” takes 2/3 */}
        <Card className="lg:col-span-2">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-semibold">Orders vs Collections — Last 30 Days</CardTitle>
          </CardHeader>
          <CardContent>
            <SalesTrendChart
              data={data?.timeseries}
              loading={isLoading}
              error={isError}
            />
          </CardContent>
        </Card>

        {/* Order pipeline rings â€” takes 1/3 */}
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-semibold">Order Pipeline</CardTitle>
          </CardHeader>
          <CardContent>
            {isLoading ? (
              <div className="grid grid-cols-3 gap-4 py-4">
                {[1,2,3].map(i => <div key={i} className="flex flex-col items-center gap-2 animate-pulse"><div className="h-10 w-10 rounded-full bg-gray-100" /><div className="h-4 w-8 rounded bg-gray-100" /><div className="h-3 w-14 rounded bg-gray-100" /></div>)}
              </div>
            ) : (
              <>
                <div className="grid grid-cols-3 gap-4 py-4">
                  <PipelineRing label="Pending" count={data?.orders.pending ?? 0} color="bg-amber-100 text-amber-600" icon={Clock} />
                  <PipelineRing label="Approved" count={data?.orders.approved ?? 0} color="bg-blue-100 text-blue-600" icon={CheckCircle2} />
                  <PipelineRing label="On Hold" count={data?.orders.on_hold ?? 0} color="bg-red-100 text-red-600" icon={Ban} />
                </div>
                <div className="border-t border-border pt-3 grid grid-cols-2 gap-2 text-center">
                  <div>
                    <p className="text-lg font-bold text-text-primary">{(data?.orders.mtd ?? 0).toLocaleString("en-IN")}</p>
                    <p className="text-xs text-text-secondary">Orders MTD</p>
                  </div>
                  <div>
                    <p className="text-lg font-bold text-text-primary">{Number(data?.collections.collection_rate ?? 0).toFixed(1)}%</p>
                    <p className="text-xs text-text-secondary">Collection Rate</p>
                  </div>
                </div>
              </>
            )}
          </CardContent>
        </Card>
      </div>

      {/* â”€â”€ Top Lists row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3 mb-5">

        <TopTable
          title="Top Customers (MTD)"
          rows={data?.top_customers ?? []}
          renderSub={r => `${r.invoice_count} invoice${r.invoice_count !== 1 ? "s" : ""}`}
          renderRight={r => fmt(r.revenue_mtd, true)}
          href="/customers"
        />

        <TopTable
          title="Top Products (MTD)"
          rows={data?.top_products ?? []}
          renderSub={r => `${(r as unknown as { sku: string }).sku ?? ""} - ${(r as unknown as { qty_mtd: number }).qty_mtd?.toLocaleString("en-IN") ?? 0} units`}
          renderRight={r => fmt((r as unknown as { revenue_mtd: number }).revenue_mtd, true)}
          href="/products"
        />

        {/* Inventory + Credit snapshot */}
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-semibold">Risk Snapshot</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {isLoading ? (
              <div className="space-y-3">
                {[1,2,3,4,5,6].map(i => <div key={i} className="h-4 w-full rounded bg-gray-100 animate-pulse" />)}
              </div>
            ) : (
              <>
                <div>
                  <p className="text-xs font-semibold uppercase tracking-wide text-text-secondary mb-2">Inventory</p>
                  <div className="space-y-1.5">
                    <RiskRow label="Low Stock" value={data?.inventory.low_stock ?? 0} suffix="SKUs" href="/inventory/stock" warn={data ? data.inventory.low_stock > 0 : false} />
                    <RiskRow label="Zero Stock" value={data?.inventory.zero_stock ?? 0} suffix="SKUs" href="/inventory/stock" warn={data ? data.inventory.zero_stock > 0 : false} />
                    <RiskRow label="Dead Stock" value={data?.inventory.dead_stock ?? 0} suffix="SKUs" href="/inventory/stock" warn={false} />
                  </div>
                </div>
                <div>
                  <p className="text-xs font-semibold uppercase tracking-wide text-text-secondary mb-2">Credit</p>
                  <div className="space-y-1.5">
                    <RiskRow label="Risky Accounts" value={data?.credit.risky_accounts ?? 0} href="/approvals/credit-limits" warn={data ? data.credit.risky_accounts > 0 : false} />
                    <RiskRow label="Blocked" value={data?.credit.blocked_accounts ?? 0} href="/approvals/credit-limits" warn={data ? data.credit.blocked_accounts > 0 : false} />
                    <RiskRow label="Total Overdue" value={fmt(data?.credit.total_overdue, true)} href="/finance" warn={data ? (data.credit.total_overdue ?? 0) > 0 : false} />
                  </div>
                </div>
              </>
            )}
          </CardContent>
        </Card>
      </div>

      {/* ── Riskiest Retailers ─────────────────────────────────────────────────── */}
      {/* {(!role || role === "owner" || role === "admin" || role === "manager") && (
        <div className="mb-5">
          <RiskiestRetailersPanel />
        </div>
      )} */}

      {/* ── Recent Orders ──────────────────────────────────────────────────────── */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between pb-3">
          <CardTitle className="text-sm font-semibold">Recent Orders</CardTitle>
          <button
            onClick={() => router.push("/orders")}
            className="text-xs text-accent hover:underline font-medium flex items-center gap-0.5"
          >
            View all <ChevronRight className="h-3 w-3" />
          </button>
        </CardHeader>
        <CardContent className="p-0">
          {ordersLoading ? (
            <div className="divide-y divide-border">
              {[1,2,3,4,5].map(i => (
                <div key={i} className="flex items-center gap-3 px-5 py-3 animate-pulse">
                  <div className="h-4 w-24 rounded bg-gray-100" />
                  <div className="flex-1 h-4 w-32 rounded bg-gray-100" />
                  <div className="h-4 w-16 rounded bg-gray-100" />
                  <div className="h-5 w-20 rounded-full bg-gray-100" />
                </div>
              ))}
            </div>
          ) : orders.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 text-text-secondary">
              <ShoppingCart className="h-8 w-8 mb-3 opacity-40" />
              <p className="text-sm">No orders yet</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border bg-background-subtle">
                    <th className="px-5 py-2.5 text-left text-xs font-medium text-text-secondary">Order #</th>
                    <th className="px-5 py-2.5 text-left text-xs font-medium text-text-secondary">Customer</th>
                    <th className="px-5 py-2.5 text-right text-xs font-medium text-text-secondary">Amount</th>
                    <th className="px-5 py-2.5 text-left text-xs font-medium text-text-secondary">Status</th>
                    <th className="px-5 py-2.5 text-left text-xs font-medium text-text-secondary">Date</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {orders.map((order) => (
                    <tr
                      key={order.id}
                      onClick={() => router.push(`/orders/${order.id}`)}
                      className="hover:bg-background-subtle transition-colors cursor-pointer"
                    >
                      <td className="px-5 py-3 font-mono text-xs text-text-secondary">{order.order_number}</td>
                      <td className="px-5 py-3 font-medium text-text-primary">{order.customer?.name ?? "—"}</td>
                      <td className="px-5 py-3 text-right font-medium text-text-primary">{fmt(order.total_amount)}</td>
                      <td className="px-5 py-3">
                        <Badge variant={STATUS_VARIANTS[order.status] ?? "secondary"}>
                          {order.status.replace(/_/g, " ").replace(/^\w/, c => c.toUpperCase())}
                        </Badge>
                      </td>
                      <td className="px-5 py-3 text-text-secondary">{fmtDate(order.created_at)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>
        </>
      )}

    </AppShell>
  );
}

// â”€â”€ Risk row helper (inline to keep file single-concern) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
function RiskRow({
  label, value, suffix = "", href, warn,
}: {
  label: string;
  value: number | string;
  suffix?: string;
  href: string;
  warn: boolean;
}) {
  return (
    <Link
      href={href}
      className="flex items-center justify-between rounded px-2 py-1 hover:bg-background-subtle transition-colors text-sm group"
    >
      <span className="text-text-secondary group-hover:text-text-primary transition-colors">{label}</span>
      <span className={`font-semibold tabular-nums ${warn ? "text-danger" : "text-text-primary"}`}>
        {typeof value === "number" ? value.toLocaleString("en-IN") : value}
        {suffix && <span className="ml-1 text-xs font-normal text-text-secondary">{suffix}</span>}
      </span>
    </Link>
  );
}
