"use client";

import { AppShell } from "@/components/layout/app-shell";
import { WorkspaceHeader } from "@/components/workspace/WorkspaceHeader";
import { WorkspaceKpis, WorkspaceActions, WorkspaceActivity } from "@/components/workspace/WorkspaceWidgets";
import { WORKSPACE_CONFIGS } from "@/components/workspace/workspace.config";
import { useCurrentRole } from "@/lib/hooks/use-current-role";
import { useOverviewStats, useWorkspaceActivity } from "@/lib/hooks/use-workspace-stats";
import { Layers, Plus, ArrowLeftRight, ShoppingBag, AlertTriangle, Package, BarChart2, Archive } from "lucide-react";

const config = WORKSPACE_CONFIGS.inventory;

const QUICK_ACTIONS = [
  { label: "View Stock",        icon: Package,       href: "/inventory",                description: "Browse current stock levels" },
  { label: "Create Transfer",   icon: ArrowLeftRight,href: "/inventory/transfers/new",  description: "Move stock between branches" },
  { label: "View Transfers",    icon: ArrowLeftRight,href: "/inventory/transfers",      description: "Browse stock transfers" },
  { label: "View Purchases",    icon: ShoppingBag,   href: "/purchases/invoices",       description: "Browse purchase invoices" },
  { label: "Create Purchase",   icon: Plus,          href: "/purchases/invoices/new",   description: "Create a purchase invoice" },
  { label: "View Insights",     icon: BarChart2,     href: "/insights/inventory",       description: "Review inventory analytics" },
];

export default function InventoryPage() {
  const role = useCurrentRole();
  const { stats, loading } = useOverviewStats();
  const { items: activityItems, loading: activityLoading } = useWorkspaceActivity("inventory");
  const inv = stats?.inventory;

  const KPI_ITEMS = [
    {
      label: "Total SKUs",
      value: loading ? "—" : String(inv?.total_skus ?? 0),
      icon: Layers,
      color: "blue" as const,
    },
    {
      label: "Low Stock SKUs",
      value: loading ? "—" : String(inv?.low_stock_count ?? 0),
      icon: AlertTriangle,
      color: "amber" as const,
    },
    {
      label: "Zero Stock SKUs",
      value: loading ? "—" : String(inv?.zero_stock_count ?? 0),
      icon: Package,
      color: "red" as const,
    },
    {
      label: "Dead Stock SKUs",
      value: loading ? "—" : String(inv?.dead_stock_count ?? 0),
      icon: Archive,
      color: "purple" as const,
    },
  ];

  return (
    <AppShell noPad hideBreadcrumb>
      <WorkspaceHeader config={config} role={role} />
      <div className="max-w-[1400px] mx-auto px-4 md:px-6 py-6 space-y-6">
        <WorkspaceKpis items={KPI_ITEMS} loading={loading} />
        <div className="grid gap-6 lg:grid-cols-3">
          <div className="lg:col-span-2">
            <WorkspaceActions actions={QUICK_ACTIONS} />
          </div>
          <div>
            <WorkspaceActivity items={activityItems} loading={activityLoading} />
          </div>
        </div>
      </div>
    </AppShell>
  );
}