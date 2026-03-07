"use client";

import Link from "next/link";
import { Package, AlertTriangle, ArrowLeftRight, ShoppingBag, Layers, ChevronRight } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { KpiCard } from "@/components/dashboard/KpiCard";
import type { DashboardData, DashboardAlert } from "@/lib/api/hooks/useDashboard";

interface Props {
  data: DashboardData | undefined;
  isLoading: boolean;
  isError: boolean;
}

const INVENTORY_ALERT_TYPES = new Set(["low_stock"]);

const QUICK_LINKS = [
  { label: "View Inventory",      href: "/inventory",                  icon: Layers },
  { label: "Stock Transfer",      href: "/inventory/transfers/new",    icon: ArrowLeftRight },
  { label: "Receive Purchase",    href: "/purchases/receive",          icon: ShoppingBag },
  { label: "Stock Adjustment",    href: "/inventory/adjustments/new",  icon: Package },
  { label: "Suppliers",           href: "/suppliers",                  icon: ChevronRight },
];

const ALERT_BG: Record<string, string> = {
  high:   "bg-red-50 border-red-200 text-red-700",
  medium: "bg-amber-50 border-amber-200 text-amber-700",
  low:    "bg-blue-50 border-blue-200 text-blue-700",
};

function InventoryAlertRibbon({ alerts }: { alerts: DashboardAlert[] }) {
  const invAlerts = alerts.filter((a) => INVENTORY_ALERT_TYPES.has(a.type));
  if (!invAlerts.length) return null;
  return (
    <div className="flex flex-wrap gap-2">
      {invAlerts.map((a) => (
        <Link
          key={a.type}
          href={a.href}
          className={`flex items-center gap-2 rounded-lg border px-3 py-2 text-sm font-medium transition-opacity hover:opacity-80 ${ALERT_BG[a.severity]}`}
        >
          <AlertTriangle className="h-4 w-4 shrink-0" />
          <span className="font-bold">{a.count}</span>&nbsp;{a.label}
        </Link>
      ))}
    </div>
  );
}

export function WarehouseView({ data, isLoading, isError }: Props) {
  return (
    <div className="space-y-5">
      {/* ── KPI row ──────────────────────────────────────────────────────── */}
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <KpiCard
          label="Low Stock SKUs"
          value={isLoading ? "" : (data?.inventory.low_stock ?? 0).toLocaleString("en-IN")}
          icon={AlertTriangle}
          color={data && data.inventory.low_stock > 0 ? "amber" : "green"}
          loading={isLoading}
          error={isError}
        />
        <KpiCard
          label="Zero Stock SKUs"
          value={isLoading ? "" : (data?.inventory.zero_stock ?? 0).toLocaleString("en-IN")}
          icon={Package}
          color={data && data.inventory.zero_stock > 0 ? "red" : "green"}
          loading={isLoading}
          error={isError}
        />
        <KpiCard
          label="Dead Stock SKUs"
          value={isLoading ? "" : (data?.inventory.dead_stock ?? 0).toLocaleString("en-IN")}
          icon={Layers}
          color="blue"
          loading={isLoading}
          error={isError}
        />
      </div>

      {/* ── Alert ribbon (inventory only) ────────────────────────────────── */}
      {!isLoading && data?.alerts && <InventoryAlertRibbon alerts={data.alerts} />}

      {/* ── Body row: stock health + shortcuts ───────────────────────────── */}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">

        {/* Stock health summary */}
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-semibold">Stock Health</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            {isLoading ? (
              <div className="space-y-2">
                {[1, 2, 3].map((i) => <div key={i} className="h-7 rounded bg-gray-100 animate-pulse" />)}
              </div>
            ) : (
              <>
                <StockRow label="Low Stock"  value={data?.inventory.low_stock ?? 0}  href="/inventory/stock" severity="amber" />
                <StockRow label="Zero Stock" value={data?.inventory.zero_stock ?? 0} href="/inventory/stock" severity="red" />
                <StockRow label="Dead Stock" value={data?.inventory.dead_stock ?? 0} href="/inventory/stock" severity="none" />
              </>
            )}
          </CardContent>
        </Card>

        {/* Quick links */}
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-semibold">Quick Actions</CardTitle>
          </CardHeader>
          <CardContent className="p-0">
            <ul className="divide-y divide-border">
              {QUICK_LINKS.map(({ label, href, icon: Icon }) => (
                <li key={href}>
                  <Link
                    href={href}
                    className="flex items-center gap-3 px-5 py-3 hover:bg-background-subtle transition-colors text-sm group"
                  >
                    <Icon className="h-4 w-4 text-text-secondary group-hover:text-accent transition-colors" />
                    <span className="flex-1 text-text-primary">{label}</span>
                    <ChevronRight className="h-3.5 w-3.5 text-text-secondary group-hover:text-accent transition-colors" />
                  </Link>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

// ── Internal helper ──────────────────────────────────────────────────────────
function StockRow({
  label, value, href, severity,
}: {
  label: string;
  value: number;
  href: string;
  severity: "red" | "amber" | "none";
}) {
  const textColor =
    severity === "red"   ? (value > 0 ? "text-danger" : "text-text-primary") :
    severity === "amber" ? (value > 0 ? "text-amber-600" : "text-text-primary") :
    "text-text-primary";

  return (
    <Link
      href={href}
      className="flex items-center justify-between rounded px-2 py-1.5 hover:bg-background-subtle transition-colors text-sm group"
    >
      <span className="text-text-secondary group-hover:text-text-primary transition-colors">{label}</span>
      <span className={`font-semibold tabular-nums ${textColor}`}>
        {value.toLocaleString("en-IN")}
        <span className="ml-1 text-xs font-normal text-text-secondary">SKUs</span>
      </span>
    </Link>
  );
}
