"use client";

import { useRouter } from "next/navigation";
import { AppShell } from "@/components/layout/app-shell";
import { WorkspaceHeader } from "@/components/workspace/WorkspaceHeader";
import { WorkspaceKpis, WorkspaceSections, WorkspaceActivity } from "@/components/workspace/WorkspaceWidgets";
import { WORKSPACE_CONFIGS } from "@/components/workspace/workspace.config";
import { useCurrentRole } from "@/lib/hooks/use-current-role";
import { useCatalogStats, useWorkspaceActivity } from "@/lib/hooks/use-workspace-stats";
import { Button } from "@/components/ui/button";
import { Package, List, Tag, BookOpen, Hash, Archive, Plus } from "lucide-react";

const config = WORKSPACE_CONFIGS.catalog;

const SECTIONS = [
  { label: "Products",    description: "Browse and manage your product catalog",     href: "/products",              icon: Package },
  { label: "Price Lists", description: "Manage price list versions and assignments",  href: "/products/price-lists",  icon: List },
  { label: "Schemes",     description: "Configure discount and promotion schemes",    href: "/pricing/schemes",        icon: Tag },
  { label: "Categories",  description: "Organise products into categories",           href: "/products/categories",   icon: BookOpen },
  { label: "HSN / SAC",   description: "Manage tax classification codes",             href: "/products/hsn-codes",    icon: Hash },
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

  const router = useRouter();

  return (
    <AppShell noPad hideBreadcrumb>
      <WorkspaceHeader
        config={config}
        role={role}
        actions={
          <Button size="sm" onClick={() => router.push("/products/new")}>
            <Plus className="mr-2 h-4 w-4" />
            Create Product
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