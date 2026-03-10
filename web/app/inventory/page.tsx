"use client";

import { useRouter } from "next/navigation";
import { AppShell } from "@/components/layout/app-shell";
import { WorkspaceHeader } from "@/components/workspace/WorkspaceHeader";
import { WorkspaceKpis, WorkspaceSections, WorkspaceActivity } from "@/components/workspace/WorkspaceWidgets";
import { WORKSPACE_CONFIGS } from "@/components/workspace/workspace.config";
import { useCurrentRole } from "@/lib/hooks/use-current-role";
import { useOverviewStats, useWorkspaceActivity } from "@/lib/hooks/use-workspace-stats";
import { Button } from "@/components/ui/button";
import { Layers, AlertTriangle, Package, Archive, ArrowLeftRight, ShoppingBag, Users2, Plus } from "lucide-react";

const config = WORKSPACE_CONFIGS.inventory;

const SECTIONS = [
  { label: "Stock",      description: "Current stock levels across all products",  href: "/inventory/stock",    icon: Package },
  { label: "Transfers",  description: "Move stock between branches",               href: "/inventory/transfers", icon: ArrowLeftRight },
  { label: "Purchases",  description: "Purchase invoices and goods received",      href: "/purchases/invoices", icon: ShoppingBag },
  { label: "Suppliers",  description: "Manage vendors and supplier details",       href: "/suppliers",          icon: Users2 },
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

  const router = useRouter();

  return (
    <AppShell noPad hideBreadcrumb>
      <WorkspaceHeader
        config={config}
        role={role}
        actions={
          <Button size="sm" onClick={() => router.push("/inventory/transfers/new")}>
            <Plus className="mr-2 h-4 w-4" />
            Create Transfer
          </Button>
        }
      />
      <div className="max-w-[1400px] mx-auto px-4 md:px-6 py-6 space-y-6">
        <WorkspaceKpis items={KPI_ITEMS} loading={loading} />
        <div className="grid gap-6 lg:grid-cols-3">
          <div className="lg:col-span-2">
            <WorkspaceSections sections={SECTIONS} title="Sections" />
          </div>
          <div>
            <WorkspaceActivity items={activityItems} loading={activityLoading} />
          </div>
        </div>
      </div>
    </AppShell>
  );
}