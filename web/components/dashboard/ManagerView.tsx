"use client";

import Link from "next/link";
import {
  CheckCircle2,
  Truck,
  AlertTriangle,
  ClipboardList,
  UsersRound,
  ShoppingCart,
  ChevronRight,
  Plus,
} from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { KpiCard } from "@/components/dashboard/KpiCard";
import { Badge } from "@/components/ui/badge";
import type { DashboardData } from "@/lib/api/hooks/useDashboard";
import { useApprovals } from "@/lib/api/hooks/useApprovals";

function fmt(val: number | null | undefined) {
  if (val == null) return "—";
  return val.toLocaleString("en-IN");
}

const QUICK_ACTIONS = [
  { label: "View All Orders",   href: "/orders",              icon: ShoppingCart },
  { label: "Create Trip",       href: "/delivery/trips/new",  icon: Truck },
  { label: "Auto-Create Trips", href: "/delivery/trips/auto", icon: Plus },
  { label: "Team Management",   href: "/settings/team",       icon: UsersRound },
];

interface Props {
  data: DashboardData | undefined;
  isLoading: boolean;
  isError: boolean;
}

export function ManagerView({ data, isLoading, isError }: Props) {
  const { data: approvals } = useApprovals();
  const pendingApprovals = approvals?.total_count ?? data?.orders?.on_hold ?? 0;

  return (
    <div className="space-y-5">
      {/* ── KPI row ──────────────────────────────────────────────────────── */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <Link href="/approvals" className="block group">
          <KpiCard
            label="Pending Approvals"
            value={isLoading ? "" : fmt(pendingApprovals)}
            icon={CheckCircle2}
            color={pendingApprovals > 0 ? "amber" : "green"}
            loading={isLoading}
            error={isError}
          />
        </Link>
        <KpiCard
          label="Active Trips"
          value="—"
          icon={Truck}
          color="blue"
          loading={isLoading}
          error={isError}
        />
        <KpiCard
          label="Orders Today"
          value={isLoading ? "" : fmt(data?.orders?.today)}
          icon={ShoppingCart}
          color="blue"
          loading={isLoading}
          error={isError}
        />
        <KpiCard
          label="Low Stock SKUs"
          value={isLoading ? "" : fmt(data?.inventory?.low_stock)}
          icon={AlertTriangle}
          color={(data?.inventory?.low_stock ?? 0) > 0 ? "amber" : "green"}
          loading={isLoading}
          error={isError}
        />
      </div>

      <div className="grid grid-cols-1 gap-5 lg:grid-cols-2">
        {/* ── Pending Approvals ────────────────────────────────────────── */}
        <Card>
          <CardHeader className="pb-2 flex flex-row items-center justify-between">
            <CardTitle className="text-sm font-semibold">Pending Approvals</CardTitle>
            <Link href="/approvals" className="text-xs text-accent hover:underline flex items-center gap-0.5">
              View all <ChevronRight size={12} />
            </Link>
          </CardHeader>
          <CardContent className="pt-0 space-y-2">
            {!approvals && isLoading && (
              <div className="space-y-2">
                {[1,2].map((i) => (
                  <div key={i} className="h-14 rounded-lg bg-background-subtle animate-pulse" />
                ))}
              </div>
            )}
            {approvals?.held_orders.slice(0, 3).map((order) => (
              <Link
                key={order.id}
                href="/approvals"
                className="flex items-center justify-between rounded-lg border border-border px-3 py-2.5 hover:bg-background-subtle transition-colors"
              >
                <div>
                  <p className="text-xs font-semibold text-text-primary">{order.order_number}</p>
                  <p className="text-xs text-text-secondary">{order.customer_name}</p>
                </div>
                <div className="text-right">
                  <p className="text-xs font-bold text-text-primary">
                    ₹{order.total_amount?.toLocaleString("en-IN")}
                  </p>
                  <Badge variant="warning" className="text-[10px] mt-0.5">On Hold</Badge>
                </div>
              </Link>
            ))}
            {approvals && approvals.held_orders.length === 0 && (
              <p className="text-xs text-text-secondary text-center py-4">No orders on hold</p>
            )}
          </CardContent>
        </Card>

        {/* ── Today's Trip Overview ─────────────────────────────────── */}
        <Card>
          <CardHeader className="pb-2 flex flex-row items-center justify-between">
            <CardTitle className="text-sm font-semibold">Today&apos;s Trips</CardTitle>
            <Link href="/delivery/trips" className="text-xs text-accent hover:underline flex items-center gap-0.5">
              Manage <ChevronRight size={12} />
            </Link>
          </CardHeader>
          <CardContent className="pt-0">
            <div className="grid grid-cols-3 gap-2">
              {[
              { label: "Active",    value: null as number | null | undefined,    color: "text-blue-600" },
              { label: "Completed", value: null as number | null | undefined,  color: "text-success" },
              { label: "Pending",   value: data?.orders?.pending,   color: "text-amber-600" },
              ].map(({ label, value, color }) => (
                <div key={label} className="text-center p-3 rounded-lg bg-background-subtle">
                  <p className={`text-2xl font-bold tabular-nums ${color}`}>
                    {isLoading ? "—" : fmt(value)}
                  </p>
                  <p className="text-xs text-text-secondary mt-0.5">{label}</p>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* ── Quick Actions ──────────────────────────────────────────────── */}
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-semibold">Quick Actions</CardTitle>
        </CardHeader>
        <CardContent className="pt-0">
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
            {QUICK_ACTIONS.map(({ label, href, icon: Icon }) => (
              <Link
                key={href}
                href={href}
                className="flex flex-col items-center gap-2 p-3 rounded-xl border border-border hover:bg-background-subtle hover:border-primary/20 transition-all text-center group"
              >
                <div className="w-9 h-9 rounded-lg bg-primary-50 text-primary flex items-center justify-center group-hover:bg-primary-100 transition-colors">
                  <Icon size={16} />
                </div>
                <span className="text-xs font-medium text-text-secondary group-hover:text-text-primary transition-colors leading-tight">
                  {label}
                </span>
              </Link>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* ── Order funnel link ─────────────────────────────────────────── */}
      <div className="flex items-center justify-between rounded-xl border border-border bg-background-subtle px-4 py-3">
        <div className="flex items-center gap-6 text-xs">
          {[
            { label: "Submitted",  value: data?.orders?.pending,    color: "bg-amber-400" },
            { label: "Approved",   value: data?.orders?.approved,   color: "bg-blue-400" },
            { label: "Dispatched", value: null as number | null | undefined, color: "bg-indigo-400" },
            { label: "Delivered",  value: null as number | null | undefined, color: "bg-green-400" },
          ].map(({ label, value, color }) => (
            <div key={label} className="flex items-center gap-1.5">
              <div className={`w-2 h-2 rounded-full ${color}`} />
              <span className="text-text-secondary">{label}</span>
              <span className="font-semibold text-text-primary tabular-nums">
                {isLoading ? "…" : fmt(value)}
              </span>
            </div>
          ))}
        </div>
        <Link href="/orders" className="text-xs text-accent hover:underline flex items-center gap-0.5 shrink-0">
          <ClipboardList size={12} /> View orders
        </Link>
      </div>
    </div>
  );
}
