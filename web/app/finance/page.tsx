"use client";

import { AppShell } from "@/components/layout/app-shell";
import { WorkspaceHeader } from "@/components/workspace/WorkspaceHeader";
import { WorkspaceKpis, WorkspaceActions, WorkspaceActivity } from "@/components/workspace/WorkspaceWidgets";
import { WORKSPACE_CONFIGS } from "@/components/workspace/workspace.config";
import { useCurrentRole } from "@/lib/hooks/use-current-role";
import { useOverviewStats, useWorkspaceActivity, fmtINR } from "@/lib/hooks/use-workspace-stats";
import { DollarSign, FileText, CreditCard, Banknote, Plus, List, AlertCircle, TrendingUp, FileSpreadsheet, ReceiptText } from "lucide-react";

const config = WORKSPACE_CONFIGS.finance;

const QUICK_ACTIONS = [
  { label: "View Collections",    icon: DollarSign,       href: "/collections",              description: "Browse collection entries" },
  { label: "Record Collection",   icon: Plus,             href: "/collections/new",          description: "Capture a new payment" },
  { label: "View Invoices",       icon: FileText,         href: "/sales-invoices",           description: "Browse sales invoices" },
  { label: "View Credit Notes",   icon: CreditCard,       href: "/credit-notes",             description: "Review issued credit notes" },
  { label: "GSTR-1 Export",       icon: FileSpreadsheet,  href: "/compliance/gstr1",         description: "Generate & download GSTR-1" },
  { label: "Supplier Debit Notes",icon: ReceiptText,      href: "/supplier-debit-notes",     description: "Manage supplier debit notes" },
  { label: "Review Credit",       icon: Banknote,         href: "/approvals/credit-limits",  description: "Process credit limit approvals" },
  { label: "View Insights",       icon: List,             href: "/insights/collections",     description: "Review collections analytics" },
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