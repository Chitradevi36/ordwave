"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { AppShell } from "@/components/layout/app-shell";
import { WorkspaceHeader } from "@/components/workspace/WorkspaceHeader";
import { WorkspaceKpis, WorkspaceSections, WorkspaceActivity } from "@/components/workspace/WorkspaceWidgets";
import { WORKSPACE_CONFIGS } from "@/components/workspace/workspace.config";
import { useCurrentRole } from "@/lib/hooks/use-current-role";
import { useOperationsStats, useWorkspaceActivity } from "@/lib/hooks/use-workspace-stats";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  Truck, Plus, RotateCcw, MapPin, CheckCircle, Package, ClipboardList,
  AlertTriangle, ArrowDownToLine, TrendingUp, TrendingDown, SlidersHorizontal,
} from "lucide-react";
import { cn } from "@/lib/utils";

const config = WORKSPACE_CONFIGS.operations;

const SECTIONS = [
  { label: "Delivery Trips", description: "Plan, dispatch, and track delivery trips",  href: "/delivery",               icon: Truck },
  { label: "Returns",        description: "Review and process customer returns",        href: "/returns",                icon: RotateCcw },
  { label: "Exceptions",     description: "Resolve failed or flagged deliveries",      href: "/delivery/exceptions",   icon: AlertTriangle },
  { label: "Pick Lists",     description: "Warehouse order-picking tasks",             href: "/operations/pick-lists", icon: ClipboardList },
];

// ─── WarehouseView section ────────────────────────────────────────────────────
interface WarehouseStats {
  orders_to_pick:       number;
  trips_ready_dispatch: number;
  incoming_transfers:   number;
  low_stock_items:      number;
  movements_today: {
    units_in:       number;
    units_out:      number;
    units_adjusted: number;
  };
}

function WarehouseView({ stats, loading }: { stats: WarehouseStats | null; loading: boolean }) {
  const router = useRouter();

  const cards = [
    {
      label:   "Orders to Pick",
      value:   stats?.orders_to_pick ?? 0,
      icon:    ClipboardList,
      color:   "text-blue-600",
      bg:      "bg-blue-50",
      href:    "/operations/pick-lists?status=pending",
      caption: "Pending pick lists",
    },
    {
      label:   "Ready to Dispatch",
      value:   stats?.trips_ready_dispatch ?? 0,
      icon:    Truck,
      color:   "text-violet-600",
      bg:      "bg-violet-50",
      href:    "/delivery?status=planned",
      caption: "Planned trips awaiting dispatch",
    },
    {
      label:   "Incoming Transfers",
      value:   stats?.incoming_transfers ?? 0,
      icon:    ArrowDownToLine,
      color:   "text-emerald-600",
      bg:      "bg-emerald-50",
      href:    "/inventory/transfers?direction=incoming",
      caption: "Dispatched → this branch",
    },
    {
      label:   "Low Stock Items",
      value:   stats?.low_stock_items ?? 0,
      icon:    AlertTriangle,
      color:   stats?.low_stock_items ? "text-red-600" : "text-text-secondary",
      bg:      stats?.low_stock_items ? "bg-red-50" : "bg-surface-secondary",
      href:    "/inventory/stock?filter=low_stock",
      caption: "Below minimum threshold",
    },
  ];

  return (
    <div className="space-y-4">
      <h2 className="text-sm font-semibold text-text-secondary uppercase tracking-wide">
        Warehouse Overview
      </h2>

      {/* 4 metric cards */}
      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        {cards.map((c) => (
          <Card
            key={c.label}
            className="cursor-pointer hover:shadow-md transition-shadow"
            onClick={() => router.push(c.href)}
          >
            <CardContent className="p-4 flex gap-3 items-start">
              <div className={cn("p-2 rounded-lg shrink-0", c.bg)}>
                <c.icon className={cn("h-5 w-5", c.color)} />
              </div>
              <div className="min-w-0">
                <p className="text-2xl font-bold text-text-primary leading-none mt-0.5">
                  {loading ? "—" : c.value.toLocaleString("en-IN")}
                </p>
                <p className="text-xs font-medium text-text-primary mt-1 truncate">{c.label}</p>
                <p className="text-xs text-text-secondary truncate">{c.caption}</p>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Today's movements summary */}
      <Card>
        <CardContent className="p-4">
          <div className="flex items-center gap-2 mb-3">
            <SlidersHorizontal className="h-4 w-4 text-text-secondary" />
            <span className="text-sm font-medium text-text-primary">Today's Stock Movements</span>
          </div>
          <div className="grid grid-cols-3 gap-4 text-center">
            <div>
              <div className="flex items-center justify-center gap-1">
                <TrendingUp className="h-4 w-4 text-emerald-500" />
                <span className="text-lg font-bold text-text-primary">
                  {loading ? "—" : (stats?.movements_today?.units_in ?? 0).toLocaleString("en-IN")}
                </span>
              </div>
              <p className="text-xs text-text-secondary mt-0.5">Units In</p>
            </div>
            <div>
              <div className="flex items-center justify-center gap-1">
                <TrendingDown className="h-4 w-4 text-red-500" />
                <span className="text-lg font-bold text-text-primary">
                  {loading ? "—" : (stats?.movements_today?.units_out ?? 0).toLocaleString("en-IN")}
                </span>
              </div>
              <p className="text-xs text-text-secondary mt-0.5">Units Out</p>
            </div>
            <div>
              <div className="flex items-center justify-center gap-1">
                <SlidersHorizontal className="h-4 w-4 text-amber-500" />
                <span className="text-lg font-bold text-text-primary">
                  {loading ? "—" : (stats?.movements_today?.units_adjusted ?? 0).toLocaleString("en-IN")}
                </span>
              </div>
              <p className="text-xs text-text-secondary mt-0.5">Adjusted</p>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

export default function OperationsPage() {
  const router = useRouter();
  const role = useCurrentRole();
  const { data, loading } = useOperationsStats();
  const { items: activityItems, loading: activityLoading } = useWorkspaceActivity("operations");
  const { token, orgId } = useOrgBranch();

  const [warehouseStats,        setWarehouseStats]        = useState<WarehouseStats | null>(null);
  const [warehouseStatsLoading, setWarehouseStatsLoading] = useState(false);

  useEffect(() => {
    if (!token || !orgId) return;
    setWarehouseStatsLoading(true);
    fetch(`${API_URL}/api/v1/dashboard/warehouse_stats`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then((r) => r.json())
      .then((j) => setWarehouseStats(j.data ?? null))
      .catch(() => null)
      .finally(() => setWarehouseStatsLoading(false));
  }, [token, orgId]);

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
      <WorkspaceHeader
        config={config}
        role={role}
        actions={
          <Button size="sm" onClick={() => router.push("/delivery/new")}>
            <Plus className="mr-2 h-4 w-4" />
            Create Trip
          </Button>
        }
      />
      <div className="max-w-[1400px] mx-auto px-4 md:px-6 py-6 space-y-6">
        <WorkspaceKpis items={KPI_ITEMS} loading={loading} />
        <WarehouseView stats={warehouseStats} loading={warehouseStatsLoading} />
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