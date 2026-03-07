"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { ShoppingCart, Wallet, CreditCard, Plus, Users, MapPin, ChevronRight } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { KpiCard } from "@/components/dashboard/KpiCard";
import { SalesTrendChart } from "@/components/dashboard/SalesTrendChart";
import { useOrders } from "@/lib/api/hooks/useOrders";
import type { DashboardData } from "@/lib/api/hooks/useDashboard";

// ── Formatters ──────────────────────────────────────────────────────────────
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

interface Props {
  data: DashboardData | undefined;
  isLoading: boolean;
  isError: boolean;
}

export function SalesRepView({ data, isLoading, isError }: Props) {
  const router = useRouter();
  const { data: ordersData, isLoading: ordersLoading } = useOrders({ per_page: 5, sort: "created_at_desc" });
  const orders = ordersData?.data ?? [];

  // Sparkline: last 14 days of orders_value
  const spark14 = (data?.timeseries ?? []).slice(-14).map((d) => d.orders_value);

  return (
    <div className="space-y-5">
      {/* ── KPI row ──────────────────────────────────────────────────────── */}
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <KpiCard
          label="My Orders Today"
          value={isLoading ? "" : (data?.orders.today ?? 0).toLocaleString("en-IN")}
          icon={ShoppingCart}
          color="blue"
          sparklineData={spark14.length ? spark14 : undefined}
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
      </div>

      {/* ── Trend chart ──────────────────────────────────────────────────── */}
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-semibold">Orders vs Collections — Last 30 Days</CardTitle>
        </CardHeader>
        <CardContent>
          <SalesTrendChart data={data?.timeseries} loading={isLoading} error={isError} />
        </CardContent>
      </Card>

      {/* ── Action shortcuts ─────────────────────────────────────────────── */}
      <div className="flex flex-wrap gap-2">
        <button
          onClick={() => router.push("/orders/new")}
          className="flex items-center gap-1.5 rounded-lg bg-accent px-4 py-2 text-sm font-semibold text-white hover:bg-accent/90 transition-colors"
        >
          <Plus className="h-4 w-4" /> New Order
        </button>
        <Link
          href="/customers"
          className="flex items-center gap-1.5 rounded-lg border border-border bg-background px-4 py-2 text-sm font-medium text-text-primary hover:bg-background-subtle transition-colors"
        >
          <Users className="h-4 w-4" /> Customers
        </Link>
        <Link
          href="/beats"
          className="flex items-center gap-1.5 rounded-lg border border-border bg-background px-4 py-2 text-sm font-medium text-text-primary hover:bg-background-subtle transition-colors"
        >
          <MapPin className="h-4 w-4" /> Beat Plan
        </Link>
      </div>

      {/* ── Recent orders ────────────────────────────────────────────────── */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between pb-3">
          <CardTitle className="text-sm font-semibold">My Recent Orders</CardTitle>
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
              {[1, 2, 3, 4, 5].map((i) => (
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
                          {order.status.replace(/_/g, " ").replace(/^\w/, (c) => c.toUpperCase())}
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
    </div>
  );
}
