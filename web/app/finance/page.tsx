"use client";

import { useRouter } from "next/navigation";
import { AppShell } from "@/components/layout/app-shell";
import { WorkspaceHeader } from "@/components/workspace/WorkspaceHeader";
import { WorkspaceKpis, WorkspaceSections, WorkspaceActivity } from "@/components/workspace/WorkspaceWidgets";
import { WORKSPACE_CONFIGS } from "@/components/workspace/workspace.config";
import { useCurrentRole } from "@/lib/hooks/use-current-role";
import { useOverviewStats, useWorkspaceActivity, fmtINR } from "@/lib/hooks/use-workspace-stats";
import { Button } from "@/components/ui/button";
import { DollarSign, FileText, CreditCard, AlertCircle, TrendingUp, FileSpreadsheet, Plus } from "lucide-react";

const config = WORKSPACE_CONFIGS.finance;

const SECTIONS = [
  { label: "Collections",   description: "Record and track customer payments",       href: "/collections",      icon: DollarSign },
  { label: "Invoices",      description: "View and manage sales invoices",            href: "/sales-invoices",   icon: FileText },
  { label: "Credit Notes",  description: "Issue and track credit adjustments",        href: "/credit-notes",     icon: CreditCard },
  { label: "GST Export",    description: "Generate GSTR-1 and compliance reports",    href: "/compliance/gstr1", icon: FileSpreadsheet },
];

export default function FinancePage() {
  const role = useCurrentRole();
  const { stats, loading } = useOverviewStats();
  const { items: activityItems, loading: activityLoading } = useWorkspaceActivity("finance");
  const c = stats?.collections;

  const KPI_ITEMS = [
    {
      label: "Collections (MTD)",
      value: loading ? "—" : fmtINR(c?.payments_mtd ?? 0),
      trend: "up" as const,
      trendValue: `+${c?.collection_rate ?? 0}% rate`,
      icon: DollarSign,
      color: "green" as const,
    },
    {
      label: "Today's Collections",
      value: loading ? "—" : fmtINR(c?.payments_today ?? 0),
      icon: TrendingUp,
      color: "blue" as const,
    },
    {
      label: "Unpaid Invoices",
      value: loading ? "—" : String(c?.unpaid_invoices_count ?? 0),
      subValue: loading ? undefined : fmtINR(c?.unpaid_invoices_value ?? 0),
      icon: AlertCircle,
      color: "red" as const,
    },
    {
      label: "Collection Rate",
      value: loading ? "—" : `${c?.collection_rate ?? 0}%`,
      icon: CreditCard,
      color: "amber" as const,
    },
  ];

  const router = useRouter();

  return (
    <AppShell noPad hideBreadcrumb>
      <WorkspaceHeader
        config={config}
        role={role}
        actions={
          <Button size="sm" onClick={() => router.push("/collections/new")}>
            <Plus className="mr-2 h-4 w-4" />
            Record Collection
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