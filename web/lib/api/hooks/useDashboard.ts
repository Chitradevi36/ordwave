import { useQuery } from "@tanstack/react-query";
import { apiClient } from "../client";

// ── Types ────────────────────────────────────────────────────────────────────
export interface DashboardSummary {
  total_orders: number;
  active_customers: number;
  total_products: number;
  revenue_mtd: number;
  pending_orders: number;
  overdue_amount: number;
  low_stock_skus: number;
}

export interface SalesTrendPoint {
  date: string;
  revenue: number;
}

export interface OrderStatusBreakdown {
  status: string;
  count: number;
}

// ── Dashboard KPI summary ────────────────────────────────────────────────────
export function useDashboardSummary() {
  return useQuery<DashboardSummary>({
    queryKey: ["analytics", "dashboard_summary"],
    queryFn: async () => {
      const { data } = await apiClient.get<{ data: DashboardSummary }>(
        "/api/v1/analytics/overview"
      );
      return data.data;
    },
    staleTime: 30_000,
  });
}

// ── Sales trend (last 30 days) ────────────────────────────────────────────────
export function useSalesTrend() {
  return useQuery<SalesTrendPoint[]>({
    queryKey: ["analytics", "sales_trend"],
    queryFn: async () => {
      const { data } = await apiClient.get("/api/v1/analytics/sales");
      // Handle both { data: [...] } and plain array responses
      const payload = data?.data ?? data;
      return Array.isArray(payload) ? (payload as SalesTrendPoint[]) : [];
    },
    staleTime: 60_000,
  });
}

// ── Order status breakdown ────────────────────────────────────────────────────
export function useOrderStatusBreakdown() {
  return useQuery<OrderStatusBreakdown[]>({
    queryKey: ["analytics", "order_status_breakdown"],
    queryFn: async () => {
      const { data } = await apiClient.get("/api/v1/analytics/overview");
      const payload = data?.data ?? data;
      const breakdown = payload?.order_status_breakdown ?? payload;
      return Array.isArray(breakdown) ? (breakdown as OrderStatusBreakdown[]) : [];
    },
    staleTime: 60_000,
  });
}
