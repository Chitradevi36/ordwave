"use client";

import { AppShell } from "@/components/layout/app-shell";
import { WorkspaceHeader } from "@/components/workspace/WorkspaceHeader";
import { WorkspaceKpis, WorkspaceActions, WorkspaceActivity } from "@/components/workspace/WorkspaceWidgets";
import { WORKSPACE_CONFIGS } from "@/components/workspace/workspace.config";
import { useCurrentRole } from "@/lib/hooks/use-current-role";
import { useOperationsStats, useWorkspaceActivity } from "@/lib/hooks/use-workspace-stats";
import { Truck, Plus, RotateCcw, MapPin, CheckCircle, AlertCircle, Package } from "lucide-react";

const config = WORKSPACE_CONFIGS.operations;

const QUICK_ACTIONS = [
  { label: "View Trips",     icon: Truck,      href: "/delivery",          description: "Track active delivery trips" },
  { label: "Create Trip",    icon: Plus,       href: "/delivery/new",       description: "Plan a new delivery trip" },
  { label: "View Returns",   icon: RotateCcw,  href: "/returns",            description: "Review return requests" },
  { label: "Create Return",  icon: Plus,       href: "/returns/new",        description: "Log a new return request" },
  { label: "Manage Zones",   icon: MapPin,     href: "/settings/fleet",     description: "Configure delivery zones" },
  { label: "View Purchases", icon: Package,    href: "/purchases/invoices", description: "Browse inbound purchase invoices" },
];

export default function OperationsPage() {
  const role = useCurrentRole();
  const { data, loading } = useOperationsStats();
  const { items: activityItems, loading: activityLoading } = useWorkspaceActivity("operations");

  const KPI_ITEMS = [
    {
      label: "Active Trips",
      value: loading ? "—" : String(data?.active_trips ?? 0),
      icon: Truck,
      color: "blue" as const,
    },
    {
      label: "Pending Stops",
      value: loading ? "—" : String(data?.pending_stops ?? 0),
      icon: MapPin,
      color: "amber" as const,
    },
    {
      label: "Open Returns",
      value: loading ? "—" : String(data?.returns_open ?? 0),
      icon: RotateCcw,
      color: "amber" as const,
    },
    {
      label: "Completed Today",
      value: loading ? "—" : String(data?.completed_today ?? 0),
      trend: "up" as const,
      icon: CheckCircle,
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