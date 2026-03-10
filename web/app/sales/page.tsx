"use client";

import { useRouter } from "next/navigation";
import { AppShell } from "@/components/layout/app-shell";
import { WorkspaceHeader } from "@/components/workspace/WorkspaceHeader";
import { WorkspaceKpis, WorkspaceSections, WorkspaceActivity } from "@/components/workspace/WorkspaceWidgets";
import { WORKSPACE_CONFIGS } from "@/components/workspace/workspace.config";
import { useCurrentRole } from "@/lib/hooks/use-current-role";
import { useOverviewStats, useSalesStats, useWorkspaceActivity, fmtINR } from "@/lib/hooks/use-workspace-stats";
import { Button } from "@/components/ui/button";
import { ShoppingCart, FileText, ClipboardCheck, DollarSign, Tag, Plus } from "lucide-react";

const config = WORKSPACE_CONFIGS.sales;

const SECTIONS = [
  { label: "Orders",    description: "View and manage all sales orders",         href: "/orders",          icon: FileText },
  { label: "Approvals", description: "Review orders pending approval",           href: "/approvals",       icon: ClipboardCheck },
  { label: "Pricing",   description: "Manage price lists and customer pricing",  href: "/products/price-lists", icon: DollarSign },
  { label: "Schemes",   description: "Configure discount and promotion schemes", href: "/pricing/schemes", icon: Tag },
];

export default function SalesPage() {
  const role = useCurrentRole();
  const { stats, loading: overviewLoading } = useOverviewStats();
  const { data: salesData, loading: salesLoading } = useSalesStats();
  const { items: activityItems, loading: activityLoading } = useWorkspaceActivity("sales");
  const loading = overviewLoading || salesLoading;
  const sales = stats?.sales;

  const KPI_ITEMS = [
    {
      label: "Orders Today",
      value: loading ? "—" : String(sales?.count ?? 0),
      icon: ShoppingCart,
      color: "blue" as const,
    },
    {
      label: "Pending Approvals",
      value: loading ? "—" : String(salesData?.pending_approvals ?? 0),
      icon: ClipboardCheck,
      color: "amber" as const,
    },
    {
      label: "Open Orders",
      value: loading ? "—" : String(salesData?.open_orders ?? 0),
      icon: FileText,
      color: "red" as const,
    },
    {
      label: "Sales MTD",
      value: loading ? "—" : fmtINR(sales?.value ?? 0),
      trend: "up" as const,
      trendValue: loading ? undefined : `Avg ${fmtINR(sales?.avg ?? 0)}`,
      icon: DollarSign,
      color: "green" as const,
    },
  ];

  const router = useRouter();

  return (
    <AppShell noPad hideBreadcrumb>
      <WorkspaceHeader
        config={config}
        role={role}
        actions={
          <Button size="sm" onClick={() => router.push("/orders/new")}>
            <Plus className="mr-2 h-4 w-4" />
            Create Order
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