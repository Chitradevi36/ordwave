"use client";

import { AppShell } from "@/components/layout/app-shell";
import { WorkspaceHeader } from "@/components/workspace/WorkspaceHeader";
import { WorkspaceKpis, WorkspaceActions, WorkspaceActivity } from "@/components/workspace/WorkspaceWidgets";
import { WORKSPACE_CONFIGS } from "@/components/workspace/workspace.config";
import { useCurrentRole } from "@/lib/hooks/use-current-role";
import { useOverviewStats, useSalesStats, useWorkspaceActivity, fmtINR } from "@/lib/hooks/use-workspace-stats";
import { ShoppingCart, FileText, Users, CheckCircle2, Plus, BarChart2, ClipboardCheck, DollarSign } from "lucide-react";

const config = WORKSPACE_CONFIGS.sales;

const QUICK_ACTIONS = [
  { label: "View Orders", icon: FileText, href: "/orders", description: "Browse sales orders" },
  { label: "Create Order", icon: Plus, href: "/orders/new", description: "Create a new sales order" },
  { label: "View Customers", icon: Users, href: "/customers", description: "Browse customer accounts" },
  { label: "Review Approvals", icon: ClipboardCheck, href: "/approvals", description: "Process pending approvals" },
  { label: "Track Deliveries", icon: CheckCircle2, href: "/delivery", description: "Monitor dispatch progress" },
  { label: "View Insights", icon: BarChart2, href: "/insights/sales", description: "Review sales analytics" },
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