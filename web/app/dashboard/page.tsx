"use client";

import { useRouter } from "next/navigation";
import { Plus, ShoppingCart, Users, Package, TrendingUp, AlertCircle, CreditCard, AlertTriangle } from "lucide-react";
import { useOnboardingGuard } from "@/lib/hooks/useOnboardingGuard";
import { AppShell } from "@/components/layout/app-shell";
import { PageHeader } from "@/components/layout/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { KpiCard, KpiCardSkeleton } from "@/components/dashboard/KpiCard";
import { SalesTrendChart } from "@/components/dashboard/SalesTrendChart";
import { OrderStatusChart } from "@/components/dashboard/OrderStatusChart";
import { useDashboardSummary, useSalesTrend, useOrderStatusBreakdown } from "@/lib/api/hooks/useDashboard";
import { useOrders } from "@/lib/api/hooks/useOrders";

//  Status badge helper 
const STATUS_VARIANTS: Record<string, "warning" | "secondary" | "default" | "success" | "danger"> = {
  pending: "warning",
  draft: "secondary",
  approved: "default",
  confirmed: "default",
  dispatched: "default",
  delivered: "success",
  cancelled: "danger",
};

function formatAmount(val: string | number | null | undefined): string {
  if (val == null) return "";
  const n = typeof val === "string" ? parseFloat(val) : val;
  if (isNaN(n)) return String(val);
  return `?${n.toLocaleString("en-IN", { maximumFractionDigits: 0 })}`;
}

function formatRevenue(val: number | null | undefined): string {
  if (val == null) return "";
  if (val >= 100_000) return `?${(val / 100_000).toFixed(1)}L`;
  if (val >= 1_000)   return `?${(val / 1_000).toFixed(1)}K`;
  return `?${val}`;
}

function formatDate(iso: string) {
  try { return new Date(iso).toLocaleDateString("en-IN", { day: "2-digit", month: "short" }); }
  catch { return iso; }
}

//  Dashboard 
export default function DashboardPage() {
  const isReady = useOnboardingGuard();
  const router  = useRouter();

  const { data: summary, isLoading: summaryLoading, isError: summaryError } = useDashboardSummary();
  const { data: salesTrend, isLoading: salesLoading,  isError: salesError  } = useSalesTrend();
  const { data: orderBreakdown, isLoading: breakdownLoading, isError: breakdownError } = useOrderStatusBreakdown();
  const { data: ordersData, isLoading: ordersLoading } = useOrders({ per_page: 5 });

  if (!isReady) return null;

  const orders = ordersData?.data ?? [];

  return (
    <AppShell title="Dashboard">
      <PageHeader
        title="Dashboard"
        description="Welcome back. Here is what is happening today."
        actions={[{ label: "New Order", onClick: () => router.push("/orders/new"), icon: Plus }]}
      />

      {/*  KPI cards  */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4 mb-6">
        <KpiCard
          label="Total Orders"
          value={summaryLoading ? "" : (summary?.total_orders?.toLocaleString("en-IN") ?? "")}
          icon={ShoppingCart}
          color="green"
          loading={summaryLoading}
          error={summaryError}
        />
        <KpiCard
          label="Active Customers"
          value={summaryLoading ? "" : (summary?.active_customers?.toLocaleString("en-IN") ?? "")}
          icon={Users}
          color="blue"
          loading={summaryLoading}
          error={summaryError}
        />
        <KpiCard
          label="Products"
          value={summaryLoading ? "" : (summary?.total_products?.toLocaleString("en-IN") ?? "")}
          icon={Package}
          color="amber"
          loading={summaryLoading}
          error={summaryError}
        />
        <KpiCard
          label="Revenue (MTD)"
          value={summaryLoading ? "" : formatRevenue(summary?.revenue_mtd)}
          icon={TrendingUp}
          color="green"
          loading={summaryLoading}
          error={summaryError}
        />
      </div>

      {/*  Secondary KPI row  */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3 mb-6">
        <KpiCard
          label="Pending Orders"
          value={summaryLoading ? "" : (summary?.pending_orders?.toLocaleString("en-IN") ?? "")}
          icon={AlertCircle}
          color="amber"
          loading={summaryLoading}
          error={summaryError}
        />
        <KpiCard
          label="Overdue Amount"
          value={summaryLoading ? "" : formatRevenue(summary?.overdue_amount)}
          icon={CreditCard}
          color="red"
          loading={summaryLoading}
          error={summaryError}
        />
        <KpiCard
          label="Low Stock SKUs"
          value={summaryLoading ? "" : (summary?.low_stock_skus?.toLocaleString("en-IN") ?? "")}
          icon={AlertTriangle}
          color="red"
          loading={summaryLoading}
          error={summaryError}
        />
      </div>

      {/*  Charts row  */}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3 mb-6">
        {/* Sales trend  takes 2/3 width */}
        <Card className="lg:col-span-2">
          <CardHeader className="pb-2">
            <CardTitle className="text-base">Sales Trend (Last 30 Days)</CardTitle>
          </CardHeader>
          <CardContent>
            <SalesTrendChart data={salesTrend} loading={salesLoading} error={salesError} />
          </CardContent>
        </Card>

        {/* Order status donut  takes 1/3 width */}
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-base">Order Status</CardTitle>
          </CardHeader>
          <CardContent>
            <OrderStatusChart data={orderBreakdown} loading={breakdownLoading} error={breakdownError} />
          </CardContent>
        </Card>
      </div>

      {/*  Recent Orders table  */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between pb-3">
          <CardTitle className="text-base">Recent Orders</CardTitle>
          <button
            onClick={() => router.push("/orders")}
            className="text-sm text-accent hover:underline font-medium"
          >
            View all
          </button>
        </CardHeader>
        <CardContent className="p-0">
          {ordersLoading ? (
            <div className="divide-y divide-border">
              {[1, 2, 3, 4, 5].map(i => (
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
                    <th className="px-5 py-2.5 text-left text-xs font-medium text-text-secondary">Order ID</th>
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
                      <td className="px-5 py-3 font-medium text-text-primary">{order.customer?.name ?? ""}</td>
                      <td className="px-5 py-3 text-right font-medium text-text-primary">{formatAmount(order.total_amount)}</td>
                      <td className="px-5 py-3">
                        <Badge variant={STATUS_VARIANTS[order.status] ?? "secondary"}>
                          {order.status.charAt(0).toUpperCase() + order.status.slice(1)}
                        </Badge>
                      </td>
                      <td className="px-5 py-3 text-text-secondary">{formatDate(order.created_at)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>
    </AppShell>
  );
}
