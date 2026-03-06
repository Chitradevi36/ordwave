"use client";

import { AppShell } from "@/components/layout/app-shell";
import { WorkspaceHeader } from "@/components/workspace/WorkspaceHeader";
import { WorkspaceKpis, WorkspaceActions, WorkspaceActivity } from "@/components/workspace/WorkspaceWidgets";
import { WORKSPACE_CONFIGS } from "@/components/workspace/workspace.config";
import { useCurrentRole } from "@/lib/hooks/use-current-role";
import { useCatalogStats, useWorkspaceActivity } from "@/lib/hooks/use-workspace-stats";
import { BookOpen, Plus, Tag, List, Package, Archive, BarChart2, CheckCircle } from "lucide-react";

const config = WORKSPACE_CONFIGS.catalog;

const QUICK_ACTIONS = [
  { label: "View Products",    icon: Package,  href: "/products",              description: "Browse product catalog" },
  { label: "Create Product",   icon: Plus,     href: "/products/new",          description: "Add a new product" },
  { label: "View Price Lists", icon: List,     href: "/products/price-lists",  description: "Manage price list versions" },
  { label: "View Schemes",     icon: Tag,      href: "/pricing/schemes",       description: "Manage discount schemes" },
  { label: "View Categories",  icon: BookOpen, href: "/products/categories",   description: "Browse product categories" },
  { label: "View Insights",    icon: BarChart2,href: "/insights/inventory",    description: "Review catalog-related analytics" },
];

export default function CatalogPage() {
  const role = useCurrentRole();
  const { data, loading } = useCatalogStats();
  const { items: activityItems, loading: activityLoading } = useWorkspaceActivity("catalog");

  const KPI_ITEMS = [
    {
      label: "Active Products",
      value: loading ? "—" : String(data?.active_products ?? 0),
      icon: Package,
      color: "blue" as const,
    },
    {
      label: "Price Lists",
      value: loading ? "—" : String(data?.price_lists ?? 0),
      icon: List,
      color: "purple" as const,
    },
    {
      label: "Active Schemes",
      value: loading ? "—" : String(data?.active_schemes ?? 0),
      icon: Tag,
      color: "green" as const,
    },
    {
      label: "Inactive Products",
      value: loading ? "—" : String(data?.inactive_products ?? 0),
      icon: Archive,
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