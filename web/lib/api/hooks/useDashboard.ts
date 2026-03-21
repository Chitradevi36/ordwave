import { useQuery } from "@tanstack/react-query";
import { apiClient } from "../client";

// ── Types ────────────────────────────────────────────────────────────────────

export interface DashboardTimeseriesPoint {
  date: string;
  orders_value: number;
  collections: number;
}

export interface DashboardCustomer {
  id: number;
  name: string;
  code: string;
  invoice_count: number;
  revenue_mtd: number;
}

export interface DashboardProduct {
  id: number;
  name: string;
  sku: string;
  qty_mtd: number;
  revenue_mtd: number;
}

export interface DashboardAlert {
  type: string;
  severity: "high" | "medium" | "low";
  count: number;
  label: string;
  href: string;
}

export interface DashboardData {
  as_of: string;
  greeting_name: string;
  org_name: string;
  revenue: {
    mtd: number;
    prev_mtd: number;
    delta_pct: number | null;
    today_invoiced: number;
  };
  orders: {
    today: number;
    yesterday: number;
    mtd: number;
    on_hold: number;
    pending: number;
    approved: number;
  };
  collections: {
    today: number;
    mtd: number;
    outstanding: number;
    overdue: number;
    collection_rate: number;
  };
  inventory: {
    low_stock: number;
    dead_stock: number;
    zero_stock: number;
  };
  credit: {
    risky_accounts: number;
    blocked_accounts: number;
    total_overdue: number;
  };
  active_schemes: number;
  alerts: DashboardAlert[];
  timeseries: DashboardTimeseriesPoint[];
  top_customers: DashboardCustomer[];
  top_products: DashboardProduct[];
}

// ── Primary hook: single fetch for the entire dashboard ──────────────────────
import { useOrgBranch } from "@/lib/org-branch-context";

export function useDashboardData() {
  const { orgId, branchId } = useOrgBranch();
  
  return useQuery<DashboardData>({
    queryKey: ["dashboard", { orgId, branchId }],
    queryFn: async () => {
      const params = branchId ? { branch_id: branchId } : {};
      const { data } = await apiClient.get<{ data: DashboardData }>(
        "/api/v1/dashboard",
        { params }
      );
      return data.data;
    },
    staleTime: 3 * 60 * 1_000, // 3 min — matches backend cache TTL
    enabled: !!orgId,
  });
}

// ── Legacy re-exports (kept so old imports don't break until removed) ─────────
/** @deprecated Use useDashboardData() */
export const useDashboardSummary = useDashboardData;
/** @deprecated Use useDashboardData() */
export const useSalesTrend = useDashboardData;
/** @deprecated Use useDashboardData() */
export const useOrderStatusBreakdown = useDashboardData;
